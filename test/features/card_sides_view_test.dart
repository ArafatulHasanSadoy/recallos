import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/back_capture_service.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/widgets/card_image_overlay.dart';
import 'package:recallos/features/cards/presentation/widgets/card_sides_view.dart';


/// The rule this widget exists to enforce: a highlight belongs to the front.
///
/// Field regions are stored in the front image's pixel space and `card_fields`
/// has no side column, so a highlight drawn while the back is showing would
/// box a spot on the back unrelated to the value it came from. Nothing throws
/// and nothing logs — the box is simply in the wrong place, on a screen whose
/// entire purpose is letting someone check a value against the printing. Only
/// a test that looks at what was handed to the painter catches that.
void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('recallos_sides'));
  tearDown(() async => dir.delete(recursive: true));

  /// The files are never real images. The overlay reports a failed decode and
  /// draws a placeholder, which is all this needs: what is asserted is which
  /// file and which highlight it was *given*, not what it painted.
  File write(String name) {
    final File file = File(p.join(dir.path, name));
    file.writeAsStringSync(name);
    return file;
  }

  /// Advances animations without waiting for the tree to go quiet.
  ///
  /// `pumpAndSettle` cannot be used anywhere in this file: the overlay spins
  /// until its image resolves, and these files never resolve, so an animation
  /// is in flight for the whole test. Two pumps cover the transitions that
  /// matter here — a popup menu and a dialog.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(
    WidgetTester tester, {
    required File front,
    int? cardId = 1,
    String? backPath,
    String? highlight,
    AppDatabase? db,
    BackCaptureService Function(Ref)? backCapture,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (db != null) databaseProvider.overrideWithValue(db),
          if (backCapture != null)
            backCaptureServiceProvider.overrideWith(backCapture),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CardSidesView(
              cardId: cardId,
              front: front,
              backPath: backPath,
              highlight: highlight,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  CardImageOverlay overlay(WidgetTester tester) =>
      tester.widget<CardImageOverlay>(find.byType(CardImageOverlay));

  testWidgets('offers to add a back when there is none',
      (WidgetTester t) async {
    await pump(t, front: write('front.jpg'));

    expect(find.text('Add back'), findsOneWidget);
    // No sides to switch between yet, so no switch.
    expect(find.text('Front'), findsNothing);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('offers nothing at all before the card row exists',
      (WidgetTester t) async {
    // The moment between the shutter and the first write. Offering to attach a
    // back to a card that has no id yet would be an action with nowhere to go.
    await pump(t, front: write('front.jpg'), cardId: null);

    expect(find.text('Add back'), findsNothing);
    expect(find.byType(CardImageOverlay), findsOneWidget);
  });

  testWidgets('shows the front, highlight and all, by default',
      (WidgetTester t) async {
    final File front = write('front.jpg');
    await pump(
      t,
      front: front,
      backPath: write('back.jpg').path,
      highlight: '1,2,3,4',
    );

    expect(overlay(t).image.path, front.path);
    expect(overlay(t).highlight, '1,2,3,4');
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('drops the highlight when the card is turned over',
      (WidgetTester t) async {
    final File back = write('back.jpg');
    await pump(
      t,
      front: write('front.jpg'),
      backPath: back.path,
      highlight: '1,2,3,4',
    );

    await t.tap(find.text('Back'));
    await settle(t);

    expect(overlay(t).image.path, back.path);
    // The whole point. A region measured on the front, painted on the back, is
    // wrong in a way nothing else would report.
    expect(overlay(t).highlight, isNull);
  });

  testWidgets('turns back to the front when a field asks to be shown',
      (WidgetTester t) async {
    final File front = write('front.jpg');
    final File back = write('back.jpg');
    await pump(t, front: front, backPath: back.path);

    await t.tap(find.text('Back'));
    await settle(t);
    expect(overlay(t).image.path, back.path);

    // Tapping a field on the list below is a request to see where that value
    // was read from. Leaving the back up would answer it with silence.
    await pump(t, front: front, backPath: back.path, highlight: '5,6,7,8');

    expect(overlay(t).image.path, front.path);
    expect(overlay(t).highlight, '5,6,7,8');
  });

  testWidgets('falls back to the front if the back disappears underneath it',
      (WidgetTester t) async {
    final File front = write('front.jpg');
    final File back = write('back.jpg');
    await pump(t, front: front, backPath: back.path);

    await t.tap(find.text('Back'));
    await settle(t);

    // One frame with a stale "showing the back" and no back to show is all it
    // would take to ask the overlay for a file that is not there.
    await pump(t, front: front);

    expect(overlay(t).image.path, front.path);
    expect(find.text('Add back'), findsOneWidget);
  });

  group('writing through to the card', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Future<int> seedCard(File front) => db.into(db.cards).insert(
          CardsCompanion.insert(
            imagePath: front.path,
            capturedAt: DateTime(2026, 8, 23),
          ),
        );

    testWidgets('captures a back and turns to it', (WidgetTester t) async {
      final File front = write('front.jpg');
      final File captured = write('captured.jpg');
      final int id = await seedCard(front);

      await pump(
        t,
        front: front,
        cardId: id,
        db: db,
        backCapture: (Ref ref) => _StubBackCapture(ref, captured.path),
      );

      await t.tap(find.text('Add back'));
      await settle(t);

      final CardRow card = await db.select(db.cards).getSingle();
      expect(card.backImagePath, captured.path);

      // The screens stream the card, so the new path arrives as a rebuild.
      // Shown rather than merely stored: the scanner crops, and it sometimes
      // crops wrongly, so the result has to be visible to be checked.
      await pump(
        t,
        front: front,
        cardId: id,
        backPath: captured.path,
        db: db,
        backCapture: (Ref ref) => _StubBackCapture(ref, captured.path),
      );
      expect(overlay(t).image.path, captured.path);
    });

    testWidgets('asks before removing a back', (WidgetTester t) async {
      final File front = write('front.jpg');
      final File back = write('back.jpg');
      final int id = await seedCard(front);
      await CardRepository(db)
          .attachBackImage(cardId: id, backImagePath: back.path);

      await pump(t, front: front, cardId: id, backPath: back.path, db: db);

      await t.tap(find.byIcon(Icons.more_horiz));
      await settle(t);
      await t.tap(find.text('Remove back'));
      await settle(t);

      // Deleting the photo is the one thing here with no undo behind it, so it
      // is confirmed rather than done on a tap.
      expect(find.text('Remove the back?'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(t);

      expect(back.existsSync(), isTrue);
      expect((await db.select(db.cards).getSingle()).backImagePath, back.path);
    });

    testWidgets('removes the back once confirmed', (WidgetTester t) async {
      final File front = write('front.jpg');
      final File back = write('back.jpg');
      final int id = await seedCard(front);
      await CardRepository(db)
          .attachBackImage(cardId: id, backImagePath: back.path);

      await pump(t, front: front, cardId: id, backPath: back.path, db: db);

      await t.tap(find.text('Back'));
      await settle(t);

      await t.tap(find.byIcon(Icons.more_horiz));
      await settle(t);
      await t.tap(find.text('Remove back'));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Remove'));
      await settle(t);

      expect(back.existsSync(), isFalse);
      expect((await db.select(db.cards).getSingle()).backImagePath, isNull);
      // Whatever the parent does next, the view must not still be pointing at
      // the file it just deleted.
      expect(overlay(t).image.path, front.path);
    });
  });
}

/// Stands in for the scanner, which cannot run in a widget test.
///
/// Does what a real capture does either side of the platform call — files the
/// image against the card — so the widget's reaction to a successful capture
/// is exercised for real rather than mocked at the boundary being tested.
class _StubBackCapture extends BackCaptureService {
  _StubBackCapture(this._ref, this._path) : super(_ref);

  final Ref _ref;
  final String _path;

  @override
  Future<BackCapture> capture(int cardId) async {
    await _ref
        .read(cardRepositoryProvider)
        .attachBackImage(cardId: cardId, backImagePath: _path);
    return (outcome: BackCaptureOutcome.captured, message: null);
  }
}
