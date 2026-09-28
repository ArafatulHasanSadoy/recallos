import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:recallos/core/imaging/photo_keyring.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/cards/presentation/widgets/full_image_view.dart';

/// The full-size photograph has a way back that can be seen.
///
/// It used to be a Material `AppBar` on a hard-coded black, and the back
/// arrow took the theme's ink: near-black on black. Every assertion about the
/// route passed; only a phone showed the arrow was not there to a person.
/// So these tests measure the contrast the eye would, in both modes, and then
/// tap the arrow.
void main() {
  late Directory dir;
  late File photo;

  setUp(() async {
    PhotoKeyring.instance.debugUseKey(null);
    dir = await Directory.systemTemp.createTemp('recallos_full_image');
    photo = File(p.join(dir.path, 'card.png'))
      ..writeAsBytesSync(
        Uint8List.fromList(img.encodePng(img.Image(width: 160, height: 100))),
      );
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('card screen')),
      ),
    );
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => FullImageView(image: photo),
            ),
          ),
    );
    await tester.pumpAndSettle();
  }

  for (final (String mode, ThemeData Function() theme) in <(
    String,
    ThemeData Function(),
  )>[('light', AppTheme.light), ('dark', AppTheme.dark)]) {
    testWidgets('the back arrow stands out from the stage in $mode mode', (
      WidgetTester tester,
    ) async {
      await open(tester, theme());

      expect(find.byType(AppBar), findsNothing);
      final Color stage = tester
          .widget<Scaffold>(find.byType(Scaffold).last)
          .backgroundColor!;
      final Color arrow = tester
          .widget<Icon>(find.byIcon(Icons.chevron_left))
          .color!;
      // WCAG asks 3:1 of an icon; this pair is text-grade, so hold it to 4.5.
      expect(
        _contrast(stage, arrow),
        greaterThanOrEqualTo(4.5),
        reason: 'arrow $arrow on stage $stage',
      );
      // The stage is dark in both modes; a white card reads against it.
      expect(stage.computeLuminance(), lessThan(0.05));
    });
  }

  testWidgets('tapping the arrow goes back to the card', (
    WidgetTester tester,
  ) async {
    await open(tester, AppTheme.light());
    expect(find.text('card screen'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(FullImageView), findsNothing);
    expect(find.text('card screen'), findsOneWidget);
  });
}

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
