import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/back_capture_service.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/widgets/card_image_overlay.dart';
import 'package:recallos/features/cards/presentation/widgets/card_sides_view.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';

/// The rule this widget exists to enforce: a highlight belongs to one side.
///
/// Every stored region is a rectangle in one image's pixel space, so a box
/// drawn while the other side is showing lands somewhere unrelated to the value
/// it came from. Nothing throws and nothing logs — the box is simply in the
/// wrong place, on a screen whose entire purpose is letting someone check a
/// value against the printing. Only a test that looks at what was handed to the
/// painter catches that.
void main() {
  late Directory dir;

  setUp(
    () async => dir = await Directory.systemTemp.createTemp('recallos_sides'),
  );
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
    FieldHighlight? highlight,
    Object? heroTag,
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
              heroTag: heroTag,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  CardImageOverlay overlay(WidgetTester tester) =>
      tester.widget<CardImageOverlay>(find.byType(CardImageOverlay));

  testWidgets('offers to add a back when there is none', (
    WidgetTester t,
  ) async {
    await pump(t, front: write('front.jpg'));

    expect(find.text('Add back'), findsOneWidget);
    // No sides to switch between yet, so no switch.
    expect(find.text('Front'), findsNothing);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('offers nothing at all before the card row exists', (
    WidgetTester t,
  ) async {
    // The moment between the shutter and the first write. Offering to attach a
    // back to a card that has no id yet would be an action with nowhere to go.
    await pump(t, front: write('front.jpg'), cardId: null);

    expect(find.text('Add back'), findsNothing);
    expect(find.byType(CardImageOverlay), findsOneWidget);
  });

  testWidgets('shows the front, highlight and all, by default', (
    WidgetTester t,
  ) async {
    final File front = write('front.jpg');
    await pump(
      t,
      front: front,
      backPath: write('back.jpg').path,
      highlight: const FieldHighlight(rect: '1,2,3,4', side: CardSide.front),
    );

    expect(overlay(t).image.path, front.path);
    expect(overlay(t).highlight, '1,2,3,4');
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('drops a front highlight when the card is turned over', (
    WidgetTester t,
  ) async {
    final File back = write('back.jpg');
    await pump(
      t,
      front: write('front.jpg'),
      backPath: back.path,
      highlight: const FieldHighlight(rect: '1,2,3,4', side: CardSide.front),
    );

    await t.tap(find.text('Back'));
    await settle(t);

    expect(overlay(t).image.path, back.path);
    // The whole point. A region measured on the front, painted on the back, is
    // wrong in a way nothing else would report.
    expect(overlay(t).highlight, isNull);
  });

  testWidgets('keeps the card transition available while showing the back', (
    WidgetTester t,
  ) async {
    await pump(
      t,
      front: write('front.jpg'),
      backPath: write('back.jpg').path,
      heroTag: 'card-1',
    );

    Hero hero() => t.widget<Hero>(find.byType(Hero));
    expect(hero().tag, 'card-1');
    expect(hero().transitionOnUserGestures, isTrue);

    await t.tap(find.text('Back'));
    await settle(t);

    expect(find.byType(Hero), findsOneWidget);
    expect(hero().tag, 'card-1');
  });

  testWidgets('turns back to the front when a front field asks to be shown', (
    WidgetTester t,
  ) async {
    final File front = write('front.jpg');
    final File back = write('back.jpg');
    await pump(t, front: front, backPath: back.path);

    await t.tap(find.text('Back'));
    await settle(t);
    expect(overlay(t).image.path, back.path);

    // Opening a field on the list below is a request to see where that value
    // was read from. Leaving the back up would answer it with silence.
    await pump(
      t,
      front: front,
      backPath: back.path,
      highlight: const FieldHighlight(rect: '5,6,7,8', side: CardSide.front),
    );

    expect(overlay(t).image.path, front.path);
    expect(overlay(t).highlight, '5,6,7,8');
  });

  testWidgets('turns to the back when a back field asks to be shown', (
    WidgetTester t,
  ) async {
    final File front = write('front.jpg');
    final File back = write('back.jpg');
    await pump(t, front: front, backPath: back.path);
    expect(overlay(t).image.path, front.path);

    // The other direction, which only became possible once fields could say
    // which side they were read from. A value printed on the back is boxed on
    // the back, and asking to see it turns the card over.
    await pump(
      t,
      front: front,
      backPath: back.path,
      highlight: const FieldHighlight(rect: '9,10,11,12', side: CardSide.back),
    );

    expect(overlay(t).image.path, back.path);
    expect(overlay(t).highlight, '9,10,11,12');
  });

  testWidgets('never paints a back region on the front', (
    WidgetTester t,
  ) async {
    final File front = write('front.jpg');
    await pump(
      t,
      front: front,
      // No back attached, so there is nothing to turn to — and the region has
      // no image it could honestly be drawn on.
      highlight: const FieldHighlight(rect: '9,10,11,12', side: CardSide.back),
    );

    expect(overlay(t).image.path, front.path);
    expect(overlay(t).highlight, isNull);
  });

  testWidgets('falls back to the front if the back disappears underneath it', (
    WidgetTester t,
  ) async {
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

    Future<int> seedCard(File front) => db
        .into(db.cards)
        .insert(
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
      await CardRepository(
        db,
      ).attachBackImage(cardId: id, backImagePath: back.path);

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
      await CardRepository(
        db,
      ).attachBackImage(cardId: id, backImagePath: back.path);

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
  _StubBackCapture(Ref ref, this._path)
    : super(
        cards: ref.watch(cardRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        identity: ref.watch(identityRepositoryProvider),
        engine: _SilentOcr(),
      );

  final String _path;

  @override
  Future<BackCapture> capture(int cardId) async {
    await cards.attachBackImage(cardId: cardId, backImagePath: _path);
    return (outcome: BackCaptureOutcome.captured, message: null);
  }
}

/// Reads nothing, so the widget test stays about the widget.
///
/// The real recogniser needs a device; what is under test here is which side
/// is shown and what the overlay is handed, not what OCR made of it.
class _SilentOcr implements OcrEngine {
  @override
  String get id => 'silent';

  @override
  Set<Script> get supportedScripts => const <Script>{Script.latin};

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<OcrResult> recognize(
    File image, {
    Set<Script> scripts = const <Script>{Script.latin},
    Duration timeout = const Duration(seconds: 15),
  }) async => const OcrResult(
    blocks: <OcrBlock>[],
    engine: 'silent',
    duration: Duration.zero,
  );

  @override
  Future<void> dispose() async {}
}
