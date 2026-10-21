import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/eval/ocr_scoring.dart';
import 'package:recallos/core/extraction/metrics.dart';

/// PLAN §6's OCR, receipt and warranty, and classification scores.
///
/// The first tests pin the scoring itself. The last one is the real run, and
/// is skipped unless two files are named:
///
///     RECALLOS_OCR_RESULTS=~/recallos-eval/results.json \
///     RECALLOS_OCR_LABELS=~/recallos-eval/labels.json \
///     flutter test test/eval/ocr_score_test.dart
///
/// `results.json` is what the bench screen exports (a release APK built with
/// `--dart-define=RECALLOS_BENCH=true`, so R8 is in the loop);
/// `labels.json` is written by hand — the format is in
/// `lib/core/eval/ocr_scoring.dart` and `tool/spike/score.dart`. Both stay
/// outside the repo: real cards carry real people's details.
void main() {
  test('a receipt label written as printed is compared as stored', () {
    final OcrScore s = scoreOcrRun(
      <String, dynamic>{
        'cards': <dynamic>[
          <String, dynamic>{
            'image': 'r1.jpg',
            'results': <dynamic>[
              <String, dynamic>{
                'engine': 'routed',
                'durationMs': 800,
                'plainText': 'SHWAPNO\nGrand Total 432.60',
                'blockCount': 4,
                'kind': 'receipt',
                'fields': <String, dynamic>{
                  'merchant': 'SHWAPNO',
                  'total': '43260',
                  'purchase_date': '2026-10-12',
                },
              },
            ],
          },
          <String, dynamic>{
            'image': 'w1.jpg',
            'results': <dynamic>[
              <String, dynamic>{
                'engine': 'routed',
                'durationMs': 900,
                'plainText': 'HP Warranty',
                'blockCount': 5,
                'kind': 'receipt',
                'fields': <String, dynamic>{},
              },
            ],
          },
          <String, dynamic>{'image': 'nolabel.jpg', 'results': <dynamic>[]},
        ],
      },
      <String, dynamic>{
        'r1.jpg': <String, dynamic>{
          'script': 'latin',
          'kind': 'receipt',
          'group': 'thermal',
          'rawText': 'SHWAPNO\nGrand Total 432.60',
          'fields': <String, dynamic>{
            'merchant': 'Shwapno',
            'total': '432.60',
            'purchase_date': '12/10/2026',
          },
        },
        'w1.jpg': <String, dynamic>{
          'script': 'latin',
          'kind': 'warranty',
          'fields': <String, dynamic>{'cover_months': '2 years'},
        },
      },
    );

    expect(s.unlabelled, 1);
    final EngineReport r = s.reports['routed']!;
    expect(r.cardCount, 2);
    final Map<String, FieldScore> by = <String, FieldScore>{
      for (final FieldScore f in r.overall.scores()) f.fieldKey: f,
    };
    expect(by['total']!.f1, 1, reason: '"432.60" is 43260 paisa');
    expect(by['purchase_date']!.f1, 1, reason: '"12/10/2026" is 2026-10-12');
    expect(by['merchant']!.f1, 1, reason: 'case does not count');
    expect(by['cover_months']!.recall, 0, reason: 'a miss is a miss');
    expect(r.groups['thermal']!.weightedF1(), 1);
    expect(r.classification.accuracy, 0.5);
    expect(r.classification.scoreOf('warranty').recall, 0);
  });

  final String? resultsPath = Platform.environment['RECALLOS_OCR_RESULTS'];
  final String? labelsPath = Platform.environment['RECALLOS_OCR_LABELS'];
  test(
    'the real run',
    () {
      final OcrScore s = scoreOcrRun(
        jsonDecode(File(resultsPath!).readAsStringSync())
            as Map<String, dynamic>,
        jsonDecode(File(labelsPath!).readAsStringSync())
            as Map<String, dynamic>,
      );
      if (s.unlabelled > 0) {
        // ignore: avoid_print
        print('note: ${s.unlabelled} result(s) had no label and were skipped');
      }
      for (final EngineReport r in s.reports.values) {
        // ignore: avoid_print
        print('${'=' * 66}\n${r.format()}');
      }
      expect(s.reports, isNotEmpty);
    },
    skip: resultsPath == null || labelsPath == null
        ? 'Set RECALLOS_OCR_RESULTS and RECALLOS_OCR_LABELS to score a real '
              'run.'
        : false,
  );
}
