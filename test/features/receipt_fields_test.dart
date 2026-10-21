import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/field_validator.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/widgets/card_sides_view.dart';
import 'package:recallos/features/cards/presentation/widgets/editable_field_list.dart';

/// A receipt's fields on the review and card screens (B2): named in words,
/// the critical ones asking to be checked, and a correction stored as the
/// typed value it says.
void main() {
  group('validateField on receipt and warranty values', () {
    test('a total is re-read into paisa, in its own currency', () {
      final FieldValidation v = validateField(ReceiptKeys.total, '8450.5');
      expect(v.amountMinor, 845050);
      expect(v.currency, 'BDT');
      expect(v.display, 'BDT 8,450.50');

      final FieldValidation usd = validateField(
        ReceiptKeys.total,
        '12.5',
        currency: 'USD',
      );
      expect(usd.currency, 'USD', reason: 'a dollar receipt stays in dollars');
      expect(usd.amountMinor, 1250);
    });

    test('a date is re-read into a calendar day', () {
      final FieldValidation v = validateField(
        ReceiptKeys.purchaseDate,
        '12/10/26',
      );
      expect(v.dateValue, LocalDate(2026, 10, 12));
      expect(v.display, '12 Oct 2026');
    });

    test('a cover length is read in months', () {
      expect(
        validateField(WarrantyKeys.coverMonths, '2 years').normalized,
        '24',
      );
      expect(validateField(WarrantyKeys.coverMonths, '18').normalized, '18');
    });

    test('what is not an amount, a date or a period says so plainly', () {
      final String? amount = validateField(ReceiptKeys.total, 'paid').issue;
      final String? date = validateField(WarrantyKeys.expiryDate, 'soon').issue;
      final String? period = validateField(
        WarrantyKeys.coverMonths,
        'lifetime',
      ).issue;
      expect(amount, 'not_an_amount');
      expect(date, 'not_a_date');
      expect(period, 'not_a_period');
      for (final String? token in <String?>[amount, date, period]) {
        expect(describeFieldIssue(token), isNot(contains('_')));
      }
    });
  });

  test('correcting a total stores the new amount, confirmed', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final CardRepository repo = CardRepository(db);
    final int card = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/tmp/r.jpg',
            capturedAt: DateTime(2026, 10, 13),
          ),
        );
    await repo.addField(
      cardId: card,
      fieldKey: ReceiptKeys.total,
      value: '432.60',
    );
    final CardField added = await db.select(db.cardFields).getSingle();
    expect(added.amountMinor, 43260);
    expect(added.value, 'BDT 432.60');

    await repo.updateField(fieldId: added.id, value: '452.60');
    final CardField fixed = await db.select(db.cardFields).getSingle();
    expect(fixed.amountMinor, 45260);
    expect(fixed.currency, 'BDT');
    expect(fixed.review, FactReview.confirmed);
  });

  group('the field list on a receipt', () {
    final DateTime now = DateTime(2026, 10, 13);

    CardField f(int id, String key, String value, {bool confirmed = false}) =>
        CardField(
          id: id,
          cardId: 1,
          fieldKey: key,
          value: value,
          source: FactSource.printed,
          verifiedByUser: confirmed,
          origin: FactOrigin.printed,
          review: confirmed ? FactReview.confirmed : FactReview.unreviewed,
          validity: FactValidity.current,
          valueKind: FieldValueKind.text,
          side: CardSide.front,
          createdAt: now,
          updatedAt: now,
        );

    CardDetail receipt({bool totalConfirmed = false}) => CardDetail(
      card: CardRow(
        id: 1,
        type: CardType.receipt,
        captureSource: CaptureSource.documentScanner,
        imagePath: '/tmp/r.jpg',
        extractionStatus: ExtractionStatus.complete,
        capturedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      fields: <CardField>[
        f(1, ReceiptKeys.merchant, 'SHOPNO SUPER SHOP'),
        f(2, ReceiptKeys.purchaseDate, '12 Oct 2026'),
        f(3, ReceiptKeys.total, 'BDT 432.60', confirmed: totalConfirmed),
      ],
      notes: const <Note>[],
      blocks: const <OcrBlockRow>[],
    );

    Future<void> pump(WidgetTester tester, CardDetail detail) async {
      tester.view.physicalSize = const Size(1080, 2408);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ListView(
                children: <Widget>[
                  EditableFieldList(
                    detail: detail,
                    onRegionChanged: (FieldHighlight? _) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('named in words, and the total and date ask to be checked', (
      WidgetTester tester,
    ) async {
      await pump(tester, receipt());
      expect(find.text('SHOP'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('CHECK THIS'), findsNWidgets(2));
    });

    testWidgets('a confirmed total no longer asks', (
      WidgetTester tester,
    ) async {
      await pump(tester, receipt(totalConfirmed: true));
      expect(find.text('CHECK THIS'), findsOneWidget, reason: 'only the date');
    });

    testWidgets('the editor offers a receipt\'s fields, not a card\'s', (
      WidgetTester tester,
    ) async {
      await pump(tester, receipt());
      await tester.tap(find.text('BDT 432.60'));
      await tester.pumpAndSettle();
      expect(find.text('Invoice no.'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Designation'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
