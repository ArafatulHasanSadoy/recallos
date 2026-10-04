import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'play_key.dart';
import 'purchase_check.dart';
import 'store_port.dart';

/// How many reminders the free version keeps waiting at once. Steps are not
/// limited, only reminders; a step finished or a reminder sent frees a slot.
/// Decided 2026-10-04.
const int kFreeReminders = 5;

final storePortProvider = Provider<StorePort>((Ref ref) => PlayStorePort());
final grantStoreProvider = Provider<GrantStore>(
  (Ref ref) => KeystoreGrantStore(),
);

/// The key receipts are checked against. A provider so tests can use their
/// own key pair; the app always reads [kPlayLicenseKey].
final playKeyProvider = Provider<String>((Ref ref) => kPlayLicenseKey);

final plusProvider = NotifierProvider<PlusController, PlusState>(
  PlusController.new,
);

enum PlusPhase {
  /// The kept receipt is still being read. Treated as free.
  checking,
  free,

  /// Bought, but Google has not confirmed the payment — cash at a shop, a
  /// slow card. Plus turns on by itself when it does.
  pending,
  owned,
}

/// What happened when the user asked to restore a purchase.
enum RestoreOutcome { owned, none, unreachable }

class PlusState {
  const PlusState({
    required this.phase,
    this.offer,
    this.offerLoaded = false,
    this.notice,
    this.noticeIsProblem = false,
  });

  final PlusPhase phase;

  /// Plus and Play's price for it; null until asked, or when it cannot be
  /// bought here.
  final StoreOffer? offer;
  final bool offerLoaded;

  /// The last thing worth saying about a purchase, in plain words.
  final String? notice;
  final bool noticeIsProblem;

  bool get owned => phase == PlusPhase.owned;

  PlusState _with({
    PlusPhase? phase,
    StoreOffer? offer,
    bool clearOffer = false,
    bool? offerLoaded,
    String? notice,
    bool clearNotice = false,
    bool noticeIsProblem = false,
  }) => PlusState(
    phase: phase ?? this.phase,
    offer: clearOffer ? null : (offer ?? this.offer),
    offerLoaded: offerLoaded ?? this.offerLoaded,
    notice: clearNotice ? null : (notice ?? this.notice),
    noticeIsProblem: clearNotice ? false : noticeIsProblem,
  );
}

/// RecallOS Plus: a one-time purchase, checked and kept on the phone.
///
/// Plus is on exactly when a receipt Google signed for `recallos_plus` is in
/// hand — kept from the last time Play was reached, re-checked on every
/// launch. Asking Play again (at launch, on return to the app, on "Restore")
/// brings it back after a reinstall and takes it away after a refund. Asking
/// and failing — offline, no Play Store — changes nothing, so a paid user is
/// never locked out by a bad connection.
class PlusController extends Notifier<PlusState> {
  late StorePort _store;
  late GrantStore _grants;
  late String _key;
  StreamSubscription<List<StorePurchase>>? _updates;
  late Future<void> _kept;

  @override
  PlusState build() {
    _store = ref.watch(storePortProvider);
    _grants = ref.watch(grantStoreProvider);
    _key = ref.watch(playKeyProvider);
    ref.onDispose(() => unawaited(_updates?.cancel()));
    _kept = _readKept();
    return const PlusState(phase: PlusPhase.checking);
  }

  /// Whether Plus is on, once the kept receipt has been read. For decisions
  /// taken in the first moments after launch, when [state] may still say
  /// "checking" — a paid user must never be told the free limit applies.
  Future<bool> isOwned() async {
    // A Keystore that stalls must not hold a sheet shut: after a second the
    // answer is whatever is known, which for a paid user is fixed the moment
    // the read lands.
    await _kept.timeout(const Duration(seconds: 1), onTimeout: () {});
    return state.owned;
  }

  /// Whether Plus can be sold by this build at all. Without the licence key
  /// a receipt cannot be checked, and a purchase that cannot be checked
  /// would take the money and never turn Plus on.
  bool get _canSell => parsePlayKey(_key) != null;

  Future<void> _readKept() async {
    PlusGrant? kept;
    try {
      kept = await _grants.read();
    } on Object {
      kept = null;
    }
    if (!ref.mounted || state.phase != PlusPhase.checking) return;
    final bool genuine =
        kept != null &&
        isGenuinePlusReceipt(
          originalJson: kept.originalJson,
          signature: kept.signature,
          key: _key,
        );
    state = state._with(phase: genuine ? PlusPhase.owned : PlusPhase.free);
  }

  /// Once the app is up: listens for purchases, and asks Play what this
  /// account owns.
  Future<void> start() async {
    _listen();
    await refresh();
  }

  /// Purchase outcomes arrive only on the update stream, so nothing opens
  /// Play's sheet without something listening — whoever gets there first.
  void _listen() {
    _updates ??= _store.updates.listen(
      (List<StorePurchase> all) => unawaited(_onUpdates(all)),
      onError: (Object _) {},
    );
  }

  /// Asks Play what the account owns, and makes Plus match.
  Future<RestoreOutcome> refresh() async {
    final OwnedPurchases owned;
    try {
      owned = await _store.owned();
    } on Object {
      return RestoreOutcome.unreachable;
    }
    if (!ref.mounted || !owned.reached) return RestoreOutcome.unreachable;

    final StorePurchase? plus = owned.purchases
        .where((StorePurchase p) => p.productId == kPlusProductId)
        .firstOrNull;
    if (plus == null) {
      // Play answered and holds no Plus for this account: refunded, revoked,
      // or a different Google account on this phone.
      await _forget();
      return RestoreOutcome.none;
    }
    await _settle(plus);
    return state.owned ? RestoreOutcome.owned : RestoreOutcome.none;
  }

  /// "Already bought it?" — the same question as [refresh], with an answer
  /// the screen can say out loud.
  Future<void> restore() async {
    final RestoreOutcome outcome = await refresh();
    if (!ref.mounted) return;
    state = switch (outcome) {
      RestoreOutcome.owned => state._with(clearNotice: true),
      RestoreOutcome.none => state._with(
        notice:
            'Google Play has no purchase of Plus for the account signed in '
            'on this phone.',
      ),
      RestoreOutcome.unreachable => state._with(
        notice:
            'Google Play could not be reached. Try again when you are '
            'online.',
        noticeIsProblem: true,
      ),
    };
  }

  /// Asks Play for Plus and its price, for the purchase screen.
  Future<void> loadOffer() async {
    StoreOffer? offer;
    if (_canSell) {
      try {
        offer = await _store.offer();
      } on Object {
        offer = null;
      }
    }
    if (!ref.mounted) return;
    state = offer == null
        ? state._with(clearOffer: true, offerLoaded: true)
        : state._with(offer: offer, offerLoaded: true);
  }

  /// Opens Play's purchase sheet. What happens there arrives as an update.
  Future<void> buy() async {
    final StoreOffer? offer = state.offer;
    if (offer == null || !_canSell) return;
    _listen();
    state = state._with(clearNotice: true);
    bool opened;
    try {
      opened = await _store.buy(offer);
    } on Object {
      opened = false;
    }
    if (!opened && ref.mounted) {
      state = state._with(
        notice:
            'Google Play could not open the purchase. Try again in a '
            'moment.',
        noticeIsProblem: true,
      );
    }
  }

  Future<void> _onUpdates(List<StorePurchase> all) async {
    for (final StorePurchase p in all) {
      if (p.productId == kPlusProductId) await _settle(p);
    }
  }

  Future<void> _settle(StorePurchase p) async {
    if (!ref.mounted) return;
    switch (p.status) {
      case StoreStatus.pending:
        if (!state.owned) {
          state = state._with(phase: PlusPhase.pending, clearNotice: true);
        }
      case StoreStatus.canceled:
        if (!state.owned) {
          state = state._with(
            phase: PlusPhase.free,
            notice: 'Cancelled. Nothing was charged.',
          );
        }
      case StoreStatus.error:
        if (!state.owned) {
          state = state._with(
            phase: PlusPhase.free,
            notice:
                'The purchase did not go through, and nothing was '
                'charged.',
            noticeIsProblem: true,
          );
        }
      case StoreStatus.purchased:
        if (!isGenuinePlusReceipt(
          originalJson: p.originalJson,
          signature: p.signature,
          key: _key,
        )) {
          // Not acknowledged either: Play refunds an unacknowledged purchase
          // by itself within three days, which is the right end for one
          // this phone cannot vouch for.
          state = state._with(
            notice:
                "Google Play's receipt could not be checked, so Plus was "
                'not turned on. If you were charged, Google refunds it.',
            noticeIsProblem: true,
          );
          return;
        }
        try {
          await _grants.write((
            originalJson: p.originalJson,
            signature: p.signature,
          ));
        } on Object {
          // Plus still turns on now; the next launch asks Play again.
        }
        if (p.needsAcknowledging) {
          try {
            await _store.acknowledge(p);
          } on Object {
            // Retried on the next refresh, well inside Play's three days.
          }
        }
        if (ref.mounted) {
          state = state._with(phase: PlusPhase.owned, clearNotice: true);
        }
    }
  }

  Future<void> _forget() async {
    try {
      await _grants.clear();
    } on Object {
      // Nothing kept is the same outcome.
    }
    if (ref.mounted) state = state._with(phase: PlusPhase.free);
  }
}
