import 'dart:convert';
import 'dart:io';

import '../../../core/extraction/card_extractor.dart';
import '../../../core/intelligence/engines/mlkit_ocr_engine.dart';
import '../../../core/intelligence/engines/routed_ocr_engine.dart';
import '../../../core/intelligence/ocr_engine.dart';

/// What one engine produced for one card.
class SpikeCardResult {
  const SpikeCardResult({
    required this.engineId,
    required this.durationMs,
    required this.plainText,
    required this.fields,
    required this.blockCount,
    this.failure,
  });

  final String engineId;
  final int durationMs;
  final String plainText;

  /// Field key to extracted value, so scoring can compare against ground truth
  /// without re-running the extractor.
  final Map<String, String> fields;

  final int blockCount;
  final String? failure;

  bool get isTotalFailure => blockCount == 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'engine': engineId,
        'durationMs': durationMs,
        'plainText': plainText,
        'fields': fields,
        'blockCount': blockCount,
        'failure': failure,
      };
}

/// Every engine's output for one card.
class SpikeCard {
  const SpikeCard({required this.imageName, required this.results});

  final String imageName;
  final List<SpikeCardResult> results;

  SpikeCardResult? byEngine(String id) {
    for (final SpikeCardResult r in results) {
      if (r.engineId == id) return r;
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'image': imageName,
        'results': results.map((SpikeCardResult r) => r.toJson()).toList(),
      };
}

/// Runs every OCR strategy over the same images so they can be compared.
///
/// This is the Phase 0 gate. It answers one question before the rest of the app
/// is built on top of an assumption: **how well do we actually read the cards
/// people will scan?**
///
/// Scope is Latin script — English and the Latin portions of mixed cards, which
/// on Bangladeshi cards is where phone numbers, emails and websites live
/// regardless. Bengali-script recognition is future work; see the plan.
///
/// Scoring lives elsewhere on purpose. This part needs a real device (ML Kit is
/// native); turning results into precision, recall and CER is pure Dart and
/// runs anywhere. So this exports JSON, and `tool/spike/score.dart` grades it
/// on a laptop where iterating is fast.
class SpikeRunner {
  SpikeRunner({OcrEngine? latin})
      : _latin = latin ?? MlKitOcrEngine();

  final OcrEngine _latin;

  late final RoutedOcrEngine _routed = RoutedOcrEngine(primary: _latin);

  /// Every strategy under test, in report order. One engine today; the
  /// comparison shape is kept for when a second script engine returns.
  List<OcrEngine> get engines => <OcrEngine>[_latin, _routed];

  /// Runs every engine over [images], reporting progress as it goes.
  ///
  /// Never throws: an engine that fails on one card is recorded as a failure and
  /// the run continues. A spike that aborts halfway through 30 cards is worse
  /// than useless.
  Future<List<SpikeCard>> run(
    List<File> images, {
    void Function(int done, int total, String label)? onProgress,
  }) async {
    final List<SpikeCard> cards = <SpikeCard>[];
    final int total = images.length * engines.length;
    int done = 0;

    for (final File image in images) {
      final String name = image.uri.pathSegments.last;
      final List<SpikeCardResult> results = <SpikeCardResult>[];

      for (final OcrEngine engine in engines) {
        onProgress?.call(done, total, '$name → ${engine.id}');

        results.add(await _runOne(engine, image));
        done++;
      }
      cards.add(SpikeCard(imageName: name, results: results));
    }

    onProgress?.call(done, total, 'done');
    return cards;
  }

  Future<SpikeCardResult> _runOne(OcrEngine engine, File image) async {
    try {
      final OcrResult result = await engine.recognize(image);
      final CardExtraction extraction =
          CardFieldExtractor.extract(result.blocks);

      return SpikeCardResult(
        engineId: engine.id,
        durationMs: result.duration.inMilliseconds,
        plainText: result.plainText,
        fields: <String, String>{
          for (final String key in FieldKeys.all)
            if (extraction.firstOfKey(key) case final ExtractedField f)
              key: f.normalizedValue ?? f.value,
        },
        blockCount: result.blocks.length,
        failure: result.failure?.name,
      );
    } on Object catch (e) {
      // Should not happen — engines are contracted not to throw — but a spike
      // that dies on card 17 of 30 wastes the whole run.
      return SpikeCardResult(
        engineId: engine.id,
        durationMs: 0,
        plainText: '',
        fields: const <String, String>{},
        blockCount: 0,
        failure: 'threw: $e',
      );
    }
  }

  /// Serialises a run for `tool/spike/score.dart`.
  static String toJsonReport(List<SpikeCard> cards) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'cards': cards.map((SpikeCard c) => c.toJson()).toList(),
    });
  }

  Future<void> dispose() async {
    await _latin.dispose();
  }
}
