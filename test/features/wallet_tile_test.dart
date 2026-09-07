import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/primitives.dart';
import 'package:recallos/core/ui/wallet_stack.dart';

/// The stack hides the bottom of every tile except the last one.
///
/// A tile is 116 tall on a 92 pitch, so the lowest 24 are behind the next
/// card. Anything laid out down there is rendered, hit-testable and findable
/// by a widget test, and invisible on a phone — which is exactly how the
/// metadata line was lost the first time. These pin the content into the band
/// that is actually on screen.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    double width = 346,
    double scale = 1,
    String subtitle = 'Cheapest for 20+ tees. Slow on delivery.',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (BuildContext c, Widget? w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: WalletCardTile(
              title: 'Sharif Printing',
              subtitle: subtitle,
              meta: MetaLabel('Farmgate · 3d'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the meta line sits where it can be seen',
      (WidgetTester tester) async {
    await pump(tester);

    final Rect meta = tester.getRect(find.text('FARMGATE · 3D'));
    final Rect tile = tester.getRect(find.byType(WalletCardTile));

    expect(meta.bottom - tile.top,
        lessThanOrEqualTo(tile.height * StackMetrics.visibleFraction),
        reason: 'the meta line is behind the next card in the stack');
  });

  testWidgets('a long note cannot push it under the next card',
      (WidgetTester tester) async {
    // The real failure mode: the frames' sample note fits one line at 390dp,
    // and every phone narrower than that wraps it.
    await pump(
      tester,
      width: 300,
      subtitle: 'Cotton wholesale, ask for Nabil directly, and bring a '
          'written quote if you want him to match it.',
    );

    final Rect meta = tester.getRect(find.text('FARMGATE · 3D'));
    final Rect tile = tester.getRect(find.byType(WalletCardTile));

    expect(meta.bottom - tile.top,
        lessThanOrEqualTo(tile.height * StackMetrics.visibleFraction));
  });

  testWidgets('and larger type does not either', (WidgetTester tester) async {
    // DESIGN.md §5 asks for 1.3 explicitly, and names the stack as the first
    // thing that breaks.
    await pump(tester, scale: 1.3);

    final Rect meta = tester.getRect(find.text('FARMGATE · 3D'));
    final Rect tile = tester.getRect(find.byType(WalletCardTile));

    expect(meta.bottom - tile.top,
        lessThanOrEqualTo(tile.height * StackMetrics.visibleFraction));
  });

  testWidgets('the stack overlaps by the difference between pitch and height',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CardStack(
            count: 3,
            builder: (BuildContext c, int i) => WalletCardTile(
              title: 'Card $i',
              subtitle: 'note',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final List<Rect> tiles = tester
        .widgetList<WalletCardTile>(find.byType(WalletCardTile))
        .map((WalletCardTile w) => tester.getRect(find.byWidget(w)))
        .toList();

    expect(tiles, hasLength(3));
    expect(tiles[1].top - tiles[0].top, Gap.stackPitch);
    expect(tiles[0].height, Gap.stackCardHeight);
    expect(StackMetrics.visibleFraction, closeTo(92 / 116, 0.001));
    // The overlap is the metaphor. Without it this is a list.
    expect(tiles[0].bottom, greaterThan(tiles[1].top));
  });
}
