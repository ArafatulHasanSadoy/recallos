import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engines/mlkit_ocr_engine.dart';
import 'ocr_engine.dart';

/// The app's OCR engine, shared rather than owned by whichever screen scans.
///
/// It used to be a private field on the capture screen, which meant nothing
/// else could read a card — a retry queue could list the failures but not do
/// anything about them. A recogniser is also expensive enough to be worth
/// holding open across screens rather than rebuilding per scan.
///
/// Disposed with the provider, so the native recogniser is released when the
/// scope goes rather than being leaked for the process lifetime.
final ocrEngineProvider = Provider<OcrEngine>((Ref ref) {
  final OcrEngine engine = MlKitOcrEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
