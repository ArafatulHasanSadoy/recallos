import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/linking/purchase_link_rules.dart';
import 'package:recallos/core/linking/warranty_expiry.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';

import '../support/ocr_layout.dart';

/// PLAN §3's *Purchase* story, below the screens: a receipt, then its
/// warranty; a suggestion with its reasons; the user's answer; the expiry
/// worked out, labelled, and kept in step with everything it came from.
void main() {
  late AppDatabase db;
  late PurchaseLinks links;
  late CardRepository cards;
  final DateTime today = DateTime(2026, 10, 15, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    links = PurchaseLinks(db, now: () => today);
    cards = CardRepository(db, purchases: links);
  });
  tearDown(() async => db.close());

  /// Stores a paper the way capture does: saved, read, then typed.
  Future<int> store(List<OcrBlock> blocks, CardType type) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/tmp/p.jpg',
            capturedAt: DateTime(2026, 10, 12),
          ),
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
    return id;
  }

  final List<OcrBlock> laptopReceipt = paper(<Object>[
    'STAR TECH & ENGINEERING LTD',
    'Multiplan Center, Elephant Road, Dhaka',
    'Invoice No: ST-2026-0412',
    'Date: 12/10/2026',
    ('HP 15s-fq5111TU Laptop', '78,500.00'),
    'S/N: 5CD3281XYZ',
    ('Grand Total', '78,500.00'),
  ]);

  /// No purchase date of its own: its end can only come from the receipt.
  List<OcrBlock> laptopWarranty({String serial = '5CD3281XYZ'}) =>
      paper(<Object>[
        'HP',
        'WARRANTY CARD',
        'Product: Laptop',
        'Model: 15s-fq5111TU',
        'Serial No: $serial',
        'Warranty Period: 2 Years from the date of purchase',
      ]);

  Future<List<ItemLink>> allLinks() => db.select(db.itemLinks).get();

  Future<List<CardField>> expiryFields(int cardId) =>
      (db.select(db.cardFields)..where(
            ($CardFieldsTable f) =>
                f.cardId.equals(cardId) &
                f.fieldKey.equals(WarrantyKeys.expiryDate),
          ))
          .get();

  Future<ImportantDate?> expiryDate(int cardId) =>
      (db.select(db.importantDates)..where(
            ($ImportantDatesTable d) =>
                d.cardId.equals(cardId) &
                d.kind.equalsValue(DateKind.warrantyExpiry),
          ))
          .getSingleOrNull();

  Future<List<Reminder>> scheduled(int dateId) =>
      (db.select(db.reminders)..where(
            ($RemindersTable r) =>
                r.importantDateId.equals(dateId) &
                r.status.equalsValue(ReminderStatus.scheduled),
          ))
          .get();

  Future<CardField> field(int cardId, String key) =>
      (db.select(db.cardFields)..where(
            ($CardFieldsTable f) =>
                f.cardId.equals(cardId) &
                f.fieldKey.equals(key) &
                f.origin.equalsValue(FactOrigin.derived).not(),
          ))
          .getSingle();

  group('suggesting', () {
    test('a receipt, then its warranty: suggested, with the serial', () async {
      final int receipt = await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);

      final List<ItemLink> all = await allLinks();
      expect(all, hasLength(1));
      expect(all.single.fromCardId, warranty);
      expect(all.single.toCardId, receipt);
      expect(all.single.kind, LinkKind.warrantyOf);
      expect(all.single.status, LinkStatus.suggested);
      expect(all.single.confidence, greaterThan(0.95));
      expect(all.single.reasons, contains('"cue":"serial"'));

      // A suggestion is not a fact: no receipt date has been lent yet.
      expect(await expiryFields(warranty), isEmpty);
      expect(await expiryDate(warranty), isNull);
    });

    test('a warranty, then its receipt: suggested all the same', () async {
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);
      final int receipt = await store(laptopReceipt, CardType.receipt);
      final ItemLink l = (await allLinks()).single;
      expect((l.fromCardId, l.toCardId), (warranty, receipt));
    });

    test('both sides see it, with the other paper and its reasons', () async {
      final int receipt = await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);

      final PurchaseLink fromWarranty =
          (await links.watchLinks(warranty).first).single;
      expect(fromWarranty.other.id, receipt);
      expect(fromWarranty.isConfirmed, isFalse);
      expect(fromWarranty.reasons.first.cue, LinkCue.serial);

      final PurchaseLink fromReceipt =
          (await links.watchLinks(receipt).first).single;
      expect(fromReceipt.other.id, warranty);
    });

    test('corrected evidence renews the reasons, and takes the serial '
        'with it', () async {
      await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);
      await cards.updateField(
        fieldId: (await field(warranty, WarrantyKeys.serial)).id,
        value: '5CD9999ABC',
      );
      // Still the model and the brand on the receipt — but no longer the
      // serial, and said with less certainty.
      final PurchaseLink l = (await links.watchLinks(warranty).first).single;
      expect(
        l.reasons.map((LinkReason r) => r.cue),
        isNot(contains(LinkCue.serial)),
      );
      expect(l.row.confidence, lessThan(0.6));
    });

    test('a suggestion with no evidence left is gone', () async {
      await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(
        paper(<Object>[
          'ACME',
          'WARRANTY CARD',
          'Product: Charger',
          'Serial No: 5CD3281XYZ',
          'Warranty Period: 6 Months',
        ]),
        CardType.warrantyCard,
      );
      expect(await allLinks(), hasLength(1));
      await cards.updateField(
        fieldId: (await field(warranty, WarrantyKeys.serial)).id,
        value: 'AC12345678',
      );
      expect(await allLinks(), isEmpty);
    });

    test('a business card is never suggested', () async {
      await store(laptopReceipt, CardType.receipt);
      await store(laptopWarranty(), CardType.visitingCard);
      expect(await allLinks(), isEmpty);
    });
  });

  group("the user's answer", () {
    test('confirmed: the expiry is calculated from the receipt, labelled, '
        'dated and reminded', () async {
      await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);
      await links.confirm((await allLinks()).single.id);

      final CardField end = (await expiryFields(warranty)).single;
      expect(end.origin, FactOrigin.derived);
      expect(end.dateValue, LocalDate(2028, 10, 11));
      expect(end.value, '11 Oct 2028');

      final ImportantDate date = (await expiryDate(warranty))!;
      expect(date.dueOn, DateTime(2028, 10, 11));
      expect(date.status, DateStatus.open);
      expect(
        (await scheduled(date.id)).single.remindAt,
        DateTime(2028, 9, 11, 9),
      );

      final ExpiryView view = (await links.watchExpiry(warranty).first)!;
      expect(view.expiry.isCalculated, isTrue);
      expect(view.expiry.start, ExpiryStart.receipt);
      expect(view.remindAt, DateTime(2028, 9, 11, 9));
    });

    test(
      'Android holds the reminder, but it is not one of the free five',
      () async {
        await store(laptopReceipt, CardType.receipt);
        await store(laptopWarranty(), CardType.warrantyCard);
        await links.confirm((await allLinks()).single.id);

        final FollowUpRepository followUps = FollowUpRepository(
          db,
          now: () => today,
        );
        final PendingReminder r = (await followUps.pendingReminders()).single;
        expect(r.kind, DateKind.warrantyExpiry);
        expect(r.dueOn, DateTime(2028, 10, 11));
        expect(
          r.cardTitle,
          'HP Laptop',
          reason: 'titled as the warranty, not "A card"',
        );
        expect(await followUps.activeReminderCount(), 0);
        // Nor a next step, on the card or on Today.
        expect(await followUps.watchOpen().first, isEmpty);
      },
    );

    test('dismissed: kept, and never suggested again', () async {
      final int receipt = await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);
      await links.dismiss((await allLinks()).single.id);

      await cards.reReadAs(warranty, CardType.warrantyCard);
      await cards.reReadAs(receipt, CardType.receipt);

      final ItemLink l = (await allLinks()).single;
      expect(l.status, LinkStatus.dismissed);
      expect(await links.watchLinks(warranty).first, isEmpty);
    });

    test('a matched warranty is offered no other receipt', () async {
      await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);
      await links.confirm((await allLinks()).single.id);

      // The same laptop on a second, delivery receipt.
      await store(laptopReceipt, CardType.receipt);
      final List<ItemLink> mine = (await allLinks())
          .where((ItemLink l) => l.fromCardId == warranty)
          .toList();
      expect(mine, hasLength(1));
      expect(mine.single.status, LinkStatus.confirmed);
    });

    test('unlinked: dismissed, and the calculated end goes', () async {
      await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(laptopWarranty(), CardType.warrantyCard);
      final int id = (await allLinks()).single.id;
      await links.confirm(id);
      await links.unlink(id);

      expect((await allLinks()).single.status, LinkStatus.dismissed);
      expect(await expiryFields(warranty), isEmpty);
      expect(await expiryDate(warranty), isNull);
    });

    test('linked by hand when nothing printed matches', () async {
      final int receipt = await store(laptopReceipt, CardType.receipt);
      final int warranty = await store(
        paper(<Object>[
          'ACME',
          'WARRANTY CARD',
          'Product: Laptop bag',
          'Warranty Period: 2 Years',
        ]),
        CardType.warrantyCard,
      );
      expect(await allLinks(), isEmpty);

      await links.link(warrantyId: warranty, receiptId: receipt);
      final PurchaseLink l = (await links.watchLinks(warranty).first).single;
      expect(l.isConfirmed, isTrue);
      expect(l.reasons.single.cue, LinkCue.chosen);
      expect(
        (await expiryFields(warranty)).single.dateValue,
        LocalDate(2028, 10, 11),
      );
    });
  });

  group('kept in step with its inputs', () {
    late int receipt;
    late int warranty;

    setUp(() async {
      receipt = await store(laptopReceipt, CardType.receipt);
      warranty = await store(laptopWarranty(), CardType.warrantyCard);
      await links.confirm((await allLinks()).single.id);
    });

    test(
      'a corrected cover moves the end, the date and the reminder',
      () async {
        final ImportantDate before = (await expiryDate(warranty))!;
        await cards.updateField(
          fieldId: (await field(warranty, WarrantyKeys.coverMonths)).id,
          value: '3 years',
        );

        expect(
          (await expiryFields(warranty)).single.dateValue,
          LocalDate(2029, 10, 11),
        );
        final ImportantDate after = (await expiryDate(warranty))!;
        expect(after.id, before.id);
        expect(after.dueOn, DateTime(2029, 10, 11));
        expect(
          (await scheduled(after.id)).single.remindAt,
          DateTime(2029, 9, 11, 9),
          reason: 'the old reminder is cancelled, not left beside the new one',
        );
      },
    );

    test("a corrected date on the receipt moves the warranty's end", () async {
      await cards.updateField(
        fieldId: (await field(receipt, ReceiptKeys.purchaseDate)).id,
        value: '10/10/2026',
      );
      expect(
        (await expiryFields(warranty)).single.dateValue,
        LocalDate(2028, 10, 9),
      );
    });

    test('an edit elsewhere leaves a shown reminder where it was', () async {
      final ImportantDate date = (await expiryDate(warranty))!;
      final Reminder r = (await scheduled(date.id)).single;
      await cards.updateField(
        fieldId: (await field(warranty, WarrantyKeys.product)).id,
        value: 'Notebook',
      );
      expect((await scheduled(date.id)).single.id, r.id);
    });

    test('an expiry the user types wins, and the date follows it', () async {
      await cards.addField(
        cardId: warranty,
        fieldKey: WarrantyKeys.expiryDate,
        value: '31/12/2028',
      );
      final List<CardField> ends = await expiryFields(warranty);
      expect(ends.single.origin, FactOrigin.user);
      expect((await expiryDate(warranty))!.dueOn, DateTime(2028, 12, 31));
    });

    test(
      'a receipt in the bin lends nothing; restored, it does again',
      () async {
        await cards.softDelete(receipt);
        expect(await expiryFields(warranty), isEmpty);
        expect(await expiryDate(warranty), isNull);
        expect(await links.watchLinks(warranty).first, isEmpty);

        await cards.restore(receipt);
        expect(
          (await expiryFields(warranty)).single.origin,
          FactOrigin.derived,
        );
        expect(
          (await links.watchLinks(warranty).first).single.isConfirmed,
          isTrue,
        );
      },
    );

    test('a receipt deleted for good takes its date with it', () async {
      await cards.purge(receipt);
      expect(await allLinks(), isEmpty);
      expect(await expiryFields(warranty), isEmpty);
      expect(await expiryDate(warranty), isNull);
    });

    test('a warranty that turns out to be a receipt has no end', () async {
      await cards.setKind(warranty, CardType.receipt);
      expect(await expiryFields(warranty), isEmpty);
      expect(await expiryDate(warranty), isNull);
    });
  });

  test('the card screen titles a receipt by its shop', () async {
    final int receipt = await store(laptopReceipt, CardType.receipt);
    final CardDetail detail = (await cards.watchCard(receipt).first)!;
    expect(detail.title, 'STAR TECH & ENGINEERING LTD');
  });

  group('without a receipt', () {
    test("a warranty's own purchase date is enough", () async {
      final int w = await store(
        paper(<Object>[
          'WALTON',
          'WARRANTY CARD',
          'Product: Refrigerator',
          'Serial No: 2309WF0045812',
          'Date of Purchase: 01/09/2026',
          'Warranty Period: 5 Years',
        ]),
        CardType.warrantyCard,
      );
      final CardField end = (await expiryFields(w)).single;
      expect(end.origin, FactOrigin.derived);
      expect(end.dateValue, LocalDate(2031, 8, 31));
      final ExpiryView view = (await links.watchExpiry(w).first)!;
      expect(view.expiry.start, ExpiryStart.warranty);
    });

    test(
      'a printed expiry is shown as printed, and nothing is calculated',
      () async {
        final int w = await store(
          paper(<Object>[
            'WALTON',
            'WARRANTY CARD',
            'Product: Refrigerator',
            'Date of Purchase: 01/09/2026',
            'Warranty Period: 5 Years',
            'Valid till: 31/08/2031',
          ]),
          CardType.warrantyCard,
        );
        final CardField end = (await expiryFields(w)).single;
        expect(end.origin, FactOrigin.printed);
        expect((await expiryDate(w))!.dueOn, DateTime(2031, 8, 31));
        final ExpiryView view = (await links.watchExpiry(w).first)!;
        expect(view.expiry.basis, ExpiryBasis.printed);
      },
    );

    test('a warranty already over gets its date but no reminder', () async {
      final int w = await store(
        paper(<Object>[
          'WALTON',
          'WARRANTY CARD',
          'Product: Iron',
          'Date of Purchase: 01/09/2024',
          'Warranty Period: 1 Year',
        ]),
        CardType.warrantyCard,
      );
      final ImportantDate date = (await expiryDate(w))!;
      expect(date.dueOn, DateTime(2025, 8, 31));
      expect(await scheduled(date.id), isEmpty);
    });
  });
}
