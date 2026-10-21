/// Reading a receipt or an invoice (B2): who sold it, when, for how much.
///
/// Deterministic rules over rows, tested on invented receipts in the shapes
/// common in Bangladesh and tuned on real ones as they come. Every value it
/// returns is what the paper printed — a total is never worked out from the
/// line items, and a receipt with no labelled total gets no total rather
/// than a guess. The total and the date always ask for a look
/// ([ReceiptKeys.critical]): read wrong, they are wrong spending totals.
library;

import 'dart:ui' show Rect;

import '../domain/local_date.dart';
import '../domain/money.dart';
import '../intelligence/ocr_engine.dart';
import 'card_extractor.dart';
import 'document_lines.dart';

abstract final class ReceiptExtractor {
  /// Reads [blocks]. Amounts are in [defaultCurrency] unless the receipt
  /// prints another.
  static CardExtraction extract(
    List<OcrBlock> blocks, {
    String defaultCurrency = 'BDT',
  }) {
    final List<DocLine> rows = rowsOf(blocks);
    final String text = rows.map((DocLine r) => r.text).join('\n');
    final String currency = currencyOf(text) ?? defaultCurrency;

    final List<ExtractedField> fields = <ExtractedField>[
      ?_merchant(rows, blocks),
      ?_date(rows, blocks),
      ?_total(rows, blocks, currency),
      ?_invoiceNumber(rows, blocks),
    ];
    final ExtractedField? merchant = fields
        .where((ExtractedField f) => f.fieldKey == ReceiptKeys.merchant)
        .firstOrNull;
    final ExtractedField? category = _category(merchant?.value ?? '', text);
    if (category != null) fields.add(category);

    final Set<int> used = <int>{
      for (final ExtractedField f in fields) ...f.sourceBlockIndices,
    };
    return CardExtraction(
      fields: fields,
      unassignedBlockIndices: <int>[
        for (int i = 0; i < blocks.length; i++)
          if (!used.contains(i)) i,
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Total
  // -------------------------------------------------------------------------

  /// Labels that mean "this is what was paid", most certain first.
  static final RegExp _finalTotal = RegExp(
    r'\b(?:grand\s*total|net\s*(?:total|payable|amount)|total\s*payable|'
    r'amount\s*payable|payable\s*amount|total\s*due|amount\s*due|'
    r'bill\s*amount|total\s*bill)\b|সর্বমোট|মোট\s*প্রদেয়',
    caseSensitive: false,
  );

  static final RegExp _anyTotal = RegExp(
    r'\btotal(?:\s*amount)?\b|মোট',
    caseSensitive: false,
  );

  /// Totals of something else: never what was paid.
  static final RegExp _notTheTotal = RegExp(
    r'\b(?:sub\s*-?\s*total|total\s*(?:qty|quantity|items?|vat|tax|'
    r'discount|saving|savings|weight|pcs)|items?\s*total)\b',
    caseSensitive: false,
  );

  /// A number in a labelled row: grouped, with a fraction, or plain — a
  /// restaurant's "Total 900" counts once the label says it is the total.
  static final RegExp _amountInRow = RegExp(
    r'(?<![\d.,])\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?(?![\d])|'
    r'(?<![\d.,])\d+(?:\.\d{1,2})?(?![\d.,])',
  );

  static ExtractedField? _total(
    List<DocLine> rows,
    List<OcrBlock> blocks,
    String currency,
  ) {
    ExtractedField? read(DocLine row, double certainty, {DocLine? next}) {
      final String line = asciiDigits(row.text);
      final RegExpMatch? label =
          _finalTotal.firstMatch(line) ?? _anyTotal.firstMatch(line);
      if (label == null) return null;
      // The amount is to the right of the label, or alone on the row below
      // when the paper wraps it.
      String? amount = _amountInRow
          .allMatches(line.substring(label.end))
          .map((RegExpMatch m) => m[0]!)
          .lastOrNull;
      DocLine source = row;
      if (amount == null && next != null) {
        final String below = asciiDigits(next.text);
        if (!RegExp(r'[A-Za-z]{3,}').hasMatch(below)) {
          amount = _amountInRow
              .allMatches(below)
              .map((RegExpMatch m) => m[0]!)
              .lastOrNull;
          source = next;
        }
      }
      if (amount == null) return null;
      final Money? money = Money.parse(amount, currency: currency);
      if (money == null || money.minor <= 0) return null;
      return ExtractedField(
        fieldKey: ReceiptKeys.total,
        value: money.format(),
        rawText: row == source ? row.text : '${row.text}\n${source.text}',
        normalizedValue: '${money.minor}',
        amountMinor: money.minor,
        currency: money.currency,
        confidence: certainty * _ocr(blocks, row),
        regionRect: _rect(
          row == source ? row.rect : row.rect.expandToInclude(source.rect),
        ),
        needsReview: true,
        sourceBlockIndices: <int>[
          ...row.blockIndices,
          if (source != row) ...source.blockIndices,
        ],
      );
    }

    // The last "grand total"-kind row wins: totals are printed after the
    // items, and cash and change come after the total but are not labelled
    // as one.
    for (int pass = 0; pass < 2; pass++) {
      for (int i = rows.length - 1; i >= 0; i--) {
        final String line = rows[i].text;
        if (_notTheTotal.hasMatch(line) && !_finalTotal.hasMatch(line)) {
          continue;
        }
        final bool strong = _finalTotal.hasMatch(line);
        if (pass == 0 && !strong) continue;
        if (pass == 1 && !_anyTotal.hasMatch(line)) continue;
        final ExtractedField? f = read(
          rows[i],
          pass == 0 ? 0.9 : 0.75,
          next: i + 1 < rows.length ? rows[i + 1] : null,
        );
        if (f != null) return f;
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Date
  // -------------------------------------------------------------------------

  static final RegExp _dateLabel = RegExp(
    r'\b(?:date|dated|invoice\s*date|bill\s*date|sale\s*date)\b|তারিখ',
    caseSensitive: false,
  );

  /// Dates that are about something else than the purchase.
  static final RegExp _otherDate = RegExp(
    r'\b(?:warranty|expir|valid|due\s*date|delivery|exp\b|mfg|best before)',
    caseSensitive: false,
  );

  static ExtractedField? _date(List<DocLine> rows, List<OcrBlock> blocks) {
    ExtractedField? from(DocLine row, double certainty) {
      if (_otherDate.hasMatch(row.text)) return null;
      final List<FoundDate> found = findDates(row.text);
      if (found.isEmpty) return null;
      final LocalDate day = found.first.date;
      return ExtractedField(
        fieldKey: ReceiptKeys.purchaseDate,
        value: formatDay(day),
        rawText: row.text,
        normalizedValue: day.toIso(),
        dateValue: day,
        confidence: certainty * _ocr(blocks, row),
        regionRect: _rect(row.rect),
        needsReview: true,
        sourceBlockIndices: row.blockIndices,
      );
    }

    for (final DocLine row in rows) {
      if (!_dateLabel.hasMatch(row.text)) continue;
      final ExtractedField? f = from(row, 0.9);
      if (f != null) return f;
    }
    for (final DocLine row in rows) {
      final ExtractedField? f = from(row, 0.7);
      if (f != null) return f;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Merchant
  // -------------------------------------------------------------------------

  /// Lines near the top that are about the receipt, not the shop's name.
  static final RegExp _notAName = RegExp(
    r'\b(?:invoice|receipt|cash\s*memo|bill|tax|vat|bin|mushak|reg\b|'
    r'date|time|tel|phone|mobile|hotline|email|www|road|house|floor|'
    r'level|shop\s*(?:no\.?|#)\s*[:#]?\s*\d|block|sector|dhaka|chattogram|'
    r'chittagong|sylhet|'
    r'customer|cashier|counter|table|order|token)\b|@|\d{5,}',
    caseSensitive: false,
  );

  static ExtractedField? _merchant(List<DocLine> rows, List<OcrBlock> blocks) {
    DocLine? best;
    for (final DocLine row in rows.take(6)) {
      final String t = row.text.trim();
      final int letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
      // A row with a price on it is an item, never the shop's name.
      if (letters < 3 ||
          _notAName.hasMatch(t) ||
          moneyPattern.hasMatch(asciiDigits(t))) {
        continue;
      }
      // The shop's name is usually the largest type at the top.
      if (best == null || row.height > best.height * 1.15) best = row;
    }
    if (best == null) return null;
    return ExtractedField(
      fieldKey: ReceiptKeys.merchant,
      value: best.text.trim(),
      confidence: 0.8 * _ocr(blocks, best),
      regionRect: _rect(best.rect),
      sourceBlockIndices: best.blockIndices,
    );
  }

  // -------------------------------------------------------------------------
  // Invoice number
  // -------------------------------------------------------------------------

  static final RegExp _invoice = RegExp(
    r'\b(?:invoice|inv|bill|receipt|order|memo|challan)\s*'
    r'(?:no\.?|number|#|id)?\s*[:#.\-]?\s*([A-Z0-9][A-Z0-9\-/]{2,})',
    caseSensitive: false,
  );

  static ExtractedField? _invoiceNumber(
    List<DocLine> rows,
    List<OcrBlock> blocks,
  ) {
    for (final DocLine row in rows) {
      for (final RegExpMatch m in _invoice.allMatches(row.text)) {
        final String id = m[1]!;
        // A date after "Bill" is not the bill's number, and a number needs a
        // digit in it.
        if (findDates(id).isNotEmpty || !RegExp(r'\d').hasMatch(id)) continue;
        return ExtractedField(
          fieldKey: ReceiptKeys.invoiceNumber,
          value: id,
          normalizedValue: id.toUpperCase(),
          confidence: 0.85 * _ocr(blocks, row),
          regionRect: _rect(row.rect),
          sourceBlockIndices: row.blockIndices,
        );
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Category
  // -------------------------------------------------------------------------

  static const Map<String, String> _categoryWords = <String, String>{
    r'tech|electronic|computer|laptop|mobile|digital|gadget|camera|'
            r'walton|samsung|lenovo|hp\b|dell|asus|xiaomi|vivo|oppo|realme':
        'Electronics',
    r'super\s*shop|mart|bazar|bazaar|grocery|shwapno|shopno|agora|meena|'
            r'unimart|daily\s*shopping':
        'Groceries',
    r'restaurant|cafe|café|kitchen|food|pizza|burger|biryani|kacchi|'
            r'bakery|sweets|coffee|tea':
        'Food and drink',
    r'pharma|pharmacy|medicine|drug|lazz|tamanna|hospital|clinic|'
            r'diagnostic':
        'Health',
    r'fashion|cloth|apparel|boutique|aarong|yellow|ecstasy|shoe|'
            r'footwear|bata|apex|tailor':
        'Clothing',
    r'fuel|filling\s*station|petrol|octane|cng|pathao|uber|bus|'
            r'airlines|biman|novoair|us-bangla|railway':
        'Transport',
    r'furniture|hatil|otobi|hardware|paint|sanitary': 'Home',
  };

  /// A guess from the shop's name and the receipt's words. Returned as a
  /// field like any other, but the storing code marks its origin
  /// *inferred*: it was not printed as a category.
  static ExtractedField? _category(String merchant, String text) {
    final String hay = '$merchant\n$text'.toLowerCase();
    for (final MapEntry<String, String> e in _categoryWords.entries) {
      if (RegExp('(?:${e.key})').hasMatch(hay)) {
        return ExtractedField(
          fieldKey: ReceiptKeys.category,
          value: e.value,
          confidence: 0.5,
          issue: kGuessedIssue,
        );
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------

  static double _ocr(List<OcrBlock> blocks, DocLine row) {
    final List<double> known = <double>[
      for (final int i in row.blockIndices)
        if (blocks[i].hasConfidence) blocks[i].confidence,
    ];
    if (known.isEmpty) return 0.7;
    return known.reduce((double a, double b) => a + b) / known.length;
  }

  static String _rect(Rect r) =>
      '${r.left.round()},${r.top.round()},${r.right.round()},${r.bottom.round()}';
}

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "5 Oct 2026" — how a stored day is shown as a field's text.
String formatDay(LocalDate d) =>
    '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
