import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/search/index_subjects.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;

final interactionLogProvider = Provider<InteractionLog>(
  (Ref ref) => InteractionLog(ref.watch(databaseProvider)),
);

/// The kinds that mean the user reached out to the person on a card.
///
/// Each records only what RecallOS did — handed a number to the dialler, a
/// chat to WhatsApp, an address to mail — never that a call was made or a
/// message sent, which happens out of its sight.
const List<InteractionKind> kReachedOut = <InteractionKind>[
  InteractionKind.helloOpened,
  InteractionKind.callOpened,
  InteractionKind.messageOpened,
  InteractionKind.emailOpened,
];

/// What the user did with the people in the wallet, as search ranks by it.
class InteractionLog {
  InteractionLog(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Records that another app was opened for the person on [cardId].
  /// Call it only once the hand-off succeeded.
  Future<void> opened(int cardId, InteractionKind kind, {String? detail}) => _db
      .into(_db.interactions)
      .insert(
        InteractionsCompanion.insert(
          subjectType: kCardSubject,
          subjectId: cardId,
          kind: kind,
          detail: Value<String?>(detail),
          occurredAt: Value<DateTime>(_now()),
        ),
      );

  /// When the user last reached out to each of [cardIds], every time.
  ///
  /// Matched on the kind's stored name in SQL rather than read back through
  /// the enum, so a row a newer build wrote can never fail a search here.
  Future<Map<int, List<DateTime>>> reachedOut(Iterable<int> cardIds) async {
    final List<int> ids = cardIds.toSet().toList();
    if (ids.isEmpty) return const <int, List<DateTime>>{};

    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT subject_id, occurred_at FROM interactions '
          'WHERE subject_type = ? '
          'AND subject_id IN (${List<String>.filled(ids.length, '?').join(', ')}) '
          'AND kind IN (${List<String>.filled(kReachedOut.length, '?').join(', ')})',
          variables: <Variable<Object>>[
            Variable<String>(kCardSubject),
            for (final int id in ids) Variable<int>(id),
            for (final InteractionKind k in kReachedOut)
              Variable<String>(k.name),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.interactions,
          },
        )
        .get();

    final Map<int, List<DateTime>> out = <int, List<DateTime>>{};
    for (final QueryRow r in rows) {
      out
          .putIfAbsent(r.read<int>('subject_id'), () => <DateTime>[])
          .add(r.read<DateTime>('occurred_at'));
    }
    return out;
  }

  /// The previous-use signal for each of [cardIds] — see [previousUseFrom].
  Future<Map<int, double>> useSignals(Iterable<int> cardIds) async {
    final DateTime now = _now();
    return <int, double>{
      for (final MapEntry<int, List<DateTime>> e in (await reachedOut(
        cardIds,
      )).entries)
        e.key: previousUseFrom(<Duration>[
          for (final DateTime at in e.value) now.difference(at),
        ]),
    };
  }
}

/// How much the user has reached out to someone, as 0..1.
///
/// Each time counts for less as it ages, halving every [halfLife], and the
/// sum is squashed so that a handful of recent calls is near the top and no
/// amount of calling reaches 1: s / (s + 1). Somebody you have already
/// called is likelier to be the one you mean — but that is a tie-breaker,
/// weighted lightly, never a reason to bury a better match.
double previousUseFrom(
  Iterable<Duration> ages, {
  Duration halfLife = const Duration(days: 180),
}) {
  double s = 0;
  for (final Duration age in ages) {
    final double halfLives = age.isNegative
        ? 0
        : age.inSeconds / halfLife.inSeconds;
    s += math.pow(0.5, halfLives).toDouble();
  }
  return s / (s + 1);
}
