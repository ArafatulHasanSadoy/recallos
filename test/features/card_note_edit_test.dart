import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';

/// The note can be written after the card is saved.
///
/// It used to be writable exactly once, in the save sheet, and the card screen
/// showed it read-only — or, for a card saved with "Skip for now", not at all.
/// So the one line that makes a card findable by need could never be added
/// later or corrected. These tests tap the screen the way a person would; an
/// assertion about what the repository *can* do would have passed on the
/// broken version, because `addNote` always worked.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> seed({String? note}) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/card.jpg',
            capturedAt: DateTime(2026, 9, 28),
          ),
        );
    if (note != null) {
      await CardRepository(db).addNote(cardId: id, body: note);
    }
    return id;
  }

  Future<void> pump(WidgetTester tester, int cardId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CardDetailScreen(cardId: cardId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drift closes a query stream on a zero-length timer; unmounting and
  /// pumping once lets it fire inside the test instead of failing it.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<String?> storedNote(int cardId) async {
    final List<Note> notes = await (db.select(db.notes)
          ..where(($NotesTable n) => n.subjectId.equals(cardId)))
        .get();
    return notes.isEmpty ? null : notes.first.body;
  }

  testWidgets('a card saved without a note offers to add one', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    await pump(tester, id);

    expect(find.textContaining('Nothing yet'), findsOneWidget);

    await tester.tap(find.textContaining('Nothing yet'));
    await tester.pumpAndSettle();
    expect(find.text('Why did you save this?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'printing guy from CSE fest');
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => storedNote(id)), 'printing guy from CSE fest');
    expect(find.text('printing guy from CSE fest'), findsOneWidget);
    expect(find.textContaining('Nothing yet'), findsNothing);
    await unmount(tester);
  });

  testWidgets('an existing note opens prefilled and can be corrected', (
    WidgetTester tester,
  ) async {
    final int id = await seed(note: 'tshirt');
    await pump(tester, id);

    await tester.tap(find.text('tshirt'));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'tshirt');

    await tester.enterText(find.byType(TextField), 'cheap t-shirt printing');
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => storedNote(id)), 'cheap t-shirt printing');
    expect(find.text('cheap t-shirt printing'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Cancel changes nothing', (WidgetTester tester) async {
    final int id = await seed(note: 'tshirt');
    await pump(tester, id);

    await tester.tap(find.text('tshirt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'something else');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => storedNote(id)), 'tshirt');
    await unmount(tester);
  });
}
