import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'card_geometry.dart';

/// What one capture produced: the image everything else works from, and a
/// smaller copy for list rows.
class PreparedImage {
  const PreparedImage({required this.imagePath, required this.thumbPath});

  /// The card itself, capped at [CardImageRequest.maxEdge].
  ///
  /// This is the file OCR reads *and* the file the screens display. The two
  /// must not diverge: field regions are stored in this image's pixel space, so
  /// a different image on screen puts every highlight in the wrong place.
  final String imagePath;

  /// A smaller copy for the library list, where a dozen full-size decodes would
  /// exhaust the heap on a cheap phone.
  final String thumbPath;
}

/// Everything [prepareCardImage] needs, in one sendable object.
class CardImageRequest {
  const CardImageRequest({
    required this.sourcePath,
    required this.targetDir,
    required this.baseName,
    this.maxEdge = 1600,
    this.thumbEdge = 1000,
  });

  final String sourcePath;
  final String targetDir;

  /// Filename stem; the two outputs are `<baseName>.jpg` and
  /// `<baseName>_thumb.jpg`.
  final String baseName;

  /// Long edge of the stored card. Card text stays legible well below a
  /// sensor's full resolution, and a 12-megapixel bitmap decodes to ~50 MB —
  /// which is what actually kills this app on a 3 GB phone.
  final int maxEdge;

  /// Long edge of the thumbnail. Large by thumbnail standards because these are
  /// full-width card art in the library, not 56 px squares.
  final int thumbEdge;
}

class CardImageException implements Exception {
  const CardImageException(this.reason);
  final String reason;
  @override
  String toString() => 'CardImageException: $reason';
}

/// Downscales a captured card and writes a thumbnail beside it.
///
/// Synchronous and free of any Flutter import, so it can be handed straight to
/// `Isolate.run` — decoding and resizing a full-resolution photo on the UI
/// thread drops frames on exactly the hardware this app is aimed at. Being a
/// plain function also makes it testable without a device.
PreparedImage prepareCardImage(CardImageRequest request) {
  final File source = File(request.sourcePath);
  if (!source.existsSync()) {
    throw CardImageException('No image at ${request.sourcePath}');
  }

  final Uint8List bytes = source.readAsBytesSync();
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const CardImageException('Could not decode the captured image');
  }

  // Rotate the pixels to match any EXIF orientation and drop the tag, so every
  // later reader — ML Kit, Flutter, the region painter — agrees on which way up
  // the card is without having to interpret metadata.
  final img.Image upright = img.bakeOrientation(decoded);

  // Shave the rim of desk, then undo any impossible stretch. Both happen
  // before anything reads the image, so OCR records its regions against the
  // final geometry.
  final img.Image shaped = _unstretch(_trimBackground(upright));

  final String imagePath = p.join(request.targetDir, '${request.baseName}.jpg');
  final String thumbPath =
      p.join(request.targetDir, '${request.baseName}_thumb.jpg');

  File(imagePath).writeAsBytesSync(
    img.encodeJpg(_within(shaped, request.maxEdge), quality: 85),
  );
  File(thumbPath).writeAsBytesSync(
    img.encodeJpg(_within(shaped, request.thumbEdge), quality: 80),
  );

  return PreparedImage(imagePath: imagePath, thumbPath: thumbPath);
}

/// The proportions a landscape business card can actually have.
///
/// The standards cluster tightly: 85×55 mm (1.55), 85.6×54 ISO ID-1 (1.59),
/// 90×55 (1.64), 3.5×2 in (1.75), 90×50 (1.80). A little slack is added for
/// the border trim. Anything outside this is not a card shape.
const double _minCardAspect = 1.45;
const double _maxCardAspect = 1.90;

/// Below this, treat the image as a genuinely square or portrait card and
/// leave it alone — vertical-layout cards are real, and reshaping one would
/// destroy it.
const double _portraitCeiling = 1.20;

/// Undoes a perspective correction that came back the wrong shape.
///
/// The document scanner warps the quadrilateral it detected into a rectangle,
/// but recovering a card's true proportions from a single photograph needs the
/// camera's intrinsics. Without them the scanner approximates, and at a steep
/// angle it can be well out — a real capture came back at 2.24:1, stretched
/// horizontally by 43%, which was measurable because the card carried a QR
/// code and a QR code is square. Correcting that one landed on 1.567, which is
/// ISO ID-1 to within a rounding error.
///
/// So the scanner is trusted whenever it returns a shape a card could actually
/// be, and overridden only when it returns one no card has. That distinction
/// matters: an earlier version reshaped *everything* to the credit-card ratio
/// and visibly stretched the cards the scanner had got right.
///
/// Only the deficient axis is grown, so nothing is cropped away; [_within]
/// brings the result back under the size cap afterwards.
img.Image _unstretch(img.Image src) {
  if (src.width <= 0 || src.height <= 0) return src;

  final double aspect = src.width / src.height;
  if (aspect < _portraitCeiling) return src;
  if (aspect >= _minCardAspect && aspect <= _maxCardAspect) return src;

  return aspect > _maxCardAspect
      // Too wide for any card: it is short of height.
      ? img.copyResize(
          src,
          width: src.width,
          height: (src.width / cardAspectRatio).round(),
          interpolation: img.Interpolation.cubic,
        )
      // Too square for a landscape card: it is short of width.
      : img.copyResize(
          src,
          width: (src.height * cardAspectRatio).round(),
          height: src.height,
          interpolation: img.Interpolation.cubic,
        );
}

/// Most of a line has to be background before that line is shaved off.
///
/// The rim the scanner leaves is usually wedge-shaped rather than even — the
/// detected quadrilateral is a little rotated as well as a little large — so a
/// line near the edge is part background, part card. Trimming while a quarter
/// of it is background clears the visible dark edging; demanding more would
/// leave a fringe, and demanding less would start eating the card.
const double _backgroundLineFraction = 0.25;

/// How much of each side may be shaved at most.
///
/// A hard ceiling matters more than the detection does: if the reference
/// colour is wrong for any reason, this is what stops a runaway trim from
/// cutting the address line off the bottom of a card.
const double _maxTrimFraction = 0.06;

/// How different two colours must be to count as different materials.
const double _colourDistance = 48;

/// Removes the border of desk, hand or tablecloth left around a scanned card.
///
/// The document scanner crops to the quadrilateral it detected, and that
/// quadrilateral sits slightly outside the card — so the "cropped" card arrives
/// with a thin dark rim, which then gets baked into the rounded tile and looks
/// like a printing fault.
///
/// The rim is identified by what it *is* rather than by where it is: the four
/// corners are sampled for the surface the card was lying on, and lines are
/// shaved from each edge only while they are largely made of that colour. That
/// distinction matters, because plenty of cards carry a band of ink right to
/// their own edge — trimming "anything unlike the middle" would eat it, while
/// trimming "things that look like the tablecloth" leaves it alone.
///
/// Returns [src] untouched when the corners disagree, when they match the card
/// itself, or when the trim would exceed [_maxTrimFraction].
img.Image _trimBackground(img.Image src) {
  if (src.width < 40 || src.height < 40) return src;

  final _Rgb? background = _cornerColour(src);
  if (background == null) return src;

  final int maxX = (src.width * _maxTrimFraction).round();
  final int maxY = (src.height * _maxTrimFraction).round();

  int left = 0;
  while (left < maxX && _columnIsBackground(src, background, left)) {
    left++;
  }
  int right = src.width - 1;
  while (src.width - 1 - right < maxX &&
      _columnIsBackground(src, background, right)) {
    right--;
  }
  int top = 0;
  while (top < maxY && _rowIsBackground(src, background, top)) {
    top++;
  }
  int bottom = src.height - 1;
  while (src.height - 1 - bottom < maxY &&
      _rowIsBackground(src, background, bottom)) {
    bottom--;
  }

  final int width = right - left + 1;
  final int height = bottom - top + 1;
  if (width < src.width * 0.5 || height < src.height * 0.5) return src;
  if (width == src.width && height == src.height) return src;

  return img.copyCrop(src, x: left, y: top, width: width, height: height);
}

/// The colour of whatever the card was resting on, read from the corners.
///
/// Corners are used because that is where an over-large crop shows most. Null
/// when they do not agree with each other, or when they look like the card —
/// either way there is no border worth trimming and guessing would be worse
/// than leaving the image alone.
_Rgb? _cornerColour(img.Image src) {
  final int patch = math.max(4, (math.min(src.width, src.height) * 0.04).round());

  final List<_Rgb> corners = <_Rgb>[
    _median(src, 0, 0, patch),
    _median(src, src.width - patch, 0, patch),
    _median(src, 0, src.height - patch, patch),
    _median(src, src.width - patch, src.height - patch, patch),
  ];

  // All four have to describe the same surface, or what is in the corners is
  // card rather than background.
  for (final _Rgb corner in corners) {
    if (corner.distanceTo(corners.first) > _colourDistance) return null;
  }

  final _Rgb centre = _median(
    src,
    (src.width - patch) ~/ 2,
    (src.height - patch) ~/ 2,
    patch,
  );
  if (corners.first.distanceTo(centre) <= _colourDistance) return null;

  return corners.first;
}

bool _rowIsBackground(img.Image src, _Rgb background, int y) =>
    _fractionMatching(src, background, y: y) >= _backgroundLineFraction;

bool _columnIsBackground(img.Image src, _Rgb background, int x) =>
    _fractionMatching(src, background, x: x) >= _backgroundLineFraction;

/// How much of one row or column is the background colour.
///
/// Sampled every fourth pixel: this runs over every edge of a multi-megapixel
/// image and the answer does not change for looking at all of them.
double _fractionMatching(img.Image src, _Rgb background, {int? x, int? y}) {
  const int step = 4;
  int matched = 0;
  int total = 0;

  if (y != null) {
    for (int i = 0; i < src.width; i += step) {
      total++;
      if (_at(src, i, y).distanceTo(background) <= _colourDistance) matched++;
    }
  } else {
    for (int i = 0; i < src.height; i += step) {
      total++;
      if (_at(src, x!, i).distanceTo(background) <= _colourDistance) matched++;
    }
  }
  return total == 0 ? 0 : matched / total;
}

/// Median colour of a square patch, which ignores specks and glare in a way a
/// mean does not.
_Rgb _median(img.Image src, int x0, int y0, int size) {
  final List<int> reds = <int>[];
  final List<int> greens = <int>[];
  final List<int> blues = <int>[];

  for (int y = y0; y < math.min(y0 + size, src.height); y++) {
    for (int x = x0; x < math.min(x0 + size, src.width); x++) {
      final _Rgb pixel = _at(src, x, y);
      reds.add(pixel.r);
      greens.add(pixel.g);
      blues.add(pixel.b);
    }
  }
  if (reds.isEmpty) return const _Rgb(0, 0, 0);

  reds.sort();
  greens.sort();
  blues.sort();
  final int mid = reds.length ~/ 2;
  return _Rgb(reds[mid], greens[mid], blues[mid]);
}

_Rgb _at(img.Image src, int x, int y) {
  final img.Pixel pixel = src.getPixel(x, y);
  return _Rgb(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
}

class _Rgb {
  const _Rgb(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;

  double distanceTo(_Rgb other) {
    final int dr = r - other.r;
    final int dg = g - other.g;
    final int db = b - other.b;
    return math.sqrt((dr * dr + dg * dg + db * db).toDouble());
  }
}

/// Scales [src] down so its longest side is at most [maxEdge], preserving the
/// aspect ratio. Images already smaller than that are left alone rather than
/// upscaled into blur.
img.Image _within(img.Image src, int maxEdge) {
  final int longest = math.max(src.width, src.height);
  if (longest <= maxEdge) return src;

  return src.width >= src.height
      ? img.copyResize(src, width: maxEdge, interpolation: img.Interpolation.average)
      : img.copyResize(src, height: maxEdge, interpolation: img.Interpolation.average);
}
