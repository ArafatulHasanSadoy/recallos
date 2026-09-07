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
    this.loaded = true,
  });

  final ThemeMode themeMode;

  /// Whether the three first-run panels have been seen.
  final bool onboarded;

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
    loaded: false,
  );
}

const String _themeKey = 'appearance';
const String _onboardedKey = 'onboarded';

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
    state = AppSettings(themeMode: mode, onboarded: state.onboarded);
    await _write(_themeKey, mode.name);
  }

  Future<void> markOnboarded() async {
    await loaded;
    state = AppSettings(themeMode: state.themeMode, onboarded: true);
    await _write(_onboardedKey, 'true');
  }

  Future<void> _write(String key, String value) =>
      _db.into(_db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: value),
          );
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);
