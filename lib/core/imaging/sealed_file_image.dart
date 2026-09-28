import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'photo_keyring.dart';
import 'photo_vault.dart';

/// [FileImage] for photographs that may be sealed on disk.
///
/// Every stored photograph is displayed through this, never through
/// `Image.file` or `FileImage` — those hand the raw bytes to the decoder, and a
/// sealed file is not a JPEG until it has been opened with the photo key. An
/// unsealed file (a photo from before encryption, or a gallery picture) is
/// shown exactly as `FileImage` would show it.
///
/// Equality is by path and scale, like [FileImage], so the image cache works
/// the same way it always has.
@immutable
class SealedFileImage extends ImageProvider<SealedFileImage> {
  const SealedFileImage(this.file, {this.scale = 1.0});

  final File file;
  final double scale;

  /// Photographs bigger than this are opened on a background isolate; a full
  /// card is ~400 KB and decrypting it on the UI thread would drop a frame on
  /// the phones this app is built for. Thumbnails are small enough not to.
  static const int _isolateThreshold = 256 * 1024;

  @override
  Future<SealedFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<SealedFileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    SealedFileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(key, decode),
    scale: key.scale,
    debugLabel: key.file.path,
    informationCollector: () => <DiagnosticsNode>[
      ErrorDescription('Path: ${file.path}'),
    ],
  );

  Future<ui.Codec> _load(SealedFileImage key, ImageDecoderCallback decode) async {
    final Uint8List raw = await key.file.readAsBytes();
    if (raw.isEmpty) {
      // Same as FileImage: an empty file is not cached as a broken image, so
      // a file still being written shows once it is complete.
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('${key.file.path} is empty and cannot be loaded.');
    }

    Uint8List plain = raw;
    if (isSealedPhoto(raw)) {
      final Uint8List? photoKey = await PhotoKeyring.instance.key;
      plain = raw.length > _isolateThreshold
          ? await Isolate.run(() => openPhoto(photoKey, raw))
          : openPhoto(photoKey, raw);
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(plain));
  }

  @override
  bool operator ==(Object other) =>
      other is SealedFileImage &&
      other.file.path == file.path &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(file.path, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'SealedFileImage')}("${file.path}", scale: $scale)';
}

/// A [SealedFileImage], decoded at [cacheWidth]/[cacheHeight] when given —
/// what `Image.file`'s `cacheWidth` did, so list rows never decode a full
/// capture.
ImageProvider sealedPhoto(File file, {int? cacheWidth, int? cacheHeight}) =>
    ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, SealedFileImage(file));
