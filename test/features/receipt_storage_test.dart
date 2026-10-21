import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';

import '../support/ocr_layout.dart';

/// A receipt and a warranty read and stored the way capture stores a card:
/// typed values in their typed columns, a guess stored as a guess, the type
/// recorded — and nobody added to the contacts.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late IdentityRepository identity;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cards = CardRepository(db);
    identity = IdentityRepository(db);
  });
  tearDown(() async => db.close());

  Future<int> store(List<OcrBlock> blocks) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/tmp/r.jpg',
            capturedAt: DateTime(2026, 10, 13),
          ),
        );
    final DocumentReading reading = readDocument(blocks);
    await cards.attachExtraction(
      cardId: id,
      result: OcrResult(
        blocks: blocks,
        engine: 'test',
        duration: const Duration(milliseconds: 5),
      ),
      extraction: reading.extraction,
    );
    await cards.setKind(
      id,
      reading.type,
      confidence: reading.classification.confidence,
      title: reading.title,
    );
    await identity.promote(id);
    return id;
  }

  Future<Map<String, CardField>> fields(int id) async => <String, CardField>{
    for (final CardField f in await (db.select(
      db.cardFields,
    )..where(($CardFieldsTable t) => t.cardId.equals(id))).get())
      f.fieldKey: f,
  };

  final List<OcrBlock> shopReceipt = paper(<Object>[
    'SHOPNO SUPER SHOP',
    'Banani, Dhaka',
    'Invoice No: 4432-118',
    'Date: 12/10/2026 18:42',
    ('Milk 1L 2 x 95.00', '190.00'),
    ('Subtotal', '412.00'),
    ('VAT 5%', '20.60'),
    ('Grand Total', '432.60'),
    ('Cash', '500.00'),
    'Served by: Rafiq Islam 01711-223344',
  ]);

  test(
    'a receipt: typed money and day, a guessed category, its type',
    () async {
      final int id = await store(shopReceipt);
      final Map<String, CardField> f = await fields(id);

      final CardField total = f[ReceiptKeys.total]!;
      expect(total.amountMinor, 43260);
      expect(total.currency, 'BDT');
      expect(total.origin, FactOrigin.printed);
      expect(total.review, FactReview.unreviewed);

      expect(f[ReceiptKeys.purchaseDate]!.dateValue, LocalDate(2026, 10, 12));

      final CardField category = f[ReceiptKeys.category]!;
      expect(category.origin, FactOrigin.inferred);
      expect(
        category.validationIssue,
        isNull,
        reason: 'a guess is labelled a guess, not flagged as misread',
      );

      final CardRow card = await (db.select(
        db.cards,
      )..where(($CardsTable c) => c.id.equals(id))).getSingle();
      expect(card.type, CardType.receipt);
      expect(card.title, 'SHOPNO SUPER SHOP');
      expect(card.classificationConfidence, greaterThan(0.6));
      expect(card.extractionStatus, ExtractionStatus.complete);
    },
  );

  test('the cashier on a receipt never becomes a contact', () async {
    await store(shopReceipt);
    expect(await db.select(db.people).get(), isEmpty);
    expect(await db.select(db.organizations).get(), isEmpty);
    expect(await db.select(db.contactPoints).get(), isEmpty);
  });

  test('a warranty: its serial, its cover, its title', () async {
    final int id = await store(
      paper(<Object>[
        'WALTON',
        'WARRANTY CARD',
        'Product: Refrigerator',
        'Model: WFC-3F5-GDEL',
        'Serial No: 2309WF0045812',
        'Date of Purchase: 01/09/2026',
        'Warranty Period: 5 Years',
      ]),
    );
    final Map<String, CardField> f = await fields(id);
    expect(f[WarrantyKeys.serial]!.normalizedValue, '2309WF0045812');
    expect(f[WarrantyKeys.coverMonths]!.normalizedValue, '60');
    expect(f[WarrantyKeys.purchaseDate]!.dateValue, LocalDate(2026, 9, 1));

    final CardRow card = await (db.select(
      db.cards,
    )..where(($CardsTable c) => c.id.equals(id))).getSingle();
    expect(card.type, CardType.warrantyCard);
    expect(card.title, 'WALTON Refrigerator');
    expect(card.extractionStatus, ExtractionStatus.complete);
  });

  test('a business card is still read and promoted as one', () async {
    final int id = await store(
      paper(<Object>[
        'TechFix Repair Centre',
        'Kamal Hossain',
        'Service Manager',
        '+880 1617-223311',
        'kamal@techfixrepair.com',
      ]),
    );
    final CardRow card = await (db.select(
      db.cards,
    )..where(($CardsTable c) => c.id.equals(id))).getSingle();
    expect(card.type, CardType.visitingCard);
    expect(card.title, isNull);
    expect(await db.select(db.contactPoints).get(), isNotEmpty);
  });

  test('a type given is a type kept: no asking, no reclassifying', () {
    final DocumentReading r = readDocument(shopReceipt, as: CardType.receipt);
    expect(r.chosen, isTrue);
    expect(r.shouldAsk, isFalse);
    expect(r.type, CardType.receipt);
  });

  test('an unclear page asks', () {
    final DocumentReading r = readDocument(
      paper(<Object>['Thank you, come again']),
    );
    expect(r.shouldAsk, isTrue);
  });
}
