// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';

import '../support/ocr_layout.dart';

/// Receipts and warranties in the lists and in search (B2): named for what
/// they are, findable by what is printed on them, and never "met" anywhere.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late SearchRepository search;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cards = CardRepository(db);
    // Words only: these tests are about what is indexed, not about meaning.
    search = SearchRepository(
      db,
      () async => throw const EmbeddingAssetError('not needed'),
    );
  });
  tearDown(() async => db.close());

  Future<int> scan(List<OcrBlock> blocks, {String? metAt}) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/tmp/x.jpg',
            capturedAt: DateTime(2026, 10, 13),
          ),
        );
    if (metAt != null) {
      // What Event Mode writes as the card is saved, before it is read.
      await db
          .into(db.encounters)
          .insert(
            EncountersCompanion.insert(
              cardId: id,
              metOn: Value<DateTime?>(DateTime(2026, 10, 13)),
              place: Value<String?>(metAt),
              origin: const Value<EncounterOrigin>(EncounterOrigin.event),
            ),
          );
    }
    final DocumentReading r = readDocument(blocks);
    await cards.attachExtraction(
      cardId: id,
      result: OcrResult(
        blocks: blocks,
        engine: 'test',
        duration: const Duration(milliseconds: 1),
      ),
      extraction: r.extraction,
    );
    await cards.setKind(
      id,
      r.type,
      confidence: r.classification.confidence,
      title: r.title,
    );
    await search.reindexCard(id);
    return id;
  }

  final List<OcrBlock> receipt = paper(<Object>[
    'SHOPNO SUPER SHOP',
    'Date: 12/10/2026',
    ('Subtotal', '412.00'),
    ('Grand Total', '432.60'),
  ]);
  final List<OcrBlock> warranty = paper(<Object>[
    'WALTON',
    'WARRANTY CARD',
    'Product: Refrigerator',
    'Serial No: 2309WF0045812',
    'Warranty Period: 5 Years',
  ]);

  test(
    'the library names a receipt and a warranty for what they are',
    () async {
      await scan(receipt);
      await scan(warranty);
      final List<CardSummary> all = await cards.watchCards().first;

      final CardSummary r = all.firstWhere(
        (CardSummary c) => c.type == CardType.receipt,
      );
      expect(r.title, 'SHOPNO SUPER SHOP');
      expect(r.subtitle, 'BDT 432.60 · 12 Oct 2026');

      final CardSummary w = all.firstWhere(
        (CardSummary c) => c.type == CardType.warrantyCard,
      );
      expect(w.title, 'WALTON Refrigerator');
      expect(w.subtitle, '5 years of cover');
    },
  );

  test('a printed expiry is what the warranty tile says', () async {
    await scan(
      paper(<Object>[
        'realme',
        'Warranty Certificate',
        'Model Name: realme 12 Pro',
        'IMEI 1: 864392051234567',
        'Valid till: 14/09/2027',
      ]),
    );
    final CardSummary w = (await cards.watchCards().first).single;
    expect(w.subtitle, 'Covered until 14 Sep 2027');
  });

  test(
    'search finds a receipt by its shop, a warranty by its serial',
    () async {
      final int r = await scan(receipt);
      final int w = await scan(warranty);
      expect(
        (await search.search('shopno')).map((SearchHit h) => h.card.id),
        contains(r),
      );
      expect(
        (await search.search('2309WF0045812')).map((SearchHit h) => h.card.id),
        contains(w),
      );
    },
  );

  test('a receipt scanned during an event was not "met" there', () async {
    final int r = await scan(receipt, metAt: 'Tech fair at BICC');
    final int person = await scan(
      paper(<Object>[
        'Nusrat Jahan',
        'Bengal Event Solutions',
        '01812-445566',
        'nusrat@bengalevents.com',
      ]),
      metAt: 'Tech fair at BICC',
    );
    final List<Encounter> met = await db.select(db.encounters).get();
    expect(met.map((Encounter e) => e.cardId), <int>[person]);
    expect(met.map((Encounter e) => e.cardId), isNot(contains(r)));

    // And the event's summary, which lists everyone met there, agrees.
    final List<MetCard> summary = await FollowUpRepository(db)
        .watchMetAt(
          place: 'Tech fair at BICC',
          from: DateTime(2000),
          until: DateTime(2100),
        )
        .first;
    expect(summary.map((MetCard m) => m.cardId), <int>[person]);
  });

  test(
    'where the user said they met is theirs, whatever the paper is',
    () async {
      final int r = await scan(receipt);
      await FollowUpRepository(db).setEncounter(cardId: r, place: 'Gulshan');
      await cards.setKind(r, CardType.receipt);
      expect(await db.select(db.encounters).get(), hasLength(1));
    },
  );
}
