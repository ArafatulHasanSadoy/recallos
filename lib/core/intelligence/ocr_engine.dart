import 'dart:io';
import 'dart:ui' show Rect;

/// Writing systems RecallOS distinguishes between.
///
/// This matters because no single on-device engine covers both: ML Kit reads
/// Latin but not Bengali, Tesseract reads Bengali but is slow and weaker on
/// decorative type. Knowing a block's script is what lets us route it.
enum Script {
  latin,
  bengali,

  /// Text present but the script could not be determined.
  unknown,
}

/// A single recognised region of text, with the box it came from.
///
/// Keeping the box is not decorative. It is what powers tap-to-assign and
/// tap-a-field-to-highlight-its-source: when extraction assigns text to the
/// wrong field, the user fixes it by tapping the card instead of typing.
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.rect,
    required this.confidence,
    required this.script,
    this.engine,
  });

  final String text;

  /// Bounds in the coordinate space of the image that was passed to the engine.
  final Rect rect;

  /// 0.0–1.0. Engines that do not report confidence should say so with
  /// [confidenceUnknown] rather than inventing a number.
  final double confidence;

  final Script script;

  /// Which engine produced this block, for per-engine accuracy reporting.
  final String? engine;

  /// Sentinel for engines with no confidence signal. Treated as "review me"
  /// rather than as high or low confidence.
  static const double confidenceUnknown = -1;

  bool get hasConfidence => confidence >= 0;

  OcrBlock copyWith({
    String? text,
    Rect? rect,
    double? confidence,
    Script? script,
    String? engine,
  }) {
    return OcrBlock(
      text: text ?? this.text,
      rect: rect ?? this.rect,
      confidence: confidence ?? this.confidence,
      script: script ?? this.script,
      engine: engine ?? this.engine,
    );
  }

  @override
  String toString() =>
      'OcrBlock(${script.name}, ${confidence.toStringAsFixed(2)}, "$text")';
}

/// Why an OCR attempt did not produce a usable result.
///
/// Every one of these has a defined recovery path in the UI. They are named so
/// that the screen can say something specific instead of "something went wrong".
enum OcrFailure {
  /// The engine ran but found no text at all.
  noTextFound,

  /// Image was too blurry, too dark, or too washed out to attempt.
  unusableImage,

  /// Model weights or language data are not on the device yet.
  engineUnavailable,

  /// Ran out of memory mid-inference. Caller should drop a device tier.
  outOfMemory,

  /// Exceeded the time budget. Partial blocks may still be present.
  timedOut,

  /// Anything else. [OcrResult.errorDetail] carries the specifics.
  unknown,
}

/// The outcome of running one or more engines over a card image.
///
/// A result with [failure] set can still carry [blocks] — a timeout often
/// yields partial text that is worth keeping.
class OcrResult {
  const OcrResult({
    required this.blocks,
    required this.engine,
    required this.duration,
    this.failure,
    this.errorDetail,
  });

  const OcrResult.failed({
    required this.failure,
    required this.engine,
    required this.duration,
    this.errorDetail,
  }) : blocks = const <OcrBlock>[];

  final List<OcrBlock> blocks;

  /// Identifier for the engine or routing strategy that produced this, e.g.
  /// `mlkit`, `tesseract-ben`, `routed`. Recorded per attempt so accuracy can
  /// be reported per engine.
  final String engine;

  final Duration duration;

  final OcrFailure? failure;
  final String? errorDetail;

  bool get isEmpty => blocks.isEmpty;
  bool get hasText => blocks.isNotEmpty;

  /// True when nothing usable came back. The caller must still save the card —
  /// it just goes straight to the note prompt instead of a field form.
  bool get isTotalFailure => blocks.isEmpty;

  /// All text joined in reading order, for keyword indexing and for the raw
  /// text the user can always fall back to reading themselves.
  String get plainText => blocks.map((b) => b.text).join('\n');

  Iterable<OcrBlock> blocksOfScript(Script script) =>
      blocks.where((b) => b.script == script);

  @override
  String toString() => failure == null
      ? 'OcrResult($engine, ${blocks.length} blocks, ${duration.inMilliseconds}ms)'
      : 'OcrResult($engine, FAILED ${failure!.name}, ${duration.inMilliseconds}ms)';
}

/// Recognises text in an image.
///
/// Implementations must never throw for an unreadable card — an unreadable card
/// is a normal outcome, reported as an [OcrResult] with a [OcrFailure]. Throwing
/// would risk losing a card the user has already been told is saved.
abstract interface class OcrEngine {
  /// Stable identifier used in `extraction_attempts.engine`.
  String get id;

  /// Which scripts this engine can actually read. Callers use this to route.
  Set<Script> get supportedScripts;

  /// True when the engine is ready right now — models downloaded, language
  /// data present, enough memory. Checked before every use so the UI can
  /// degrade honestly instead of failing mid-scan.
  Future<bool> isAvailable();

  /// Recognise text in [image].
  ///
  /// [scripts] narrows the work when the caller already knows what it is
  /// looking for, e.g. re-running only Bengali over one cropped region.
  /// [timeout] must be honoured; returning partial blocks beats returning
  /// nothing.
  Future<OcrResult> recognize(
    File image, {
    Set<Script> scripts,
    Duration timeout,
  });

  /// Release native resources. Safe to call more than once.
  Future<void> dispose();
}
