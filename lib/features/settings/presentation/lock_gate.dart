import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/brand.dart';
import '../../../core/ui/primitives.dart';
import '../data/app_lock.dart';
import '../data/app_settings.dart';

/// Stands between the launcher and the wallet.
///
/// Installed as the `MaterialApp.router` builder rather than above it, so the
/// lock screen inherits the app's own palette and typography, and so the
/// router underneath keeps its state — coming back from the lock lands where
/// the user left off rather than at home.
///
/// While locked, the app below is kept alive but taken off stage: built, not
/// painted, not hit-testable and not readable by a screen reader. Replacing it
/// outright would tear down the navigator and lose the user's place every time
/// they took a call.
/// Whether the wallet is open right now.
///
/// Lifted out of the gate's own state so that something else can shut it — the
/// "Lock now" row in Settings, which is the whole reason this is a provider
/// and not a `bool` field. Deliberately not persisted: a wallet that was open
/// when the app was killed is shut when it comes back, because a cold start is
/// the one moment where the honest default is "prove it".
class WalletLock extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;

  void shut() => state = false;
}

final walletLockProvider = NotifierProvider<WalletLock, bool>(WalletLock.new);

class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, this.grace, super.key});

  final Widget child;

  /// Overrides the user's own "Lock after" setting.
  ///
  /// Only tests pass this. `DateTime.now()` is the real clock even under a
  /// fake-async binding, so there is no honest way to wait out a minute in a
  /// widget test; passing the grace instead says "gone long enough" without
  /// waiting. Null means what it should mean everywhere else: whatever the
  /// user chose.
  final Duration? grace;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  /// A prompt is up. Prevents a second one being stacked behind the first when
  /// the OS re-delivers a resume, which on Android it does.
  bool _asking = false;

  /// When the app was last taken away, or null while it is in front.
  DateTime? _left;

  /// Said only after something actually went wrong. An ordinary cancel says
  /// nothing at all — the shut wallet is the whole message.
  String? _trouble;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // `inactive` is deliberately not here. It fires for the notification
      // shade, a permission dialog, a screenshot — things that never take the
      // app away, and would otherwise start the clock several times a minute.
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _left ??= DateTime.now();
      case AppLifecycleState.resumed:
        final DateTime? left = _left;
        _left = null;
        if (left == null || !ref.read(walletLockProvider)) return;

        final Duration grace =
            widget.grace ?? ref.read(appSettingsProvider).lockAfter;
        if (DateTime.now().difference(left) >= grace) {
          setState(() => _trouble = null);
          ref.read(walletLockProvider.notifier).shut();
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    setState(() {
      _asking = true;
      _trouble = null;
    });

    final UnlockResult result = await ref.read(appLockProvider).unlock();
    if (!mounted) return;

    if (result == UnlockResult.unlocked) {
      ref.read(walletLockProvider.notifier).open();
    }
    setState(() {
      _asking = false;
      _trouble = switch (result) {
        UnlockResult.unlocked || UnlockResult.refused => null,
        UnlockResult.lockedOut =>
          'Too many tries. Use your screen PIN instead.',
        UnlockResult.failed => 'That did not work. Try again.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    // Turning the lock off opens the wallet on the spot; turning it on while
    // the user is standing right there does not throw them out, because [_open]
    // is already true by then. The same listener is what opens the wallet on a
    // launch with no lock armed.
    ref.listen<AppSettings>(appSettingsProvider, (
      AppSettings? before,
      AppSettings after,
    ) {
      if (after.loaded && !after.lockEnabled && !ref.read(walletLockProvider)) {
        ref.read(walletLockProvider.notifier).open();
      }
    });

    final AppSettings settings = ref.watch(appSettingsProvider);
    final bool open = ref.watch(walletLockProvider);

    // Nothing is known yet. Showing the wallet here would flash it at somebody
    // who locked it, and showing the lock would flash it at somebody who did
    // not — so it shows neither, for the one frame it takes the read to land.
    if (!settings.loaded) return const RecallLaunchCover();

    final bool shut = settings.lockEnabled && !open;

    return Stack(
      children: <Widget>[
        // Alive, but not on screen: no paint, no hit test, no semantics.
        ExcludeSemantics(
          excluding: shut,
          child: Offstage(
            offstage: shut,
            child: TickerMode(enabled: !shut, child: widget.child),
          ),
        ),
        if (shut)
          _LockScreen(
            asking: _asking,
            trouble: _trouble,
            onUnlock: () => unawaited(_unlock()),
          ),
      ],
    );
  }
}

/// Frame 12's privacy row, made into a door.
///
/// Deliberately says nothing about what is behind it. A lock screen listing
/// how many cards or whose name is on the newest one would hand the contents
/// to whoever is holding the phone, which is the entire thing it exists to
/// prevent.
///
/// Wrapped in a [Material], which is not decoration and not optional. This
/// screen is installed through `MaterialApp.builder`, which puts it *beside*
/// the navigator rather than inside it — so unlike every other screen in the
/// app it has no `Scaffold` above it. Flutter marks text with no `Material`
/// ancestor by drawing a yellow double underline under every line of it, and
/// that is exactly what shipped: the one screen in the app that is meant to
/// look composed and trustworthy arrived striped in warning yellow.
class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.asking,
    required this.trouble,
    required this.onUnlock,
  });

  final bool asking;
  final String? trouble;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? problem = trouble;

    return Material(
      // The design's own paper, not Material's. Every colour and type style
      // below still comes from `AppColors` / `AppText`; this is here to be an
      // ancestor, nothing more.
      color: c.page,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              const _ShutWallet(),
              const SizedBox(height: Gap.xl),
              // Rule 3: the serif italic is the app's own voice, and this is
              // the app speaking to the person holding the phone.
              Text(
                'Only you.',
                style: AppText.displayAsk(c).copyWith(fontSize: 34),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Your wallet is closed. Unlock it the same way you unlock '
                'the phone.',
                style: AppText.body(c).copyWith(fontSize: 15),
              ),
              if (problem != null) ...<Widget>[
                const SizedBox(height: Gap.md),
                Text(
                  problem,
                  style: AppText.body(
                    c,
                  ).copyWith(fontSize: 14, color: c.vermilion),
                ),
              ],
              const Spacer(),
              InkPill(
                // Rule 5: no spinner. The label carries the state, which also
                // says more than a ring going round would.
                label: asking ? 'Waiting…' : 'Unlock',
                height: 58,
                onTap: asking ? null : onUnlock,
              ),
              const SizedBox(height: Gap.md),
              Center(
                child: MicroLabel(
                  'RecallOS · on this phone only',
                  color: c.inkFaint,
                ),
              ),
              const SizedBox(height: Gap.md),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card, face down. The whole illustration.
///
/// The onboarding screen fans three of them open; this is the same object
/// closed, which is the shortest way to say what state the app is in without
/// an icon that means nothing on its own.
class _ShutWallet extends StatelessWidget {
  const _ShutWallet();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Center(
      child: SizedBox(
        width: 176,
        height: 111,
        child: DecoratedBox(
          decoration: AppDecoration.card(c, isDark: isDarkTheme(context)),
          child: Center(child: const RecallMark(size: 64)),
        ),
      ),
    );
  }
}
