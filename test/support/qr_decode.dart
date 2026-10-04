import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a QR code out of a PNG the way a camera would: from pixels, with no
/// knowledge of what was encoded. The image is laid on white with a margin
/// round it first — the paper tile and its padding on screen, which is the
/// quiet zone a scanner needs to find the corners. [margin] is zero for a
/// screenshot, which already has its surroundings.
String decodeQrPng(Uint8List png, {int margin = 48}) {
  final img.Image raw = img.decodePng(png)!;
  final img.Image flat = img.Image(
    width: raw.width + 2 * margin,
    height: raw.height + 2 * margin,
    numChannels: 4,
  )..clear(img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(flat, raw, dstX: margin, dstY: margin);
  final LuminanceSource source = RGBLuminanceSource(
    flat.width,
    flat.height,
    flat.getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
  );
  final Result result = QRCodeReader().decode(
    BinaryBitmap(HybridBinarizer(source)),
    hints: DecodeHints()..put(DecodeHintType.tryHarder),
  );
  // zxing2 reads the bytes correctly and then hands them to Dart's UTF-8
  // decoder as *signed* bytes, so every byte over 127 becomes U+FFFD and any
  // non-Latin name comes back as a row of question marks. A phone's scanner
  // has no such bug, so the bytes are read here and decoded the way it does.
  final Object? segments =
      result.resultMetadata[ResultMetadataType.byteSegments];
  if (segments is List<Int8List>) {
    return utf8.decode(<int>[
      for (final Int8List seg in segments) ...Uint8List.view(seg.buffer),
    ]);
  }
  return result.text;
}
