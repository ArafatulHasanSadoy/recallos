import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:recallos/features/cards/presentation/widgets/wallet_card.dart';

void main() {
  late Directory dir;
  late String cardPath;

  /// Writes a JPEG of the given size and returns its path.
  String image(int width, int height, {String name = 'card'}) {
    final img.Image picture = img.Image(width: width, height: height);
    img.fill(picture, color: img.ColorRgb8(40, 90, 70));
    final String path = p.join(dir.path, '$name.jpg');
    File(path).writeAsBytesSync(img.encodeJpg(picture));
    return path;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recallos_wallet');
    cardPath = image(600, 380);
  });
  tearDown(() async => dir.delete(recursive: true));

  /// The sharp card image, as opposed to any fill behind it.
  Image art(WidgetTester tester) =>
      tester.widget<Image>(find.byKey(const ValueKey<String>('card-art')));

  Future<void> pump(
    WidgetTester tester, {
    required String path,
    bool needsAttention = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final Widget app = MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: WalletCard(
            imagePath: path,
            needsAttention: needsAttention,
          ),
        ),
      ),
    );

    // Reading a file off disk is real I/O, and the fake clock a widget test
    // runs under never completes it — so the tile would be judged before it
    // knows the card's shape.
    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('holds the credit-card proportion', (WidgetTester tester) async {
    await pump(tester, path: cardPath);

    final Size size = tester.getSize(find.byType(WalletCard));
    expect(size.width / size.height, closeTo(WalletCard.aspectRatio, 0.01));
  });

  testWidgets('lays out on a narrow screen without overflowing', (
    WidgetTester tester,
  ) async {
    await pump(tester, path: cardPath);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills the frame when the card is close to card-shaped', (
    WidgetTester tester,
  ) async {
    // 600x380 is 1.58, near enough to the frame that cover trims nothing worth
    // keeping and the tile reads as a solid card.
    await pump(tester, path: cardPath);

    expect(art(tester).fit, BoxFit.cover);
  });

  testWidgets('fills the frame with a slim card too', (
    WidgetTester tester,
  ) async {
    // A real 2.05:1 card. It still goes edge to edge — a wallet card with a
    // border round it does not look like a card.
    await pump(tester, path: image(1230, 600, name: 'slim'));

    expect(art(tester).fit, BoxFit.cover);
  });

  testWidgets('crops from the far edge so the logo corner survives', (
    WidgetTester tester,
  ) async {
    await pump(tester, path: image(1230, 600, name: 'slim'));

    expect(art(tester).alignment, Alignment.topLeft);
  });

  testWidgets('fits a portrait photograph rather than showing a patch of it', (
    WidgetTester tester,
  ) async {
    // Cropping a portrait photo to a landscape frame shows the middle of
    // somebody's desk. Only legacy cards, saved before edge detection.
    await pump(tester, path: image(900, 1200, name: 'photo'));

    expect(art(tester).fit, BoxFit.contain);
  });

  testWidgets('no card is ever left sitting in dead space', (
    WidgetTester tester,
  ) async {
    // Either the card covers the frame itself, or something fills in behind
    // it. A tile with bare background showing does not read as a card.
    for (final List<int> size in <List<int>>[
      <int>[600, 380],
      <int>[1230, 600],
      <int>[900, 1200],
    ]) {
      await pump(tester, path: image(size[0], size[1], name: 'f${size[0]}'));
      final bool fills = art(tester).fit == BoxFit.cover;
      expect(
        fills || find.byType(CardBackdrop).evaluate().isNotEmpty,
        isTrue,
        reason: '${size[0]}x${size[1]} leaves the frame partly empty',
      );
    }
  });

  testWidgets('never distorts the card', (WidgetTester tester) async {
    // The regression that made cards look elongated: the fit must always be
    // one that preserves proportions.
    for (final List<int> size in <List<int>>[
      <int>[600, 380],
      <int>[1230, 600],
      <int>[900, 1200],
    ]) {
      await pump(tester, path: image(size[0], size[1], name: 'd${size[0]}'));
      expect(
        art(tester).fit,
        anyOf(BoxFit.cover, BoxFit.contain),
        reason: '${size[0]}x${size[1]} must not be stretched',
      );
    }
  });

  testWidgets('decodes at draw size rather than native size', (
    WidgetTester tester,
  ) async {
    await pump(tester, path: cardPath);

    // 360 dp of screen minus 16 dp padding each side, at 3x.
    final ResizeImage provider = art(tester).image as ResizeImage;
    expect(provider.width, (360 - 32) * 3);
  });

  testWidgets('shows a card face rather than a broken image when the file is gone',
      (WidgetTester tester) async {
    await pump(tester, path: p.join(dir.path, 'missing.jpg'));

    expect(find.byIcon(Icons.credit_card_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('badges a card that needs attention', (
    WidgetTester tester,
  ) async {
    await pump(tester, path: cardPath, needsAttention: true);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
  });
}
