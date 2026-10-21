import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/features/cards/data/interaction_log.dart';

/// What search learns from the user reaching out to someone.
void main() {
  group('previousUseFrom', () {
    test('is nothing without any history', () {
      expect(previousUseFrom(const <Duration>[]), 0);
    });

    test('rises with each time, and never reaches 1', () {
      final double once = previousUseFrom(const <Duration>[Duration.zero]);
      final double thrice = previousUseFrom(
        List<Duration>.filled(3, Duration.zero),
      );
      expect(once, closeTo(0.5, 1e-9));
      expect(thrice, greaterThan(once));
      expect(
        previousUseFrom(List<Duration>.filled(200, Duration.zero)),
        lessThan(1),
      );
    });

    test('counts an old call for less than a recent one', () {
      final double recent = previousUseFrom(const <Duration>[
        Duration(days: 1),
      ]);
      final double old = previousUseFrom(const <Duration>[Duration(days: 365)]);
      expect(old, lessThan(recent));
      expect(old, greaterThan(0));
    });
  });

  group('InteractionLog', () {
    late AppDatabase db;
    late InteractionLog log;
    final DateTime now = DateTime(2026, 10, 7, 12);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      log = InteractionLog(db, now: () => now);
    });
    tearDown(() async => db.close());

    Future<int> card() => db
        .into(db.cards)
        .insert(CardsCompanion.insert(imagePath: '/x.jpg', capturedAt: now));

    test('records an opened call against the card', () async {
      final int id = await card();
      await log.opened(id, InteractionKind.callOpened);

      final List<Interaction> rows = await db.select(db.interactions).get();
      expect(rows.single.subjectId, id);
      expect(rows.single.kind, InteractionKind.callOpened);
      expect(rows.single.occurredAt, now);
    });

    test('only reaching out counts — not scanning or editing', () async {
      final int reached = await card();
      final int edited = await card();
      await log.opened(reached, InteractionKind.messageOpened);
      await log.opened(reached, InteractionKind.helloOpened);
      await log.opened(edited, InteractionKind.scanned);
      await log.opened(edited, InteractionKind.edited);

      final Map<int, double> use = await log.useSignals(<int>[reached, edited]);
      expect(use[reached], greaterThan(0));
      expect(use.containsKey(edited), isFalse);
    });

    test('a kind this build does not know cannot break ranking', () async {
      final int id = await card();
      await db.customStatement(
        'INSERT INTO interactions(subject_type, subject_id, kind, occurred_at) '
        "VALUES ('card', ?, 'teleported', ?)",
        <Object?>[id, now.millisecondsSinceEpoch ~/ 1000],
      );
      expect(await log.useSignals(<int>[id]), isEmpty);
    });
  });
}
