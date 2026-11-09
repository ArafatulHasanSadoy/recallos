import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_notification_port.dart';

/// A phone that changes time zone keeps the same days and the same times on
/// the clock.
///
/// Every moment here is built in a named zone and compared as an instant, so
/// the tests mean the same on a machine in any zone.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late FollowUpRepository repo;
  late DateTime now;

  tz.Location at(String name) => tz.getLocation(name);

  DateTime clock(String zone, int m, int d, [int h = 0, int min = 0]) {
    final tz.TZDateTime t = tz.TZDateTime(at(zone), 2026, m, d, h, min);
    return DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch);
  }

  Future<int> card() => db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(
          imagePath: '/cards/x.jpg',
          capturedAt: clock('Asia/Dhaka', 10, 1),
        ),
      );

  /// A step due on 12 Nov and a 9 AM reminder, as written in Dhaka.
  Future<({int step, int reminder})> stepInDhaka({int snoozes = 0}) async {
    final int cardId = await card();
    final int step = await db
        .into(db.importantDates)
        .insert(
          ImportantDatesCompanion.insert(
            cardId: cardId,
            kind: DateKind.followUp,
            title: 'Send the proposal',
            dueOn: clock('Asia/Dhaka', 11, 12),
          ),
        );
    final int reminder = await db
        .into(db.reminders)
        .insert(
          RemindersCompanion.insert(
            importantDateId: step,
            remindAt: clock('Asia/Dhaka', 11, 12, 9),
            snoozeCount: Value<int>(snoozes),
          ),
        );
    return (step: step, reminder: reminder);
  }

  Future<DateTime> dueOn(int step) async => (await (db.select(
    db.importantDates,
  )..where(($ImportantDatesTable d) => d.id.equals(step))).getSingle()).dueOn;

  Future<DateTime> remindAt(int reminder) async => (await (db.select(
    db.reminders,
  )..where(($RemindersTable r) => r.id.equals(reminder))).getSingle()).remindAt;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = clock('Asia/Dhaka', 11, 1, 10);
    repo = FollowUpRepository(db, now: () => now);
    await repo.followZone('Asia/Dhaka');
  });
  tearDown(() async => db.close());

  test('the first time, it only remembers the zone', () async {
    final AppDatabase fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    final int cardId = await fresh
        .into(fresh.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/cards/x.jpg',
            capturedAt: clock('Asia/Dhaka', 10, 1),
          ),
        );
    final DateTime due = clock('Asia/Dhaka', 11, 12);
    final int step = await fresh
        .into(fresh.importantDates)
        .insert(
          ImportantDatesCompanion.insert(
            cardId: cardId,
            kind: DateKind.followUp,
            title: 'Call',
            dueOn: due,
          ),
        );

    await FollowUpRepository(fresh, now: () => now).followZone('Asia/Dubai');

    final ImportantDate d = await (fresh.select(
      fresh.importantDates,
    )..where(($ImportantDatesTable t) => t.id.equals(step))).getSingle();
    expect(d.dueOn.isAtSameMomentAs(due), isTrue);
  });

  for (final String zone in <String>[
    'Asia/Dubai', // Two hours west: the trip that first read a day early.
    'Europe/London',
    'America/Los_Angeles', // Fourteen hours: more than rounding could fix.
    'Asia/Tokyo',
  ]) {
    test('12 Nov stays 12 Nov and 9 AM stays 9 AM in $zone', () async {
      final ({int step, int reminder}) s = await stepInDhaka();

      await repo.followZone(zone);

      expect(
        (await dueOn(s.step)).isAtSameMomentAs(clock(zone, 11, 12)),
        isTrue,
      );
      expect(
        (await remindAt(s.reminder)).isAtSameMomentAs(clock(zone, 11, 12, 9)),
        isTrue,
      );
    });
  }

  test('a clock change between the two dates is respected', () async {
    // Written in New York in October; the 12 Nov it means is after US summer
    // time ends, so a fixed shift would land an hour out.
    await repo.followZone('America/New_York');
    final int cardId = await card();
    final int step = await db
        .into(db.importantDates)
        .insert(
          ImportantDatesCompanion.insert(
            cardId: cardId,
            kind: DateKind.followUp,
            title: 'Call',
            dueOn: clock('America/New_York', 11, 12),
          ),
        );

    await repo.followZone('Europe/Paris');

    expect(
      (await dueOn(step)).isAtSameMomentAs(clock('Europe/Paris', 11, 12)),
      isTrue,
    );
  });

  test('the day a person was met moves with it', () async {
    final int cardId = await card();
    final int id = await db
        .into(db.encounters)
        .insert(
          EncountersCompanion.insert(
            cardId: cardId,
            metOn: Value<DateTime?>(clock('Asia/Dhaka', 10, 20)),
          ),
        );

    await repo.followZone('Asia/Dubai');

    final Encounter e = await (db.select(
      db.encounters,
    )..where(($EncountersTable t) => t.id.equals(id))).getSingle();
    expect(e.metOn!.isAtSameMomentAs(clock('Asia/Dubai', 10, 20)), isTrue);
  });

  test('there and back again reads the same', () async {
    final ({int step, int reminder}) s = await stepInDhaka();
    final DateTime due = await dueOn(s.step);
    final DateTime remind = await remindAt(s.reminder);

    await repo.followZone('America/Los_Angeles');
    await repo.followZone('Asia/Dhaka');

    expect((await dueOn(s.step)).isAtSameMomentAs(due), isTrue);
    expect((await remindAt(s.reminder)).isAtSameMomentAs(remind), isTrue);
  });

  test('two reconciles at once move a row only once', () async {
    final ({int step, int reminder}) s = await stepInDhaka();

    await Future.wait(<Future<void>>[
      repo.followZone('Asia/Dubai'),
      repo.followZone('Asia/Dubai'),
    ]);

    expect(
      (await dueOn(s.step)).isAtSameMomentAs(clock('Asia/Dubai', 11, 12)),
      isTrue,
    );
  });

  test('a snooze is a length of time, so it stays where it is', () async {
    final ({int step, int reminder}) s = await stepInDhaka(snoozes: 1);
    final DateTime before = await remindAt(s.reminder);

    await repo.followZone('Asia/Dubai');

    expect((await remindAt(s.reminder)).isAtSameMomentAs(before), isTrue);
  });

  test('a reminder already gone by does not come round again', () async {
    // 9 AM in Dhaka has passed. It is only 8 AM in Dubai, and carrying the
    // clock time across would put it ahead and fire it a second time.
    final ({int step, int reminder}) s = await stepInDhaka();
    now = clock('Asia/Dhaka', 11, 12, 10);

    await repo.followZone('Asia/Dubai');

    expect(
      (await remindAt(
        s.reminder,
      )).isAtSameMomentAs(clock('Asia/Dhaka', 11, 12, 9)),
      isTrue,
    );
  });

  test('a reminder that would fall behind keeps its moment', () async {
    // Still ahead in Dhaka; 9 AM in Tokyo has already gone.
    final ({int step, int reminder}) s = await stepInDhaka();
    now = clock('Asia/Dhaka', 11, 12, 8);

    await repo.followZone('Asia/Tokyo');

    expect(
      (await remindAt(
        s.reminder,
      )).isAtSameMomentAs(clock('Asia/Dhaka', 11, 12, 9)),
      isTrue,
    );
  });

  test('a zone it has never heard of changes nothing', () async {
    final ({int step, int reminder}) s = await stepInDhaka();
    final DateTime before = await dueOn(s.step);

    await repo.followZone('Mars/Olympus');

    expect((await dueOn(s.step)).isAtSameMomentAs(before), isTrue);
  });

  test('the engine carries the rows over before it schedules', () async {
    final ({int step, int reminder}) s = await stepInDhaka();
    final FakePort port = FakePort();
    final ReminderEngine engine = ReminderEngine(repo: repo, port: port);
    await engine.reconcile();
    expect(port.held.keys, <int>[s.reminder]);

    port.zone = 'Asia/Dubai';
    await engine.reconcile();

    expect(
      port.held[s.reminder]!.remindAt.isAtSameMomentAs(
        clock('Asia/Dubai', 11, 12, 9),
      ),
      isTrue,
    );
  });
}
