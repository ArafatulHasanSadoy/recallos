import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/primitives.dart';
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
          theme: AppTheme.light(),
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

  /// Opens a field for editing. The editor is a modal sheet, so this has to
  /// let the sheet finish arriving before anything inside it can be found.
  Future<void> openField(WidgetTester tester, String value) async {
    await tester.tap(find.text(value));
    await tester.pumpAndSettle();
  }

  /// Taps one of the "What is this?" chips.
  ///
  /// Scrolled into view first: every field key gets a chip, and on a 600px
  /// test viewport they run past the bottom of the sheet. Matched on the chip
  /// rather than on its text, or a row's own label in the list behind would
  /// be an equally good match. [SelectChip] is the design system's own; the
  /// Material `ChoiceChip` this used to find brought an outline and a ripple
  /// that belong to a different app.
  Future<void> tapLabel(WidgetTester tester, String key) async {
    final Finder chip = find.widgetWithText(SelectChip, fieldLabel(key));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('an email field opens on a letter keyboard',
      (WidgetTester tester) async {
    final CardDetail detail =
        await seed(FieldKeys.email, 'someone@example.com');
    await pump(tester, detail);

    await openField(tester, 'someone@example.com');

    expect(keyboardOf(tester), TextInputType.emailAddress);
  });

  testWidgets('a phone field opens on the number pad',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await openField(tester, '01711363991');

    expect(keyboardOf(tester), TextInputType.phone);
  });

  testWidgets('re-labelling a phone as an email changes the keyboard',
      (WidgetTester tester) async {
    // The reported bug. Adding a field starts on Phone, so anyone adding an
    // email switched the label and was left on a keypad with no `@`.
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await openField(tester, '01711363991');
    expect(keyboardOf(tester), TextInputType.phone);

    await tapLabel(tester, FieldKeys.email);

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

    await openField(tester, '01711363991');
    final Key? before = tester.widget<TextField>(find.byType(TextField)).key;

    await tapLabel(tester, FieldKeys.personName);
    final Key? after = tester.widget<TextField>(find.byType(TextField)).key;

    expect(after, isNot(before));
  });

  testWidgets('re-labelling mid-edit keeps the cursor in the field',
      (WidgetTester tester) async {
    // Rebuilding the field to change its keyboard closes the old one. Someone
    // part-way through typing should not have to tap back in.
    final CardDetail detail = await seed(FieldKeys.phone, '01711363991');
    await pump(tester, detail);

    await openField(tester, '01711363991');
    // Scrolled into view first, for the same reason the chips are: the sheet
    // scrolls, and on a 600px test viewport the value field sits below the
    // fold. Tapping an off-screen widget quietly does nothing.
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tapLabel(tester, FieldKeys.email);

    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('a name is capitalised and an email is not',
      (WidgetTester tester) async {
    final CardDetail detail = await seed(FieldKeys.personName, 'Asif Ahmed');
    await pump(tester, detail);

    await openField(tester, 'Asif Ahmed');
    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.words,
    );

    await tapLabel(tester, FieldKeys.email);
    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.none,
    );
  });
}
