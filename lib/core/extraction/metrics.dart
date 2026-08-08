/// Accuracy measurement for the OCR spike and the ongoing evaluation harness.
///
/// These are the numbers the Phase 0 gate turns on: if routed Bengali field
/// accuracy comes in under about 60%, the approach changes before three weeks
/// of work get built on top of it. Keeping them as pure functions means the
/// gate can be re-run on any dataset at any time, on a laptop, with no device.
library;

import 'dart:math' as math;

/// Levenshtein edit distance between two strings, counted in characters.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final List<int> aRunes = a.runes.toList();
  final List<int> bRunes = b.runes.toList();

  // Only two rows are ever needed, which matters when comparing whole cards.
  List<int> previous = List<int>.generate(bRunes.length + 1, (int i) => i);
  List<int> current = List<int>.filled(bRunes.length + 1, 0);

  for (int i = 1; i <= aRunes.length; i++) {
    current[0] = i;
    for (int j = 1; j <= bRunes.length; j++) {
      final int cost = aRunes[i - 1] == bRunes[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    final List<int> swap = previous;
    previous = current;
    current = swap;
  }
  return previous[bRunes.length];
}

/// Character error rate: edits needed to turn [hypothesis] into [reference],
/// over the length of the reference.
///
/// Can exceed 1.0 when the engine hallucinates more text than was there —
/// which is genuinely worse than reading nothing, so it is not clamped.
double characterErrorRate({
  required String reference,
  required String hypothesis,
}) {
  final String ref = _collapseWhitespace(reference);
  final String hyp = _collapseWhitespace(hypothesis);

  if (ref.isEmpty) return hyp.isEmpty ? 0 : 1;
  return editDistance(ref, hyp) / ref.runes.length;
}

String _collapseWhitespace(String s) =>
    s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Precision, recall and F1 for one field across a dataset.
class FieldScore {
  const FieldScore({
    required this.fieldKey,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
  });

  final String fieldKey;

  /// Extracted, and correct.
  final int truePositives;

  /// Extracted, but wrong. **The number that matters most.** A missing field is
  /// visible and self-correcting; a wrong one is invisible and corrosive.
  final int falsePositives;

  /// Present on the card but not extracted.
  final int falseNegatives;

  double get precision => truePositives + falsePositives == 0
      ? 0
      : truePositives / (truePositives + falsePositives);

  double get recall => truePositives + falseNegatives == 0
      ? 0
      : truePositives / (truePositives + falseNegatives);

  double get f1 => precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);

  int get support => truePositives + falseNegatives;

  @override
  String toString() => '$fieldKey  P=${precision.toStringAsFixed(3)}  '
      'R=${recall.toStringAsFixed(3)}  F1=${f1.toStringAsFixed(3)}  '
      'n=$support';
}

/// Accumulates field-level scores while a dataset is processed.
class FieldScorer {
  final Map<String, int> _tp = <String, int>{};
  final Map<String, int> _fp = <String, int>{};
  final Map<String, int> _fn = <String, int>{};

  /// Records one field on one card.
  ///
  /// [expected] is null when the card genuinely has no such field; [actual] is
  /// null when nothing was extracted. Correctly extracting nothing from a card
  /// that has nothing is not scored — it would inflate every number.
  void record({
    required String fieldKey,
    required String? expected,
    required String? actual,
  }) {
    final String? want = _norm(expected);
    final String? got = _norm(actual);

    if (want == null && got == null) return;

    if (want == null) {
      _fp[fieldKey] = (_fp[fieldKey] ?? 0) + 1;
    } else if (got == null) {
      _fn[fieldKey] = (_fn[fieldKey] ?? 0) + 1;
    } else if (want == got) {
      _tp[fieldKey] = (_tp[fieldKey] ?? 0) + 1;
    } else {
      // A wrong value is both a miss and a false alarm. Counting it twice is
      // deliberate: it should hurt precision and recall at once.
      _fp[fieldKey] = (_fp[fieldKey] ?? 0) + 1;
      _fn[fieldKey] = (_fn[fieldKey] ?? 0) + 1;
    }
  }

  static String? _norm(String? v) {
    if (v == null) return null;
    final String t = _collapseWhitespace(v).toLowerCase();
    return t.isEmpty ? null : t;
  }

  List<FieldScore> scores() {
    final Set<String> keys = <String>{..._tp.keys, ..._fp.keys, ..._fn.keys};
    final List<FieldScore> out = <FieldScore>[
      for (final String k in keys)
        FieldScore(
          fieldKey: k,
          truePositives: _tp[k] ?? 0,
          falsePositives: _fp[k] ?? 0,
          falseNegatives: _fn[k] ?? 0,
        ),
    ];
    out.sort((FieldScore a, FieldScore b) => a.fieldKey.compareTo(b.fieldKey));
    return out;
  }

  /// F1 averaged over fields, each weighted by how often it actually appears.
  /// Unweighted averaging would let a rare field swing the headline number.
  double weightedF1() {
    final List<FieldScore> all = scores();
    final int total =
        all.fold<int>(0, (int sum, FieldScore s) => sum + s.support);
    if (total == 0) return 0;

    return all.fold<double>(
      0,
      (double sum, FieldScore s) => sum + s.f1 * s.support,
    ) / total;
  }
}

/// One engine's result over one dataset, split by script.
///
/// The split is the point. A headline accuracy number averaged across English
/// and Bengali cards hides exactly the thing the gate needs to see.
class EngineReport {
  EngineReport({required this.engine});

  final String engine;

  final FieldScorer overall = FieldScorer();
  final FieldScorer latinCards = FieldScorer();
  final FieldScorer bengaliCards = FieldScorer();

  final List<double> _cers = <double>[];
  final List<int> _durationsMs = <int>[];
  int _cards = 0;
  int _totalFailures = 0;

  void addCard({
    required double cer,
    required int durationMs,
    required bool totalFailure,
  }) {
    _cards++;
    _cers.add(cer);
    _durationsMs.add(durationMs);
    if (totalFailure) _totalFailures++;
  }

  int get cardCount => _cards;

  double get meanCer => _cers.isEmpty
      ? 0
      : _cers.reduce((double a, double b) => a + b) / _cers.length;

  double get meanDurationMs => _durationsMs.isEmpty
      ? 0
      : _durationsMs.reduce((int a, int b) => a + b) / _durationsMs.length;

  /// Slowest 10% — the number users actually notice, unlike the mean.
  double get p90DurationMs {
    if (_durationsMs.isEmpty) return 0;
    final List<int> sorted = List<int>.from(_durationsMs)..sort();
    final int index =
        ((sorted.length - 1) * 0.9).round().clamp(0, sorted.length - 1);
    return sorted[index].toDouble();
  }

  /// Fraction of cards that produced no usable text at all.
  double get totalFailureRate => _cards == 0 ? 0 : _totalFailures / _cards;

  /// Human-readable summary, ready to paste into the CO2 report.
  String format() {
    final StringBuffer b = StringBuffer()
      ..writeln('Engine: $engine')
      ..writeln('Cards: $_cards')
      ..writeln('Mean CER: ${meanCer.toStringAsFixed(3)}')
      ..writeln('Total-failure rate: '
          '${(totalFailureRate * 100).toStringAsFixed(1)}%')
      ..writeln('Latency: mean ${meanDurationMs.round()}ms, '
          'p90 ${p90DurationMs.round()}ms')
      ..writeln('')
      ..writeln('Fields (all cards):');
    for (final FieldScore s in overall.scores()) {
      b.writeln('  $s');
    }
    b
      ..writeln('  weighted F1: ${overall.weightedF1().toStringAsFixed(3)}')
      ..writeln('')
      ..writeln('Latin-only cards:  weighted F1 = '
          '${latinCards.weightedF1().toStringAsFixed(3)}')
      ..writeln('Bengali cards:     weighted F1 = '
          '${bengaliCards.weightedF1().toStringAsFixed(3)}');
    return b.toString();
  }
}

/// The Phase 0 go/no-go threshold on Bengali field accuracy.
const double kBengaliGateThreshold = 0.60;

/// Whether a routed report clears the gate.
///
/// Falling short is not a reason to abandon the project — it is a reason to
/// choose deliberately between shipping Bengali cards as image-plus-manual-entry,
/// fine-tuning Tesseract, or taking the cloud escape hatch. The point of a gate
/// is that the choice gets made now rather than in week four.
bool clearsBengaliGate(EngineReport routed) =>
    routed.bengaliCards.weightedF1() >= kBengaliGateThreshold;
