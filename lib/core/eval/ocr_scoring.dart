/// Scores a bench run against hand-written labels (PLAN §6): character error
/// rate, per-field F1 split by script and by group, and — for receipts and
/// warranties (B2) — how often the classifier named the right kind.
///
/// The same scoring `tool/spike/score.dart` does for cards, plus what B2
/// added, and run inside `flutter test` because comparing a hand-written
/// "432.60" with a stored 43260 needs the app's own `validateField`, which
/// the extractors (and so `dart:ui`) come with. See
/// `test/eval/ocr_score_test.dart` for how to run it on real files.
library;

import '../extraction/field_validator.dart';
import '../extraction/metrics.dart';

/// Every engine's report, and how many results had no label.
typedef OcrScore = ({Map<String, EngineReport> reports, int unlabelled});

/// [results] is the JSON the bench screen exports; [labels] maps an image
/// name to its truth: `script`, optional `rawText`, `kind` and `group`, and
/// `fields` written as printed.
OcrScore scoreOcrRun(
  Map<String, dynamic> results,
  Map<String, dynamic> labels,
) {
  final Map<String, EngineReport> reports = <String, EngineReport>{};
  int unlabelled = 0;

  for (final dynamic entry
      in results['cards'] as List<dynamic>? ?? <dynamic>[]) {
    final Map<String, dynamic> card = entry as Map<String, dynamic>;
    final Map<String, dynamic>? truth =
        labels[card['image'] as String] as Map<String, dynamic>?;
    if (truth == null) {
      unlabelled++;
      continue;
    }

    final String script = (truth['script'] as String? ?? 'latin').toLowerCase();
    final Map<String, dynamic> wantFields =
        truth['fields'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final String? wantRaw = truth['rawText'] as String?;
    final String? wantKind = (truth['kind'] as String?)?.toLowerCase();
    final String? group = (truth['group'] as String?)?.toLowerCase();

    for (final dynamic r in card['results'] as List<dynamic>) {
      final Map<String, dynamic> result = r as Map<String, dynamic>;
      final String engine = result['engine'] as String;
      final EngineReport report = reports.putIfAbsent(
        engine,
        () => EngineReport(engine: engine),
      );

      if (wantKind != null) {
        report.classification.record(
          expected: wantKind,
          predicted: result['kind'] as String?,
        );
      }
      report.addCard(
        cer: wantRaw == null
            ? 0
            : characterErrorRate(
                reference: wantRaw,
                hypothesis: result['plainText'] as String? ?? '',
              ),
        durationMs: result['durationMs'] as int? ?? 0,
        totalFailure: (result['blockCount'] as int? ?? 0) == 0,
      );

      final Map<String, dynamic> gotFields =
          result['fields'] as Map<String, dynamic>? ?? <String, dynamic>{};
      // The union, so both misses and inventions count.
      for (final String key in <String>{
        ...wantFields.keys,
        ...gotFields.keys,
      }) {
        final String? written = wantFields[key] as String?;
        // As the app stores it: "432.60" → 43260, "12/10/2026" → 2026-10-12,
        // "2 years" → 24, a phone → E.164. Anything with no canonical form
        // is compared as written.
        final String? want = written == null
            ? null
            : validateField(key, written).normalized ?? written;
        final String? got = gotFields[key] as String?;

        report.overall.record(fieldKey: key, expected: want, actual: got);
        // Mixed cards count toward Bengali, as in `tool/spike/score.dart`.
        (script == 'latin' ? report.latinCards : report.bengaliCards).record(
          fieldKey: key,
          expected: want,
          actual: got,
        );
        if (group != null) {
          report.groups
              .putIfAbsent(group, FieldScorer.new)
              .record(fieldKey: key, expected: want, actual: got);
        }
      }
    }
  }
  return (reports: reports, unlabelled: unlabelled);
}
