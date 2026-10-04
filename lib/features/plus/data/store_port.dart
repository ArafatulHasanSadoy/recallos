import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'purchase_check.dart';

/// Where a purchase stands, in the four states the app treats differently.
enum StoreStatus { pending, purchased, canceled, error }

/// One purchase as Google Play reports it.
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    this.originalJson = '',
    this.signature = '',
    this.needsAcknowledging = false,
    this.error,
    this.handle,
  });

  final String productId;
  final StoreStatus status;

  /// The receipt and Google's signature of it — what [isGenuinePlusReceipt]
  /// checks, and what is kept so Plus works offline.
  final String originalJson;
  final String signature;

  /// Play refunds a purchase that is not acknowledged within three days, so
  /// this is answered as soon as the receipt checks out.
  final bool needsAcknowledging;
  final String? error;

  /// The plugin's own object, handed back to acknowledge it.
  final Object? handle;
}

/// Plus as Play offers it: its price in the buyer's currency, as Play words it.
class StoreOffer {
  const StoreOffer({required this.price, this.handle});

  final String price;
  final Object? handle;
}

/// What Play says this Google account owns. [reached] is false when Play
/// could not be asked — offline, or no Play Store — which is not the same
/// as owning nothing, and must not be treated like it.
typedef OwnedPurchases = ({bool reached, List<StorePurchase> purchases});

/// What the app needs from Google Play, and nothing more.
///
/// An interface for the same reason as `NotificationPort`: the rules — when
/// Plus turns on, when it goes, what is acknowledged — are tested against a
/// fake store rather than trusted to a plugin.
abstract interface class StorePort {
  /// Purchases as they change: bought, pending, cancelled, failed.
  Stream<List<StorePurchase>> get updates;

  /// Plus and its price, or null when it cannot be bought here.
  Future<StoreOffer?> offer();

  /// Opens Play's purchase sheet. False when it could not be opened; the
  /// outcome arrives on [updates].
  Future<bool> buy(StoreOffer offer);

  Future<OwnedPurchases> owned();

  Future<void> acknowledge(StorePurchase purchase);
}

/// The real store, through `in_app_purchase` and Play Billing Library 8.
///
/// Every call is guarded: a phone without the Play Store, a sideloaded build
/// or a test without the plugin gets "not available", never an exception.
class PlayStorePort implements StorePort {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<StorePurchase>> get updates {
    try {
      return _iap.purchaseStream.map(
        (List<PurchaseDetails> all) => <StorePurchase>[
          for (final PurchaseDetails d in all) _from(d),
        ],
      );
    } on Object {
      return const Stream<List<StorePurchase>>.empty();
    }
  }

  @override
  Future<StoreOffer?> offer() async {
    try {
      if (!await _iap.isAvailable()) return null;
      final ProductDetailsResponse r = await _iap.queryProductDetails(<String>{
        kPlusProductId,
      });
      final ProductDetails? plus = r.productDetails
          .where((ProductDetails p) => p.id == kPlusProductId)
          .firstOrNull;
      return plus == null ? null : StoreOffer(price: plus.price, handle: plus);
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> buy(StoreOffer offer) async {
    final Object? product = offer.handle;
    if (product is! ProductDetails) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } on Object {
      return false;
    }
  }

  @override
  Future<OwnedPurchases> owned() async {
    try {
      final QueryPurchaseDetailsResponse r = await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();
      if (r.error != null) {
        return (reached: false, purchases: const <StorePurchase>[]);
      }
      return (
        reached: true,
        purchases: <StorePurchase>[
          for (final PurchaseDetails d in r.pastPurchases) _from(d),
        ],
      );
    } on Object {
      return (reached: false, purchases: const <StorePurchase>[]);
    }
  }

  @override
  Future<void> acknowledge(StorePurchase purchase) async {
    final Object? details = purchase.handle;
    if (details is PurchaseDetails) await _iap.completePurchase(details);
  }

  static StorePurchase _from(PurchaseDetails d) => StorePurchase(
    productId: d.productID,
    status: switch (d.status) {
      PurchaseStatus.pending => StoreStatus.pending,
      PurchaseStatus.purchased ||
      PurchaseStatus.restored => StoreStatus.purchased,
      PurchaseStatus.canceled => StoreStatus.canceled,
      PurchaseStatus.error => StoreStatus.error,
    },
    originalJson: d.verificationData.localVerificationData,
    signature: d is GooglePlayPurchaseDetails
        ? d.billingClientPurchase.signature
        : '',
    needsAcknowledging: d.pendingCompletePurchase,
    error: d.error?.message,
    handle: d,
  );
}

/// A checked receipt, kept so Plus works with no connection at all.
typedef PlusGrant = ({String originalJson, String signature});

/// Where the receipt is kept between launches.
abstract interface class GrantStore {
  Future<PlusGrant?> read();
  Future<void> write(PlusGrant grant);
  Future<void> clear();
}

/// The Android Keystore, through the same secure storage that holds the
/// wallet's keys.
///
/// Not the database: Plus belongs to the Google account, not to the wallet.
/// A wallet restored onto another phone should not carry it — Play restores
/// it there for the same account — and keeping it out of the database keeps
/// it out of every backup and export by construction.
///
/// It is Google's signed receipt, not a flag: it is checked again on every
/// launch, so writing "true" somewhere does not turn Plus on.
class KeystoreGrantStore implements GrantStore {
  // `resetOnError: false`, as for the wallet's keys. The default wipes the
  // whole store when one entry cannot be decrypted — the database key with
  // it. A lost receipt is fetched again from Play; a lost key is the wallet.
  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  static const String _key = 'plus_grant_v1';

  @override
  Future<PlusGrant?> read() async {
    final String? raw = await _store.read(key: _key);
    if (raw == null) return null;
    final Object? m = jsonDecode(raw);
    if (m is! Map<String, Object?>) return null;
    final Object? json = m['originalJson'];
    final Object? signature = m['signature'];
    if (json is! String || signature is! String) return null;
    return (originalJson: json, signature: signature);
  }

  @override
  Future<void> write(PlusGrant grant) => _store.write(
    key: _key,
    value: jsonEncode(<String, String>{
      'originalJson': grant.originalJson,
      'signature': grant.signature,
    }),
  );

  @override
  Future<void> clear() => _store.delete(key: _key);
}
