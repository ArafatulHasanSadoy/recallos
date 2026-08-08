import 'dart:io';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../ocr_engine.dart';

/// Dispatches an image to whichever engine can read the scripts asked for.
///
/// Today there is exactly one engine — ML Kit, Latin only — so this mostly just
/// forwards. It is kept because the *shape* of the problem has not gone away:
/// when Bengali support returns (see the plan's future-work section), it will
/// arrive as a second engine, and routing between them is where that logic
/// belongs. Collapsing this into a direct ML Kit call would mean rebuilding it.
///
/// Registering a second engine is a one-line change at the call site; nothing
/// downstream of [OcrEngine] needs to know.
class RoutedOcrEngine implements OcrEngine {
  RoutedOcrEngine({required this.primary, this.secondary});

  /// Handles the scripts the app supports today.
  final OcrEngine primary;

  /// An engine for scripts [primary] cannot read. Null until one exists.
  final OcrEngine? secondary;

  @override
  String get id => 'routed';

  @override
  Set<Script> get supportedScripts => <Script>{
        ...primary.supportedScripts,
        ...?secondary?.supportedScripts,
      };

  /// Available whenever the primary engine is. Losing the secondary degrades
  /// the result; it never prevents a scan.
  @override
  Future<bool> isAvailable() => primary.isAvailable();

  @override
  Future<OcrResult> recognize(
    File image, {
    Set<Script> scripts = const <Script>{Script.latin},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final Stopwatch clock = Stopwatch()..start();

    final OcrResult primaryPass = await primary.recognize(
      image,
      scripts: primary.supportedScripts.intersection(scripts).isEmpty
          ? primary.supportedScripts
          : primary.supportedScripts.intersection(scripts),
      timeout: timeout,
    );

    final List<OcrBlock> blocks = <OcrBlock>[...primaryPass.blocks];

    final OcrEngine? second = secondary;
    final Set<Script> unread =
        scripts.difference(primary.supportedScripts);

    if (second != null && unread.isNotEmpty && await second.isAvailable()) {
      final Duration remaining = timeout - clock.elapsed;
      if (remaining > Duration.zero) {
        final OcrResult secondPass = await second.recognize(
          image,
          scripts: unread,
          timeout: remaining,
        );
        // Drop anything sitting on top of text the primary pass already read,
        // so one line does not appear twice in two scripts.
        for (final OcrBlock b in secondPass.blocks) {
          if (!_overlapsExisting(b, primaryPass.blocks)) blocks.add(b);
        }
      }
    }

    clock.stop();

    if (blocks.isEmpty) {
      return OcrResult.failed(
        failure: primaryPass.failure ?? OcrFailure.noTextFound,
        engine: id,
        duration: clock.elapsed,
        errorDetail: primaryPass.errorDetail,
      );
    }

    blocks.sort((OcrBlock a, OcrBlock b) {
      final int byTop = a.rect.top.compareTo(b.rect.top);
      return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
    });

    return OcrResult(blocks: blocks, engine: id, duration: clock.elapsed);
  }

  static bool _overlapsExisting(OcrBlock candidate, List<OcrBlock> existing) {
    for (final OcrBlock e in existing) {
      final Rect intersection = candidate.rect.intersect(e.rect);
      if (intersection.width <= 0 || intersection.height <= 0) continue;

      final double overlap = intersection.width * intersection.height;
      final double own = candidate.rect.width * candidate.rect.height;
      if (own > 0 && overlap / own > 0.5) return true;
    }
    return false;
  }

  @override
  Future<void> dispose() async {
    await primary.dispose();
    await secondary?.dispose();
  }
}

/// Crops a region out of an image so a single field can be re-read at higher
/// resolution.
///
/// This is what powers tap-to-crop-and-retry: small regions OCR far better than
/// whole cards, so re-running one box often succeeds where the full-card pass
/// failed.
Future<File?> cropRegion(
  File source,
  Rect region, {
  required String outputDir,
  double padding = 8,
  int upscale = 2,
}) async {
  try {
    final img.Image? decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) return null;

    final int x = (region.left - padding).clamp(0, decoded.width - 1).round();
    final int y = (region.top - padding).clamp(0, decoded.height - 1).round();
    final int w =
        (region.width + padding * 2).clamp(1, decoded.width - x).round();
    final int h =
        (region.height + padding * 2).clamp(1, decoded.height - y).round();

    img.Image crop = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    if (upscale > 1) {
      crop = img.copyResize(
        crop,
        width: w * upscale,
        height: h * upscale,
        interpolation: img.Interpolation.cubic,
      );
    }

    final String name = 'crop_${DateTime.now().microsecondsSinceEpoch}.png';
    final File out = File(p.join(outputDir, name));
    await out.writeAsBytes(img.encodePng(crop));
    return out;
  } on Object {
    return null;
  }
}
