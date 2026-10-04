import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/followup/data/follow_up_actions.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';

import '../support/fake_notification_port.dart';

/// Android holds exactly the reminders that are still due — after an add, a
/// finish, a snooze, a deleted card, or anything else — because every change
/// ends in the same reconcile.
void main() {
  late AppDatabase db;
  late FakePort port;
  late FollowUpRepository repo;
  late ReminderEngine engine;
  late FollowUpActions actions;
  DateTime now = DateTime(2026, 10, 1, 10, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    port = FakePort();
    now = DateTime(2026, 10, 1, 10, 30);
    repo = FollowUpRepository(db, now: () => now);
    engine = ReminderEngine(repo: repo, port: port);
    actions = FollowUpActions(repo: repo, engine: engine, now: () => now);
  });
  tearDown(() async => db.close());

  Future<int> card(String company) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/cards/x.jpg',
            capturedAt: DateTime(2026, 9, 28),
          ),
        );
    await db
        .into(db.cardFields)
        .insert(
          CardFieldsCompanion.insert(
            cardId: id,
            fieldKey: FieldKeys.company,
            value: company,
            source: FactSource.printed,
          ),
        );
    return id;
  }

  test('a step is scheduled at the reminder time the sheet showed', () async {
    final int id = await card('Test Card Printing Ltd');
    final bool ok = await actions.addStep(id, (
      title: 'Send sponsorship proposal',
      dueOn: DateTime(2026, 10, 2),
      remindAt: DateTime(2026, 10, 2, 9),
      remove: false,
    ));

    expect(ok, isTrue);
    final PendingReminder held = port.held.values.single;
    expect(held.remindAt, DateTime(2026, 10, 2, 9));
    expect(held.stepTitle, 'Send sponsorship proposal');
    expect(held.cardTitle, 'Test Card Printing Ltd');
  });

  test(
    'permission is asked the first time a reminder is wanted, not before',
    () async {
      final int id = await card('Padma Soft Ltd');
      await actions.addStep(id, (
        title: 'No reminder here',
        dueOn: DateTime(2026, 10, 2),
        remindAt: null,
        remove: false,
      ));
      expect(port.asked, 0, reason: 'a step without a reminder asks nothing');

      await actions.addStep(id, (
        title: 'Remind me',
        dueOn: DateTime(2026, 10, 3),
        remindAt: DateTime(2026, 10, 3, 9),
        remove: false,
      ));
      expect(port.asked, 1);

      await actions.addStep(id, (
        title: 'And me',
        dueOn: DateTime(2026, 10, 4),
        remindAt: DateTime(2026, 10, 4, 9),
        remove: false,
      ));
      expect(port.asked, 1, reason: 'once granted, never asked again');
    },
  );

  test('a refused permission still saves the step, and says so', () async {
    port.grantOnAsk = false;
    final int id = await card('Padma Soft Ltd');
    final bool ok = await actions.addStep(id, (
      title: 'Send CVs',
      dueOn: DateTime(2026, 10, 2),
      remindAt: DateTime(2026, 10, 2, 9),
      remove: false,
    ));
    expect(ok, isFalse);
    expect(await repo.watchOpenSteps(id).first, hasLength(1));
  });

  test('finishing a step takes its notification away', () async {
    final int id = await card('Padma Soft Ltd');
    await actions.addStep(id, (
      title: 'Send CVs',
      dueOn: DateTime(2026, 10, 2),
      remindAt: DateTime(2026, 10, 2, 9),
      remove: false,
    ));
    final int step = (await repo.watchOpenSteps(id).first).single.date.id;

    await actions.complete(step);
    expect(port.held, isEmpty);

    await actions.reopen(step);
    expect(port.held, hasLength(1));
  });

  test(
    'removing a step from the edit sheet takes its notification away',
    () async {
      final int id = await card('Padma Soft Ltd');
      await actions.addStep(id, (
        title: 'Send CVs',
        dueOn: DateTime(2026, 10, 2),
        remindAt: DateTime(2026, 10, 2, 9),
        remove: false,
      ));
      final int step = (await repo.watchOpenSteps(id).first).single.date.id;

      await actions.editStep(step, (
        title: 'Send CVs',
        dueOn: DateTime(2026, 10, 2),
        remindAt: DateTime(2026, 10, 2, 9),
        remove: true,
      ));
      expect(port.held, isEmpty);
      expect(await repo.watchOpenSteps(id).first, isEmpty);
    },
  );

  test(
    'a reminder time that went by while the sheet stood open is renewed',
    () async {
      final int id = await card('Padma Soft Ltd');
      // The sheet said 9 AM; it was saved at 10:30. A time in the past would
      // never fire, so the usual "an hour from now" is used instead.
      await actions.addStep(id, (
        title: 'Send CVs',
        dueOn: DateTime(2026, 10, 1),
        remindAt: DateTime(2026, 10, 1, 9),
        remove: false,
      ));
      expect(port.held.values.single.remindAt, DateTime(2026, 10, 1, 11, 30));
    },
  );

  test('snooze reschedules the same notification an hour out', () async {
    final int id = await card('Padma Soft Ltd');
    await actions.addStep(id, (
      title: 'Send CVs',
      dueOn: DateTime(2026, 10, 2),
      remindAt: DateTime(2026, 10, 2, 9),
      remove: false,
    ));
    final int reminderId = port.held.keys.single;

    now = DateTime(2026, 10, 2, 9, 1);
    await actions.snooze(reminderId, const Duration(hours: 1));
    expect(port.held.keys.single, reminderId, reason: 'replaced, not added');
    expect(port.held[reminderId]!.remindAt, DateTime(2026, 10, 2, 10, 1));
  });

  test('reconcile drops what the database no longer wants', () async {
    // Something Android is holding that the database never asked for — a
    // step deleted on another screen, or a reminder from before a restore.
    port.held[999] = PendingReminder(
      id: 999,
      stepId: 1,
      cardId: 1,
      remindAt: DateTime(2026, 10, 5, 9),
      stepTitle: 'Stale',
      cardTitle: 'Gone',
    );
    final int id = await card('Old Town Garments Ltd');
    await actions.addStep(id, (
      title: 'Return samples',
      dueOn: DateTime(2026, 10, 2),
      remindAt: DateTime(2026, 10, 2, 9),
      remove: false,
    ));
    expect(port.held.keys, isNot(contains(999)));

    // A deleted card goes quiet on the next reconcile.
    await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
        .write(CardsCompanion(deletedAt: Value<DateTime?>(now)));
    await engine.reconcile();
    expect(port.held, isEmpty);
    expect(
      port.prepared,
      greaterThan(0),
      reason: 'the time zone is refreshed on every reconcile',
    );
  });

  test('a reconcile that fails leaves the app running', () async {
    final ReminderEngine broken = ReminderEngine(
      repo: repo,
      port: _ThrowingPort(),
    );
    await broken.reconcile();
    expect(await broken.ensurePermission(), isFalse);
  });
}

class _ThrowingPort implements NotificationPort {
  @override
  Future<void> prepare() => throw StateError('no plugin');
  @override
  Future<bool> enabled() => throw StateError('no plugin');
  @override
  Future<bool> requestPermission() => throw StateError('no plugin');
  @override
  Future<Set<int>> scheduledIds() => throw StateError('no plugin');
  @override
  Future<void> schedule(PendingReminder r) => throw StateError('no plugin');
  @override
  Future<void> cancel(int id) => throw StateError('no plugin');
  @override
  Future<bool> openSettings() => throw StateError('no plugin');
}
