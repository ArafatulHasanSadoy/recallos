import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:recallos/core/imaging/card_geometry.dart';
import 'package:recallos/core/imaging/card_image_processor.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recallos_imaging');
  });
  tearDown(() async => dir.delete(recursive: true));

  /// Writes a JPEG of the given size, standing in for a camera capture.
  String sourceImage(int width, int height, {String name = 'src'}) {
    final img.Image image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 180, 160));
    // A darker band, so a resize that silently returns the wrong image is
    // visible as a difference rather than passing on dimensions alone.
    img.fillRect(image,
        x1: 0, y1: 0, x2: width ~/ 2, y2: height ~/ 2,
        color: img.ColorRgb8(20, 40, 60));

    final String path = p.join(dir.path, '$name.jpg');
    File(path).writeAsBytesSync(img.encodeJpg(image));
    return path;
  }

  PreparedImage run(String source, {int maxEdge = 1600, int thumbEdge = 1000}) =>
      prepareCardImage(CardImageRequest(
        sourcePath: source,
        targetDir: dir.path,
        baseName: 'card_1',
        maxEdge: maxEdge,
        thumbEdge: thumbEdge,
      ));

  img.Image read(String path) => img.decodeImage(File(path).readAsBytesSync())!;

  double aspectOf(String path) {
    final img.Image image = read(path);
    return image.width / image.height;
  }

  /// A scanner crop: a light card sitting on a darker surface, with [border]
  /// pixels of that surface left around it because the detected quadrilateral
  /// was slightly too big.
  String scannedCard(
    int width,
    int height, {
    required int border,
    String name = 'scan',
    bool inkToEdge = false,
  }) {
    final img.Image image = img.Image(width: width, height: height);
    // The desk.
    img.fill(image, color: img.ColorRgb8(48, 56, 50));
    // The card.
    img.fillRect(image,
        x1: border,
        y1: border,
        x2: width - border - 1,
        y2: height - border - 1,
        color: img.ColorRgb8(238, 232, 222));

    if (inkToEdge) {
      // A band of print running right to the card's own edge, as on the real
      // TARGET CENTER card. Trimming "anything unlike the middle" would eat it.
      img.fillRect(image,
          x1: width - border - 1 - (width ~/ 8),
          y1: border,
          x2: width - border - 1,
          y2: height - border - 1,
          color: img.ColorRgb8(214, 40, 120));
    }

    final String path = p.join(dir.path, '$name.jpg');
    File(path).writeAsBytesSync(img.encodeJpg(image, quality: 100));
    return path;
  }

  /// Fraction of the outermost ring of pixels that still looks like desk.
  double deskRemaining(String path) {
    final img.Image image = read(path);
    int desk = 0;
    int total = 0;

    bool isDesk(int x, int y) {
      final img.Pixel px = image.getPixel(x, y);
      return px.r < 120 && px.g < 130 && px.b < 120;
    }

    for (int x = 0; x < image.width; x++) {
      total += 2;
      if (isDesk(x, 0)) desk++;
      if (isDesk(x, image.height - 1)) desk++;
    }
    for (int y = 0; y < image.height; y++) {
      total += 2;
      if (isDesk(0, y)) desk++;
      if (isDesk(image.width - 1, y)) desk++;
    }
    return desk / total;
  }

  group('trimming the border the scanner leaves', () {
    test('a scan with no trimming still shows desk around the card', () {
      // Establishes that the fixture really does have a border, so the test
      // below is measuring the trim rather than an already-clean image.
      final String source = scannedCard(1600, 1000, border: 24, name: 'raw');
      expect(deskRemaining(source), greaterThan(0.9));
    });

    test('shaves the desk off the edges', () {
      final PreparedImage out =
          run(scannedCard(1600, 1000, border: 24, name: 'bordered'));
      expect(deskRemaining(out.imagePath), lessThan(0.1));
    });

    test('keeps ink that runs to the card edge', () {
      // The failure that a naive "trim anything unlike the centre" would cause.
      final PreparedImage out = run(scannedCard(1600, 1000,
          border: 20, name: 'inked', inkToEdge: true));
      final img.Image image = read(out.imagePath);

      final img.Pixel edge =
          image.getPixel(image.width - 2, image.height ~/ 2);
      expect(edge.r, greaterThan(150), reason: 'the pink band should survive');
      expect(edge.g, lessThan(120));
    });

    test('leaves a card with no border alone', () {
      final PreparedImage out =
          run(scannedCard(1600, 1000, border: 0, name: 'clean'));
      // Nothing to trim, so the image comes through untouched.
      expect(aspectOf(out.imagePath), closeTo(1.6, 0.02));
    });

    test('never trims more than a sliver, however odd the image', () {
      // A hard ceiling is what stops a bad reference colour from cutting the
      // address line off the bottom of a card.
      final int border = 400; // far more than the cap allows
      final PreparedImage out = run(
        scannedCard(1600, 1000, border: border, name: 'huge'),
        maxEdge: 5000,
        thumbEdge: 5000,
      );
      final img.Image image = read(out.imagePath);

      expect(image.width, greaterThan(1600 * 0.85));
    });
  });

  /// A correctly-proportioned card carrying a square marker, the way a real
  /// one carries a QR code. The marker is what makes a wrong aspect
  /// measurable rather than a matter of opinion.
  img.Image trueCard() {
    const int width = 1600;
    final int height = (width / cardAspectRatio).round();
    final img.Image picture = img.Image(width: width, height: height);
    img.fill(picture, color: img.ColorRgb8(240, 238, 232));

    final int side = height ~/ 4;
    final int x = width - side - (width ~/ 12);
    final int y = (height - side) ~/ 2;
    img.fillRect(picture,
        x1: x, y1: y, x2: x + side, y2: y + side,
        color: img.ColorRgb8(20, 20, 20));
    return picture;
  }

  String write(img.Image picture, String name) {
    final String path = p.join(dir.path, '$name.jpg');
    File(path).writeAsBytesSync(img.encodeJpg(picture, quality: 100));
    return path;
  }

  /// Width divided by height of the dark marker, which must be 1.0.
  double markerAspect(String path) {
    final img.Image picture = read(path);
    int minX = picture.width, maxX = -1, minY = picture.height, maxY = -1;

    for (int y = 0; y < picture.height; y++) {
      for (int x = 0; x < picture.width; x++) {
        final img.Pixel px = picture.getPixel(x, y);
        if (px.r < 90 && px.g < 90 && px.b < 90) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return 0;
    return (maxX - minX + 1) / (maxY - minY + 1);
  }

  group('undoing a bad perspective correction', () {
    test('a square marker on a well-scanned card stays square', () {
      // The control: a plausible card shape is trusted and left untouched.
      final PreparedImage out = run(write(trueCard(), 'ok'));
      expect(markerAspect(out.imagePath), closeTo(1.0, 0.06));
    });

    test('a square marker stretched by the scanner comes back square', () {
      // The real failure, reproduced: a capture arrived at 2.24:1 with its QR
      // code 1.43x wider than tall. Nothing in the image says it is wrong
      // except that no business card is that shape.
      final img.Image stretched =
          img.copyResize(trueCard(), width: 2240, height: 1000);
      final PreparedImage out = run(write(stretched, 'stretched'));

      expect(markerAspect(out.imagePath), closeTo(1.0, 0.08));
    });

    test('an impossibly wide capture is brought back to a card shape', () {
      final PreparedImage out = run(sourceImage(2240, 1000, name: 'wide'));
      expect(aspectOf(out.imagePath), closeTo(cardAspectRatio, 0.02));
    });

    test('a plausible card shape is trusted, not reshaped', () {
      // 3.5x2 in. An earlier version forced every card to ISO ID-1 and visibly
      // stretched the ones the scanner had already got right.
      final PreparedImage out = run(sourceImage(1750, 1000, name: 'us'));
      expect(aspectOf(out.imagePath), closeTo(1.75, 0.02));
    });

    test('a portrait card is left alone', () {
      // Vertical-layout cards are real; reshaping one would destroy it.
      final PreparedImage out = run(sourceImage(1000, 1700, name: 'vertical'));
      expect(aspectOf(out.imagePath), closeTo(1000 / 1700, 0.02));
    });
  });

  group('keeping the card its own shape', () {
    // Business cards are not all ISO ID-1. 90x50 mm is ordinary here, 3.5x2 in
    // in the US, and slimmer formats exist — an earlier version scaled them all
    // to the credit-card ratio and stretched real cards by nearly a third.
    // Uniformity belongs to the frame, not to the image.
    test('a standard card keeps its proportions', () {
      final PreparedImage out = run(sourceImage(1636, 1000));
      expect(aspectOf(out.imagePath), closeTo(1.636, 0.02));
    });

    test('the thumbnail is the same shape as the card', () {
      final PreparedImage out = run(sourceImage(1700, 1000));
      expect(aspectOf(out.thumbPath), closeTo(aspectOf(out.imagePath), 0.02));
    });

    test('a receipt keeps its proportions', () {
      final PreparedImage out = run(sourceImage(1000, 3000));
      expect(aspectOf(out.imagePath), closeTo(1000 / 3000, 0.02));
    });
  });

  test('caps the long edge of a landscape capture', () {
    // 3:2 is a plausible card, so it is trusted and only resized.
    final PreparedImage out = run(sourceImage(3000, 2000));
    final img.Image image = read(out.imagePath);

    expect(image.width, 1600);
    expect(image.height, closeTo(1067, 2));
  });

  test('caps the long edge of a portrait capture', () {
    // The long edge is the height here, so capping the width would leave a
    // much bigger bitmap than intended.
    final PreparedImage out = run(sourceImage(2000, 3000));
    final img.Image image = read(out.imagePath);

    expect(image.height, 1600);
    expect(image.width, closeTo(1067, 1));
  });

  test('writes a smaller thumbnail alongside', () {
    final PreparedImage out = run(sourceImage(3000, 2000));
    final img.Image thumb = read(out.thumbPath);

    expect(thumb.width, 1000);
    expect(out.thumbPath, isNot(out.imagePath));
    expect(File(out.thumbPath).lengthSync(), greaterThan(0));
    // The whole point is that a list row decodes far less than the card does.
    expect(
      File(out.thumbPath).lengthSync(),
      lessThan(File(out.imagePath).lengthSync()),
    );
  });

  test('leaves an already-small capture exactly as it is', () {
    final PreparedImage out = run(sourceImage(800, 500));
    final img.Image image = read(out.imagePath);

    expect(image.width, 800);
    expect(image.height, 500);
  });

  test('throws a typed error for a missing file', () {
    expect(
      () => run(p.join(dir.path, 'nothing.jpg')),
      throwsA(isA<CardImageException>()),
    );
  });

  test('throws a typed error for bytes that are not an image', () {
    // Callers keep the card and carry on when this happens; an untyped crash
    // mid-capture would lose it.
    final String path = p.join(dir.path, 'junk.jpg');
    File(path).writeAsStringSync('not an image');

    expect(() => run(path), throwsA(isA<CardImageException>()));
  });
}
