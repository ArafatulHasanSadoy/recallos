import 'dart:io';
import 'dart:typed_data';

// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';

/// End-to-end search, against a real database and the real embedding assets.
///
/// This is the test that would have caught the actual bug: every piece of the
/// search pipeline existed and passed its own unit tests, but nothing called
/// them — the FTS index was never written, no embedding was ever stored, and
/// the search box was a `const TextField` with no handler. Unit tests on the
/// parts cannot see that the parts are not connected.
void main() {
  late AppDatabase db;
  late SearchRepository search;

  StaticEmbedder? shared;
  Future<StaticEmbedder> loadEmbedder() async {
    return shared ??= StaticEmbedder.fromBytes(
      matrixBytes: File('assets/embedding/matrix.bin').readAsBytesSync(),
      tokenizer: WordPieceTokenizer.fromAssets(
        vocabText: File('assets/embedding/vocab.txt').readAsStringSync(),
        normalizerJson:
            File('assets/embedding/normalizer.json').readAsStringSync(),
      ),
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    search = SearchRepository(db, loadEmbedder);
  });
  tearDown(() async => db.close());

  /// Saves a card the way the capture flow does, then indexes it.
  Future<int> saveCard({
    required String company,
    required String phone,
    String? note,
    String rawText = '',
  }) async {
    final int id = await db.into(db.cards).insert(
          CardsCompanion.insert(
            imagePath: '/tmp/card_$company.jpg',
            capturedAt: DateTime.now(),
            rawOcrText: Value<String?>(rawText),
            extractionStatus:
                const Value<ExtractionStatus>(ExtractionStatus.complete),
          ),
        );
    await db.batch((Batch b) {
      b.insertAll(db.cardFields, <CardFieldsCompanion>[
        CardFieldsCompanion.insert(
          cardId: id,
          fieldKey: 'company',
          value: company,
          source: FactSource.printed,
        ),
        CardFieldsCompanion.insert(
          cardId: id,
          fieldKey: 'phone',
          value: phone,
          normalizedValue: Value<String?>('+880${phone.substring(1)}'),
          source: FactSource.printed,
        ),
      ]);
    });
    if (note != null) {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              subjectType: 'card',
              subjectId: id,
              body: Value<String?>(note),
            ),
          );
    }
    await search.reindexCard(id);
    return id;
  }

  group('indexing', () {
    test('writes both a text row and a vector', () async {
      final int id = await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711223344',
        note: 'cheap t-shirt printing, did our fest shirts',
      );

      final List<QueryRow> indexed = await db.customSelect(
        'SELECT subject_id FROM search_index WHERE subject_id = ?',
        variables: <Variable<Object>>[Variable<int>(id)],
      ).get();
      expect(indexed, hasLength(1));

      final List<Embedding> vectors = await db.select(db.embeddings).get();
      expect(vectors, hasLength(1));
      expect(vectors.single.dim, 256);
      expect(vectors.single.model, StaticEmbedder.modelId);
    });

    test('re-indexing replaces rather than duplicating', () async {
      final int id = await saveCard(
        company: 'Acme',
        phone: '01711223344',
        note: 'first',
      );
      await search.reindexCard(id);
      await search.reindexCard(id);

      final List<QueryRow> rows = await db
          .customSelect('SELECT subject_id FROM search_index')
          .get();
      expect(rows, hasLength(1));
      expect(await db.select(db.embeddings).get(), hasLength(1));
    });

    test('backfill indexes cards saved before search existed', () async {
      // Written straight to the table, bypassing reindexCard — exactly the
      // state every card was in before this wiring landed.
      final int id = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/old.jpg',
              capturedAt: DateTime.now(),
              rawOcrText: const Value<String?>('Dhaka Dental Clinic'),
            ),
          );

      expect(await search.search('dental'), isEmpty);

      await search.backfill();

      final List<SearchHit> hits = await search.search('dental');
      expect(hits.map((SearchHit h) => h.card.id), contains(id));
    });
  });

  group('finding things', () {
    setUp(() async {
      await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711223344',
        note: 'cheap t-shirt printing, did our fest shirts, small orders fine',
        rawText: 'Sonar Bangla Press\nShop No:12, New Market',
      );
      await saveCard(
        company: 'Dhaka Dental Care',
        phone: '01911556677',
        note: 'dentist near campus, expensive but good',
      );
      await saveCard(
        company: 'G AHMED',
        phone: '01673465717',
        rawText: 'G AHMED\nPresident\nShop No:278, New Market, Dhaka-1205',
      );
    });

    test('finds a card by a word from the note', () async {
      final List<SearchHit> hits = await search.search('printing');
      expect(hits, isNotEmpty);
      expect(hits.first.card.title, 'Sonar Bangla Press');
    });

    test('finds a card by its printed name', () async {
      final List<SearchHit> hits = await search.search('G AHMED');
      expect(hits.first.card.title, 'G AHMED');
    });

    test('finds a card by phone number, hyphens and all', () async {
      // A hyphen is FTS5 syntax; before the query sanitiser this threw.
      final List<SearchHit> hits = await search.search('01711-223344');
      expect(hits, isNotEmpty);
      expect(hits.first.card.title, 'Sonar Bangla Press');
    });

    // The reason the 7.3 MB embedding table is worth carrying: this query
    // shares no words with the note, so the lexical arm alone finds nothing.
    test('finds a card by meaning when no word matches', () async {
      final List<SearchHit> hits = await search.search('who makes custom shirts');

      expect(hits, isNotEmpty);
      expect(hits.first.card.title, 'Sonar Bangla Press');
    });

    test('explains why a card matched, in the user\'s own words', () async {
      final List<SearchHit> hits = await search.search('cheap printing');
      expect(hits.first.reasons, isNotEmpty);
      expect(hits.first.reasons.join(' '), contains('note'));
    });

    test('ranks the note-matching card above an unrelated one', () async {
      final List<SearchHit> hits = await search.search('dentist');
      expect(hits.first.card.title, 'Dhaka Dental Care');
    });

    test('returns nothing for a query with no searchable characters',
        () async {
      expect(await search.search('   '), isEmpty);
      expect(await search.search('???'), isEmpty);
    });

    test('survives hostile input rather than throwing', () async {
      for (final String hostile in <String>[
        'a OR b',
        'NEAR(x y)',
        'quote " inside',
        '* (parens)',
        '^caret',
        't-shirt',
      ]) {
        await search.search(hostile);
      }
    });
  });

  group('deleted cards', () {
    test('drop out of results as soon as they are hidden', () async {
      final int id = await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711223344',
        note: 'cheap printing',
      );
      expect(await search.search('printing'), isNotEmpty);

      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
          .write(CardsCompanion(deletedAt: Value<DateTime?>(DateTime.now())));

      // Soft-deleted rows stay in the index until purge, so the summary lookup
      // is what has to filter them — otherwise a deleted card keeps appearing.
      expect(await search.search('printing'), isEmpty);
    });

    test('purging removes the index rows too', () async {
      final int id = await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711223344',
        note: 'cheap printing',
      );

      await CardRepository(db).purge(id);

      final List<QueryRow> rows = await db
          .customSelect('SELECT subject_id FROM search_index')
          .get();
      expect(rows, isEmpty);
      expect(await db.select(db.embeddings).get(), isEmpty);
      expect(await search.search('printing'), isEmpty);
    });
  });

  group('without the embedding assets', () {
    test('search still works on the lexical arm alone', () async {
      // What happens on a device where the asset failed to load. Losing
      // semantic matching should degrade results, not break search.
      final SearchRepository lexicalOnly = SearchRepository(
        db,
        () async => throw const EmbeddingAssetError('simulated'),
      );

      final int id = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/x.jpg',
              capturedAt: DateTime.now(),
              rawOcrText: const Value<String?>('Sonar Bangla Press'),
            ),
          );
      await lexicalOnly.reindexCard(id);

      final List<SearchHit> hits = await lexicalOnly.search('sonar');
      expect(hits, hasLength(1));

      // No vectors were written, which is the honest outcome rather than a
      // half-populated index.
      expect(await db.select(db.embeddings).get(), isEmpty);
    });
  });

  group('embedding sanity', () {
    test('a query vector is unit length and usable', () async {
      final StaticEmbedder e = await loadEmbedder();
      final Float32List v = e.embed('cheap t-shirt printing');
      expect(StaticEmbedder.isUsable(v), isTrue);
      expect(v.length, 256);
    });
  });
}
