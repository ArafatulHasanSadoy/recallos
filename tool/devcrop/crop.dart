/// Crops and upscales a region of a device screenshot for close inspection.
///
/// `dart run tool/devcrop/crop.dart <png> <x> <y> <w> <h> <out.jpg>`
library;
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> a) {
  final img.Image src = img.decodeImage(File(a[0]).readAsBytesSync())!;
  final img.Image out = img.copyCrop(src,
      x: int.parse(a[1]), y: int.parse(a[2]),
      width: int.parse(a[3]), height: int.parse(a[4]));
  final img.Image up = img.copyResize(out,
      width: (out.width * 2.0).round(),
      interpolation: img.Interpolation.cubic);
  File(a[5]).writeAsBytesSync(img.encodeJpg(up, quality: 95));
  stdout.writeln('ok ${up.width}x${up.height}');
}
