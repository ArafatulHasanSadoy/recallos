import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../capture/data/card_repository.dart';

/// The handful of preferences the app actually has state for.
///
/// Stored in the `settings` key/value table the identity graph already uses
/// for its rules version, rather than in `shared_preferences`: one store, one
/// backup, and nothing extra to keep in step. `design/DESIGN.md` frame 12
/// proposes several more rows — "Ask for a note every time", "Photo quality",
/// "Larger type" — and is explicit that they should ship with the features
/// that back them, not before, so they are deliberately absent here.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.onboarded,
    required this.lockEnabled,
    required this.lockAfter,
    this.loaded = true,
  });

  final ThemeMode themeMode;

  /// Whether the three first-run panels have been seen.
  final bool onboarded;

  /// Whether the wallet asks who is holding the phone before it opens.
  ///
  /// Off by default, and deliberately: a lock the user did not ask for is a
  /// lock they will meet for the first time as an obstacle. `LockGate` reads
  /// this, and reads [loaded] first — see the note there.
  final bool lockEnabled;

  /// How long the app may be away before it shuts again.
  ///
  /// [Duration.zero] means the moment it loses the foreground, which is what a
  /// password manager does and what some people want. It is not the default,
  /// because this app hands off to the scanner, the dialler and the share
  /// sheet constantly and at zero every one of those costs a fingerprint on
  /// the way back. The picker says so rather than letting people find out.
  final Duration lockAfter;

  /// False until the stored values have been read.
  ///
  /// Anything that *acts* on a preference has to check this, because the read
  /// is asynchronous and the defaults are indistinguishable from a real
  /// answer. The first-run redirect learned that the hard way: it saw
  /// `onboarded: false` on every launch and showed the panels again to
  /// somebody who had already dismissed them.
  final bool loaded;

  static const AppSettings initial = AppSettings(
    themeMode: ThemeMode.system,
    onboarded: false,
    lockEnabled: false,
    lockAfter: defaultLockAfter,
    loaded: false,
  );

  /// What somebody who has never chosen gets.
  ///
  /// Not zero, and that is a considered default rather than laziness. RecallOS
  /// hands off to other apps constantly and by design — the document scanner
  /// is a separate activity, so is the dialler, the mail client, the share
  /// sheet. Defaulting to the instant the app loses focus would mean a
  /// fingerprint after every single scan and every single phone call, which is
  /// how a security feature gets switched off within a day.
  ///
  /// A minute covers the round trip through another app and nothing more. Put
  /// the phone down, hand it over, or take a call that runs long, and the
  /// wallet is shut again. Anyone who wants stricter than that can say so —
  /// see [lockAfterChoices].
  static const Duration defaultLockAfter = Duration(seconds: 60);

  /// What the picker offers, in order.
  static const List<Duration> lockAfterChoices = <Duration>[
    Duration.zero,
    Duration(seconds: 60),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? onboarded,
    bool? lockEnabled,
    Duration? lockAfter,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    onboarded: onboarded ?? this.onboarded,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    lockAfter: lockAfter ?? this.lockAfter,
  );
}

/// How a delay reads in a row and in the picker.
String lockAfterLabel(Duration d) => switch (d.inSeconds) {
  0 => 'Immediately',
  60 => 'After a minute',
  final int s when s < 3600 => 'After ${d.inMinutes} minutes',
  _ => 'After ${d.inHours} hours',
};

const String _themeKey = 'appearance';
const String _onboardedKey = 'onboarded';
const String _lockKey = 'lock_enabled';
const String _lockAfterKey = 'lock_after_seconds';

/// Reads and writes [AppSettings], and notifies the app when they change.
class AppSettingsController extends Notifier<AppSettings> {
  late final AppDatabase _db;

  /// Completes once the stored values have replaced [AppSettings.initial].
  ///
  /// Exposed so a test does not have to guess how long the read takes. The app
  /// deliberately does not await it — see [build].
  late final Future<void> loaded;

  @override
  AppSettings build() {
    _db = ref.watch(databaseProvider);
    // Deliberately not awaited here: the app opens on the system theme and
    // settles onto the stored one a frame later. Blocking the first frame on a
    // database read to avoid a single repaint is the wrong trade.
    loaded = _load();
    unawaited(loaded);
    return AppSettings.initial;
  }

  Future<void> _load() async {
    final List<Setting> rows = await _db.select(_db.settings).get();
    String? valueOf(String key) {
      for (final Setting row in rows) {
        if (row.key == key) return row.value;
      }
      return null;
    }

    // The read is asynchronous and the provider can be gone by the time it
    // lands — a container torn down between launch and the first frame, which
    // is exactly what a test does. Writing state then throws.
    if (!ref.mounted) return;
    state = AppSettings(
      themeMode: switch (valueOf(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      onboarded: valueOf(_onboardedKey) == 'true',
      lockEnabled: valueOf(_lockKey) == 'true',
      lockAfter: _durationOf(valueOf(_lockAfterKey)),
      loaded: true,
    );
  }

  /// Both setters wait for the startup read before touching state.
  ///
  /// Without it there is a race with a very short fuse: the read is in flight
  /// from the first frame, so a preference changed in the first moments of a
  /// launch is set, written, and then silently overwritten when the read lands
  /// carrying the values from before the write. Awaiting a future that has
  /// almost always already completed costs nothing and closes it.
  Future<void> setThemeMode(ThemeMode mode) async {
    await loaded;
    state = state.copyWith(themeMode: mode);
    await _write(_themeKey, mode.name);
  }

  Future<void> markOnboarded() async {
    await loaded;
    state = state.copyWith(onboarded: true);
    await _write(_onboardedKey, 'true');
  }

  Future<void> setLockEnabled(bool enabled) async {
    await loaded;
    state = state.copyWith(lockEnabled: enabled);
    await _write(_lockKey, enabled ? 'true' : 'false');
  }

  Future<void> setLockAfter(Duration after) async {
    await loaded;
    state = state.copyWith(lockAfter: after);
    await _write(_lockAfterKey, '${after.inSeconds}');
  }

  /// Reads a stored delay, falling back rather than throwing.
  ///
  /// A missing row is somebody who has never chosen, and gets the default. A
  /// row that is not a number at all is a corrupted or hand-edited store, and
  /// the safe reading of "I cannot tell how long you wanted" is the default
  /// too — never "never lock".
  static Duration _durationOf(String? raw) {
    final int? seconds = raw == null ? null : int.tryParse(raw);
    if (seconds == null || seconds < 0) return AppSettings.defaultLockAfter;
    return Duration(seconds: seconds);
  }

  Future<void> _write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
