import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/primitives.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/followup/presentation/card_follow_up_blocks.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/router.dart';

import '../support/fake_notification_port.dart';
import '../support/fake_store.dart';
import '../support/play_fixtures.dart';

/// The free version keeps five reminders waiting; Plus has no limit.
///
/// At the limit the step sheet offers no Remind me switch — it could not
/// work — but says why and goes to Plus. These tap the sheet, so a switch
/// that rendered and did nothing would fail them.
void main() {
  late AppDatabase db;
  late MemoryGrants grants;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    grants = MemoryGrants();
  });
  tearDown(() async => db.close());

  Future<int> seed({required int reminders}) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/card.jpg',
            capturedAt: DateTime.now(),
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
    for (int i = 0; i < reminders; i++) {
      await FollowUpRepository(db).addStep(
        cardId: id,
        title: 'Step ${i + 1}',
        dueOn: DateTime.now().add(Duration(days: i + 2)),
        remindAt: DateTime.now().add(Duration(days: i + 2)),
      );
    }
    return id;
  }

  Future<void> pump(WidgetTester tester, int cardId) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(child: NextStepsBlock(cardId: cardId)),
          ),
        ),
        GoRoute(
          path: Routes.plus,
          builder: (_, _) => const Scaffold(body: Text('plus screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          notificationPortProvider.overrideWithValue(
            FakePort()..allowed = true,
          ),
          storePortProvider.overrideWithValue(FakeStore()),
          grantStoreProvider.overrideWithValue(grants),
          playKeyProvider.overrideWithValue(testPlayKey),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('with five waiting, a sixth is not offered — Plus is', (
    WidgetTester tester,
  ) async {
    final int id = await seed(reminders: kFreeReminders);
    await pump(tester, id);

    await tapText(tester, 'Add another step');
    expect(find.text("What's the next step?"), findsOneWidget);
    expect(find.byType(AppSwitch), findsNothing);
    expect(
      find.textContaining('All 5 free reminders are waiting'),
      findsOneWidget,
    );

    await tapText(tester, 'No limit with RecallOS Plus');
    expect(find.text('plus screen'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('with four waiting, the fifth is still free', (
    WidgetTester tester,
  ) async {
    final int id = await seed(reminders: kFreeReminders - 1);
    await pump(tester, id);

    await tapText(tester, 'Add another step');
    expect(find.byType(AppSwitch), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a step that already has a reminder keeps it at the limit', (
    WidgetTester tester,
  ) async {
    final int id = await seed(reminders: kFreeReminders);
    await pump(tester, id);

    await tapText(tester, 'Step 1');
    expect(find.text('Remind me'), findsOneWidget);
    expect(find.byType(AppSwitch), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('with Plus there is no limit', (WidgetTester tester) async {
    grants.kept = (originalJson: plusReceipt, signature: plusSignature);
    final int id = await seed(reminders: kFreeReminders + 2);
    await pump(tester, id);

    await tapText(tester, 'Add another step');
    expect(find.byType(AppSwitch), findsOneWidget);
    expect(find.textContaining('free reminders'), findsNothing);
    await unmount(tester);
  });
}
