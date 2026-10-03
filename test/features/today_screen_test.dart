import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/followup/presentation/today_screen.dart';

import '../support/fake_notification_port.dart';

/// Today: overdue first, then today, then upcoming, then review work — split
/// against the clock when the screen is drawn.
void main() {
  late AppDatabase db;
  late FakePort port;
  final DateTime now = DateTime(2026, 10, 1, 10, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    port = FakePort()..allowed = true;
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

  Future<void> pump(WidgetTester tester) async {
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
          home: TodayScreen(now: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// Where [text] sits on screen. The last match, because the screen's own
  /// header also says TODAY above the section of that name.
  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text).last).dy;

  testWidgets('overdue comes first, then today, then upcoming', (
    WidgetTester tester,
  ) async {
    final FollowUpRepository repo = FollowUpRepository(db, now: () => now);
    await tester.runAsync(() async {
      final int a = await card('Spice Route Catering');
      final int b = await card('Padma Soft Ltd');
      await repo.addStep(
        cardId: b,
        title: 'Send CVs',
        dueOn: DateTime(2026, 10, 6),
      );
      await repo.addStep(
        cardId: a,
        title: 'Confirm menu',
        dueOn: DateTime(2026, 10, 1),
      );
      await repo.addStep(
        cardId: a,
        title: 'Pay advance',
        dueOn: DateTime(2026, 9, 29),
      );
    });
    await pump(tester);

    expect(top(tester, 'OVERDUE'), lessThan(top(tester, 'TODAY')));
    expect(top(tester, 'TODAY'), lessThan(top(tester, 'UPCOMING')));
    expect(top(tester, 'Pay advance'), lessThan(top(tester, 'Confirm menu')));
    expect(top(tester, 'Confirm menu'), lessThan(top(tester, 'Send CVs')));
    expect(
      find.text('Overdue since Tue, 29 Sep'),
      findsOneWidget,
      reason: 'overdue is said in words, not only coloured',
    );
    await unmount(tester);
  });

  testWidgets('Done on Today finishes the step', (WidgetTester tester) async {
    final FollowUpRepository repo = FollowUpRepository(db, now: () => now);
    await tester.runAsync(() async {
      final int a = await card('Spice Route Catering');
      await repo.addStep(
        cardId: a,
        title: 'Confirm menu',
        dueOn: DateTime(2026, 10, 1),
      );
    });
    await pump(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('Mark done: Confirm menu')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm menu'), findsNothing);
    expect(find.text('Nothing due'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'with reminders set and notifications off, the row turns them on',
    (WidgetTester tester) async {
      port.allowed = false;
      final FollowUpRepository repo = FollowUpRepository(db, now: () => now);
      await tester.runAsync(() async {
        final int a = await card('Spice Route Catering');
        await repo.addStep(
          cardId: a,
          title: 'Confirm menu',
          dueOn: DateTime(2026, 10, 2),
          remindAt: DateTime(2026, 10, 2, 9),
        );
      });
      await pump(tester);

      expect(find.text('Reminders are off'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(port.settingsOpened, 1);
      await unmount(tester);
    },
  );

  testWidgets('with notifications on, there is nothing to turn on', (
    WidgetTester tester,
  ) async {
    final FollowUpRepository repo = FollowUpRepository(db, now: () => now);
    await tester.runAsync(() async {
      final int a = await card('Spice Route Catering');
      await repo.addStep(
        cardId: a,
        title: 'Confirm menu',
        dueOn: DateTime(2026, 10, 2),
        remindAt: DateTime(2026, 10, 2, 9),
      );
    });
    await pump(tester);
    expect(find.text('Reminders are off'), findsNothing);
    expect(find.textContaining('reminder 9 AM tomorrow'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('nothing due says so', (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Nothing due'), findsOneWidget);
    await unmount(tester);
  });
}
