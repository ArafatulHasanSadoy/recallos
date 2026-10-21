import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/domain/money.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/spending/spending_totals.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/spending/data/spending_repository.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';

import '../support/ocr_layout.dart';

/// B4 through the real wallet: receipts scanned and checked the way the app
/// does it, then summed. Each test checks what is counted *and* what is held
/// back, because a receipt silently missing from a total is as wrong as one
/// silently added.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late SpendingRepository spending;

  const SpendingPeriod october = SpendingPeriod.month(2026, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cards = CardRepository(db);
    spending = SpendingRepository(db);
  });
  tearDown(() async => db.close());

  Future<int> scan(List<Object> rows, {CardType as = CardType.receipt}) async {
    final List<OcrBlock> blocks = paper(rows);
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/r.jpg',
            capturedAt: DateTime(2026, 10, 12, 18),
          ),
        );
    final DocumentReading reading = readDocument(blocks, as: as);
    await cards.attachExtraction(
      cardId: id,
      result: OcrResult(
        blocks: blocks,
        engine: 'test',
        duration: const Duration(milliseconds: 5),
      ),
      extraction: reading.extraction,
    );
    await cards.setKind(id, as, title: reading.title);
    return id;
  }

  Future<int> shwapno({String total = '432.60'}) => scan(<Object>[
    'SHWAPNO',
    'Gulshan 1, Dhaka',
    'Date: 12/10/2026',
    ('Rice 5kg', '410.00'),
    ('Grand Total', total),
  ]);

  Future<CardField> field(int cardId, String key) =>
      (db.select(db.cardFields)..where(
            ($CardFieldsTable f) =>
                f.cardId.equals(cardId) & f.fieldKey.equals(key),
          ))
          .getSingle();

  /// Opening a field and saving it unchanged, as *check this* asks.
  Future<void> check(int cardId, String key) async =>
      cards.updateField(fieldId: (await field(cardId, key)).id);

  Future<SpendingSummary> october_({String? currency}) async =>
      SpendingSummary.of(
        await spending.receipts(),
        period: october,
        currency: currency,
      );

  test('a scanned receipt is held back until its total and date are '
      'checked, then added to the paisa', () async {
    final int id = await shwapno();

    ReceiptFacts r = (await spending.receipts()).single;
    expect(r.total, const Money(43260, 'BDT'));
    expect(r.totalState, FactState.unchecked);
    expect(r.dateState, FactState.unchecked);
    expect(r.shop, 'SHWAPNO');
    expect(r.category, 'Groceries');
    expect(r.categoryGuessed, isTrue);
    SpendingSummary s = await october_();
    expect(s.total, isNull);
    expect(s.notAdded.single.whatToDo, 'Check the total and the date');

    await check(id, ReceiptKeys.total);
    s = await october_();
    expect(s.total, isNull);
    expect(s.notAdded.single.whatToDo, 'Check the date');

    await check(id, ReceiptKeys.purchaseDate);
    r = (await spending.receipts()).single;
    expect(r.counts, isTrue);
    s = await october_();
    expect(s.total, const Money(43260, 'BDT'));
    expect(s.notAdded, isEmpty);
    expect(s.scope, '1–31 Oct 2026 · 1 receipt you checked');
  });

  test('a corrected total is the one added', () async {
    final int id = await shwapno();
    await cards.updateField(
      fieldId: (await field(id, ReceiptKeys.total)).id,
      value: '1,432.60',
    );
    await check(id, ReceiptKeys.purchaseDate);
    expect((await october_()).total, const Money(143260, 'BDT'));
  });

  test('a total the reader missed, typed by the user, counts once the date '
      'is checked', () async {
    final int id = await scan(<Object>[
      'Rahim Tea Stall',
      'Date: 12/10/2026',
      'Thank you',
    ]);
    expect(
      (await spending.receipts()).single.whatToDo,
      'Add the total and check the date',
    );
    await cards.addField(cardId: id, fieldKey: ReceiptKeys.total, value: '40');
    await check(id, ReceiptKeys.purchaseDate);
    expect((await october_()).total, const Money(4000, 'BDT'));
  });

  test('a receipt in the bin is not counted, and counts again when it '
      'comes back', () async {
    final int id = await shwapno();
    await check(id, ReceiptKeys.total);
    await check(id, ReceiptKeys.purchaseDate);

    await cards.softDelete(id);
    expect(await spending.receipts(), isEmpty);
    await cards.restore(id);
    expect((await october_()).total, const Money(43260, 'BDT'));
  });

  test('a receipt re-typed as a business card leaves the totals', () async {
    final int id = await shwapno();
    await cards.setKind(id, CardType.visitingCard);
    expect(await spending.receipts(), isEmpty);
  });

  test('the same receipt scanned twice: the second is held back; Count '
      'both adds it, Undo asks again', () async {
    final int first = await shwapno();
    final int second = await shwapno();
    for (final int id in <int>[first, second]) {
      await check(id, ReceiptKeys.total);
      await check(id, ReceiptKeys.purchaseDate);
    }

    SpendingSummary s = await october_();
    expect(s.total, const Money(43260, 'BDT'));
    expect(s.copies.single.receipt.cardId, second);
    expect(s.copies.single.original.cardId, first);
    final List<ReceiptFacts> all = await spending.receipts();
    final ReceiptFacts copy = all.firstWhere(
      (ReceiptFacts r) => r.cardId == second,
    );
    expect(lookAlikes(copy, all), <int>[first]);

    await spending.countBoth(second, lookAlikes(copy, all));
    s = await october_();
    expect(s.copies, isEmpty);
    expect(s.total, const Money(86520, 'BDT'));

    // The answer survives the refresh every write ends with.
    await PurchaseLinks(db).refresh(second);
    await PurchaseLinks(db).refresh(first);
    expect((await october_()).total, const Money(86520, 'BDT'));

    await spending.undoCountBoth(second, <int>[first]);
    s = await october_();
    expect(s.copies.single.receipt.cardId, second);
    expect(s.total, const Money(43260, 'BDT'));
  });

  test(
    'Bin this copy: the copy goes to the bin and the total stands',
    () async {
      final int first = await shwapno();
      final int second = await shwapno();
      for (final int id in <int>[first, second]) {
        await check(id, ReceiptKeys.total);
        await check(id, ReceiptKeys.purchaseDate);
      }
      await cards.softDelete(second);
      final SpendingSummary s = await october_();
      expect(s.copies, isEmpty);
      expect(s.total, const Money(43260, 'BDT'));
    },
  );

  test('a "count both" answer is never read as a warranty link', () async {
    final int receipt = await scan(<Object>[
      'STAR TECH & ENGINEERING LTD',
      'Invoice No: ST-2026-0412',
      'Date: 12/10/2026',
      ('HP 15s-fq5111TU Laptop', '78,500.00'),
      'S/N: 5CD3281XYZ',
      ('Grand Total', '78,500.00'),
    ]);
    final int other = await shwapno();
    await spending.countBoth(other, <int>[receipt]);
    final int warranty = await scan(<Object>[
      'HP',
      'WARRANTY CARD',
      'Product: Laptop',
      'Model: 15s-fq5111TU',
      'Serial No: 5CD3281XYZ',
      'Warranty Period: 2 Years from the date of purchase',
    ], as: CardType.warrantyCard);

    final List<PurchaseLink> links = await PurchaseLinks(
      db,
    ).watchLinks(warranty).first;
    expect(links.single.receiptId, receipt);
    expect(links.single.isConfirmed, isFalse);
    expect(await PurchaseLinks(db).watchLinks(other).first, isEmpty);
  });

  test(
    'the stream follows a check made on the receipt\'s own screen',
    () async {
      final int id = await shwapno();
      await check(id, ReceiptKeys.total);
      final Stream<List<ReceiptFacts>> stream = spending.watchReceipts();
      final Future<void> counted = stream
          .firstWhere((List<ReceiptFacts> all) => all.single.counts)
          .timeout(const Duration(seconds: 5));
      await check(id, ReceiptKeys.purchaseDate);
      await counted;
    },
  );

  test('a confirmed category is no longer a guess', () async {
    final int id = await shwapno();
    expect((await spending.receipts()).single.categoryGuessed, isTrue);
    await check(id, ReceiptKeys.category);
    expect((await spending.receipts()).single.categoryGuessed, isFalse);
  });
}
