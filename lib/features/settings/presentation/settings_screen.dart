import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/encrypted_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/brand.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../../cards/presentation/needs_attention_screen.dart';
import '../../contacts/data/identity_repository.dart';
import '../data/app_lock.dart';
import '../data/app_settings.dart';
import '../data/wallet_export.dart';
import 'lock_gate.dart';

/// Whether this phone can be asked to prove who is holding it.
///
/// A provider rather than a field so the answer is fetched once and shared:
/// the settings screen asks, and anything else that needs to know can too.
/// Null while the platform is still being asked.
final lockAvailabilityProvider = FutureProvider<LockUnavailable?>(
  (Ref ref) => ref.watch(appLockProvider).unavailableReason(),
);

/// What the database on disk actually is, as reported when it was opened.
///
/// Read rather than asserted. A settings row that says "encrypted" because
/// somebody wrote the word into a string is worth nothing — this is the answer
/// the open itself gave, including when it is the answer nobody wanted.
final storageStatusProvider = FutureProvider<StorageStatus>(
  (Ref ref) => storageStatus,
);

/// Frame 12.
///
/// Only rows with something behind them. The frame also proposes "Ask for a
/// note every time", "Capture the back too", "Photo quality" and "Larger
/// type"; none of those has a store or a consumer yet, and a switch that
/// remembers nothing is worse than an absent one — so they ship with their
/// features, not before.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppSettings settings = ref.watch(appSettingsProvider);
    final int deleted = ref.watch(deletedCardsProvider).value?.length ?? 0;
    final int duplicates =
        ref.watch(duplicateCandidatesProvider).value?.length ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'Settings', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
                children: <Widget>[
                  Text('Settings', style: AppText.title(c)),
                  const SizedBox(height: Gap.lg),

                  SettingGroup(
                    label: 'Your wallet',
                    children: <Widget>[
                      SettingRow(
                        label: 'Recently deleted',
                        description: deleted == 1
                            ? '1 card, still on the phone'
                            : '$deleted cards, still on the phone',
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: c.inkFaint,
                        ),
                        onTap: () => context.push(Routes.needsAttention),
                      ),
                      SettingRow(
                        label: 'Duplicates to review',
                        description: duplicates == 1
                            ? '1 pair waiting'
                            : '$duplicates pairs waiting',
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: c.inkFaint,
                        ),
                        onTap: () => context.push(Routes.duplicates),
                      ),
                      SettingRow(
                        label: 'Needs attention',
                        description: 'Cards that did not read cleanly',
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: c.inkFaint,
                        ),
                        onTap: () => context.push(Routes.needsAttention),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),

                  SettingGroup(
                    label: 'Privacy',
                    children: <Widget>[
                      const LockRow(),
                      // Both only exist once there is a lock to configure. A
                      // "Lock now" on a wallet that never locks would do
                      // nothing visible, and a delay before a lock that is off
                      // is a setting for a thing that never happens.
                      if (settings.lockEnabled) ...<Widget>[
                        SettingRow(
                          label: 'Lock after',
                          description: lockAfterLabel(settings.lockAfter),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: c.inkFaint,
                          ),
                          onTap: () => unawaited(_pickLockAfter(context, ref)),
                        ),
                        const LockNowRow(),
                      ],
                      const _StorageRow(),
                      const SettingRow(
                        label: 'On this phone only',
                        description:
                            'Nothing is uploaded, and Android is told '
                            'not to back the wallet up either.',
                      ),
                      // Directly under the row that says nothing backs this
                      // up, because that is the sentence it answers.
                      const _ExportRow(),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),

                  SettingGroup(
                    label: 'Look',
                    children: <Widget>[
                      SettingRow(
                        label: 'Appearance',
                        description: switch (settings.themeMode) {
                          ThemeMode.system => 'Follow system',
                          ThemeMode.light => 'Always light',
                          ThemeMode.dark => 'Always dark',
                        },
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: c.inkFaint,
                        ),
                        onTap: () => unawaited(_pickAppearance(context, ref)),
                      ),
                    ],
                  ),
                  // Phase 0 scaffolding, and the last thing still reachable
                  // only from a menu. It lives here until the spike screen
                  // itself goes.
                  //
                  // Debug builds only. The spike reads whatever is picked out
                  // of the gallery and writes the raw OCR to a file, which is a
                  // developer's tool and not something to hand a user. The
                  // route is gated the same way in `router.dart`, so the group
                  // and its destination disappear together — `kDebugMode` is a
                  // const, so neither survives into a release build.
                  if (kDebugMode) ...<Widget>[
                    const SizedBox(height: Gap.lg),
                    SettingGroup(
                      label: 'Development',
                      children: <Widget>[
                        SettingRow(
                          label: 'OCR spike',
                          description: 'Scores extraction against real cards',
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: c.inkFaint,
                          ),
                          onTap: () => context.push(Routes.spike),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: Gap.xl),
                  const Center(child: RecallBrand()),
                  const SizedBox(height: Gap.sm),
                  Center(
                    child: MicroLabel(
                      'Your pocket memory · offline',
                      color: c.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// How long away is long enough to shut the wallet.
  ///
  /// "Immediately" carries its consequence in the picker rather than leaving
  /// people to discover it: this app leaves the foreground every time it opens
  /// the scanner, the dialler or the share sheet, so at zero every scan and
  /// every phone call costs a fingerprint on the way back. That is a real
  /// choice, and the one a password manager makes — but not one to make blind.
  Future<void> _pickLockAfter(BuildContext context, WidgetRef ref) async {
    final AppColors c = AppColors.of(context);
    final Duration? picked = await showModalBottomSheet<Duration>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Lock after', style: AppText.rowSerif(c)),
            const SizedBox(height: Gap.sm),
            for (final Duration option in AppSettings.lockAfterChoices)
              SettingRow(
                label: lockAfterLabel(option),
                description: option == Duration.zero
                    ? 'Also every time you scan a card or make a call.'
                    : null,
                onTap: () => Navigator.of(sheet).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(appSettingsProvider.notifier).setLockAfter(picked);
  }

  Future<void> _pickAppearance(BuildContext context, WidgetRef ref) async {
    final AppColors c = AppColors.of(context);
    final ThemeMode? picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Appearance', style: AppText.rowSerif(c)),
            const SizedBox(height: Gap.sm),
            for (final (ThemeMode mode, String label) in <(ThemeMode, String)>[
              (ThemeMode.system, 'Follow system'),
              (ThemeMode.light, 'Always light'),
              (ThemeMode.dark, 'Always dark'),
            ])
              SettingRow(
                label: label,
                onTap: () => Navigator.of(sheet).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(appSettingsProvider.notifier).setThemeMode(picked);
  }
}

/// The lock switch — or a way to get to what it needs, when it cannot be one.
///
/// Public so it can be tested on its own: what matters here is what a *tap*
/// does, and that is not reachable through the whole settings screen without
/// standing up its half-dozen other providers.
///
/// A phone with no PIN, pattern or fingerprint has nothing to authenticate
/// against, so the switch genuinely cannot be armed. The first version of this
/// row said so in grey text under a disabled switch, and that was wrong in the
/// way that matters: tapping it did nothing, and a control that does nothing
/// reads as broken, not as unavailable. It got reported as a bug, correctly.
///
/// So when the lock cannot be armed there is no switch at all — there is a row
/// that takes you to the Android screen where the missing piece is set. And
/// the check runs again every time the app comes back, because the whole point
/// is that somebody leaves, sets a PIN, and returns.
class LockRow extends ConsumerStatefulWidget {
  const LockRow({super.key});

  @override
  ConsumerState<LockRow> createState() => _LockRowState();
}

class _LockRowState extends ConsumerState<LockRow>
    with WidgetsBindingObserver {
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
    // The answer to "can this phone lock?" changes while the app is in the
    // background — that is the entire journey this row sends people on. Asked
    // once at startup, the row would still be telling somebody to set a screen
    // lock they had just finished setting, until they restarted the app.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(lockAvailabilityProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSettings settings = ref.watch(appSettingsProvider);
    final AsyncValue<LockUnavailable?> availability = ref.watch(
      lockAvailabilityProvider,
    );

    // Rule 5: no spinner. While the platform is being asked the row says what
    // it is waiting on, which is more informative than a ring going round.
    if (!availability.hasValue) {
      return const SettingRow(
        label: 'Lock the wallet',
        description: 'Checking this phone…',
      );
    }

    final LockUnavailable? blocked = availability.value;
    if (blocked != null) {
      return SettingRow(
        label: 'Lock the wallet',
        description: switch (blocked) {
          LockUnavailable.noScreenLock =>
            'This phone has no screen lock yet. Set a PIN, pattern or '
                'fingerprint, and this switch turns on.',
          LockUnavailable.unknown =>
            'This phone did not answer when asked. Open its security settings '
                'and check that a screen lock is set.',
        },
        trailing: Icon(Icons.chevron_right, size: 18, color: c.inkFaint),
        onTap: () => unawaited(_openSecuritySettings()),
      );
    }

    return SettingRow(
      label: 'Lock the wallet',
      description: settings.lockEnabled
          ? 'Asked for on opening, and after a minute away.'
          : 'Ask for your fingerprint or PIN before opening.',
      trailing: AppSwitch(
        value: settings.lockEnabled,
        onChanged: (bool on) => unawaited(_setEnabled(on)),
      ),
      // Tapping the row does what tapping the switch does, which is what a row
      // with a switch on it looks like it should do.
      onTap: () => unawaited(_setEnabled(!settings.lockEnabled)),
    );
  }

  Future<void> _setEnabled(bool on) =>
      ref.read(appSettingsProvider.notifier).setLockEnabled(on);

  Future<void> _openSecuritySettings() async {
    final bool opened = await ref.read(appLockProvider).openSecuritySettings();
    if (opened || !mounted) return;

    // The intent found nothing to open, which happens on stripped-down ROMs.
    // Saying where to go by hand beats a tap that silently does nothing —
    // which is the fault this whole row exists to correct.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Open Android Settings, then Security, and set a screen lock.',
        ),
      ),
    );
  }
}

/// Shuts the wallet on the spot.
///
/// What a password manager puts at the top of its menu, and for the same
/// reason: the moment somebody wants their wallet shut is a moment they are
/// about to hand the phone over, and telling them to wait a minute for the
/// timer is no answer at all.
///
/// Public so it can be tested on its own — what matters is what the tap does.
class LockNowRow extends ConsumerWidget {
  const LockNowRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);

    return SettingRow(
      label: 'Lock now',
      description: 'Close the wallet without waiting.',
      trailing: Icon(Icons.lock_outline, size: 18, color: c.inkFaint),
      onTap: () {
        // The gate covers this screen too, so there is nowhere to navigate to
        // and nothing to confirm: the wallet simply shuts over whatever was
        // showing, and unlocking puts the user back exactly here.
        ref.read(walletLockProvider.notifier).shut();
      },
    );
  }
}


/// Takes a copy of the whole wallet out of the phone.
///
/// The row above it says nothing backs the wallet up, which is true and was,
/// until this existed, the end of the story. Android backup is off, there is
/// no server, and the database key lives in the Android Keystore — so it dies
/// with the app. Reinstalling, replacing the phone, or changing the signing
/// key all cost the user everything they had scanned, and the only way out was
/// sharing one contact at a time.
///
/// No spinner while it packs (rule 5). The description carries the state
/// instead, and the row stops accepting taps — a second archive halfway
/// through the first is not something to let happen.
class _ExportRow extends ConsumerStatefulWidget {
  const _ExportRow();

  @override
  ConsumerState<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends ConsumerState<_ExportRow> {
  bool _busy = false;
  WalletExportResult? _last;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return SettingRow(
      label: 'Take a copy',
      description: switch ((_busy, _last)) {
        (true, _) => 'Packing everything up…',
        (false, WalletExportResult.shared) =>
          'Sent. Keep it somewhere you trust — the copy is not encrypted.',
        (false, WalletExportResult.empty) => 'Nothing saved yet.',
        (false, WalletExportResult.failed) =>
          'That did not work. Nothing was changed or lost.',
        (false, null) =>
          'Every card, contact, note and photo, in one file you can '
              'keep off the phone.',
      },
      trailing: Icon(
        _last == WalletExportResult.failed
            ? Icons.error_outline
            : Icons.ios_share,
        size: 18,
        // Rule 2: ochre is a marker, so a state the user should act on wears
        // vermilion — the same colour a field that failed to read wears.
        color: _last == WalletExportResult.failed ? c.vermilion : c.inkFaint,
      ),
      onTap: _busy ? null : () => unawaited(_run()),
    );
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _last = null;
    });
    // Read before the await, not after: the provider is auto-disposed, and a
    // `Ref` read on the far side of an await may already be dead.
    final WalletExport export = ref.read(walletExportProvider);
    final WalletExportResult result = await export.exportAll();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = result;
    });
  }
}

/// What the wallet on disk is, said to the person who owns it.
///
/// An earlier version of this row opened a sheet of hex — the file's first
/// sixteen bytes, the SQLCipher version, a row count. That was written to
/// answer "how would I know?", and it did, but it answered it for a developer.
/// Somebody looking after their own contacts does not want to read a hex dump
/// to find out whether their wallet is safe; being shown one is closer to
/// being told to check the wiring.
///
/// So the row says what is true in a sentence. The evidence still exists — it
/// is in `test/core/encrypted_database_test.dart`, and on a debug build the
/// file header can be read with `adb` — which is where evidence belongs: with
/// the people who can act on it.
///
/// What it must never do is claim more than happened. On a build without
/// SQLCipher, `PRAGMA key` is silently ignored, so the reassuring sentence
/// would be indistinguishable from the truth — which is why the failure states
/// below are worded as plainly as the success one, and coloured.
///
/// The label used to read "Your cards are encrypted", and that was wider than
/// the truth in the other direction: the *database* is encrypted, but the card
/// photographs are ordinary JPEGs in the documents directory — see the header
/// of `encrypted_database.dart`. A card is a picture to most people, so the old
/// label promised exactly the thing SQLCipher does not cover. It now says
/// "wallet", and the description names the gap rather than leaving the reader
/// to find it.
class _StorageRow extends ConsumerWidget {
  const _StorageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<StorageStatus> status = ref.watch(storageStatusProvider);
    final StorageStatus? settled = status.value;

    return SettingRow(
      label: 'Your wallet is encrypted',
      description: switch (settled) {
        null => 'Checking…',
        (protection: StorageProtection.encrypted, reason: _) =>
          'Names, numbers and notes are scrambled on this phone with a key '
              'only this phone holds. The card photographs are not — they sit '
              'in this app\'s own storage, which no other app can open.',
        (protection: StorageProtection.plaintext, reason: final String? why) =>
          'Not encrypted on this phone. ${why ?? ''}'.trim(),
        (protection: StorageProtection.unreadable, reason: final String? why) =>
          why ?? 'These cards cannot be opened on this phone.',
      },
      trailing: Icon(
        switch (settled?.protection) {
          StorageProtection.encrypted => Icons.lock_outline,
          null => Icons.more_horiz,
          _ => Icons.lock_open_outlined,
        },
        size: 18,
        color: switch (settled?.protection) {
          StorageProtection.encrypted || null => c.inkFaint,
          // Rule 2 keeps ochre for markers, so a state the user should act on
          // is vermilion — the same colour a field that failed to read wears.
          _ => c.vermilion,
        },
      ),
    );
  }
}
