/// Reading a warranty card or certificate (B2): what is covered, how to
/// identify it, and for how long.
///
/// The serial number matters most: it is the evidence that links a
/// warranty to its receipt (B3). The cover length and a printed expiry are
/// critical ([WarrantyKeys.critical]) — read wrong, the reminder comes too
/// late — so both always ask for a look. An expiry is only ever what the
/// paper prints here; a calculated one (purchase date plus the cover) is
/// B3's, and is labelled calculated.
library;

import 'dart:ui' show Rect;

import '../domain/local_date.dart';
import '../intelligence/ocr_engine.dart';
import 'card_extractor.dart';
import 'document_lines.dart';
import 'receipt_extractor.dart' show formatDay;

abstract final class WarrantyExtractor {
  static CardExtraction extract(List<OcrBlock> read) {
    final List<OcrBlock> blocks = withLeadingIRepaired(read);
    final List<DocLine> rows = rowsOf(blocks);
    final List<ExtractedField> fields = <ExtractedField>[
      ?_labelled(rows, blocks, WarrantyKeys.product, _productLabel),
      ?_labelled(rows, blocks, WarrantyKeys.brand, _brandLabel) ??
          _brandFromHeader(rows, blocks),
      ?_labelled(rows, blocks, WarrantyKeys.model, _modelLabel),
      ?_serial(rows, blocks),
      ?_cover(rows, blocks),
      ?_startBasis(rows, blocks),
      ?_dated(
        rows,
        blocks,
        WarrantyKeys.expiryDate,
        _expiryLabel,
        review: true,
      ),
      ?_dated(rows, blocks, WarrantyKeys.purchaseDate, _purchaseLabel),
    ];
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

  static RegExp _label(String words) =>
      RegExp('^\\s*(?:$words)\\s*[:\\-#.]?\\s*(.+)\$', caseSensitive: false);

  static final RegExp _productLabel = _label(
    r'product(?:\s*name)?|item(?:\s*name)?|description|goods|product\s*type',
  );
  static final RegExp _brandLabel = _label(r'brand|make|manufacturer');
  static final RegExp _modelLabel = _label(
    r'model(?:\s*(?:no\.?|number|name|#))?',
  );

  /// "Label: value" on one row, or the label alone with the value in the
  /// next column (which [rowsOf] has already joined).
  static ExtractedField? _labelled(
    List<DocLine> rows,
    List<OcrBlock> blocks,
    String key,
    RegExp label,
  ) {
    for (final DocLine row in rows) {
      final RegExpMatch? m = label.firstMatch(row.text);
      if (m == null) continue;
      final String value = m[1]!.trim();
      if (value.length < 2) continue;
      return ExtractedField(
        fieldKey: key,
        value: value,
        normalizedValue: key == WarrantyKeys.model ? value.toUpperCase() : null,
        confidence: 0.85 * _ocr(blocks, row),
        regionRect: _rect(row.rect),
        sourceBlockIndices: row.blockIndices,
      );
    }
    return null;
  }

  /// The brand is usually the logo line at the top: one or two words, not
  /// "Warranty Card".
  static ExtractedField? _brandFromHeader(
    List<DocLine> rows,
    List<OcrBlock> blocks,
  ) {
    for (final DocLine row in rows.take(2)) {
      final String t = row.text.trim();
      final List<String> words = t.split(RegExp(r'\s+'));
      if (words.length > 3 ||
          RegExp(
            r'warranty|guarantee|certificate|card|customer',
            caseSensitive: false,
          ).hasMatch(t) ||
          !RegExp(r'[A-Za-z]{2,}').hasMatch(t)) {
        continue;
      }
      return ExtractedField(
        fieldKey: WarrantyKeys.brand,
        value: t,
        confidence: 0.6 * _ocr(blocks, row),
        regionRect: _rect(row.rect),
        sourceBlockIndices: row.blockIndices,
      );
    }
    return null;
  }

  static final RegExp _serialPattern = RegExp(
    r'\b(?:serial(?:\s*(?:no\.?|number|#))?|s\s*/\s*n|sl\.?\s*no\.?|'
    r'imei(?:\s*(?:no\.?|1|#))?)\s*[:#.\-]?\s*([A-Z0-9][A-Z0-9\-]{4,})',
    caseSensitive: false,
  );

  static ExtractedField? _serial(List<DocLine> rows, List<OcrBlock> blocks) {
    for (final DocLine row in rows) {
      final RegExpMatch? m = _serialPattern.firstMatch(asciiDigits(row.text));
      if (m == null) continue;
      final String serial = m[1]!;
      // A serial has digits in it; "SERIES" or "NUMBER" does not.
      if (!RegExp(r'\d').hasMatch(serial)) continue;
      return ExtractedField(
        fieldKey: WarrantyKeys.serial,
        value: serial,
        normalizedValue: serial.toUpperCase().replaceAll('-', ''),
        confidence: 0.9 * _ocr(blocks, row),
        regionRect: _rect(row.rect),
        sourceBlockIndices: row.blockIndices,
      );
    }
    return null;
  }

  static final RegExp _coverContext = RegExp(
    r'warranty|guarantee|period|cover|valid|service|ওয়ারেন্টি',
    caseSensitive: false,
  );

  static final RegExp _duration = RegExp(
    r'\b(\d{1,2})\s*(years?|yrs?|months?|mos?|মাস|বছর)',
    caseSensitive: false,
  );

  /// The length of cover, as months. The first period on a warranty row —
  /// "5 Years Compressor, 1 Year Parts" is read as five years and flagged,
  /// because a split cover is exactly what a person should look at.
  static ExtractedField? _cover(List<DocLine> rows, List<OcrBlock> blocks) {
    for (final DocLine row in rows) {
      final String line = asciiDigits(row.text);
      if (!_coverContext.hasMatch(line)) continue;
      final List<RegExpMatch> periods = _duration.allMatches(line).toList();
      if (periods.isEmpty) continue;
      final RegExpMatch m = periods.first;
      final int n = int.parse(m[1]!);
      final String unit = m[2]!.toLowerCase();
      final bool years = unit.startsWith('y') || unit == 'বছর';
      final int months = years ? n * 12 : n;
      if (months <= 0 || months > 240) continue;
      return ExtractedField(
        fieldKey: WarrantyKeys.coverMonths,
        value: years
            ? '$n ${n == 1 ? 'year' : 'years'}'
            : '$n ${n == 1 ? 'month' : 'months'}',
        rawText: row.text,
        normalizedValue: '$months',
        confidence: 0.85 * _ocr(blocks, row),
        regionRect: _rect(row.rect),
        needsReview: true,
        issue: periods.length > 1 ? 'split_cover' : null,
        sourceBlockIndices: row.blockIndices,
      );
    }
    return null;
  }

  static final RegExp _basis = RegExp(
    r'from\s+(?:the\s+)?(?:date\s+of\s+)?(purchase|delivery|installation|'
    r'invoice|sale|activation)',
    caseSensitive: false,
  );

  static ExtractedField? _startBasis(
    List<DocLine> rows,
    List<OcrBlock> blocks,
  ) {
    for (final DocLine row in rows) {
      final RegExpMatch? m = _basis.firstMatch(row.text);
      if (m == null) continue;
      final String basis = m[1]!.toLowerCase();
      return ExtractedField(
        fieldKey: WarrantyKeys.startBasis,
        value: 'From the $basis',
        normalizedValue: basis,
        confidence: 0.8 * _ocr(blocks, row),
        regionRect: _rect(row.rect),
        sourceBlockIndices: row.blockIndices,
      );
    }
    return null;
  }

  static final RegExp _expiryLabel = RegExp(
    r'valid\s*(?:till|until|upto|up\s*to|thru|through)|expir|'
    r'warranty\s*(?:end|until|till|upto)|end\s*date|মেয়াদ',
    caseSensitive: false,
  );

  static final RegExp _purchaseLabel = RegExp(
    r'(?:date\s*of\s*(?:purchase|sale|invoice)|purchase(?:d)?\s*(?:date|on)|'
    r'sale\s*date|invoice\s*date|bought\s*on|ক্রয়ের\s*তারিখ)',
    caseSensitive: false,
  );

  static ExtractedField? _dated(
    List<DocLine> rows,
    List<OcrBlock> blocks,
    String key,
    RegExp label, {
    bool review = false,
  }) {
    for (final DocLine row in rows) {
      if (!label.hasMatch(row.text)) continue;
      final List<FoundDate> found = findDates(row.text);
      if (found.isEmpty) continue;
      final LocalDate day = found.last.date;
      return ExtractedField(
        fieldKey: key,
        value: formatDay(day),
        rawText: row.text,
        normalizedValue: day.toIso(),
        dateValue: day,
        confidence: 0.85 * _ocr(blocks, row),
        regionRect: _rect(row.rect),
        needsReview: review,
        sourceBlockIndices: row.blockIndices,
      );
    }
    return null;
  }

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
