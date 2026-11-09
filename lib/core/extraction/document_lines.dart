/// Reading paper that is laid out in rows: receipts, invoices, warranty
/// certificates (B2).
///
/// A business card is a handful of lines, each its own block. A receipt is
/// a table: "Grand Total" on the left and "8,450.00" on the right are the
/// same row, but OCR returns them as two blocks — and a label read without
/// its amount, or an amount without its label, is useless. So the first
/// step is to put the row back together.
library;

import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../domain/local_date.dart';
import '../intelligence/ocr_engine.dart';

/// One visual row of a document: the blocks that sit beside each other,
/// left to right.
class DocLine {
  const DocLine({
    required this.text,
    required this.blockIndices,
    required this.rect,
    required this.parts,
  });

  /// The row's blocks joined with spaces, left to right.
  final String text;

  /// Indices into the original block list, left to right.
  final List<int> blockIndices;

  /// The row's bounds.
  final Rect rect;

  /// Each block's own text, left to right — so a label and the amount in
  /// the next column can be told apart.
  final List<String> parts;

  double get height => rect.height;

  @override
  String toString() => text;
}

/// Groups [blocks] into rows, top to bottom.
///
/// Two blocks share a row when their vertical centres are closer than half
/// the smaller one's height. Lines that OCR already returned whole stay
/// whole; columns split by OCR come back together.
List<DocLine> rowsOf(List<OcrBlock> blocks) {
  final List<int> order = List<int>.generate(blocks.length, (int i) => i)
    ..sort(
      (int a, int b) =>
          blocks[a].rect.center.dy.compareTo(blocks[b].rect.center.dy),
    );

  final List<List<int>> rows = <List<int>>[];
  for (final int i in order) {
    final Rect r = blocks[i].rect;
    final List<int>? row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      final Rect last = _bounds(blocks, row);
      final double tolerance = math.min(last.height, r.height) / 2;
      if ((r.center.dy - last.center.dy).abs() <= tolerance) {
        row.add(i);
        continue;
      }
    }
    rows.add(<int>[i]);
  }

  return <DocLine>[
    for (final List<int> row in rows)
      () {
        row.sort(
          (int a, int b) => blocks[a].rect.left.compareTo(blocks[b].rect.left),
        );
        final List<String> parts = <String>[
          for (final int i in row) blocks[i].text.trim(),
        ];
        return DocLine(
          text: parts.where((String t) => t.isNotEmpty).join(' '),
          blockIndices: List<int>.unmodifiable(row),
          rect: _bounds(blocks, row),
          parts: parts,
        );
      }(),
  ];
}

Rect _bounds(List<OcrBlock> blocks, List<int> indices) => indices
    .map((int i) => blocks[i].rect)
    .reduce((Rect a, Rect b) => a.expandToInclude(b));

final RegExp _leadingL = RegExp(
  r'(?<![\w@./-])l([bcdfghjkmnpqrstvwxz][a-z]{2,})(?![\w@]|\.\w)',
);

/// Puts back a capital I that OCR read as a lowercase l at the start of a word.
///
/// In most sans-serif type the two letters are the same stroke, so "Islam"
/// arrives as "lslam", "Iqbal" as "lqbal" and "International" as
/// "lnternational". Left alone, a person's name fails the sentence-case test
/// and disappears, and a company's keyword is never matched. No English word
/// or common name starts with l and a consonant, apart from a double l, which
/// is why that is the whole test. Emails and web addresses are left exactly
/// as they were read.
String repairLeadingI(String text) =>
    text.replaceAllMapped(_leadingL, (Match m) => 'I${m[1]}');

/// [blocks] with [repairLeadingI] applied. The same object when nothing
/// changed. Every reader starts here; the blocks stored for the picker stay
/// as the engine returned them.
List<OcrBlock> withLeadingIRepaired(List<OcrBlock> blocks) {
  if (!blocks.any((OcrBlock b) => _leadingL.hasMatch(b.text))) return blocks;
  return <OcrBlock>[
    for (final OcrBlock b in blocks)
      OcrBlock(
        text: repairLeadingI(b.text),
        rect: b.rect,
        confidence: b.confidence,
        script: b.script,
        engine: b.engine,
      ),
  ];
}

/// Bangla digits as ASCII, so every pattern below sees one alphabet.
String asciiDigits(String s) {
  final StringBuffer out = StringBuffer();
  for (final int rune in s.runes) {
    out.writeCharCode(
      rune >= 0x09E6 && rune <= 0x09EF ? 0x30 + rune - 0x09E6 : rune,
    );
  }
  return out.toString();
}

const Map<String, int> _months = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// A date found in a line of text, and where.
class FoundDate {
  const FoundDate(this.date, this.start, this.end);
  final LocalDate date;
  final int start;
  final int end;
}

/// Every calendar date in [text], in order.
///
/// Numeric dates are read **day first** — 05/10/2026 is 5 October — which
/// is how Bangladeshi receipts and warranties print them. A year written
/// with two digits is 20xx. Also reads "12 Oct 2026", "12-Oct-26",
/// "Oct 12, 2026" and ISO "2026-10-12". Impossible days (31/02) are not
/// dates.
List<FoundDate> findDates(String text) {
  final String s = asciiDigits(text);
  final List<FoundDate> out = <FoundDate>[];

  int year(String y) {
    final int v = int.parse(y);
    return y.length == 2 ? 2000 + v : v;
  }

  void add(int y, int m, int d, int start, int end) {
    if (y < 1990 || y > 2100) return;
    try {
      out.add(FoundDate(LocalDate(y, m, d), start, end));
    } on ArgumentError {
      // 31/02 and the like: not a date, whatever it looks like.
    }
  }

  for (final RegExpMatch m in RegExp(
    r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b',
  ).allMatches(s)) {
    add(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), m.start, m.end);
  }
  for (final RegExpMatch m in RegExp(
    r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})\b',
  ).allMatches(s)) {
    add(year(m[3]!), int.parse(m[2]!), int.parse(m[1]!), m.start, m.end);
  }
  for (final RegExpMatch m in RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?[\s\-.,]*([A-Za-z]{3})[A-Za-z]*\.?[\s\-.,]*(\d{4}|\d{2})\b',
  ).allMatches(s)) {
    final int? month = _months[m[2]!.toLowerCase()];
    if (month != null) {
      add(year(m[3]!), month, int.parse(m[1]!), m.start, m.end);
    }
  }
  for (final RegExpMatch m in RegExp(
    r'\b([A-Za-z]{3})[A-Za-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
  ).allMatches(s)) {
    final int? month = _months[m[1]!.toLowerCase()];
    if (month != null) {
      add(int.parse(m[3]!), month, int.parse(m[2]!), m.start, m.end);
    }
  }

  // Overlapping readings of the same characters ("2026-10-12" is also
  // "26-10-12" to the day-first pattern): keep the first, longest.
  out.sort((FoundDate a, FoundDate b) {
    final int byStart = a.start.compareTo(b.start);
    return byStart != 0
        ? byStart
        : (b.end - b.start).compareTo(a.end - a.start);
  });
  final List<FoundDate> kept = <FoundDate>[];
  for (final FoundDate d in out) {
    if (kept.isNotEmpty && d.start < kept.last.end) continue;
    kept.add(d);
  }
  return kept;
}

/// Amounts as receipts print them: "8,450.00", "1,23,456", "৳ 99.50".
/// Only things that look like money — a grouped number or one with a
/// two-digit fraction — not a quantity "2" or a year "2026".
final RegExp moneyPattern = RegExp(
  r'(?<![\d.,])(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+\.\d{2})(?![\d])',
);

/// The currency a document is written in, from the symbols and codes on
/// it, or null when it does not say. Taka is by far the commonest here and
/// is the caller's default.
String? currencyOf(String text) {
  final String t = text.toLowerCase();
  if (t.contains('৳') ||
      RegExp(r'\b(tk|bdt|taka)\b').hasMatch(t) ||
      t.contains('টাকা')) {
    return 'BDT';
  }
  if (t.contains(r'$') || RegExp(r'\busd\b').hasMatch(t)) return 'USD';
  if (t.contains('₹') || RegExp(r'\b(inr|rs\.?)\b').hasMatch(t)) return 'INR';
  if (t.contains('€') || RegExp(r'\beur\b').hasMatch(t)) return 'EUR';
  return null;
}
