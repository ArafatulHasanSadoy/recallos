// Grades an OCR spike run against hand-labelled ground truth.
//
//   dart run tool/spike/score.dart <results.json> <labels.json>
//
// `results.json` comes off the device from the spike screen. `labels.json` is
// written by hand. Splitting it this way means the slow part (running native
// OCR on 30 cards) happens once, and the fast part (scoring, tweaking, arguing
// about thresholds) iterates on a laptop.
//
// labels.json:
//   {
//     "card_001.jpg": {
//       "script": "bengali",
//       "rawText": "মেডিকা বুকস\nMedica Books\n01711-223344",
//       "fields": {
//         "company":     "Medica Books",
//         "person_name": "Rahim Uddin",
//         "phone":       "+8801711223344"
//       }
//     }
//   }
//
// `script` is "latin", "bengali" or "mixed" and decides which bucket a card
// counts toward. That split is the entire point: an average across English and
// Bengali cards hides exactly what the gate needs to see.
//
// `rawText` is optional — supply it for CER, omit it for field scores only.

import 'dart:convert';
import 'dart:io';

import 'package:recallos/core/extraction/metrics.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart run tool/spike/score.dart <results.json> <labels.json>',
    );
    exitCode = 64;
    return;
  }

  final Map<String, dynamic> results = await _readJson(args[0]);
  final Map<String, dynamic> labels = await _readJson(args[1]);

  final List<dynamic> cards = results['cards'] as List<dynamic>? ?? <dynamic>[];
  if (cards.isEmpty) {
    stderr.writeln('No cards in ${args[0]}.');
    exitCode = 65;
    return;
  }

  final Map<String, EngineReport> reports = <String, EngineReport>{};
  int unlabelled = 0;

  for (final dynamic entry in cards) {
    final Map<String, dynamic> card = entry as Map<String, dynamic>;
    final String image = card['image'] as String;

    final Map<String, dynamic>? truth = labels[image] as Map<String, dynamic>?;
    if (truth == null) {
      unlabelled++;
      continue;
    }

    final String script = (truth['script'] as String? ?? 'latin').toLowerCase();
    final Map<String, dynamic> wantFields =
        truth['fields'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final String? wantRaw = truth['rawText'] as String?;

    for (final dynamic r in card['results'] as List<dynamic>) {
      final Map<String, dynamic> result = r as Map<String, dynamic>;
      final String engine = result['engine'] as String;
      final EngineReport report =
          reports.putIfAbsent(engine, () => EngineReport(engine: engine));

      final Map<String, dynamic> gotFields =
          result['fields'] as Map<String, dynamic>? ?? <String, dynamic>{};

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

      // Score the union of expected and extracted keys, so both misses and
      // inventions are counted.
      for (final String key in <String>{...wantFields.keys, ...gotFields.keys}) {
        final String? want = wantFields[key] as String?;
        final String? got = gotFields[key] as String?;

        report.overall.record(fieldKey: key, expected: want, actual: got);

        // Mixed cards count toward Bengali: they are the ones that need the
        // Bengali pass, and grading them as Latin would flatter the result.
        final FieldScorer bucket = script == 'latin'
            ? report.latinCards
            : report.bengaliCards;
        bucket.record(fieldKey: key, expected: want, actual: got);
      }
    }
  }

  if (reports.isEmpty) {
    stderr.writeln('Nothing scored — no image in results.json matched a label.');
    exitCode = 65;
    return;
  }

  if (unlabelled > 0) {
    stdout.writeln('note: $unlabelled card(s) had no label and were skipped\n');
  }

  for (final EngineReport report in reports.values) {
    stdout
      ..writeln('=' * 66)
      ..writeln(report.format());
  }

  _printGate(reports['routed']);
}

void _printGate(EngineReport? routed) {
  stdout.writeln('=' * 66);
  stdout.writeln('PHASE 0 GATE');
  stdout.writeln('=' * 66);

  if (routed == null) {
    stdout.writeln('No "routed" engine in the results — cannot evaluate.');
    exitCode = 65;
    return;
  }

  final double score = routed.bengaliCards.weightedF1();
  final bool passed = clearsBengaliGate(routed);

  stdout
    ..writeln('Bengali field F1 (routed): ${score.toStringAsFixed(3)}')
    ..writeln('Threshold:                 '
        '${kBengaliGateThreshold.toStringAsFixed(2)}')
    ..writeln('')
    ..writeln(passed ? 'PASS — build on this.' : 'FAIL — decide now, not in week 4.');

  if (!passed) {
    stdout.writeln('''
Three honest options, in rough order of effort:

  a) Ship Bengali cards as image + manual entry, and let the Latin pass keep
     extracting phone, email and website automatically. Perfectly respectable,
     demos well, and costs nothing to build — the fallbacks already exist.

  b) Fine-tune Tesseract on Bangladeshi card fonts. Real work, uncertain payoff.

  c) Take the cloud escape hatch behind OcrEngine. Breaks the zero-egress story,
     which is currently the strongest thing about this project.

(a) is the default. Do not let this quietly become (c).''');
    exitCode = 1;
  }
}

Future<Map<String, dynamic>> _readJson(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No such file: $path');
    exit(66);
  }
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}
