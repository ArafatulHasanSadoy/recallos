import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/widgets/editable_field_list.dart';

/// Which keyboard comes up for which kind of value.
///
/// Worth pinning because the failure is invisible to every other kind of
/// check: the widget tree is correct, the analyzer is happy, and the value
/// still cannot be typed because the platform keyboard has no `@` on it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<CardDetail> seed(String fieldKey, String value) async {
    final int cardId = await db.into(db.cards).insert(
          CardsCompanion.insert(
            imagePath: '/tmp/cards/card.jpg',
            capturedAt: DateTime(2026, 8, 22),
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
    return (await db.select(db.cards).get()).isEmpty
        ? throw StateError('no card')
        : CardDetail(
            card: (await db.select(db.cards).get()).single,
            fields: await db.select(db.cardFields).get(),
            notes: const <Note>[],
            blocks: const <OcrBlockRow>[],
          );
  }

  Future<void> pump(WidgetTester tester, CardDetail detail) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditableFieldList(
                detail: detail,
                onRegionChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  TextInputType keyboardOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).keyboardType;

  testWidgets('an email field opens on a letter keyboard',
      (WidgetTester tester) async {
    final CardDetail detail =
        await seed(FieldKeys.email, 'someone@example.com');
    await pump(tester, detail);

    await tester.tap(find.text('someone@example.com'));
    await tester.pump();

    expect(keyboardOf(tester), TextInputType.emailAddress);
  });

  testWidgets('a phone field opens on the number pad',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pump();

    expect(keyboardOf(tester), TextInputType.phone);
  });

  testWidgets('re-labelling a phone as an email changes the keyboard',
      (WidgetTester tester) async {
    // The reported bug. Adding a field starts on Phone, so anyone adding an
    // email switched the label and was left on a keypad with no `@`.
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pump();
    expect(keyboardOf(tester), TextInputType.phone);

    await tester.tap(find.text(fieldLabel(FieldKeys.email)));
    await tester.pump();

    expect(keyboardOf(tester), TextInputType.emailAddress,
        reason: 'the keyboard has to follow the label');
  });

  testWidgets('re-labelling gives the field a new identity',
      (WidgetTester tester) async {
    // Keying the TextField on its keyboard type is what forces the platform
    // input connection to be renegotiated. Without a change of identity the
    // widget rebuilds with the new type and the keyboard stays as it was.
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pump();
    final Key? before = tester.widget<TextField>(find.byType(TextField)).key;

    await tester.tap(find.text(fieldLabel(FieldKeys.personName)));
    await tester.pump();
    final Key? after = tester.widget<TextField>(find.byType(TextField)).key;

    expect(after, isNot(before));
  });

  testWidgets('re-labelling mid-edit keeps the cursor in the field',
      (WidgetTester tester) async {
    // Rebuilding the field to change its keyboard closes the old one. Someone
    // part-way through typing should not have to tap back in.
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await tester.tap(find.text('01711363991'));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.tap(find.text(fieldLabel(FieldKeys.email)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('a name is capitalised and an email is not',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.personName, 'Asif Ahmed');
    await pump(tester, detail);

    await tester.tap(find.text('Asif Ahmed'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.words,
    );

    await tester.tap(find.text(fieldLabel(FieldKeys.email)));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.none,
    );
  });
}
