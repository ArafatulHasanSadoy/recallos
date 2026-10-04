import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/features/plus/data/store_port.dart';

import '../support/fake_store.dart';
import '../support/play_fixtures.dart';

/// When RecallOS Plus is on, and when it is not.
///
/// Plus is on exactly when a receipt Google signed is in hand. These walk
/// the ways one arrives and the ways it goes — and the one way it must not
/// go: a phone that is simply offline.
void main() {
  late FakeStore store;
  late MemoryGrants grants;

  setUp(() {
    store = FakeStore();
    grants = MemoryGrants();
  });

  ProviderContainer make({String key = testPlayKey}) {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        storePortProvider.overrideWithValue(store),
        grantStoreProvider.overrideWithValue(grants),
        playKeyProvider.overrideWithValue(key),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<ProviderContainer> started({String key = testPlayKey}) async {
    final ProviderContainer c = make(key: key);
    c.read(plusProvider);
    await settle();
    await c.read(plusProvider.notifier).start();
    await settle();
    return c;
  }

  test(
    'a purchase that checks out turns Plus on, is kept and acknowledged',
    () async {
      final ProviderContainer c = await started();
      expect(c.read(plusProvider).phase, PlusPhase.free);

      store.emit(<StorePurchase>[plusPurchase()]);
      await settle();

      expect(c.read(plusProvider).owned, isTrue);
      expect(grants.kept?.originalJson, plusReceipt);
      expect(store.acknowledged, hasLength(1));
    },
  );

  test('a receipt that does not check out turns nothing on, and is not '
      'acknowledged, so Google refunds it', () async {
    final ProviderContainer c = await started();

    store.emit(<StorePurchase>[plusPurchase(signature: plusSignatureWrongKey)]);
    await settle();

    final PlusState s = c.read(plusProvider);
    expect(s.owned, isFalse);
    expect(s.noticeIsProblem, isTrue);
    expect(grants.kept, isNull);
    expect(store.acknowledged, isEmpty);
  });

  test('waiting on payment, then confirmed', () async {
    final ProviderContainer c = await started();

    store.emit(<StorePurchase>[
      plusPurchase(
        status: StoreStatus.pending,
        json: pendingReceipt,
        signature: pendingSignature,
      ),
    ]);
    await settle();
    expect(c.read(plusProvider).phase, PlusPhase.pending);
    expect(store.acknowledged, isEmpty, reason: 'nothing to acknowledge yet');

    store.emit(<StorePurchase>[plusPurchase()]);
    await settle();
    expect(c.read(plusProvider).owned, isTrue);
  });

  test('cancelled says nothing was charged', () async {
    final ProviderContainer c = await started();
    store.emit(<StorePurchase>[plusPurchase(status: StoreStatus.canceled)]);
    await settle();

    expect(c.read(plusProvider).phase, PlusPhase.free);
    expect(c.read(plusProvider).notice, contains('Nothing was charged'));
  });

  test('offline, the kept receipt keeps Plus on', () async {
    grants.kept = (originalJson: plusReceipt, signature: plusSignature);
    store.ownedAnswer = (reached: false, purchases: const <StorePurchase>[]);

    final ProviderContainer c = await started();

    expect(c.read(plusProvider).owned, isTrue);
    expect(grants.kept, isNotNull, reason: 'not reaching Play is not a refund');
  });

  test('Play answers and holds no Plus: a refund takes it away', () async {
    grants.kept = (originalJson: plusReceipt, signature: plusSignature);
    store.ownedAnswer = (reached: true, purchases: const <StorePurchase>[]);

    final ProviderContainer c = await started();

    expect(c.read(plusProvider).owned, isFalse);
    expect(grants.kept, isNull);
  });

  test('after a reinstall, Play brings Plus back and the unacknowledged '
      'purchase is acknowledged then', () async {
    store.ownedAnswer = (
      reached: true,
      purchases: <StorePurchase>[plusPurchase()],
    );

    final ProviderContainer c = await started();

    expect(c.read(plusProvider).owned, isTrue);
    expect(grants.kept?.signature, plusSignature);
    expect(store.acknowledged, hasLength(1));
  });

  test('a kept receipt that has been tampered with is not believed', () async {
    grants.kept = (
      originalJson: plusReceipt.replaceFirst('test-token-1', 'test-token-9'),
      signature: plusSignature,
    );
    store.ownedAnswer = (reached: false, purchases: const <StorePurchase>[]);

    final ProviderContainer c = await started();

    expect(c.read(plusProvider).owned, isFalse);
  });

  test('without the licence key Plus is not for sale at all', () async {
    final ProviderContainer c = await started(key: '');

    await c.read(plusProvider.notifier).loadOffer();
    await c.read(plusProvider.notifier).buy();

    expect(c.read(plusProvider).offer, isNull);
    expect(c.read(plusProvider).offerLoaded, isTrue);
    expect(store.offersAsked, 0);
    expect(store.bought, 0, reason: 'a purchase it could not check');
  });

  test('restore says what Play said', () async {
    final ProviderContainer c = await started();

    await c.read(plusProvider.notifier).restore();
    expect(c.read(plusProvider).notice, contains('no purchase of Plus'));

    store.ownedAnswer = (reached: false, purchases: const <StorePurchase>[]);
    await c.read(plusProvider.notifier).restore();
    expect(c.read(plusProvider).notice, contains('could not be reached'));
    expect(c.read(plusProvider).noticeIsProblem, isTrue);

    store.ownedAnswer = (
      reached: true,
      purchases: <StorePurchase>[plusPurchase()],
    );
    await c.read(plusProvider.notifier).restore();
    expect(c.read(plusProvider).owned, isTrue);
    expect(c.read(plusProvider).notice, isNull);
  });
}
