/// Prepares a portrait for the user's own card.
///
/// A sibling of `card_image_processor.dart` rather than a parameter on it, and
/// the reason is the difference between a card and a face. `prepareCardImage`
/// trims the rim of desk a scanner leaves around a card and un-stretches an
/// implausible aspect ratio back to card-shaped — both correct for a rectangle
/// of printed paper, and both wrong for a photograph of a person, where they
/// would crop somebody's chin off and squash what remained.
///
/// So this does the three things a portrait actually needs and nothing else:
/// bake the orientation the camera recorded as metadata, cap the long edge, and
/// re-encode. Deliberately Flutter-free, like its sibling, so it can be handed
/// to `Isolate.run` — decoding a full-resolution photograph on the UI thread
/// drops frames on exactly the hardware this app is aimed at.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'photo_vault.dart';

/// Everything [preparePortrait] needs, in one sendable object.
class PortraitRequest {
  const PortraitRequest({
    required this.sourcePath,
    required this.targetDir,
    required this.baseName,
    this.maxEdge = 512,
    this.photoKey,
  });

  /// Seals the stored portrait when given. See `photo_vault.dart`.
  final Uint8List? photoKey;

  final String sourcePath;
  final String targetDir;
  final String baseName;

  /// Drawn at 44px on the card and never larger, so 512 is already generous —
  /// it leaves room for a future bigger treatment without keeping a two-megabyte
  /// selfie on a phone that was short of space to begin with.
  final int maxEdge;
}

/// Raised when the bytes are not an image this can work with.
class PortraitImageException implements Exception {
  const PortraitImageException(this.reason);

  final String reason;

  @override
  String toString() => 'PortraitImageException: $reason';
}

/// Writes the portrait and returns where it landed.
String preparePortrait(PortraitRequest request) {
  final File source = File(request.sourcePath);
  if (!source.existsSync()) {
    throw const PortraitImageException('the picked file is not there');
  }

  final img.Image? decoded = img.decodeImage(
    readPhotoSync(request.sourcePath, request.photoKey),
  );
  if (decoded == null) {
    throw const PortraitImageException('those bytes are not an image');
  }

  // EXIF orientation baked in rather than carried. A portrait shown sideways
  // is the commonest photo bug there is, and it happens whenever a viewer
  // reads the pixels and ignores the tag.
  final img.Image upright = img.bakeOrientation(decoded);

  final int longest = upright.width > upright.height
      ? upright.width
      : upright.height;
  final img.Image sized = longest <= request.maxEdge
      // Already small enough. Re-encoding it anyway would cost a generation of
      // JPEG quality for nothing.
      ? upright
      : (upright.width >= upright.height
            ? img.copyResize(upright, width: request.maxEdge)
            : img.copyResize(upright, height: request.maxEdge));

  final String path = p.join(request.targetDir, '${request.baseName}.jpg');
  writePhotoSync(path, img.encodeJpg(sized, quality: 85), request.photoKey);
  return path;
}
