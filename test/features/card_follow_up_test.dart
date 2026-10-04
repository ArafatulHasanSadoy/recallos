import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';
import 'package:recallos/features/followup/data/follow_up_actions.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/followup/presentation/card_follow_up_blocks.dart';

import '../support/fake_notification_port.dart';

/// A1 on the card: what to do next, and where you met.
///
/// These tap the screen the way a person does. An assertion that the
/// repository *can* store a step would pass on a screen whose Save did
/// nothing, which is the bug this class of test exists to catch.
void main() {
  late AppDatabase db;
  late FakePort port;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    port = FakePort();
  });
  tearDown(() async => db.close());

  Future<int> seed() async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/card.jpg',
            capturedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        );
    await db
        .into(db.cardFields)
        .insert(
          CardFieldsCompanion.insert(
            cardId: id,
            fieldKey: FieldKeys.company,
            value: 'Test Card Printing Ltd',
            source: FactSource.printed,
          ),
        );
    return id;
  }

  Future<void> pump(WidgetTester tester, int cardId) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationPortProvider.overrideWithValue(port),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CardDetailScreen(cardId: cardId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    // A tap target's label merges with the text around it ("NEXT STEP | Add a
    // next step | Nothing planned…"), so match it anywhere in the node.
    final Finder f = find.bySemanticsLabel(RegExp(RegExp.escape(label)));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> addStep(WidgetTester tester, String title) async {
    await tapLabel(tester, 'Add a next step');
    expect(find.text("What's the next step?"), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, title);
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
  }

  testWidgets('a next step is added from the card, with its day and reminder', (
    WidgetTester tester,
  ) async {
    port.allowed = true;
    final int id = await seed();
    await pump(tester, id);

    await addStep(tester, 'Send sponsorship proposal');

    expect(find.text('Send sponsorship proposal'), findsOneWidget);
    expect(find.text('Due tomorrow'), findsOneWidget);
    expect(find.text('Reminder 9 AM tomorrow'), findsOneWidget);
    expect(port.held, hasLength(1), reason: 'Android holds the reminder');
    expect(port.asked, 0, reason: 'already allowed, so nothing to ask');
    await unmount(tester);
  });

  testWidgets('Done clears the step and its reminder; Undo brings both back', (
    WidgetTester tester,
  ) async {
    port.allowed = true;
    final int id = await seed();
    await pump(tester, id);
    await addStep(tester, 'Send sponsorship proposal');

    await tapLabel(tester, 'Mark done: Send sponsorship proposal');
    expect(find.text('Send sponsorship proposal'), findsNothing);
    expect(port.held, isEmpty);
    expect(find.text('Done: Send sponsorship proposal'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Send sponsorship proposal'), findsOneWidget);
    expect(port.held, hasLength(1));
    await unmount(tester);
  });

  testWidgets(
    'with notifications off, the notice opens the settings to fix it',
    (WidgetTester tester) async {
      port.grantOnAsk = false;
      final int id = await seed();
      await pump(tester, id);

      await addStep(tester, 'Call about the stall');

      expect(port.asked, 1, reason: 'asked when the first reminder is set');
      expect(
        find.text('Call about the stall'),
        findsOneWidget,
        reason: 'the step is kept even though it cannot notify',
      );
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(port.settingsOpened, 1);
      await unmount(tester);
    },
  );

  testWidgets(
    'a step marked done can still be found and brought back after Undo is gone',
    (WidgetTester tester) async {
      // Found on the phone: two steps vanished from a card overnight, and
      // past the snackbar's few seconds there was no way to see when or to
      // get them back.
      port.allowed = true;
      final int id = await seed();
      await pump(tester, id);
      await addStep(tester, 'Send sponsorship proposal');

      await tapLabel(tester, 'Mark done: Send sponsorship proposal');
      // Let the snackbar and its Undo go by.
      ScaffoldMessenger.of(
        tester.element(find.byType(NextStepsBlock)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text('Send sponsorship proposal'), findsNothing);
      expect(port.held, isEmpty);

      await tester.tap(find.text('Finished recently (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Send sponsorship proposal'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Done .* at ')), findsOneWidget);

      await tester.tap(find.text('Bring back'));
      await tester.pumpAndSettle();
      expect(find.text('Finished recently (1)'), findsNothing);
      expect(find.text('Hide finished steps'), findsNothing);
      expect(find.text('Due tomorrow'), findsOneWidget, reason: 'open again');
      expect(port.held, hasLength(1), reason: 'its reminder is back too');
      await unmount(tester);
    },
  );

  testWidgets('a removed step says so, and comes back the same way', (
    WidgetTester tester,
  ) async {
    port.allowed = true;
    final int id = await seed();
    await pump(tester, id);
    await addStep(tester, 'Call about the stall');

    await tapLabel(tester, 'Call about the stall. Due tomorrow. Edit');
    await tester.tap(find.text('Remove this step'));
    await tester.pumpAndSettle();
    expect(find.text('Call about the stall'), findsNothing);

    await tester.tap(find.text('Finished recently (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^Removed .* at ')), findsOneWidget);
    await tester.tap(find.text('Bring back'));
    await tester.pumpAndSettle();
    expect(find.text('Call about the stall'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('where you met is saved only when the user saves it', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    await pump(tester, id);

    // Cancel first: nothing may be stored, the suggestion included.
    await tapLabel(tester, 'Add where you met');
    await tester.enterText(find.byType(TextField).last, 'CSE fest at NSU');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(
        () => FollowUpRepository(db).watchEncounter(id).first,
      ),
      isNull,
    );

    await tapLabel(tester, 'Add where you met');
    await tester.enterText(find.byType(TextField).last, 'CSE fest at NSU');
    await tester.tap(find.textContaining('Day I scanned it'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('CSE fest at NSU'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^on ')), findsOneWidget);
    final Encounter? e = await tester.runAsync<Encounter?>(
      () => FollowUpRepository(db).watchEncounter(id).first,
    );
    final DateTime scanned = DateTime.now().subtract(const Duration(days: 2));
    expect(e!.metOn, DateTime(scanned.year, scanned.month, scanned.day));
    expect(e.place, 'CSE fest at NSU');
    await unmount(tester);
  });

  testWidgets('a step with no words is not saved blank', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    await pump(tester, id);

    await tapLabel(tester, 'Add a next step');
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();

    expect(find.text('Write what the step is first.'), findsOneWidget);
    expect(
      find.text("What's the next step?"),
      findsOneWidget,
      reason: 'the sheet stays open to be finished',
    );
    await unmount(tester);
  });
  group('the reminder time the sheet shows is the one saved', () {
    // Found on the phone: the sheet said "10:20 PM today" and Android was
    // given 10:25, because the sheet worked the time out when it was drawn
    // and the save worked it out again a minute later, across a five-minute
    // mark. These hold a clock still and then move it, as a person does by
    // taking a minute to type.
    DateTime clock = DateTime(2026, 10, 3, 21, 24, 50);

    Future<void> pumpBlock(WidgetTester tester, int cardId) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notificationPortProvider.overrideWithValue(port),
            followUpRepositoryProvider.overrideWithValue(
              FollowUpRepository(db, now: () => clock),
            ),
            followUpActionsProvider.overrideWith(
              (Ref ref) => FollowUpActions(
                repo: ref.watch(followUpRepositoryProvider),
                engine: ref.watch(reminderEngineProvider),
                now: () => clock,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: NextStepsBlock(cardId: cardId, now: () => clock),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> addForToday(WidgetTester tester, String title) async {
      await tapLabel(tester, 'Add a next step');
      await tester.enterText(find.byType(TextField).last, title);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
    }

    setUp(() {
      port.allowed = true;
      clock = DateTime(2026, 10, 3, 21, 24, 50);
    });

    testWidgets('a save that crosses a five-minute mark keeps the shown time', (
      WidgetTester tester,
    ) async {
      final int id = await seed();
      await pumpBlock(tester, id);

      await addForToday(tester, 'Call about the stage');
      expect(find.text('A notification at 10:20 PM today'), findsOneWidget);

      clock = DateTime(2026, 10, 3, 21, 25, 10);
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();

      expect(find.text('Reminder 10:20 PM today'), findsOneWidget);
      expect(port.held.values.single.remindAt, DateTime(2026, 10, 3, 22, 20));
      await unmount(tester);
    });

    testWidgets('correcting the words keeps a snoozed reminder where it is', (
      WidgetTester tester,
    ) async {
      final int id = await seed();
      await pumpBlock(tester, id);
      await addForToday(tester, 'Call about the stage');
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();

      // "Snooze 1 hour" from the notification, as it fires at 22:20.
      clock = DateTime(2026, 10, 3, 22, 20, 30);
      await FollowUpRepository(
        db,
        now: () => clock,
      ).snooze(port.held.keys.single, const Duration(hours: 1));
      await tester.pumpAndSettle();
      expect(find.text('Reminder 11:20 PM today'), findsOneWidget);

      clock = DateTime(2026, 10, 3, 22, 31);
      await tapLabel(tester, 'Call about the stage. Due today. Edit');
      expect(
        find.text('A notification at 11:20 PM today'),
        findsOneWidget,
        reason: 'the sheet shows the reminder the step has, not a new one',
      );
      await tester.enterText(
        find.byType(TextField).last,
        'Call Nusrat about the stage',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Call Nusrat about the stage'), findsOneWidget);
      expect(find.text('Reminder 11:20 PM today'), findsOneWidget);

      // A new day is a new reminder: that day's usual time.
      await tapLabel(tester, 'Call Nusrat about the stage. Due today. Edit');
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      expect(find.text('A notification at 9 AM tomorrow'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Reminder 9 AM tomorrow'), findsOneWidget);
      await unmount(tester);
    });
  });
}
