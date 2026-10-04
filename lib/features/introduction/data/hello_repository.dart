import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;
import 'hello.dart';

final helloRepositoryProvider = Provider<HelloRepository>(
  (Ref ref) => HelloRepository(ref.watch(databaseProvider)),
);

/// The last hello opened for a card, or null when there has been none.
final lastHelloProvider = StreamProvider.family<HelloRecord?, int>(
  (Ref ref, int cardId) => ref.watch(helloRepositoryProvider).watchLast(cardId),
);

/// Hands a link to the app that handles it. A provider so a test can see
/// what would have opened without leaving the test.
final helloOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (Ref ref) =>
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// One hello, as the card shows it.
class HelloRecord {
  const HelloRecord({required this.channel, required this.openedAt});

  final HelloChannel channel;
  final DateTime openedAt;
}

/// Where hellos are recorded: the `interactions` table, against the card.
///
/// The first writer of an interaction that is about the *person* rather than
/// the card's upkeep, and the one people search (A6) will rank by — somebody
/// you have already written to is somebody you know.
class HelloRepository {
  HelloRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<void> recordOpened(int cardId, HelloChannel channel) => _db
      .into(_db.interactions)
      .insert(
        InteractionsCompanion.insert(
          subjectType: 'card',
          subjectId: cardId,
          kind: InteractionKind.helloOpened,
          detail: Value<String?>(channel.name),
          occurredAt: Value<DateTime>(_now()),
        ),
      );

  Stream<HelloRecord?> watchLast(int cardId) =>
      (_db.select(_db.interactions)
            ..where(
              ($InteractionsTable i) =>
                  i.subjectType.equals('card') &
                  i.subjectId.equals(cardId) &
                  i.kind.equalsValue(InteractionKind.helloOpened),
            )
            ..orderBy(<OrderClauseGenerator<$InteractionsTable>>[
              ($InteractionsTable i) => OrderingTerm.desc(i.occurredAt),
              ($InteractionsTable i) => OrderingTerm.desc(i.id),
            ])
            ..limit(1))
          .watchSingleOrNull()
          .map((Interaction? i) {
            if (i == null) return null;
            final HelloChannel? channel = HelloChannel.values
                .where((HelloChannel c) => c.name == i.detail)
                .firstOrNull;
            if (channel == null) return null;
            return HelloRecord(channel: channel, openedAt: i.occurredAt);
          });
}
