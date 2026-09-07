import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/settings/data/app_settings.dart';

/// Preferences live in the `settings` table the identity graph already uses.
///
/// The thing worth pinning is that they survive a restart: a switch that
/// forgets is worse than no switch, which is why frame 12's rows without a
/// store were left out rather than faked.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// A container that behaves like the running app.
  ///
  /// The subscription is not incidental: Riverpod 3 disposes a provider with
  /// no listeners, and a disposed controller abandons its load half way — so
  /// a bare `read` here would test something the app never does.
  ProviderContainer open() {
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.listen(appSettingsProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  test('opens on the system theme, and says it has not read yet', () {
    final AppSettings s = open().read(appSettingsProvider);
    expect(s.themeMode, ThemeMode.system);
    expect(s.onboarded, isFalse);
    // The flag the first-run redirect needs. Without it, defaults are
    // indistinguishable from a real answer and the panels come back on every
    // launch.
    expect(s.loaded, isFalse);
  });

  test('reports itself loaded once the read lands', () async {
    final ProviderContainer c = open();
    await c.read(appSettingsProvider.notifier).loaded;
    expect(c.read(appSettingsProvider).loaded, isTrue);
  });

  test('a choice made during the startup read is not overwritten', () async {
    // The race with the shortest fuse in the app: the stored values are read
    // in the background from the first frame, and a preference changed before
    // that read lands used to be silently reverted by it.
    final ProviderContainer racing = open();
    await racing.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await racing.read(appSettingsProvider.notifier).loaded;
    expect(racing.read(appSettingsProvider).themeMode, ThemeMode.dark);
  });

  test('an appearance choice outlives the process', () async {
    final ProviderContainer first = open();
    await first
        .read(appSettingsProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    expect(first.read(appSettingsProvider).themeMode, ThemeMode.dark);

    // Written through to the table, not just held in memory.
    final List<Setting> rows = await db.select(db.settings).get();
    expect(rows.map((Setting r) => '${r.key}=${r.value}'), contains('appearance=dark'));

    // A second container over the same database is what a relaunch looks like.
    final ProviderContainer second = open();
    // The load is deliberately not awaited at startup, so wait for the read
    // the app lets happen in the background.
    await second.read(appSettingsProvider.notifier).loaded;
    expect(second.read(appSettingsProvider).themeMode, ThemeMode.dark);
  });

  test('first run happens once', () async {
    final ProviderContainer first = open();
    await first.read(appSettingsProvider.notifier).markOnboarded();

    final ProviderContainer second = open();
    await second.read(appSettingsProvider.notifier).loaded;
    expect(second.read(appSettingsProvider).onboarded, isTrue,
        reason: 'the panels would come back on every launch');
  });

  test('appearance and first run do not overwrite each other', () async {
    final ProviderContainer c = open();
    await c.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.light);
    await c.read(appSettingsProvider.notifier).markOnboarded();

    final ProviderContainer again = open();
    await again.read(appSettingsProvider.notifier).loaded;
    final AppSettings s = again.read(appSettingsProvider);
    expect(s.themeMode, ThemeMode.light);
    expect(s.onboarded, isTrue);
  });
}
