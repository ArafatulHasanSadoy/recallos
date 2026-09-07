import 'dart:io';

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

  group('bundled type', () {
    // The failure this guards is silent by design. If a font file goes
    // missing, or the pubspec block is dropped in a merge, Flutter falls back
    // to Roboto without a warning — nothing throws, no test fails, and the
    // whole visual identity quietly becomes stock Material. See
    // design/DESIGN.md §1.
    test('the display face is the serif, not a fallback', () {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        expect(theme.textTheme.displaySmall?.fontFamily, AppFonts.serif);
        expect(theme.textTheme.bodyMedium?.fontFamily, AppFonts.sans);
      }
    });

    test('every declared font file is actually on disk', () {
      // Declaring a font that is not there is exactly as silent as not
      // declaring it, so the check has to reach the filesystem.
      final List<String> declared = <String>[
        for (final String line in File('pubspec.yaml').readAsLinesSync())
          if (line.contains('asset: assets/fonts/'))
            line.split('asset:').last.trim(),
      ];

      expect(declared, isNotEmpty, reason: 'the fonts block has gone missing');
      for (final String path in declared) {
        expect(File(path).existsSync(), isTrue, reason: '$path is not there');
        expect(File(path).lengthSync(), greaterThan(10000),
            reason: '$path is too small to be a real font file');
      }
    });

    test('a weight is cut from the axis, not faked', () {
      // Archivo ships only as a variable font, so one file serves every
      // weight. Without the `wght` axis set, Flutter renders 400 and fakes the
      // rest with synthetic bolding.
      final TextStyle micro = AppText.micro(AppColors.light);
      expect(micro.fontVariations, isNotNull,
          reason: 'the weight axis is not being driven');
      expect(
        micro.fontVariations!.single.value,
        micro.fontWeight!.value.toDouble(),
        reason: 'the axis and the declared weight disagree',
      );
    });
  });

  group('surfaces have no drawn edges', () {
    // The white line, three reports running. It was a `BlurStyle.inner`
    // highlight transcribed from the frames' `inset 0 -2px 0 rgba(255,255,255,
    // .9)`. In CSS that composites as a 2px band over a near-white card and is
    // barely there; a Flutter inner shadow paints it far harder, so it came
    // out as a near-white stroke — invisible against the card and stark where
    // the card's bottom edge meets the darker page, which is every row on card
    // detail and every block in settings.
    //
    // Paper reads as raised here through its hairline and its drop shadow. Any
    // inner highlight on a card is this bug coming back.
    test('a card has no inner highlight', () {
      for (final bool dark in <bool>[false, true]) {
        for (final bool lifted in <bool>[false, true]) {
          final BoxDecoration d = AppDecoration.card(
            dark ? AppColors.dark : AppColors.light,
            isDark: dark,
            lifted: lifted,
          );
          final Iterable<BoxShadow> inner = (d.boxShadow ?? <BoxShadow>[])
              .where((BoxShadow s) => s.blurStyle == BlurStyle.inner);
          expect(inner, isEmpty,
              reason: 'card(isDark: $dark, lifted: $lifted) draws an edge');
        }
      }
    });

    test('an unlifted card carries no shadow at all', () {
      // Grouped blocks sit flat on the page. A shadow there is the same
      // problem in a softer form.
      final BoxDecoration d =
          AppDecoration.card(AppColors.light, lifted: false);
      expect(d.boxShadow ?? <BoxShadow>[], isEmpty);
    });

    test('the pocket is recessed, not outlined', () {
      final BoxDecoration d = AppDecoration.pocket(AppColors.light);
      final List<BoxShadow> shadows = d.boxShadow ?? <BoxShadow>[];

      // Exactly one shadow, and it is the dark one at the top that makes the
      // hole. The lit bottom wall is the gradient, which follows the rounded
      // rect exactly where a stroke hooked around the corners.
      expect(shadows, hasLength(1));
      expect(shadows.single.blurStyle, BlurStyle.inner);
      expect(shadows.single.offset.dy, lessThan(0),
          reason: 'the recess shadow belongs at the top, away from the light');
      expect(d.gradient, isNotNull);
    });
  });
}
