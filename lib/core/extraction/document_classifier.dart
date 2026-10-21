/// What was scanned: a business card, a receipt or a warranty (B2).
///
/// Deterministic and explainable: a score per kind from the words and
/// shapes on the paper, the cues that decided it kept as reasons. When the
/// scores are close the answer is "not sure", and the app asks the user
/// rather than guessing (PLAN §4, B2: "What did you save?" when unsure).
library;

import 'document_lines.dart';

enum DocumentKind { businessCard, receipt, warranty }

class Classification {
  const Classification({
    required this.kind,
    required this.confidence,
    required this.reasons,
    required this.scores,
  });

  /// The best guess.
  final DocumentKind kind;

  /// 0..1 — the winner's share of all the evidence. Close scores give a low
  /// number even when the winner's own score is high.
  final double confidence;

  /// The cues that counted for [kind], in the order found — what the
  /// evaluation reports and what explains a wrong guess.
  final List<String> reasons;

  final Map<DocumentKind, double> scores;

  /// Below this the app asks instead of deciding.
  static const double sureAt = 0.6;

  bool get isSure => confidence >= sureAt;

  @override
  String toString() =>
      '${kind.name} ${confidence.toStringAsFixed(2)} ${reasons.join(", ")}';
}

class _Cue {
  const _Cue(this.kind, this.weight, this.label, this.pattern);
  final DocumentKind kind;
  final double weight;
  final String label;
  final RegExp pattern;
}

RegExp _w(String words) => RegExp('\\b(?:$words)\\b', caseSensitive: false);

final List<_Cue> _cues = <_Cue>[
  // Receipts and invoices.
  _Cue(
    DocumentKind.receipt,
    3,
    'a total',
    // Only with an amount after it on the same row: "Total solutions for
    // your home" is a shop's slogan, not a bill.
    RegExp(
      r'\b(?:grand total|net total|net payable|total payable|amount payable|'
      r'total amount|total due|bill amount|net amount|total)\b[^\n]*\d',
      caseSensitive: false,
    ),
  ),
  _Cue(DocumentKind.receipt, 1, 'a subtotal', _w('sub ?total')),
  _Cue(DocumentKind.receipt, 1, 'VAT or tax', _w('vat|tax|mushak')),
  _Cue(
    DocumentKind.receipt,
    1.5,
    'how it was paid',
    _w('cash|change|paid|payment|bkash|nagad|card no|visa|mastercard'),
  ),
  _Cue(
    DocumentKind.receipt,
    1,
    'price columns',
    _w('qty|quantity|unit price|rate|price|amount'),
  ),
  _Cue(
    DocumentKind.receipt,
    2,
    'called a receipt or invoice',
    _w('invoice|receipt|cash memo|bill no|bill|sales'),
  ),
  // Warranties.
  _Cue(
    DocumentKind.warranty,
    4,
    'the word warranty',
    RegExp(
      r'\b(?:warranty|warrantee|guarantee)\b|ওয়ারেন্টি|গ্যারান্টি',
      caseSensitive: false,
    ),
  ),
  _Cue(
    DocumentKind.warranty,
    2,
    'a serial number',
    _w(r'serial|s/?n|imei|sl\.? ?no'),
  ),
  _Cue(DocumentKind.warranty, 1, 'a model number', _w('model')),
  _Cue(
    DocumentKind.warranty,
    1.5,
    'a period of cover',
    _w(r'\d+ ?(?:years?|yrs?|months?)|valid (?:till|until|upto|up to)'),
  ),
  _Cue(
    DocumentKind.warranty,
    1,
    'a service centre',
    _w('service cent(?:re|er)|customer care|authori[sz]ed service'),
  ),
  // Business cards.
  _Cue(
    DocumentKind.businessCard,
    1.5,
    'an email address',
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
  ),
  _Cue(
    DocumentKind.businessCard,
    1,
    'a website',
    RegExp(r'\bwww\.|\.com\b|\.com\.bd\b', caseSensitive: false),
  ),
  _Cue(
    DocumentKind.businessCard,
    1.5,
    'a job title',
    _w(
      'manager|director|ceo|cto|coo|founder|co-founder|executive|officer|'
      'engineer|consultant|head of|proprietor|partner|chairman|md|'
      'designer|developer|advocate|dr\\.?',
    ),
  ),
];

/// What [text] — everything OCR read off the page — most looks like.
Classification classifyDocument(String text) {
  final Map<DocumentKind, double> scores = <DocumentKind, double>{
    for (final DocumentKind k in DocumentKind.values) k: 0,
  };
  final Map<DocumentKind, List<String>> reasons = <DocumentKind, List<String>>{
    for (final DocumentKind k in DocumentKind.values) k: <String>[],
  };
  void count(DocumentKind k, double w, String why) {
    scores[k] = scores[k]! + w;
    reasons[k]!.add(why);
  }

  for (final _Cue c in _cues) {
    if (c.pattern.hasMatch(text)) count(c.kind, c.weight, c.label);
  }

  // Shapes rather than words.
  final int amounts = moneyPattern.allMatches(asciiDigits(text)).length;
  if (amounts >= 3) count(DocumentKind.receipt, 1.5, 'several amounts');
  final List<String> lines = text
      .split('\n')
      .where((String l) => l.trim().isNotEmpty)
      .toList();
  if (amounts == 0 && lines.length <= 10) {
    count(DocumentKind.businessCard, 1, 'a few lines and no prices');
  }
  final int phones = RegExp(
    r'(?:\+?880[\s-]?)?0?1[3-9]\d{2}[\s-]?\d{6}',
  ).allMatches(asciiDigits(text)).length;
  if (phones > 0 && amounts == 0) {
    count(DocumentKind.businessCard, 1, 'a phone number');
  }

  final List<MapEntry<DocumentKind, double>> ranked = scores.entries.toList()
    ..sort(
      (MapEntry<DocumentKind, double> a, MapEntry<DocumentKind, double> b) =>
          b.value.compareTo(a.value),
    );
  final double total = scores.values.fold<double>(
    0,
    (double a, double b) => a + b,
  );
  final DocumentKind best = ranked.first.value == 0
      ? DocumentKind.businessCard
      : ranked.first.key;
  return Classification(
    kind: best,
    // +1 in the denominator: one weak cue alone is not certainty.
    confidence: ranked.first.value / (total + 1),
    reasons: reasons[best]!,
    scores: scores,
  );
}
