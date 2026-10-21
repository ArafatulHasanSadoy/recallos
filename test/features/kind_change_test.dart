import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/capture/presentation/kind_sheet.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';

import '../support/ocr_layout.dart';

/// "What did you save?" and "Saved as a receipt · Change" (B2): the user
/// says what the paper is, and it is read again as that.
void main() {
  group('the sheet', () {
    Future<List<CardType?>> pumpSheet(
      WidgetTester tester, {
      CardType suggested = CardType.receipt,
    }) async {
      final List<CardType?> answers = <CardType?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => answers.add(
                    await showKindSheet(context, suggested: suggested),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answers;
    }

    testWidgets('asks in the app\'s own voice, and marks the best guess', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text('What did you save?'), findsOneWidget);
      expect(find.text('Business card'), findsOneWidget);
      expect(find.text('Receipt or invoice'), findsOneWidget);
      expect(find.text('Warranty'), findsOneWidget);
      expect(find.text('BEST GUESS'), findsOneWidget);
    });

    testWidgets('one tap answers it', (WidgetTester tester) async {
      final List<CardType?> answers = await pumpSheet(tester);
      await tester.tap(find.text('Warranty'));
      await tester.pumpAndSettle();
      expect(answers, <CardType?>[CardType.warrantyCard]);
    });

    testWidgets('"Keep the best guess" changes nothing', (
      WidgetTester tester,
    ) async {
      final List<CardType?> answers = await pumpSheet(tester);
      await tester.tap(find.text('Keep the best guess'));
      await tester.pumpAndSettle();
      expect(answers, <CardType?>[null]);
    });
  });

  group('reading again as another kind', () {
    late AppDatabase db;
    late CardRepository cards;
    late IdentityRepository identity;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      cards = CardRepository(db);
      identity = IdentityRepository(db);
    });
    tearDown(() async => db.close());

    test(
      'a receipt misread as a card: re-read, typed, out of contacts',
      () async {
        // A shop's receipt with a phone number and a name on it — read as a
        // business card, it made a contact.
        final List<OcrBlock> blocks = paper(<Object>[
          'SHOPNO SUPER SHOP',
          'Rafiq Islam',
          '01711-223344',
          ('Grand Total', '432.60'),
        ]);
        final int id = await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(
                imagePath: '/tmp/r.jpg',
                capturedAt: DateTime(2026, 10, 13),
              ),
            );
        await cards.attachExtraction(
          cardId: id,
          result: OcrResult(
            blocks: blocks,
            engine: 'mlkit',
            duration: const Duration(milliseconds: 5),
          ),
          extraction: CardFieldExtractor.extract(blocks),
        );
        await cards.setKind(id, CardType.visitingCard, confidence: 0.5);
        await identity.promote(id);
        expect(await db.select(db.contactPoints).get(), isNotEmpty);

        await cards.reReadAs(id, CardType.receipt);
        await identity.promote(id);

        final CardRow card = await (db.select(
          db.cards,
        )..where(($CardsTable c) => c.id.equals(id))).getSingle();
        expect(card.type, CardType.receipt);
        expect(card.title, 'SHOPNO SUPER SHOP');
        expect(
          card.classificationConfidence,
          isNull,
          reason: 'the user said, so it is not a classifier\'s guess',
        );
        expect(card.ocrEngine, 'mlkit', reason: 'which engine read it is kept');

        final List<CardField> fields = await (db.select(
          db.cardFields,
        )..where(($CardFieldsTable f) => f.cardId.equals(id))).get();
        expect(
          fields
              .firstWhere((CardField f) => f.fieldKey == ReceiptKeys.total)
              .amountMinor,
          43260,
        );
        expect(
          fields.where((CardField f) => f.fieldKey == FieldKeys.personName),
          isEmpty,
          reason: 'the card reader\'s fields go with the re-read',
        );
        expect(await db.select(db.contactPoints).get(), isEmpty);
      },
    );
  });
}
