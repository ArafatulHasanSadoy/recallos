import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/eval/question_set.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/search/retrieval_metrics.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/capture/domain/eval_runner.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';

import '../support/ocr_layout.dart';

/// The question-set harness for PLAN §6 (retrieval, Ask, links): its file
/// format, and a run over a small invented wallet. The invented wallet only
/// proves the harness; §6's figures come from the owner's labelled set, run
/// from the bench screen on the phone.
void main() {
  group('the labels file', () {
    test('every form it takes', () {
      final EvalSet set = EvalSet.parse('''
{
  "questions": [
    {"q": "AC repair", "relevant": {"CoolAir Services": 2, "TechFix": 1}},
    {"q": "who prints t-shirts", "relevant": ["Pixel Print House"]},
    {"q": "When does my laptop warranty expire?",
     "cites": ["HP Laptop", "STAR TECH"], "plus": false},
    {"q": "spent this week", "cannot": true}
  ],
  "links": [{"warranty": "HP Laptop", "receipt": "STAR TECH"}]
}''');
      expect(set.questions, hasLength(4));
      expect(set.questions[0].relevant, <String, int>{
        'CoolAir Services': 2,
        'TechFix': 1,
      });
      expect(set.questions[1].relevant, <String, int>{'Pixel Print House': 1});
      expect(set.questions[2].cites, <String>{'HP Laptop', 'STAR TECH'});
      expect(set.questions[2].plus, isFalse);
      expect(set.questions[2].scoresRetrieval, isFalse);
      expect(set.questions[3].cannot, isTrue);
      expect(set.links.single.receipt, 'STAR TECH');
    });

    test('a hand-written mistake says what is wrong', () {
      expect(
        () => EvalSet.parse('{"questions": [{"question": "AC"}]}'),
        throwsA(isA<FormatException>()),
      );
      expect(() => EvalSet.parse('[]'), throwsA(isA<FormatException>()));
    });
  });

  test(
    'a run over a wallet: every score, and titles not in it skipped',
    () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final DateTime now = DateTime(2026, 10, 15, 10);
      final PurchaseLinks links = PurchaseLinks(db, now: () => now);
      final CardRepository cards = CardRepository(db, purchases: links);
      final SearchRepository search = SearchRepository(
        db,
        () async => StaticEmbedder.fromBytes(
          matrixBytes: File('assets/embedding/matrix.bin').readAsBytesSync(),
          tokenizer: WordPieceTokenizer.fromAssets(
            vocabText: File('assets/embedding/vocab.txt').readAsStringSync(),
            normalizerJson: File(
              'assets/embedding/normalizer.json',
            ).readAsStringSync(),
          ),
        ),
        now: () => now,
      );

      Future<int> scan(List<OcrBlock> blocks, CardType type) async {
        final int id = await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(imagePath: '/x.jpg', capturedAt: now),
            );
        final DocumentReading r = readDocument(blocks, as: type);
        await cards.attachExtraction(
          cardId: id,
          result: OcrResult(
            blocks: blocks,
            engine: 't',
            duration: Duration.zero,
          ),
          extraction: r.extraction,
        );
        await cards.setKind(id, type, title: r.title);
        await search.reindexCard(id);
        return id;
      }

      final int coolAir = await scan(
        paper(<Object>['CoolAir Services', 'Mehedi Hasan', '+880 1711-223344']),
        CardType.visitingCard,
      );
      await cards.addNote(cardId: coolAir, body: 'AC servicing before summer');
      await search.reindexCard(coolAir);
      await scan(
        paper(<Object>[
          'STAR TECH & ENGINEERING LTD',
          'Date: 12/10/2026',
          'S/N: 5CD3281XYZ',
          ('Grand Total', '78,500.00'),
        ]),
        CardType.receipt,
      );
      await scan(
        paper(<Object>[
          'HP',
          'WARRANTY CARD',
          'Product: Laptop',
          'Serial No: 5CD3281XYZ',
          'Warranty Period: 2 Years',
        ]),
        CardType.warrantyCard,
      );
      await links.confirm((await db.select(db.itemLinks).getSingle()).id);

      final EvalReport report =
          await EvalRunner(db: db, search: search, links: links).run(
            EvalSet.parse('''
{
  "questions": [
    {"q": "AC repair", "relevant": {"CoolAir Services": 2}},
    {"q": "who sells furniture", "relevant": ["Hatil Furniture"]},
    {"q": "When does my laptop warranty expire?",
     "cites": ["HP Laptop", "STAR TECH & ENGINEERING LTD"]},
    {"q": "how much did I spend this week", "cannot": true}
  ],
  "links": [{"warranty": "HP Laptop", "receipt": "STAR TECH & ENGINEERING LTD"}]
}'''),
          );

      // Retrieval, per mode, over the one question whose paper is here.
      expect(report.retrieval.keys, containsAll(SearchMode.values));
      final RetrievalScore hybrid = report.retrieval[SearchMode.hybrid]!;
      expect(hybrid.count, 1);
      expect(hybrid.mrr, 1, reason: 'CoolAir first for "AC repair"');
      expect(hybrid.p3, greaterThan(0));

      // Ask: both papers cited; the week declined.
      expect(report.ask.sourcesRight, 1);
      expect(report.ask.sourcesTotal, 1);
      expect(report.ask.abstainedRight, 1);
      expect(report.ask.declinedWrongly, 0);

      // Links: the rules find the one true pair, and nothing false.
      expect(report.links!.precision, 1);
      expect(report.links!.recall, 1);
      expect(report.links!.falseLinks, 0);

      // A title nobody in this wallet has is reported, not guessed.
      expect(report.unresolved, <String>{'Hatil Furniture'});
      expect(report.format(), contains('hybrid'));
      expect(report.toJson(), contains('"p@3"'));
    },
  );
}
