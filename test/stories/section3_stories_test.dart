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
import 'package:recallos/core/linking/purchase_link_rules.dart';
import 'package:recallos/core/search/query_plan.dart';
import 'package:recallos/core/spending/spending_totals.dart';
import 'package:recallos/features/ask/data/purchase_answers.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/introduction/data/hello.dart';
import 'package:recallos/features/introduction/data/hello_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';

import '../support/ocr_layout.dart';

/// PLAN §3: "499B is done when all three run end to end".
///
/// Each story is played here in the order a person plays it, through the
/// same repositories the screens use — capture, the identity graph, notes,
/// next steps, hellos, links, totals and Ask — on one wallet. The phone run
/// on a release build in airplane mode (PLAN §9) is the other half; this is
/// the half that can be re-run on every change. Nothing here touches a
/// network: there is none to touch.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late PurchaseLinks links;
  late SearchRepository search;
  late IdentityRepository identity;
  late FollowUpRepository followUps;
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
    identity = IdentityRepository(db);
    followUps = FollowUpRepository(db, now: () => now);
  });
  tearDown(() async => db.close());

  /// Scan → read → type → index → people, as capture does it.
  Future<int> scan(List<OcrBlock> blocks, {CardType? as}) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(imagePath: '/tmp/s.jpg', capturedAt: now),
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
    await cards.setKind(id, reading.type, title: reading.title);
    await search.reindexCard(id);
    await identity.promote(id);
    return id;
  }

  Future<void> checkTotalAndDate(int receipt) async {
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

  test(
    '1 · Person: scan, note, hello, a reminder, and found by the need',
    () async {
      // Scan a card.
      final int card = await scan(
        paper(<Object>[
          'Pixel Arena Esports',
          'Tanvir Hossain',
          'Partnerships Lead',
          '+880 1711-223344',
          'tanvir@pixelarena.gg',
        ]),
      );
      expect(await cards.typeOf(card), CardType.visitingCard);

      // Note why it mattered: "esports sponsorship".
      await cards.addNote(cardId: card, body: 'esports sponsorship');
      await search.reindexCard(card);

      // Where they met, then a hello the user edits and sends themselves.
      await followUps.setEncounter(
        cardId: card,
        place: 'CSE fest at NSU',
        metOn: DateTime(2026, 10, 13),
      );
      final String hello = helloMessage(
        now: now,
        theirName: 'Tanvir Hossain',
        place: 'CSE fest at NSU',
        metOn: DateTime(2026, 10, 13),
        myName: 'Arafat',
      );
      expect(
        hello,
        startsWith('Hi Tanvir, great meeting you at CSE fest at NSU'),
      );
      expect(
        hello,
        isNot(contains('sponsorship')),
        reason: 'the note is private',
      );
      await HelloRepository(
        db,
        now: () => now,
      ).recordOpened(card, HelloChannel.whatsapp);

      // A follow-up with a reminder Android will hold.
      await followUps.addStep(
        cardId: card,
        title: 'Send the sponsorship deck',
        dueOn: DateTime(2026, 10, 17),
        remindAt: DateTime(2026, 10, 17, 9),
      );
      final PendingReminder r = (await followUps.pendingReminders()).single;
      expect(r.kind, DateKind.followUp);
      expect(r.cardTitle, 'Pixel Arena Esports');

      // Later: "Who was interested in sponsorship?" finds them, by the note.
      final SearchAnswer a = await search.ask(
        'Who was interested in sponsorship?',
      );
      expect(a.hits.first.card.id, card);
      expect(a.hits.first.card.note, contains('sponsorship'));
      expect(await db.select(db.people).get(), hasLength(1));
    },
  );

  test('2 · Purchase: receipt, warranty, suggested and confirmed, the end '
      'calculated and reminded, and asked', () async {
    final int receipt = await scan(
      paper(<Object>[
        'STAR TECH & ENGINEERING LTD',
        'Invoice No: ST-2026-0412',
        'Date: 12/10/2026',
        ('HP 15s-fq5111TU Laptop', '78,500.00'),
        'S/N: 5CD3281XYZ',
        ('Grand Total', '78,500.00'),
      ]),
      as: CardType.receipt,
    );
    final int warranty = await scan(
      paper(<Object>[
        'HP',
        'WARRANTY CARD',
        'Product: Laptop',
        'Model: 15s-fq5111TU',
        'Serial No: 5CD3281XYZ',
        'Warranty Period: 2 Years from the date of purchase',
      ]),
      as: CardType.warrantyCard,
    );
    // Neither is anybody's card.
    expect(await db.select(db.people).get(), isEmpty);

    // RecallOS suggests they belong together, and shows why.
    final PurchaseLink suggestion =
        (await links.watchLinks(warranty).first).single;
    expect(suggestion.isConfirmed, isFalse);
    expect(suggestion.reasons.first.cue, LinkCue.serial);

    // The user confirms; the end is calculated and labelled so.
    await links.confirm(suggestion.id);
    final ExpiryView end = (await links.expiry(warranty))!;
    expect(end.expiry.day, LocalDate(2028, 10, 11));
    expect(end.expiry.isCalculated, isTrue);
    expect(end.expiry.explain(), startsWith('Calculated from'));

    // A reminder is scheduled.
    expect(end.remindAt, DateTime(2028, 9, 11, 9));
    expect(
      (await followUps.pendingReminders()).single.kind,
      DateKind.warrantyExpiry,
    );

    // "When does my laptop warranty expire?" — both documents cited.
    final SearchAnswer a = await search.ask(
      'When does my laptop warranty expire?',
    );
    final WarrantyAnswer w = a.warranties.single;
    expect(w.card.id, warranty);
    expect(w.receipt!.other.id, receipt);
    expect(w.expiry!.expiry.day, LocalDate(2028, 10, 11));
  });

  test('3 · Memory: a total with its receipts, and what expires', () async {
    final int laptop = await scan(
      paper(<Object>[
        'STAR TECH & ENGINEERING LTD',
        'Invoice No: ST-2026-0412',
        'Date: 12/10/2026',
        ('HP 15s-fq5111TU Laptop', '78,500.00'),
        ('Grand Total', '78,500.00'),
      ]),
      as: CardType.receipt,
    );
    final int rice = await scan(
      paper(<Object>[
        'SHWAPNO',
        'Banani, Dhaka',
        'Date: 13/10/2026',
        ('Rice 5kg', '432.60'),
        ('Grand Total', '432.60'),
      ]),
      as: CardType.receipt,
    );
    final int iron = await scan(
      paper(<Object>[
        'SINGER',
        'WARRANTY CARD',
        'Product: Iron',
        'Valid till: 30/11/2026',
      ]),
      as: CardType.warrantyCard,
    );
    await checkTotalAndDate(laptop);
    await checkTotalAndDate(rice);

    // "How much did I spend on electronics this month?" — a database sum,
    // receipts cited, worded as saved receipts.
    final SearchAnswer total = await search.ask(
      'How much did I spend on electronics this month?',
      plus: true,
    );
    final SpendingSummary s = total.spending!.summary!;
    expect(s.total!.format(), 'BDT 78,500.00');
    expect(s.counted.map((ReceiptFacts r) => r.cardId), <int>[laptop]);
    expect(s.scope, '1–31 Oct 2026 · 1 receipt you checked');

    // "What expires in the next 90 days?"
    final SearchAnswer ends = await search.ask(
      'What expires in the next 90 days?',
      plus: true,
    );
    expect(ends.plan, isA<ExpiringPlan>());
    expect(ends.expiring.map((ExpiringAnswer e) => e.card.id), <int>[iron]);
  });
}
