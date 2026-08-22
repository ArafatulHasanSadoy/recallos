import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';

/// Guards the button sizing that silently broke a whole screen.
///
/// `Size.fromHeight(52)` reads like "at least 52 tall" and is in fact
/// `Size(infinity, 52)` — an infinite *minimum width*. A button carrying it
/// into any parent that measures children against unbounded width, which a
/// `Row` does, demands infinite width; layout fails, and everything around it
/// in the enclosing list stops painting. Nothing throws where a person would
/// see it. The screen just comes up blank.
void main() {
  group('button sizing', () {
    test('minimum width is finite', () {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        for (final (String name, Size? size) in <(String, Size?)>[
          ('filled', theme.filledButtonTheme.style?.minimumSize
              ?.resolve(<WidgetState>{})),
          ('outlined', theme.outlinedButtonTheme.style?.minimumSize
              ?.resolve(<WidgetState>{})),
        ]) {
          expect(size, isNotNull, reason: '$name button has no minimum size');
          expect(size!.width.isFinite, isTrue,
              reason: '$name button demands infinite width');
          expect(size.height, 52,
              reason: '$name button lost its generous tap target');
        }
      }
    });
  });

  testWidgets('a themed button lays out inside a Row in a list',
      (WidgetTester tester) async {
    // The exact shape that failed: buttons side by side in a card in a list,
    // with no Expanded to clamp them.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListView(
          children: <Widget>[
            const Text('sibling above'),
            Card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(onPressed: () {}, child: const Text('No')),
                  FilledButton(onPressed: () {}, child: const Text('Yes')),
                ],
              ),
            ),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    // The sibling is the tell: when the button broke layout, rows either side
    // of it disappeared too.
    expect(find.text('sibling above'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
  });
}
