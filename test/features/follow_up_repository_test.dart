// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';

/// Where you met someone, what you said you would do next, and when Android
/// should remind you.
///
/// The rules these pin are the ones a screen cannot show is broken: nothing is
/// stored that the user did not give, a finished step stops reminding, a
/// deleted card's steps go quiet and come back with it, and "today" means
/// today when it is read, not when the row was written.
void main() {
  late AppDatabase db;
  late FollowUpRepository repo;
  DateTime now = DateTime(2026, 10, 1, 10, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 1, 10, 30);
    repo = FollowUpRepository(db, now: () => now);
  });
  tearDown(() async => db.close());

  Future<int> card({
    String? company,
    String? person,
    bool deleted = false,
  }) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/cards/x.jpg',
            capturedAt: DateTime(2026, 9, 28),
            deletedAt: Value<DateTime?>(deleted ? DateTime(2026, 9, 30) : null),
          ),
        );
    Future<void> put(String key, String? value) async {
      if (value == null) return;
      await db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: key,
              value: value,
              source: FactSource.printed,
            ),
          );
    }

    await put(FieldKeys.company, company);
    await put(FieldKeys.personName, person);
    return id;
  }

  group('where you met', () {
    test('a new card has no encounter: nothing is assumed', () async {
      final int id = await card(company: 'Padma Soft Ltd');
      expect(await repo.watchEncounter(id).first, isNull);
    });

    test('is saved as given, corrected in place, and cleared', () async {
      final int id = await card(company: 'Bengal Event Solutions');

      await repo.setEncounter(
        cardId: id,
        metOn: DateTime(2026, 9, 12, 18, 45),
        place: '  CSE fest,   NSU ',
      );
      Encounter? e = await repo.watchEncounter(id).first;
      expect(e!.metOn, DateTime(2026, 9, 12), reason: 'a day, not a time');
      expect(e.place, 'CSE fest, NSU');
      expect(e.origin, EncounterOrigin.user);

      await repo.setEncounter(cardId: id, place: 'Tech expo, Bashundhara');
      e = await repo.watchEncounter(id).first;
      expect(e!.metOn, isNull, reason: 'clearing the day clears it');
      expect(e.place, 'Tech expo, Bashundhara');
      expect(
        await db.select(db.encounters).get(),
        hasLength(1),
        reason: 'one encounter per card, corrected in place',
      );

      await repo.setEncounter(cardId: id, place: '   ');
      expect(await repo.watchEncounter(id).first, isNull);
      expect(await db.select(db.encounters).get(), isEmpty);
    });
  });

  group('next steps', () {
    test(
      'a step with a reminder is open, and the reminder is pending',
      () async {
        final int id = await card(
          company: 'Test Card Printing Ltd',
          person: 'Rahim Ahmed',
        );
        final int step = await repo.addStep(
          cardId: id,
          title: 'Send sponsorship proposal',
          dueOn: DateTime(2026, 10, 2, 15),
          remindAt: DateTime(2026, 10, 2, 9),
        );

        final List<NextStep> open = await repo.watchOpenSteps(id).first;
        expect(open.single.date.title, 'Send sponsorship proposal');
        expect(open.single.date.dueOn, DateTime(2026, 10, 2));
        expect(open.single.reminder!.remindAt, DateTime(2026, 10, 2, 9));

        final List<PendingReminder> pending = await repo.pendingReminders();
        expect(pending.single.stepId, step);
        expect(pending.single.cardTitle, 'Test Card Printing Ltd');
      },
    );

    test('an empty title is refused rather than saved blank', () async {
      final int id = await card(company: 'X');
      expect(
        () => repo.addStep(cardId: id, title: '   ', dueOn: now),
        throwsArgumentError,
      );
    });

    test(
      'done stops the reminder; undo brings back only one still ahead',
      () async {
        final int id = await card(company: 'Padma Soft Ltd');
        final int ahead = await repo.addStep(
          cardId: id,
          title: 'Call about internship',
          dueOn: DateTime(2026, 10, 5),
          remindAt: DateTime(2026, 10, 5, 9),
        );

        await repo.complete(ahead);
        expect(await repo.watchOpenSteps(id).first, isEmpty);
        expect(
          await repo.pendingReminders(),
          isEmpty,
          reason: 'a finished step must not keep reminding',
        );
        final ImportantDate done = await (db.select(
          db.importantDates,
        )..where(($ImportantDatesTable d) => d.id.equals(ahead))).getSingle();
        expect(done.status, DateStatus.done);
        expect(done.completedAt, now);

        await repo.reopen(ahead);
        expect(await repo.pendingReminders(), hasLength(1));

        // A step whose reminder time has already gone by is reopened quietly.
        final int past = await repo.addStep(
          cardId: id,
          title: 'Old one',
          dueOn: DateTime(2026, 10, 1),
          remindAt: DateTime(2026, 10, 1, 11),
        );
        await repo.complete(past);
        now = DateTime(2026, 10, 1, 12);
        await repo.reopen(past);
        expect(
          (await repo.pendingReminders()).map((PendingReminder r) => r.stepId),
          isNot(contains(past)),
          reason: 'rescheduling a passed time would fire it at once',
        );
      },
    );

    test('a dropped step is kept as dismissed, never as done', () async {
      final int id = await card(company: 'Padma Soft Ltd');
      final int step = await repo.addStep(
        cardId: id,
        title: 'Maybe visit office',
        dueOn: DateTime(2026, 10, 3),
      );
      await repo.dismiss(step);
      final ImportantDate row = await (db.select(
        db.importantDates,
      )..where(($ImportantDatesTable d) => d.id.equals(step))).getSingle();
      expect(row.status, DateStatus.dismissed);
      expect(row.completedAt, isNull);
      expect(await repo.watchOpenSteps(id).first, isEmpty);
    });

    test('editing can remove the reminder and keep the step', () async {
      final int id = await card(company: 'Padma Soft Ltd');
      final int step = await repo.addStep(
        cardId: id,
        title: 'Send CVs',
        dueOn: DateTime(2026, 10, 4),
        remindAt: DateTime(2026, 10, 4, 9),
      );
      await repo.editStep(
        step,
        title: 'Send three CVs',
        dueOn: DateTime(2026, 10, 6),
      );
      final NextStep s = (await repo.watchOpenSteps(id).first).single;
      expect(s.date.title, 'Send three CVs');
      expect(s.date.dueOn, DateTime(2026, 10, 6));
      expect(s.reminder, isNull);
      expect(await repo.pendingReminders(), isEmpty);
    });

    test(
      'a new reminder time replaces the old one instead of adding a second',
      () async {
        final int id = await card(company: 'Padma Soft Ltd');
        final int step = await repo.addStep(
          cardId: id,
          title: 'Send CVs',
          dueOn: DateTime(2026, 10, 4),
          remindAt: DateTime(2026, 10, 4, 9),
        );
        await repo.editStep(
          step,
          title: 'Send CVs',
          dueOn: DateTime(2026, 10, 4),
          remindAt: DateTime(2026, 10, 3, 9),
        );
        final List<PendingReminder> pending = await repo.pendingReminders();
        expect(pending.single.remindAt, DateTime(2026, 10, 3, 9));
      },
    );

    test('snooze moves the reminder, never the due day', () async {
      final int id = await card(company: 'Padma Soft Ltd');
      await repo.addStep(
        cardId: id,
        title: 'Send CVs',
        dueOn: DateTime(2026, 10, 1),
        remindAt: DateTime(2026, 10, 1, 11),
      );
      final int reminderId = (await repo.pendingReminders()).single.id;

      await repo.snooze(reminderId, const Duration(hours: 1));

      final Reminder r = await (db.select(
        db.reminders,
      )..where(($RemindersTable t) => t.id.equals(reminderId))).getSingle();
      expect(r.remindAt, now.add(const Duration(hours: 1)));
      expect(r.snoozeCount, 1);
      expect(
        (await repo.watchOpenSteps(id).first).single.date.dueOn,
        DateTime(2026, 10, 1),
      );
    });
  });

  group('today', () {
    test(
      'splits overdue, today and upcoming against the day it is read',
      () async {
        final int id = await card(
          company: 'Spice Route Catering',
          person: 'Farzana Akter',
        );
        await repo.addStep(
          cardId: id,
          title: 'Late',
          dueOn: DateTime(2026, 9, 29),
        );
        await repo.addStep(
          cardId: id,
          title: 'Now',
          dueOn: DateTime(2026, 10, 1, 23),
        );
        await repo.addStep(
          cardId: id,
          title: 'Soon',
          dueOn: DateTime(2026, 10, 9),
        );

        final List<TodayEntry> open = await repo.watchOpen().first;
        TodayView view = TodayView.split(open, now);
        expect(view.overdue.map((TodayEntry e) => e.step.title), <String>[
          'Late',
        ]);
        expect(view.today.map((TodayEntry e) => e.step.title), <String>['Now']);
        expect(view.upcoming.map((TodayEntry e) => e.step.title), <String>[
          'Soon',
        ]);
        expect(view.today.single.title, 'Spice Route Catering');
        expect(view.today.single.person, 'Farzana Akter');

        // The next morning the same rows read differently, with no write.
        view = TodayView.split(open, DateTime(2026, 10, 2, 8));
        expect(view.overdue.map((TodayEntry e) => e.step.title), <String>[
          'Late',
          'Now',
        ]);
      },
    );

    test("a deleted card's steps go quiet and come back on restore", () async {
      final int id = await card(company: 'Old Town Garments Ltd');
      await repo.addStep(
        cardId: id,
        title: 'Return samples',
        dueOn: DateTime(2026, 10, 2),
        remindAt: DateTime(2026, 10, 2, 9),
      );

      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
          .write(CardsCompanion(deletedAt: Value<DateTime?>(now)));
      expect(await repo.watchOpen().first, isEmpty);
      expect(await repo.pendingReminders(), isEmpty);

      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
          .write(const CardsCompanion(deletedAt: Value<DateTime?>(null)));
      expect(await repo.watchOpen().first, hasLength(1));
      expect(await repo.pendingReminders(), hasLength(1));
    });

    test('purging a card takes its encounter, steps and reminders', () async {
      final int id = await card(company: 'Old Town Garments Ltd');
      await repo.setEncounter(cardId: id, place: 'Lalbagh');
      await repo.addStep(
        cardId: id,
        title: 'Return samples',
        dueOn: DateTime(2026, 10, 2),
        remindAt: DateTime(2026, 10, 2, 9),
      );

      await (db.delete(
        db.cards,
      )..where(($CardsTable c) => c.id.equals(id))).go();

      expect(await db.select(db.encounters).get(), isEmpty);
      expect(await db.select(db.importantDates).get(), isEmpty);
      expect(await db.select(db.reminders).get(), isEmpty);
    });
  });
}
