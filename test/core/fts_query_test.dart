// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/search/fts_query.dart';

void main() {
  group('buildFtsQuery', () {
    test('turns a plain query into OR-ed prefix terms', () {
      expect(buildFtsQuery('cheap printing'), '"cheap"* OR "printing"*');
    });

    test('lowercases, matching how the index tokenises', () {
      expect(buildFtsQuery('Cheap PRINTING'), '"cheap"* OR "printing"*');
    });

    test('returns null when nothing searchable is left', () {
      expect(buildFtsQuery(''), isNull);
      expect(buildFtsQuery('   '), isNull);
      expect(buildFtsQuery('--- ??? ***'), isNull);
    });

    // The reason this file exists. Cards are full of hyphens and colons, and
    // every one of these is FTS5 *syntax* — passing them through raw throws
    // "fts5: syntax error" and the results screen goes blank.
    test('neutralises characters FTS5 would read as syntax', () {
      for (final String hostile in <String>[
        't-shirt',
        '01711-223344',
        'Shop No:278',
        'a OR b',
        'NEAR(x y)',
        'quote " inside',
        'star * and (parens)',
        'AND NOT OR',
        '^caret',
        'trailing-',
      ]) {
        final String? built = buildFtsQuery(hostile);
        if (built == null) continue;

        // Every term is quoted, so nothing reaches the parser as an operator.
        expect(
          built,
          matches(RegExp(r'^"[^"]*"\*?( OR "[^"]*"\*?)*$')),
          reason: 'unsafe query built from ${hostile.toString()}',
        );
      }
    });

    test('splits a hyphenated number the same way the index does', () {
      // The indexed side tokenises 01711-223344 into two words, so the query
      // has to break identically or it can never match.
      expect(buildFtsQuery('01711-223344'), '"01711"* OR "223344"*');
    });
  });

  group('short terms', () {
    test('a finished short word matches only itself', () {
      // "ac" as a prefix matched accounts, academy and accountant.
      expect(buildFtsQuery('AC repair'), '"ac" OR "repair"*');
      expect(buildFtsQuery('ac '), '"ac"');
      expect(buildFtsQuery('road 12, dhaka'), '"road"* OR "12" OR "dhaka"*');
    });

    test('a short word still being typed also matches as a prefix', () {
      // Search runs on every keystroke: "pr" on the way to "printing" must
      // not empty the screen. The bare word is in the query too, so a card
      // with the whole word outranks one that only starts with it.
      expect(buildFtsQuery('pr'), '"pr" OR "pr"*');
      expect(buildFtsQuery('repair ac'), '"repair"* OR "ac" OR "ac"*');
    });

    test('three letters and more keep the prefix', () {
      expect(buildFtsQuery('lap'), '"lap"*');
    });

    test('matchedTerms follows the same rule', () {
      expect(matchedTerms('AC repair', 'Karim Accounts & Audit'), isEmpty);
      expect(matchedTerms('AC repair', 'AC servicing'), <String>['ac']);
      expect(matchedTerms('ac', 'Karim Accounts'), <String>['ac']);
    });
  });

  group('matchedTerms', () {
    test('reports which words actually hit', () {
      expect(
        matchedTerms('cheap printing press', 'Sonar Bangla Press, cheap rates'),
        <String>['cheap', 'press'],
      );
    });

    test('matches on prefix, mirroring the wildcard', () {
      expect(matchedTerms('print', 'offset printing'), <String>['print']);
    });

    test('is empty when nothing overlaps', () {
      expect(matchedTerms('dentist', 'Sonar Bangla Press'), isEmpty);
    });

    test('does not repeat a term', () {
      expect(matchedTerms('press press', 'the press'), <String>['press']);
    });
  });

  // Building a safe-looking string is not the same as SQLite accepting it, so
  // these run the output through a real FTS5 table.
  group('against a real FTS5 index', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customStatement(
        'INSERT INTO search_index(subject_type, subject_id, card_text, '
        'note_text, canonical_en, tags) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[
          'card',
          1,
          'Sonar Bangla Press\n01711-223344\nShop No:278',
          'cheap t-shirt printing, did our fest shirts',
          '',
          '',
        ],
      );
    });
    tearDown(() async => db.close());

    Future<List<int>> run(String raw) async {
      final String? match = buildFtsQuery(raw);
      if (match == null) return const <int>[];

      final List<QueryRow> rows = await db.customSelect(
        'SELECT subject_id FROM search_index WHERE search_index MATCH ? '
        'AND subject_type = ?',
        variables: <Variable<Object>>[
          Variable<String>(match),
          Variable<String>('card'),
        ],
      ).get();
      return rows.map((QueryRow r) => r.read<int>('subject_id')).toList();
    }

    test('finds a card by a word from its note', () async {
      expect(await run('printing'), <int>[1]);
    });

    test('finds a card by a word from the printed text', () async {
      expect(await run('Sonar'), <int>[1]);
    });

    test('a finished short word does not match a longer one', () async {
      await db.customStatement(
        'INSERT INTO search_index(subject_type, subject_id, card_text, '
        'note_text) VALUES (?, ?, ?, ?)',
        <Object?>['card', 2, 'Karim Accounts & Audit', 'accounting'],
      );
      expect(await run('ac '), isEmpty);
      expect(await run('ac'), <int>[2]);
    });

    // bm25() takes one weight per column *including* the two unindexed
    // ones, so the note's weight is the fourth number, not the second. Two
    // rows with the same word, once in the card text and once in the note:
    // swapping the third and fourth weights must swap the order, or the
    // weights are landing on the wrong columns.
    test('bm25 weights land on the columns they are meant for', () async {
      await db.customStatement('DELETE FROM search_index');
      await db.customStatement(
        'INSERT INTO search_index(subject_type, subject_id, card_text, '
        'note_text) VALUES '
        "('card', 10, 'biryani house', 'family run'), "
        "('card', 11, 'family run', 'biryani house')",
      );

      Future<int> top(String weights) async =>
          (await db
                  .customSelect(
                    'SELECT subject_id, bm25(search_index, $weights) AS s '
                    "FROM search_index WHERE search_index MATCH '\"biryani\"*' "
                    'ORDER BY s LIMIT 1',
                  )
                  .getSingle())
              .read<int>('subject_id');

      expect(await top('0.0, 0.0, 1.0, 2.0, 1.0, 1.0'), 11);
      expect(await top('0.0, 0.0, 2.0, 1.0, 1.0, 1.0'), 10);
    });

    test('survives every hostile query without throwing', () async {
      for (final String hostile in <String>[
        't-shirt',
        '01711-223344',
        'Shop No:278',
        'a OR b',
        'NEAR(x y)',
        'quote " inside',
        'star * and (parens)',
        '^caret',
      ]) {
        // The assertion is that this does not throw. A syntax error here is
        // what "search does nothing" looks like from the user's side.
        await run(hostile);
      }
    });

    test('matches a hyphenated phone number as printed', () async {
      expect(await run('01711-223344'), <int>[1]);
    });

    test('returns nothing for an unrelated query', () async {
      expect(await run('dentist'), isEmpty);
    });
  });
}
