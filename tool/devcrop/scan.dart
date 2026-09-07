import 'dart:io';

import 'package:image/image.dart' as img;

/// Measures a screenshot instead of eyeballing it.
///
/// Prints the vertical runs of card-coloured pixels down one column, which is
/// how the wallet stack's real pitch and tile height get checked against
/// `design/screens.html` on a physical device.
///
/// `dart run tool/devcrop/scan.dart <png> <x> <yFrom> <yTo>`
void main(List<String> args) {
  final img.Image image = img.decodeImage(File(args[0]).readAsBytesSync())!;
  final int x = int.parse(args[1]);

  bool onCard(int y) {
    final img.Pixel p = image.getPixel(x, y);
    return (p.r - 251).abs() < 6 && (p.g - 247).abs() < 6 && (p.b - 238).abs() < 8;
  }

  int? start;
  for (int y = int.parse(args[2]); y < int.parse(args[3]); y++) {
    final bool card = onCard(y);
    if (card && start == null) start = y;
    if (!card && start != null) {
      final int top = start;
      if (y - top > 20) stdout.writeln('run top=$top h=${y - top}');
      start = null;
    }
  }
}
