import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/widgets/editable_field_list.dart';

/// Editing a field must not be able to end the scan.
///
/// The reported bug: the editor expanded inside the list, so its Save sat on
/// the same screen as the capture bar's Save. The bottom one is bigger, never
/// moves and is under the thumb already, so the natural way to finish an edit
/// was to hit it — which saved the card, left the screen, and dropped what was
/// being typed without saying anything. Labelling alone could not fix that;
/// the two had to stop being reachable at the same time.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<CardDetail> seed(String fieldKey, String value) async {
    final int cardId = await db.into(db.cards).insert(
          CardsCompanion.insert(
            imagePath: '/tmp/cards/card.jpg',
            capturedAt: DateTime(2026, 9, 5),
          ),
        );
    await db.into(db.cardFields).insert(
          CardFieldsCompanion.insert(
            cardId: cardId,
            fieldKey: fieldKey,
            value: value,
            source: FactSource.printed,
          ),
        );
    return CardDetail(
      card: (await db.select(db.cards).get()).single,
      fields: await db.select(db.cardFields).get(),
      notes: const <Note>[],
      blocks: const <OcrBlockRow>[],
    );
  }

  /// The capture screen in miniature: the field list, and a card-level Save
  /// pinned along the bottom exactly where the real one sits.
  Future<int Function()> pump(WidgetTester tester, CardDetail detail) async {
    int savedCard = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditableFieldList(
                detail: detail,
                onRegionChanged: (_) {},
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => savedCard++,
                child: const Text('Save card'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => savedCard;
  }

  testWidgets('the list shows no editor until a field is tapped',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    // Nothing to mistake for anything: the row is a row.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('What is this?'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
  });

  testWidgets('the editor arrives as a sheet over the card',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pumpAndSettle();

    expect(find.text('Edit this detail'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // Exactly one Save on screen, and it belongs to the field.
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });

  testWidgets('the card cannot be saved while a field is open',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    final int Function() savedCard = await pump(tester, detail);

    final Offset saveCard =
        tester.getCenter(find.widgetWithText(FilledButton, 'Save card'));

    await tester.tap(find.text('01711363991'));
    await tester.pumpAndSettle();

    // Tapped at the coordinates the thumb was already heading for. The sheet
    // is in the way now, which is the entire point.
    await tester.tapAt(saveCard);
    await tester.pumpAndSettle();

    expect(savedCard(), 0, reason: 'the scan must not end from an edit');
    expect(find.text('Edit this detail'), findsOneWidget,
        reason: 'and the editor must still be open');
  });

  testWidgets('closing an edited field asks before dropping the change',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '01711363992');
    await tester.pumpAndSettle();

    // The barrier: the dimmed card above, which is a very easy thing to touch
    // while reading the printing against the value.
    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();

    expect(find.text('Discard this change?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '01711363992',
    );
  });

  testWidgets('an untouched field closes without a question',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();

    // Nothing was typed, so there is nothing to protect and nothing to ask.
    expect(find.text('Discard this change?'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('saving a correction closes the sheet and writes it',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '01819104376');
    await tester.pumpAndSettle();

    // Scrolled to first: the sheet is capped so the card stays visible above
    // it, which means its own actions can sit below the fold.
    final Finder save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    final CardField field = (await db.select(db.cardFields).get()).single;
    expect(field.value, '01819104376');
    // A hand-typed correction is the user's, not the engine's.
    expect(field.verifiedByUser, isTrue);
  });
}
