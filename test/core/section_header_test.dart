import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/primitives.dart';

/// Section labels are wide-tracked caps, and run long. At 1.3× text on a
/// narrow phone, "Other text on the card" with its count overflowed the row
/// — the yellow-and-black stripe that renders, passes every assertion about
/// text, and is wrong only on a phone. A label past the cap now wraps.
void main() {
  for (final (String label, double scale, int count) in <(String, double, int)>[
    ('Other text on the card', 1.3, 12),
    ('Example · when an event ends', 1.3, 12),
    ('Next step planned', 1.3, 12),
    ('Next step planned', 2.0, 128),
  ]) {
    testWidgets('"$label" fits a narrow phone at $scale× text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: SectionHeader(label, count: count),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('$count'), findsOneWidget);
    });
  }
}
