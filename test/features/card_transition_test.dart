import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/card_face.dart';

/// The two ends of the flight a card makes when it is opened.
///
/// This is the class of fault the rest of the suite is blind to by default.
/// Every frame of the old transition rendered, laid out and would have passed
/// any assertion the app had: the card really did travel from the wallet tile
/// to the header, and arrived at the right place. It was wrong only on a
/// phone, in the first frame and the last — Flutter's default shuttle is the
/// *destination* hero's child, so the detail screen's photograph was drawn
/// into a 104×64 thumbnail before the card had moved, re-fitting the image and
/// snapping the corner from one radius to the other. Then the same in reverse
/// on the way home.
///
/// So these look at the object actually in the air, at three points, in both
/// directions.
void main() {
  const double tileRadius = AppRadius.cardFace;
  const double headerRadius = AppRadius.card;

  /// A wallet tile at the bottom of the screen, and a detail header at the
  /// top — the two ends the real app flies between, at their real sizes.
  ///
  /// The image file does not exist and does not need to: nothing here asserts
  /// what was painted, only the frame it was painted in. Both `Image`s carry
  /// an `errorBuilder`, which is what keeps a missing file from taking the
  /// test down.
  Widget wallet(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: CardFace(
          imagePath: '/nonexistent/thumb.jpg',
          size: Gap.cardFaceThumb,
          heroTag: cardHeroTag(1),
        ),
      ),
    ),
  );

  Widget detail(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: SizedBox(
          width: 312,
          height: 197,
          child: CardHero(
            tag: cardHeroTag(1),
            frame: const CardFrame.header(),
            imagePath: '/nonexistent/full.jpg',
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );

  final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();

  Future<void> pumpWallet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        navigatorKey: nav,
        home: Builder(builder: wallet),
      ),
    );
  }

  /// Mirrors the real card route: [AppMotion.hero] in both directions, with
  /// the page only fading so the Hero is the whole of the spatial movement.
  void open() {
    nav.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.hero,
        reverseTransitionDuration: AppMotion.hero,
        pageBuilder: (BuildContext c, _, _) => detail(c),
        transitionsBuilder: (_, Animation<double> a, _, Widget child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  /// The corner the card is actually wearing right now.
  double corner(WidgetTester tester) {
    final ClipRRect clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(CardFlight),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    return clip.borderRadius.resolve(TextDirection.ltr).topLeft.x;
  }

  testWidgets('one object is in the air, not two', (WidgetTester tester) async {
    await pumpWallet(tester);
    open();
    await tester.pump();
    await tester.pump(AppMotion.hero ~/ 2);

    expect(
      find.byType(CardFlight),
      findsOneWidget,
      reason:
          'the flight fell back to Flutter\'s default shuttle, which is '
          'one end\'s widget crammed into the other end\'s box',
    );
  });

  testWidgets('the corner grows across the flight rather than snapping', (
    WidgetTester tester,
  ) async {
    await pumpWallet(tester);
    open();

    // First frame in the air: still the tile's corner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      corner(tester),
      closeTo(tileRadius, 0.6),
      reason: 'the card changes shape before it has moved',
    );

    // Halfway: neither end's corner, which is the whole point.
    await tester.pump(AppMotion.hero ~/ 2);
    final double middle = corner(tester);
    expect(middle, greaterThan(tileRadius));
    expect(middle, lessThan(headerRadius));

    // Landing: the header's corner, so nothing snaps as the shuttle is
    // swapped for the real widget.
    await tester.pump(AppMotion.hero ~/ 2 - const Duration(milliseconds: 8));
    expect(
      corner(tester),
      closeTo(headerRadius, 0.6),
      reason: 'the card snaps into its final shape after it has landed',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('and shrinks back the same way on the way home', (
    WidgetTester tester,
  ) async {
    await pumpWallet(tester);
    open();
    await tester.pumpAndSettle();

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      corner(tester),
      closeTo(headerRadius, 0.6),
      reason: 'the card snaps to the thumbnail corner before it sets off',
    );

    // The reverse reads the flight the other way round — the route animation
    // runs 1→0 on a pop while the rect tween still runs from→to. Getting that
    // backwards is silent: the flight looks right going out and inverts on the
    // way home.
    await tester.pump(AppMotion.hero ~/ 2);
    final double middle = corner(tester);
    expect(middle, greaterThan(tileRadius));
    expect(middle, lessThan(headerRadius));

    await tester.pump(AppMotion.hero ~/ 2 - const Duration(milliseconds: 8));
    expect(
      corner(tester),
      closeTo(tileRadius, 0.6),
      reason: 'the card does not arrive back at the tile\'s own corner',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('it travels in a straight line', (WidgetTester tester) async {
    await pumpWallet(tester);
    final Offset start = tester.getRect(find.byType(CardFace)).center;

    open();
    await tester.pumpAndSettle();
    final Offset end = tester.getRect(find.byType(CardHero)).center;

    nav.currentState!.pop();
    await tester.pumpAndSettle();

    open();
    await tester.pump();

    // How far off the line from start to end the card has strayed. Distance
    // *along* that line is not the question — Flutter paces a hero on
    // `Curves.fastOutSlowIn`, so it is four fifths of the way home at the
    // halfway mark and should be. The question is whether it left the line at
    // all, which a `MaterialRectArcTween` — what this used to use — makes it
    // do: it swings the two corners along separate circles, so the card bows
    // out sideways and changes proportion on the way. A card lifted out of a
    // wallet goes where it is going.
    double strayed(Offset at) {
      final Offset line = end - start;
      final Offset from = at - start;
      return (line.dx * from.dy - line.dy * from.dx).abs() / line.distance;
    }

    for (final Duration at in <Duration>[
      AppMotion.hero ~/ 4,
      AppMotion.hero ~/ 4,
      AppMotion.hero ~/ 4,
    ]) {
      await tester.pump(at);
      expect(
        strayed(tester.getRect(find.byType(CardFlight)).center),
        lessThan(2),
      );
    }

    await tester.pumpAndSettle();
  });
}
