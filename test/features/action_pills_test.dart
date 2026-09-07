import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/primitives.dart';

/// Pills have to hug their label.
///
/// A `Center` inside a `Wrap` expands to the full available width, so each
/// pill claimed an entire row and the card's four actions came out stacked
/// down the middle of the screen. Nothing threw, nothing overflowed, and every
/// existing test stayed green — it is only visible on a phone, which is why it
/// is pinned here.
void main() {
  Future<double> pumpRow(WidgetTester tester, List<String> labels) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: <Widget>[
                for (final String l in labels)
                  Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: OutlinePill(label: l, height: 44, onTap: () {}),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getSize(find.byType(Wrap)).height;
  }

  testWidgets('a pill is only as wide as its label needs',
      (WidgetTester tester) async {
    await pumpRow(tester, <String>['Call']);

    final double width = tester.getSize(find.byType(OutlinePill)).width;
    expect(width, lessThan(200),
        reason: 'the pill stretched to fill its parent');
    // 18px of padding each side plus a four-letter word.
    expect(width, greaterThan(50));
  });

  testWidgets('four actions flow rather than stacking',
      (WidgetTester tester) async {
    final double height = await pumpRow(
      tester,
      <String>['Call', 'WhatsApp', 'Email', 'Map'],
    );

    // Two rows at most on a 360dp phone. Four would mean each pill took the
    // whole width, which is the bug.
    expect(height, lessThanOrEqualTo(44 * 2 + Gap.sm),
        reason: 'the pills are stacking one per row');
  });

  testWidgets('the label clears the rounded ends',
      (WidgetTester tester) async {
    await pumpRow(tester, <String>['Map']);

    final Rect pill = tester.getRect(find.byType(OutlinePill));
    final Rect label = tester.getRect(find.text('Map'));

    // The corner radius is half the height, so without real padding the curve
    // cuts into the first and last letters.
    expect(label.left - pill.left, greaterThanOrEqualTo(16));
    expect(pill.right - label.right, greaterThanOrEqualTo(16));
  });

  testWidgets('a 44 pill still answers a 52 touch',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: OutlinePill(
                label: 'Call',
                height: 44,
                hitPadding: const EdgeInsets.symmetric(vertical: 4),
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Rect r = tester.getRect(find.byType(OutlinePill));
    expect(r.height, closeTo(52, 0.01),
        reason: 'the hit padding is not part of the target');

    // A press 3px above the drawn pill still lands.
    await tester.tapAt(Offset(r.center.dx, r.top + 2));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('chips flow rather than stacking', (WidgetTester tester) async {
    // The same expansion trap as the pills, in a different widget: a
    // `Container` given an `alignment` wraps its child in an `Align`, which
    // fills whatever it is handed. Inside a `Wrap` that is the full width, so
    // seven field-label chips came down the sheet one per line.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              children: <Widget>[
                for (final String l in <String>['Name', 'Company', 'Phone'])
                  SelectChip(label: l, selected: l == 'Phone', onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final double widest = tester
        .widgetList<SelectChip>(find.byType(SelectChip))
        .map((SelectChip w) => tester.getSize(find.byWidget(w)).width)
        .reduce((double a, double b) => a > b ? a : b);

    expect(widest, lessThan(160), reason: 'a chip stretched to fill the row');
    // Three short chips belong on one line. The row is `kMinTarget` tall
    // rather than `SelectChip.height`, because the chip draws 38 and carries
    // its touch target in `hitPadding` around it.
    expect(tester.getSize(find.byType(Wrap)).height,
        lessThanOrEqualTo(kMinTarget + Gap.xs));
  });
}
