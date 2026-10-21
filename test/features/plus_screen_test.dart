import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/features/plus/data/store_port.dart';
import 'package:recallos/features/plus/presentation/plus_screen.dart';
import 'package:recallos/router.dart';

import '../support/fake_store.dart';
import '../support/play_fixtures.dart';

/// The purchase screen: Play's price, one button that works, and no button
/// at all where it could not.
void main() {
  late FakeStore store;
  late MemoryGrants grants;

  setUp(() {
    store = FakeStore();
    grants = MemoryGrants();
  });

  Future<void> pump(WidgetTester tester, {String key = testPlayKey}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          storePortProvider.overrideWithValue(store),
          grantStoreProvider.overrideWithValue(grants),
          playKeyProvider.overrideWithValue(key),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PlusScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the price is Play's, and buying turns Plus on", (
    WidgetTester tester,
  ) async {
    await pump(tester);
    expect(find.text('No limit on reminders'), findsOneWidget);

    // Below the feature rows on a short screen: scroll to it as a person
    // would.
    await tester.scrollUntilVisible(
      find.text('Buy for BDT 1.00'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy for BDT 1.00'));
    await tester.pumpAndSettle();
    expect(store.bought, 1);

    store.emit(<StorePurchase>[plusPurchase()]);
    await tester.pumpAndSettle();
    expect(find.text('Plus is on'), findsOneWidget);
    expect(find.textContaining('Buy for'), findsNothing);
  });

  testWidgets('where Plus cannot be bought there is no button, only a way '
      'to try again', (WidgetTester tester) async {
    store.offerToGive = null;
    await pump(tester);

    // Below the feature rows, which a list does not build until it is
    // scrolled to.
    await tester.scrollUntilVisible(
      find.text('Plus cannot be bought on this phone right now'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Plus cannot be bought on this phone right now'),
      findsOneWidget,
    );
    expect(find.textContaining('Buy for'), findsNothing);

    store.offerToGive = const StoreOffer(price: 'BDT 1.00');
    // Below the feature rows on a short screen: scroll to it as a person
    // would.
    await tester.scrollUntilVisible(
      find.text('Try again'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(store.offersAsked, 2);
    expect(find.text('Buy for BDT 1.00'), findsOneWidget);
  });

  testWidgets('a build without the licence key sells nothing', (
    WidgetTester tester,
  ) async {
    await pump(tester, key: '');

    // Scrolled to where the button would be, so its absence is checked
    // where it would be drawn rather than below what the list has built.
    await tester.scrollUntilVisible(
      find.text('Plus cannot be bought on this phone right now'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Buy for'), findsNothing);
    expect(store.offersAsked, 0);
  });

  testWidgets('waiting on payment says so instead of offering it again', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    // Below the feature rows on a short screen: scroll to it as a person
    // would.
    await tester.scrollUntilVisible(
      find.text('Buy for BDT 1.00'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy for BDT 1.00'));
    await tester.pumpAndSettle();

    store.emit(<StorePurchase>[
      plusPurchase(
        status: StoreStatus.pending,
        json: pendingReceipt,
        signature: pendingSignature,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.text('Waiting for Google to confirm the payment'),
      findsOneWidget,
    );
    expect(find.textContaining('Buy for'), findsNothing);
  });

  testWidgets('the receipt totals row opens the totals', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const PlusScreen()),
        GoRoute(
          path: Routes.receiptTotals,
          builder: (_, _) => const Scaffold(body: Text('totals page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          storePortProvider.overrideWithValue(store),
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

    await tester.tap(find.text('Receipt totals for any month'));
    await tester.pumpAndSettle();
    expect(find.text('totals page'), findsOneWidget);
  });

  testWidgets('says exactly what Plus unlocks, and what stays free (B5)', (
    WidgetTester tester,
  ) async {
    // A purchase must name what it unlocks (business/STRATEGY.md): B5's date
    // and total questions are Plus, a warranty's end and reminder are not.
    await pump(tester);
    expect(find.text('Ask about dates and totals'), findsOneWidget);
    expect(
      find.textContaining('what expires in the next 90 days?'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('When a warranty ends, and its reminder'),
      200,
    );
    expect(find.text('When a warranty ends, and its reminder'), findsOneWidget);
  });
}
