import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/settings/data/test_wallet.dart';

/// A wallet far bigger than anybody's: the list still loads whole, the right
/// card is still found, and neither takes long enough to be a problem.
///
/// The budgets are generous on purpose. They catch something going quadratic,
/// not a slow machine.
void main() {
  test('three thousand cards', () async {
    final _CountSelects count = _CountSelects();
    final AppDatabase db = AppDatabase(
      NativeDatabase.memory().interceptWith(count),
    );
    addTearDown(db.close);
    StaticEmbedder? shared;
    final SearchRepository search = SearchRepository(
      db,
      () async => shared ??= StaticEmbedder.fromBytes(
        matrixBytes: File('assets/embedding/matrix.bin').readAsBytesSync(),
        tokenizer: WordPieceTokenizer.fromAssets(
          vocabText: File('assets/embedding/vocab.txt').readAsStringSync(),
          normalizerJson: File(
            'assets/embedding/normalizer.json',
          ).readAsStringSync(),
        ),
      ),
    );
    final CardRepository cards = CardRepository(db);

    expect(await fillWithTestCards(cards, search), 3000);

    count.selects = 0;
    final Stopwatch list = Stopwatch()..start();
    final List<CardSummary> all = await cards.watchCards().first;
    list.stop();
    expect(all, hasLength(3000));
    expect(
      count.selects,
      lessThan(30),
      reason: 'it runs on every write, so it must not query per card',
    );
    expect(list.elapsed, lessThan(const Duration(seconds: 5)));

    final Stopwatch find = Stopwatch()..start();
    final List<SearchHit> hits = await search.search('Test Person 1234');
    find.stop();
    expect(hits, isNotEmpty);
    final CardSummary expected = all.firstWhere(
      (CardSummary c) =>
          c.title == 'Test Person 1234' || c.subtitle == 'Test Person 1234',
    );
    expect(hits.first.card.id, expected.id);
    expect(find.elapsed, lessThan(const Duration(seconds: 5)));

    // ignore: avoid_print
    print(
      '3000 cards: list ${list.elapsedMilliseconds} ms, '
      'search ${find.elapsedMilliseconds} ms',
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}

class _CountSelects extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return executor.runSelect(statement, args);
  }
}
