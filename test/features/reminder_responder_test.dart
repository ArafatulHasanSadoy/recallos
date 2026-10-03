import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/followup/presentation/reminder_responder.dart';

import '../support/fake_notification_port.dart';

/// Android's reminders follow the database whoever changes it.
///
/// Found on the phone: deleting a card from its own screen left its reminders
/// scheduled, because the card screen's delete is card code and never went
/// near the reminder engine. These tests change the database the way card
/// code does — directly, with no follow-up layer involved — and check what
/// Android is left holding.
void main() {
  late AppDatabase db;
  late FakePort port;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    port = FakePort()..allowed = true;
  });
  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationPortProvider.overrideWithValue(port),
        ],
        child: const ReminderResponder(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
  }

  /// Lets the change notification and the settle timer run, and the reconcile
  /// behind them finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('a card deleted by card code takes its reminder off Android',
      (WidgetTester tester) async {
    await pump(tester);

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
            value: 'Bengal Event Solutions',
            source: FactSource.printed,
          ),
        );
    await FollowUpRepository(db).addStep(
      cardId: id,
      title: 'Call about the stage',
      dueOn: DateTime.now().add(const Duration(days: 2)),
      remindAt: DateTime.now().add(const Duration(days: 2)),
    );
    await settle(tester);
    expect(port.held, hasLength(1),
        reason: 'a reminder written without the follow-up layer is scheduled');

    // What the card screen's trash button does: card code only.
    await CardRepository(db).softDelete(id);
    await settle(tester);
    expect(port.held, isEmpty,
        reason: 'a deleted card must not go on reminding');

    await CardRepository(db).restore(id);
    await settle(tester);
    expect(port.held, hasLength(1), reason: 'restored, it is re-armed');

    // Delete for good: the cascade removes the reminder rows themselves.
    await CardRepository(db).purge(id);
    await settle(tester);
    expect(port.held, isEmpty);
    await unmount(tester);
  });
}
