import 'dart:io';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import '../ocr_engine.dart';

/// Latin-script OCR via Google ML Kit.
///
/// Free, offline, fast, and on both platforms — but it **cannot read Bengali**.
/// ML Kit v2 covers Latin, Chinese, Devanagari, Japanese and Korean only.
///
/// That limitation is less damaging than it sounds. Phone numbers, emails and
/// websites are written in Latin characters on essentially every Bangladeshi
/// card, even ones that are otherwise entirely in Bengali — so this engine
/// reaches the highest-value fields on its own, at zero cost and with no model
/// download. Bengali company names and addresses are what it misses, and those
/// go to Tesseract.
class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine();

  mlkit.TextRecognizer? _recognizer;

  @override
  String get id => 'mlkit';

  @override
  Set<Script> get supportedScripts => const <Script>{Script.latin};

  @override
  Future<bool> isAvailable() async => true;

  mlkit.TextRecognizer get _engine =>
      _recognizer ??= mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);

  @override
  Future<OcrResult> recognize(
    File image, {
    Set<Script> scripts = const <Script>{Script.latin},
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Stopwatch clock = Stopwatch()..start();

    // Asked for scripts this engine cannot read: say so rather than returning
    // an empty result the caller would read as "the card is blank".
    if (!scripts.contains(Script.latin)) {
      return OcrResult.failed(
        failure: OcrFailure.engineUnavailable,
        engine: id,
        duration: clock.elapsed,
        errorDetail: 'ML Kit reads Latin only; asked for '
            '${scripts.map((Script s) => s.name).join(", ")}',
      );
    }

    try {
      final mlkit.RecognizedText recognized = await _engine
          .processImage(mlkit.InputImage.fromFile(image))
          .timeout(timeout);

      final List<OcrBlock> blocks = <OcrBlock>[];
      for (final mlkit.TextBlock block in recognized.blocks) {
        // Lines, not blocks. A block can merge a name and a job title into one
        // rectangle, which destroys the layout signal the field extractor uses.
        for (final mlkit.TextLine line in block.lines) {
          final String text = line.text.trim();
          if (text.isEmpty) continue;

          blocks.add(OcrBlock(
            text: text,
            rect: Rect.fromLTRB(
              line.boundingBox.left.toDouble(),
              line.boundingBox.top.toDouble(),
              line.boundingBox.right.toDouble(),
              line.boundingBox.bottom.toDouble(),
            ),
            // ML Kit exposes no per-line confidence on either platform, so we
            // record that honestly instead of inventing a number.
            confidence: OcrBlock.confidenceUnknown,
            script: Script.latin,
            engine: id,
          ));
        }
      }

      clock.stop();
      if (blocks.isEmpty) {
        return OcrResult.failed(
          failure: OcrFailure.noTextFound,
          engine: id,
          duration: clock.elapsed,
        );
      }
      return OcrResult(
        blocks: blocks,
        engine: id,
        duration: clock.elapsed,
      );
    } on Object catch (e) {
      clock.stop();
      return OcrResult.failed(
        failure: _classify(e),
        engine: id,
        duration: clock.elapsed,
        errorDetail: e.toString(),
      );
    }
  }

  static OcrFailure _classify(Object e) {
    final String message = e.toString().toLowerCase();
    if (message.contains('timeout')) return OcrFailure.timedOut;
    if (message.contains('memory')) return OcrFailure.outOfMemory;
    return OcrFailure.unknown;
  }

  @override
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
