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
import 'package:recallos/core/search/query_plan.dart';
import 'package:recallos/core/search/retrieval_metrics.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/data/interaction_log.dart';
import 'package:recallos/features/followup/data/follow_up_actions.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/search/data/search_repository.dart';

import '../support/fake_notification_port.dart';

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

      // One for the whole card, and one for the note on its own: in the
      // card's vector a short note is drowned by the OCR text.
      final List<Embedding> vectors = await db.select(db.embeddings).get();
      expect(
        vectors.map((Embedding e) => e.subjectType),
        unorderedEquals(<String>['card', 'card_note']),
      );
      for (final Embedding v in vectors) {
        expect(v.dim, 256);
        expect(v.model, StaticEmbedder.modelId);
      }
    });

    test('a card without a note gets no note vector', () async {
      await saveCard(company: 'G AHMED', phone: '01673465717');
      final List<Embedding> vectors = await db.select(db.embeddings).get();
      expect(vectors.map((Embedding e) => e.subjectType), <String>['card']);
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
      expect(await db.select(db.embeddings).get(), hasLength(2));
    });

    test('a new index version rebuilds every card once', () async {
      final int id = await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711223344',
        note: 'cheap printing',
      );
      // A card indexed by an older build: its rows exist, but not the note
      // vector this version writes.
      await (db.delete(
        db.embeddings,
      )..where(($EmbeddingsTable e) => e.subjectType.equals('card_note'))).go();

      await search.backfill();
      expect(
        (await db.select(db.embeddings).get())
            .where((Embedding e) => e.subjectId == id)
            .map((Embedding e) => e.subjectType),
        unorderedEquals(<String>['card', 'card_note']),
      );

      // Once is enough: the version is recorded, so a second launch leaves
      // the rows alone.
      await (db.delete(
        db.embeddings,
      )..where(($EmbeddingsTable e) => e.subjectType.equals('card_note'))).go();
      await search.backfill();
      expect(
        (await db.select(db.embeddings).get()).map(
          (Embedding e) => e.subjectType,
        ),
        <String>['card'],
      );
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

  // Seen on the phone, 4 Oct: "AC repair" put TechFix (a laptop repairer)
  // above CoolAir (who services ACs). Each shares one word with the query,
  // and "repair" won because TechFix prints it in its name as well as the
  // note. The person who services ACs is the answer: "ac" is the rarer,
  // more specific word, and the note is where the user wrote what they
  // needed this person for.
  group('term specificity', () {
    late int techFix;
    late int coolAir;
    late int accounts;

    setUp(() async {
      techFix = await saveCard(
        company: 'TechFix Repair Centre',
        phone: '01711000001',
        note: 'laptop repair',
        rawText:
            'TechFix Repair Centre\nLaptop and Mobile Servicing\n'
            'Shop 12, Multiplan Center, Elephant Road',
      );
      coolAir = await saveCard(
        company: 'CoolAir Solutions',
        phone: '01711000002',
        note: 'AC servicing',
        rawText: 'CoolAir Solutions\nCooling Experts\nHouse 5, Road 2, Mirpur',
      );
      // "ac" as a prefix would match all of these words, which is what made
      // a two-letter acronym look as common as "repair".
      accounts = await saveCard(
        company: 'Karim Accounts & Audit',
        phone: '01711000003',
        note: 'tax returns and accounting',
        rawText: 'Karim Accounts & Audit\nAccountant\nAcademy Road, Dhaka',
      );
      await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711000004',
        note: 'cheap t-shirt printing',
      );
    });

    test('"AC repair" finds the person who services ACs first', () async {
      final List<SearchHit> hits = await search.search('AC repair');
      expect(hits.first.card.id, coolAir);
      expect(hits.map((SearchHit h) => h.card.id), contains(techFix));
    });

    test('a finished "ac" does not match accounts or academy', () async {
      final List<SearchHit> hits = await search.search('ac ');
      expect(hits.map((SearchHit h) => h.card.id), isNot(contains(accounts)));
    });

    test(
      'while "ac" is still being typed, the whole word ranks first',
      () async {
        // Search runs per keystroke, so a lone short word still matches as a
        // prefix — but a card with the word itself outranks one that merely
        // starts with it.
        final List<SearchHit> hits = await search.search('ac');
        expect(hits.first.card.id, coolAir);
      },
    );
  });

  // Event Mode writes the event as the place a card's person was met, and
  // the user can type one in. Neither used to reach the index, so "CSE fest"
  // found nobody met there.
  group('where you met', () {
    test('finds the people met at an event, and says why', () async {
      final int nusrat = await saveCard(
        company: 'EnationX',
        phone: '01812445566',
        note: 'wants a sponsor for the esports team',
      );
      await saveCard(company: 'Sonar Bangla Press', phone: '01711223344');
      await FollowUpRepository(
        db,
      ).setEncounter(cardId: nusrat, place: 'CSE fest at NSU');
      await search.reindexCard(nusrat);

      final List<SearchHit> hits = await search.search('CSE fest');
      expect(hits.first.card.id, nusrat);
      expect(hits.first.reasons, contains('where you met'));
    });

    test('changing where you met reaches the index', () async {
      final int id = await saveCard(company: 'EnationX', phone: '01812445566');
      final FollowUpRepository repo = FollowUpRepository(db);
      final FollowUpActions actions = FollowUpActions(
        repo: repo,
        engine: ReminderEngine(repo: repo, port: FakePort()),
        reindex: search.reindexCard,
      );

      await actions.setEncounter(id, (
        metOn: null,
        place: 'Tech expo, Bashundhara',
      ));
      expect(
        (await search.search('bashundhara')).map((SearchHit h) => h.card.id),
        contains(id),
      );

      await actions.setEncounter(id, (metOn: null, place: 'Lalbagh'));
      expect(
        (await search.search('lalbagh')).map((SearchHit h) => h.card.id),
        contains(id),
      );
      // The old place leaves the index with the change: nothing else on
      // this card says Bashundhara.
      final List<QueryRow> old = await db
          .customSelect(
            'SELECT subject_id FROM search_index WHERE search_index MATCH '
            "'met_text : bashundhara'",
          )
          .get();
      expect(old, isEmpty);
    });
  });

  // Somebody the user has already called, messaged or written to is likelier
  // to be the one they mean. A light weight: it breaks a tie, it never buries
  // a better match.
  group('people you reached out to', () {
    test('a recent call breaks a tie', () async {
      final int a = await saveCard(
        company: 'Alpha Press',
        phone: '01711000011',
        note: 'printing',
      );
      final int b = await saveCard(
        company: 'Beta Press',
        phone: '01711000012',
        note: 'printing',
      );
      final List<SearchHit> before = await search.search('printing');
      final int second = before[1].card.id;
      expect(<int>[a, b], contains(second));

      await InteractionLog(db).opened(second, InteractionKind.callOpened);

      final List<SearchHit> after = await search.search('printing');
      expect(after.first.card.id, second);
    });
  });

  // "Rahim's number" asks for one fact. The answer is the number, on the
  // card it came from, with where it came from — for every Rahim, never a
  // guess at which one was meant.
  group('lookups', () {
    Future<int> person(
      String name, {
      String? company,
      String? phone,
      String? email,
      String? note,
      FactSource source = FactSource.printed,
    }) async {
      final int id = await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              imagePath: '/tmp/card_$name.jpg',
              capturedAt: DateTime.now(),
              extractionStatus: const Value<ExtractionStatus>(
                ExtractionStatus.complete,
              ),
            ),
          );
      Future<void> field(String key, String value) => db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: key,
              value: value,
              source: source,
            ),
          );
      await field('person_name', name);
      if (company != null) await field('company', company);
      if (phone != null) await field('phone', phone);
      if (email != null) await field('email', email);
      if (note != null) {
        await db
            .into(db.notes)
            .insert(
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

    test('every Rahim, each with the number from their own card', () async {
      final int a = await person(
        'Md. Rahim Uddin',
        company: 'Medica Books',
        phone: '01711-223344',
      );
      final int b = await person(
        'Rahim Chowdhury',
        company: 'CoolAir Solutions',
        phone: '01911-556677',
        source: FactSource.user,
      );
      await person('Nusrat Jahan', phone: '01812-445566');

      final SearchAnswer answer = await search.ask("Rahim's number");
      expect(answer.plan, isA<LookupPlan>());
      expect(
        answer.lookups.map((LookupAnswer l) => l.card.id),
        unorderedEquals(<int>[a, b]),
      );
      final LookupAnswer first = answer.lookups.firstWhere(
        (LookupAnswer l) => l.card.id == a,
      );
      expect(first.values.single.value, '01711-223344');
      expect(first.values.single.source, FactSource.printed);
      final LookupAnswer second = answer.lookups.firstWhere(
        (LookupAnswer l) => l.card.id == b,
      );
      expect(second.values.single.source, FactSource.user);
      // Nusrat is not a Rahim, and the answers are not repeated below.
      expect(
        answer.hits.map((SearchHit h) => h.card.id),
        isNot(anyOf(contains(a), contains(b))),
      );
    });

    test('says so when the card has no such field', () async {
      final int id = await person('Karim Hasan', phone: '01711-000003');
      final SearchAnswer answer = await search.ask('email of Karim');
      expect(answer.lookups.single.card.id, id);
      expect(answer.lookups.single.values, isEmpty);
    });

    test('a deleted card is not an answer', () async {
      final int id = await person('Rahim Uddin', phone: '01711-223344');
      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
          .write(CardsCompanion(deletedAt: Value<DateTime?>(DateTime.now())));
      expect((await search.ask('rahim number')).lookups, isEmpty);
    });

    test('a need can be asked for a number: "AC repair number"', () async {
      final int coolAir = await saveCard(
        company: 'CoolAir Solutions',
        phone: '01711000002',
        note: 'AC servicing',
      );
      final SearchAnswer answer = await search.ask('AC repair number');
      expect(answer.lookups.first.card.id, coolAir);
      expect(answer.lookups.first.viaSearch, isTrue);
      expect(answer.lookups.first.values.single.value, '01711000002');
    });

    test('a field word inside a need is just searched', () async {
      await saveCard(
        company: 'Plate Makers',
        phone: '01711000009',
        note: 'number plate for the car',
      );
      final SearchAnswer answer = await search.ask('number plate');
      expect(answer.plan, isA<SearchPlan>());
      expect(answer.lookups, isEmpty);
      expect(answer.hits, isNotEmpty);
    });
  });

  // RecallOS Plus: people by where, when and what is next — an exact list.
  // Without Plus the same words are searched, and the answer says so.
  group('people filters', () {
    late int nusrat;
    late int shafiq;
    late int karim;

    setUp(() async {
      final FollowUpRepository repo = FollowUpRepository(db);
      nusrat = await saveCard(
        company: 'Bengal Event Solutions',
        phone: '01812445566',
      );
      shafiq = await saveCard(
        company: 'Green Leaf Printing',
        phone: '01711000021',
      );
      karim = await saveCard(company: 'Karim Traders', phone: '01711000022');
      final DateTime today = DateTime.now();
      final DateTime day = DateTime(today.year, today.month, today.day);
      await repo.setEncounter(
        cardId: nusrat,
        metOn: day,
        place: 'CSE fest at NSU',
      );
      await repo.setEncounter(
        cardId: shafiq,
        metOn: day,
        place: 'CSE fest at NSU',
      );
      await repo.setEncounter(
        cardId: karim,
        metOn: day.subtract(const Duration(days: 60)),
        place: 'Tech expo',
      );
      await repo.addStep(
        cardId: shafiq,
        title: 'Send the sponsorship deck',
        dueOn: day.add(const Duration(days: 2)),
      );
      // What the app's own path (FollowUpActions) does after a change.
      for (final int id in <int>[nusrat, shafiq, karim]) {
        await search.reindexCard(id);
      }
    });

    List<int> ids(SearchAnswer a) =>
        a.people.map((PersonMatch p) => p.card.id).toList();

    test('met at an event: everyone met there, nobody else', () async {
      final SearchAnswer a = await search.ask('met at CSE fest', plus: true);
      expect(ids(a), unorderedEquals(<int>[nusrat, shafiq]));
      expect(a.plusNeeded, isFalse);
    });

    test('met in a window of days', () async {
      final SearchAnswer a = await search.ask('people I met today', plus: true);
      expect(ids(a), unorderedEquals(<int>[nusrat, shafiq]));
    });

    test('who still needs a next step, and who is waiting on one', () async {
      expect(
        ids(
          await search.ask('met at CSE fest without a next step', plus: true),
        ),
        <int>[nusrat],
      );
      final SearchAnswer waiting = await search.ask(
        'who do I need to follow up with',
        plus: true,
      );
      expect(ids(waiting), <int>[shafiq]);
      expect(waiting.people.single.nextStep, 'Send the sponsorship deck');
    });

    test('nobody fitting is an answer, not "nothing matched"', () async {
      final SearchAnswer a = await search.ask(
        'met at Dhaka book fair',
        plus: true,
      );
      expect(a.people, isEmpty);
      expect(a.isEmpty, isFalse);
    });

    test('without Plus: the words are searched, and Plus is named', () async {
      final SearchAnswer a = await search.ask('met at CSE fest');
      expect(a.plusNeeded, isTrue);
      expect(a.people, isEmpty);
      // "CSE fest" is still found, by the free where-you-met index.
      expect(
        a.hits.map((SearchHit h) => h.card.id),
        containsAll(<int>[nusrat, shafiq]),
      );
    });
  });

  // The evaluation compares keyword search, meaning alone, and both (§6).
  group('search modes', () {
    setUp(() async {
      await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711223344',
        note: 'cheap t-shirt printing, did our fest shirts',
      );
      await saveCard(
        company: 'Dhaka Dental Care',
        phone: '01911556677',
        note: 'dentist near campus',
      );
    });

    test('keyword only: every result shares a word with the query', () async {
      final List<SearchHit> hits = await search.search(
        'printing',
        mode: SearchMode.lexical,
      );
      expect(hits.single.card.title, 'Sonar Bangla Press');
      expect(hits.single.matchedOnMeaningOnly, isFalse);
      expect(await search.search('zqxv', mode: SearchMode.lexical), isEmpty);
    });

    test('meaning only: every result came from the embedding', () async {
      final List<SearchHit> hits = await search.search(
        'printing',
        mode: SearchMode.semantic,
      );
      expect(hits, isNotEmpty);
      expect(hits.every((SearchHit h) => h.matchedOnMeaningOnly), isTrue);
    });

    test('the app runs both', () async {
      final List<SearchHit> hits = await search.search('printing');
      expect(hits.first.card.title, 'Sonar Bangla Press');
      expect(hits.first.matchedOnMeaningOnly, isFalse);
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

      // Soft-deleted rows stay in the index until purge, so the search itself
      // has to filter them — otherwise a deleted card keeps appearing.
      expect(await search.search('printing'), isEmpty);
    });

    test('do not take the places of live cards', () async {
      // Deleted cards keep their index rows for thirty days. Filtered only
      // after each arm had kept its top 50 and fusion its top 20, enough of
      // them matching more strongly pushed a live card out of the results
      // entirely — the search looked like it had simply failed.
      for (int i = 0; i < 40; i++) {
        final int id = await saveCard(
          company: 'Old Printers $i',
          phone: '0171122${(3000 + i).toString()}',
          note: 'printing printing printing printing',
        );
        await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
            .write(CardsCompanion(deletedAt: Value<DateTime?>(DateTime.now())));
      }
      final int live = await saveCard(
        company: 'Sonar Bangla Press',
        phone: '01711223344',
        note: 'printing shop near campus',
      );

      final List<SearchHit> hits = await search.search('printing');

      expect(hits.map((SearchHit h) => h.card.id), contains(live));
      expect(hits, hasLength(1), reason: 'no deleted card may be shown');
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
