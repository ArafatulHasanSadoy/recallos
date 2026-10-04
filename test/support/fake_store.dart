import 'dart:async';

import 'package:recallos/features/plus/data/purchase_check.dart';
import 'package:recallos/features/plus/data/store_port.dart';

import 'play_fixtures.dart';

/// Google Play, as far as the app can see it, under the test's control.
class FakeStore implements StorePort {
  final StreamController<List<StorePurchase>> _updates =
      StreamController<List<StorePurchase>>.broadcast();

  /// Not the real price — that is set in Play Console, and is Play's to word.
  StoreOffer? offerToGive = const StoreOffer(price: 'BDT 1.00');
  OwnedPurchases ownedAnswer = (
    reached: true,
    purchases: const <StorePurchase>[],
  );
  bool buyOpens = true;

  int offersAsked = 0;
  int bought = 0;
  final List<StorePurchase> acknowledged = <StorePurchase>[];

  void emit(List<StorePurchase> purchases) => _updates.add(purchases);

  @override
  Stream<List<StorePurchase>> get updates => _updates.stream;

  @override
  Future<StoreOffer?> offer() async {
    offersAsked++;
    return offerToGive;
  }

  @override
  Future<bool> buy(StoreOffer offer) async {
    bought++;
    return buyOpens;
  }

  @override
  Future<OwnedPurchases> owned() async => ownedAnswer;

  @override
  Future<void> acknowledge(StorePurchase purchase) async =>
      acknowledged.add(purchase);
}

/// The Keystore, in memory.
class MemoryGrants implements GrantStore {
  PlusGrant? kept;

  @override
  Future<PlusGrant?> read() async => kept;

  @override
  Future<void> write(PlusGrant grant) async => kept = grant;

  @override
  Future<void> clear() async => kept = null;
}

/// A purchase of Plus as Play would report it.
StorePurchase plusPurchase({
  StoreStatus status = StoreStatus.purchased,
  String json = plusReceipt,
  String signature = plusSignature,
  bool needsAcknowledging = true,
}) => StorePurchase(
  productId: kPlusProductId,
  status: status,
  originalJson: json,
  signature: signature,
  needsAcknowledging: needsAcknowledging,
);
