import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/search/query_plan.dart';
import 'package:recallos/core/spending/spending_totals.dart';
import 'package:recallos/features/ask/data/purchase_answers.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';

import '../support/ocr_layout.dart';

/// One question, and what a correct answer is: the kind of plan it should
/// become, the papers it should cite, or that it should say it cannot
/// answer.
class AskCase {
  const AskCase(
    this.question, {
    required this.plan,
    this.cites = const <String>{},
    this.cannot = false,
    this.plus = true,
  });

  final String question;
  final Type plan;

  /// The fixture papers, by name, the answer must cite — no more, no less.
  final Set<String> cites;
  final bool cannot;
  final bool plus;
}

/// The Ask question set (B5, for PLAN §6's "Grounded Ask: answer
/// correctness, evidence correctness, abstention").
///
/// Scored three ways: is the question read as the right kind of plan; does
/// an answer cite exactly the right papers; does a question that cannot be
/// answered say so, and only then. Here it runs over an invented fixture
/// wallet, so it is a regression check and the harness, **not** a result:
/// §6's figures come from running the same scoring over questions written
/// against the owner's real, labelled wallet.
const List<AskCase> askQuestionSet = <AskCase>[
  // Purchase story (PLAN §3, 2).
  AskCase(
    'When does my laptop warranty expire?',
    plan: WarrantyPlan,
    cites: <String>{'laptop warranty', 'laptop receipt'},
    plus: false,
  ),
  AskCase(
    'where is my laptop warranty',
    plan: WarrantyPlan,
    cites: <String>{'laptop warranty', 'laptop receipt'},
    plus: false,
  ),
  AskCase(
    'is my fridge still under warranty',
    plan: WarrantyPlan,
    cites: <String>{'fridge warranty'},
    plus: false,
  ),
  AskCase(
    'AC er warranty kobe shesh',
    plan: WarrantyPlan,
    cannot: true,
    plus: false,
  ),
  AskCase(
    'when does my car warranty end',
    plan: WarrantyPlan,
    cannot: true,
    plus: false,
  ),
  // Memory story (PLAN §3, 3).
  AskCase(
    'What expires in the next 90 days?',
    plan: ExpiringPlan,
    cites: <String>{'iron warranty'},
  ),
  AskCase(
    'anything expiring soon',
    plan: ExpiringPlan,
    cites: <String>{'iron warranty'},
  ),
  AskCase('warranties ending in 3 days', plan: ExpiringPlan),
  AskCase(
    'my warranties',
    plan: ExpiringPlan,
    cites: <String>{'iron warranty', 'laptop warranty', 'fridge warranty'},
  ),
  AskCase(
    'How much did I spend on electronics this month?',
    plan: SpendingPlan,
    cites: <String>{'laptop receipt'},
  ),
  AskCase(
    'how much did I spend this month',
    plan: SpendingPlan,
    cites: <String>{'laptop receipt', 'grocery receipt'},
    plus: false,
  ),
  AskCase(
    'koto khoroch holo ei mash e',
    plan: SpendingPlan,
    cites: <String>{'laptop receipt', 'grocery receipt'},
    plus: false,
  ),
  AskCase(
    'spent at Shwapno this month',
    plan: SpendingPlan,
    cites: <String>{'grocery receipt'},
  ),
  AskCase('how much on groceries in September', plan: SpendingPlan),
  AskCase('spent this week', plan: SpendingPlan, cannot: true),
  AskCase('spending in 2027', plan: SpendingPlan, cannot: true),
  AskCase(
    'how much did I spend on jewellery this month',
    plan: SpendingPlan,
    cannot: true,
  ),
  // People (A6) — unchanged by B5.
  AskCase(
    "Rahim's number",
    plan: LookupPlan,
    cites: <String>{'rahim'},
    plus: false,
  ),
  AskCase('cheap t-shirt print', plan: SearchPlan, plus: false),
  AskCase('Samsung warranty service center', plan: SearchPlan, plus: false),
];

void main() {
  late AppDatabase db;
  late CardRepository cards;
  late SearchRepository search;
  late PurchaseLinks links;
  final DateTime now = DateTime(2026, 10, 15, 10);
  final Map<String, int> ids = <String, int>{};

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

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    links = PurchaseLinks(db, now: () => now);
    cards = CardRepository(db, purchases: links);
    search = SearchRepository(db, loadEmbedder, now: () => now);

    ids['laptop receipt'] = await store(
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
    ids['laptop warranty'] = await store(
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
    await links.confirm((await db.select(db.itemLinks).getSingle()).id);
    ids['iron warranty'] = await store(
      paper(<Object>[
        'SINGER',
        'WARRANTY CARD',
        'Product: Iron',
        'Valid till: 30/11/2026',
      ]),
      CardType.warrantyCard,
    );
    ids['fridge warranty'] = await store(
      paper(<Object>[
        'WALTON',
        'WARRANTY CARD',
        'Product: Refrigerator',
        'Date of Purchase: 01/09/2026',
        'Warranty Period: 5 Years',
      ]),
      CardType.warrantyCard,
    );
    ids['grocery receipt'] = await store(
      paper(<Object>[
        'SHWAPNO',
        'Banani, Dhaka',
        'Date: 13/10/2026',
        ('Rice 5kg', '432.60'),
        ('Grand Total', '432.60'),
      ]),
      CardType.receipt,
    );
    await check(ids['laptop receipt']!);
    await check(ids['grocery receipt']!);
    ids['rahim'] = await store(
      paper(<Object>[
        'Md. Rahim Uddin',
        'Sales Manager',
        'CoolAir Services',
        '+880 1711-223344',
      ]),
      CardType.visitingCard,
    );
  });
  tearDownAll(() async => db.close());

  /// The papers an answer cites, by fixture name.
  Set<String> cited(SearchAnswer a) {
    final Set<int> out = <int>{
      for (final WarrantyAnswer w in a.warranties) ...<int>[
        w.card.id,
        ?w.receipt?.other.id,
      ],
      for (final ExpiringAnswer e in a.expiring) e.card.id,
      if (a.spending?.summary case final SpendingSummary s)
        for (final ReceiptFacts r in s.counted) r.cardId,
      for (final LookupAnswer l in a.lookups) l.card.id,
    };
    return <String>{
      for (final MapEntry<String, int> e in ids.entries)
        if (out.contains(e.value)) e.key,
    };
  }

  test('the Ask question set: plans, sources and abstentions', () async {
    int plans = 0, sources = 0, sourced = 0, abstained = 0, toAbstain = 0;
    final List<String> misses = <String>[];

    for (final AskCase c in askQuestionSet) {
      final SearchAnswer a = await search.ask(c.question, plus: c.plus);
      if (a.plan.runtimeType == c.plan) {
        plans++;
      } else {
        misses.add('plan: "${c.question}" → ${a.plan}');
      }

      final bool said = a.cannot != null || a.spending?.cannot != null;
      if (c.cannot) {
        toAbstain++;
        if (said) {
          abstained++;
        } else {
          misses.add('abstain: "${c.question}"');
        }
      } else if (said) {
        misses.add('abstained wrongly: "${c.question}"');
      }

      if (!c.cannot && c.plan != SearchPlan) {
        sourced++;
        final Set<String> got = cited(a);
        if (got.length == c.cites.length && got.containsAll(c.cites)) {
          sources++;
        } else {
          misses.add('sources: "${c.question}" → $got');
        }
      }
    }

    // ignore: avoid_print
    print(
      'Ask question set (fixture, ${askQuestionSet.length} questions): '
      'plans $plans/${askQuestionSet.length}, '
      'sources $sources/$sourced, abstentions $abstained/$toAbstain',
    );
    expect(misses, isEmpty);
  });
}
