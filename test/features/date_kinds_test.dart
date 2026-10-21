import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';

/// `important_dates` holds more than next steps once warranties arrive (B3):
/// a warranty's expiry is a date with a reminder, but it is not something the
/// user said they would do. Android must still hold its reminder; the card,
/// Today and the free limit must not count it as a step.
void main() {
  late AppDatabase db;
  late FollowUpRepository repo;
  final DateTime now = DateTime(2026, 10, 8, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FollowUpRepository(db, now: () => now);
  });
  tearDown(() async => db.close());

  Future<int> seed() async {
    final int card = await db
        .into(db.cards)
        .insert(CardsCompanion.insert(imagePath: '/x.jpg', capturedAt: now));
    await repo.addStep(
      cardId: card,
      title: 'Send the quotation',
      dueOn: DateTime(2026, 10, 10),
      remindAt: DateTime(2026, 10, 10, 9),
    );
    final int warranty = await db
        .into(db.importantDates)
        .insert(
          ImportantDatesCompanion.insert(
            cardId: card,
            kind: DateKind.warrantyExpiry,
            title: 'Laptop warranty ends',
            dueOn: DateTime(2028, 10, 8),
          ),
        );
    await db
        .into(db.reminders)
        .insert(
          RemindersCompanion.insert(
            importantDateId: warranty,
            remindAt: DateTime(2028, 9, 8, 9),
          ),
        );
    return card;
  }

  test('the card lists only next steps', () async {
    final int card = await seed();
    final List<NextStep> steps = await repo.watchOpenSteps(card).first;
    expect(steps.map((NextStep s) => s.date.title), <String>[
      'Send the quotation',
    ]);
  });

  test('Today lists only next steps', () async {
    await seed();
    final List<TodayEntry> today = await repo.watchOpen().first;
    expect(today.map((TodayEntry e) => e.step.title), <String>[
      'Send the quotation',
    ]);
  });

  test(
    'Android holds both reminders; only the step uses a free place',
    () async {
      await seed();
      final List<PendingReminder> held = await repo.pendingReminders();
      expect(
        held.map((PendingReminder r) => r.kind),
        unorderedEquals(<DateKind>[DateKind.followUp, DateKind.warrantyExpiry]),
      );
      expect(await repo.activeReminderCount(), 1);
    },
  );
}
