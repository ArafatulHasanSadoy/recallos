import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/features/plus/data/store_port.dart';
import 'package:recallos/features/plus/presentation/plus_screen.dart';

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

    expect(
      find.text('Plus cannot be bought on this phone right now'),
      findsOneWidget,
    );
    expect(find.textContaining('Buy for'), findsNothing);

    store.offerToGive = const StoreOffer(price: 'BDT 1.00');
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(store.offersAsked, 2);
    expect(find.text('Buy for BDT 1.00'), findsOneWidget);
  });

  testWidgets('a build without the licence key sells nothing', (
    WidgetTester tester,
  ) async {
    await pump(tester, key: '');

    expect(find.textContaining('Buy for'), findsNothing);
    expect(store.offersAsked, 0);
  });

  testWidgets('waiting on payment says so instead of offering it again', (
    WidgetTester tester,
  ) async {
    await pump(tester);
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
}
