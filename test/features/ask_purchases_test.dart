import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/linking/warranty_expiry.dart';
import 'package:recallos/core/search/query_plan.dart';
import 'package:recallos/features/ask/data/purchase_answers.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';

import '../support/ocr_layout.dart';

/// Ask RecallOS on purchases (B5), below the screen: PLAN §3's *Purchase*
/// and *Memory* stories asked as questions, answered from the same facts
/// the card and Receipt totals screens show, with their papers — and said
/// plainly when they cannot be answered.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late SearchRepository search;
  late PurchaseLinks links;
  final DateTime now = DateTime(2026, 10, 15, 10);

  StaticEmbedder? shared;
  Future<StaticEmbedder> loadEmbedder() async =>
      shared ??= StaticEmbedder.fromBytes(
        matrixBytes: File('assets/embedding/matrix.bin').readAsBytesSync(),
        tokenizer: WordPieceTokenizer.fromAssets(
          vocabText: File('assets/embedding/vocab.txt').readAsStringSync(),
          normalizerJson: File(
            'assets/embedding/normalizer.json',
          ).readAsStringSync(),
        ),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    links = PurchaseLinks(db, now: () => now);
    cards = CardRepository(db, purchases: links);
    search = SearchRepository(db, loadEmbedder, now: () => now);
  });
  tearDown(() async => db.close());

  Future<int> store(List<OcrBlock> blocks, CardType type) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(imagePath: '/tmp/p.jpg', capturedAt: now),
        );
    final DocumentReading reading = readDocument(blocks, as: type);
    await cards.attachExtraction(
      cardId: id,
      result: OcrResult(
        blocks: blocks,
        engine: 'test',
        duration: const Duration(milliseconds: 5),
      ),
      extraction: reading.extraction,
    );
    await cards.setKind(id, type, title: reading.title);
    await search.reindexCard(id);
    return id;
  }

  /// What the user does on the card: open the total and the date, and save.
  Future<void> check(int receipt) async {
    for (final String key in <String>[
      ReceiptKeys.total,
      ReceiptKeys.purchaseDate,
    ]) {
      final CardField f =
          await (db.select(db.cardFields)..where(
                ($CardFieldsTable t) =>
                    t.cardId.equals(receipt) & t.fieldKey.equals(key),
              ))
              .getSingle();
      await cards.updateField(fieldId: f.id, value: f.value);
    }
  }

  Future<int> laptopReceipt() => store(
    paper(<Object>[
      'STAR TECH & ENGINEERING LTD',
      'Invoice No: ST-2026-0412',
      'Date: 12/10/2026',
      ('HP 15s-fq5111TU Laptop', '78,500.00'),
      'S/N: 5CD3281XYZ',
      ('Grand Total', '78,500.00'),
    ]),
    CardType.receipt,
  );

  Future<int> laptopWarranty() => store(
    paper(<Object>[
      'HP',
      'WARRANTY CARD',
      'Product: Laptop',
      'Model: 15s-fq5111TU',
      'Serial No: 5CD3281XYZ',
      'Warranty Period: 2 Years from the date of purchase',
    ]),
    CardType.warrantyCard,
  );

  Future<int> groceries() => store(
    paper(<Object>[
      'SHWAPNO',
      'Banani, Dhaka',
      'Date: 12/10/2026',
      ('Rice 5kg', '432.60'),
      ('Grand Total', '432.60'),
    ]),
    CardType.receipt,
  );

  group('one warranty: "When does my laptop warranty expire?"', () {
    test(
      'the end, calculated, with both papers cited (§3, Purchase)',
      () async {
        final int receipt = await laptopReceipt();
        final int warranty = await laptopWarranty();
        await links.confirm((await db.select(db.itemLinks).getSingle()).id);

        final SearchAnswer a = await search.ask(
          'When does my laptop warranty expire?',
        );
        expect(a.plan, isA<WarrantyPlan>());
        final WarrantyAnswer w = a.warranties.single;
        expect(w.card.id, warranty);
        expect(w.expiry!.expiry.day, LocalDate(2028, 10, 11));
        expect(w.expiry!.expiry.isCalculated, isTrue);
        expect(w.receipt!.other.id, receipt, reason: 'the receipt is cited');
        expect(
          a.hits.map((SearchHit h) => h.card.id),
          isNot(anyOf(contains(warranty), contains(receipt))),
          reason: 'papers already cited are not listed again',
        );
      },
    );

    test('free: a lookup is not behind Plus', () async {
      await laptopWarranty();
      expect((await search.ask('laptop warranty')).warranties, hasLength(1));
    });

    test('an end not known yet is said, not guessed', () async {
      await laptopWarranty();
      final WarrantyAnswer w = (await search.ask(
        'when does my laptop warranty end',
      )).warranties.single;
      expect(w.expiry, isNull);
      expect(w.receipt, isNull);
    });

    test('"fridge" finds the refrigerator', () async {
      await store(
        paper(<Object>[
          'WALTON',
          'WARRANTY CARD',
          'Product: Refrigerator',
          'Date of Purchase: 01/09/2026',
          'Warranty Period: 5 Years',
        ]),
        CardType.warrantyCard,
      );
      final WarrantyAnswer w = (await search.ask(
        'is my fridge still under warranty',
      )).warranties.single;
      expect(w.expiry!.expiry.day, LocalDate(2031, 8, 31));
    });

    test('no such warranty: said so, and the words still searched', () async {
      await laptopWarranty();
      final SearchAnswer a = await search.ask('when does my car warranty end');
      expect(a.warranties, isEmpty);
      expect(a.cannot, 'No saved warranty matches “car”.');
      expect(a.isEmpty, isFalse);
    });
  });

  group('what ends: "What expires in the next 90 days?" (Plus)', () {
    late int soon;
    late int later;
    late int over;

    setUp(() async {
      soon = await store(
        paper(<Object>[
          'SINGER',
          'WARRANTY CARD',
          'Product: Iron',
          'Valid till: 30/11/2026',
        ]),
        CardType.warrantyCard,
      );
      later = await laptopWarranty();
      await laptopReceipt();
      await links.confirm((await db.select(db.itemLinks).getSingle()).id);
      over = await store(
        paper(<Object>[
          'VISION',
          'WARRANTY CARD',
          'Product: Kettle',
          'Date of Purchase: 01/09/2024',
          'Warranty Period: 1 Year',
        ]),
        CardType.warrantyCard,
      );
    });

    test('with Plus: only what ends inside the window', () async {
      final SearchAnswer a = await search.ask(
        'What expires in the next 90 days?',
        plus: true,
      );
      expect((a.plan as ExpiringPlan).label, 'in the next 90 days');
      expect(a.expiring.map((ExpiringAnswer e) => e.card.id), <int>[soon]);
      expect(a.expiring.single.expiry!.basis, ExpiryBasis.printed);
    });

    test('nothing in the window is an answer, not an empty screen', () async {
      final SearchAnswer a = await search.ask(
        'what expires next month',
        plus: true,
      );
      expect(a.expiring.map((ExpiringAnswer e) => e.card.id), <int>[soon]);
      final SearchAnswer none = await search.ask(
        'warranties ending in 3 days',
        plus: true,
      );
      expect(none.expiring, isEmpty);
      expect(none.isEmpty, isFalse);
    });

    test('already ended, and every warranty', () async {
      expect(
        (await search.ask(
          'what has expired',
          plus: true,
        )).expiring.map((ExpiringAnswer e) => e.card.id),
        <int>[over],
      );
      expect(
        (await search.ask(
          'my warranties',
          plus: true,
        )).expiring.map((ExpiringAnswer e) => e.card.id),
        <int>[over, soon, later],
        reason: 'soonest end first',
      );
    });

    test('free: the words are searched, and Plus is offered', () async {
      final SearchAnswer a = await search.ask(
        'What expires in the next 90 days?',
      );
      expect(a.plusNeeded, isTrue);
      expect(a.expiring, isEmpty);
      // Still searched, but only among warranties: a receipt or somebody's
      // card that shares a word is not an answer to a date question.
      expect(
        a.hits.every((SearchHit h) => h.card.type == CardType.warrantyCard),
        isTrue,
      );
    });
  });

  group('totals: "How much did I spend on electronics this month?"', () {
    late int laptop;
    late int rice;

    setUp(() async {
      laptop = await laptopReceipt();
      rice = await groceries();
      await check(laptop);
      await check(rice);
    });

    test(
      'with Plus: one category, exact, in saved receipts (§3, Memory)',
      () async {
        final SearchAnswer a = await search.ask(
          'How much did I spend on electronics this month?',
          plus: true,
        );
        final SpendingAnswer s = a.spending!;
        expect(s.focusLabel, 'Electronics');
        expect(s.summary!.total!.minor, 7850000);
        expect(s.summary!.currency, 'BDT');
        expect(s.summary!.counted.map((r) => r.cardId), <int>[laptop]);
        expect(s.summary!.scope, '1–31 Oct 2026 · 1 receipt you checked');
      },
    );

    test(
      'free: this month in full, as the Receipt totals screen shows it',
      () async {
        final SearchAnswer a = await search.ask(
          'how much did I spend this month',
        );
        expect(a.plusNeeded, isFalse);
        expect(a.spending!.summary!.total!.minor, 7850000 + 43260);
      },
    );

    test('free: a category or another month comes with Plus', () async {
      expect(
        (await search.ask('how much did I spend on electronics')).plusNeeded,
        isTrue,
      );
      expect(
        (await search.ask('how much did I spend in September')).plusNeeded,
        isTrue,
      );
    });

    test('a shop, said with "at"', () async {
      final SpendingAnswer s = (await search.ask(
        'spent at Star Tech this month',
        plus: true,
      )).spending!;
      expect(s.focusLabel, 'STAR TECH & ENGINEERING LTD');
      expect(s.summary!.total!.minor, 7850000);
    });

    test('an unchecked receipt is held back, never added', () async {
      final int unchecked = await groceries();
      final SpendingAnswer s = (await search.ask(
        'how much did I spend this month',
      )).spending!;
      expect(s.summary!.total!.minor, 7850000 + 43260);
      expect(
        s.summary!.notAdded.map((r) => r.cardId).toList() +
            s.summary!.copies.map((c) => c.receipt.cardId).toList(),
        contains(unchecked),
      );
    });

    test('cannot answer: a week, a month to come, a shop never seen', () async {
      expect(
        (await search.ask('spent this week', plus: true)).spending!.cannot,
        contains('month or year'),
      );
      expect(
        (await search.ask('spending in 2027', plus: true)).spending!.cannot,
        contains('Nothing can have been bought in 2027 yet'),
      );
      expect(
        (await search.ask(
          'how much did I spend on jewellery this month',
          plus: true,
        )).spending!.cannot,
        contains('“jewellery”'),
      );
    });
  });
}
