import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/primitives.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/settings/data/app_lock.dart';
import 'package:recallos/features/settings/presentation/settings_screen.dart';

/// The "Lock the wallet" row, on a phone that cannot lock.
///
/// This is a regression suite before it is anything else. The first version of
/// this row rendered perfectly, passed every test, and was reported as broken —
/// because on a phone with no screen lock it showed a switch that did nothing
/// when tapped, with the reason in grey text underneath. The logic was right
/// and the product was wrong, and no assertion about state could have caught
/// it. What catches it is asking what happens when somebody taps.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<_Spy> pump(
    WidgetTester tester, {
    required LockUnavailable? blocked,
  }) async {
    final _Spy lock = _Spy(blocked);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLockProvider.overrideWithValue(lock),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SettingGroup(
              label: 'Privacy',
              children: <Widget>[LockRow()],
            ),
          ),
        ),
      ),
    );
    // One frame, then the availability future and the settings read.
    await tester.pump();
    await tester.pump();
    return lock;
  }

  testWidgets('offers no switch at all when the phone cannot lock',
      (WidgetTester t) async {
    await pump(t, blocked: LockUnavailable.noScreenLock);

    // A disabled switch is the thing that got reported. An unavailable control
    // should not look like a control that is merely off.
    expect(find.byType(AppSwitch), findsNothing);
    expect(find.textContaining('no screen lock yet'), findsOneWidget);
  });

  testWidgets('tapping it goes somewhere instead of nowhere',
      (WidgetTester t) async {
    final _Spy lock = await pump(t, blocked: LockUnavailable.noScreenLock);

    await t.tap(find.text('Lock the wallet'));
    await t.pumpAndSettle();

    // The whole defect in one assertion: a tap has to do something. Sending
    // the user to the screen where the missing piece is set is the only useful
    // answer an app can give here — it cannot set a screen lock itself.
    expect(lock.settingsOpened, 1);
  });

  testWidgets('says where to go by hand when nothing will open',
      (WidgetTester t) async {
    final _Spy lock = await pump(t, blocked: LockUnavailable.unknown)
      ..opens = false;

    await t.tap(find.text('Lock the wallet'));
    await t.pumpAndSettle();

    expect(lock.settingsOpened, 1);
    // A stripped-down ROM with no security activity would otherwise put us
    // straight back to a tap that silently does nothing.
    expect(find.textContaining('then Security'), findsOneWidget);
  });

  testWidgets('shows a working switch once the phone can lock',
      (WidgetTester t) async {
    await pump(t, blocked: null);

    expect(find.byType(AppSwitch), findsOneWidget);
    expect(t.widget<AppSwitch>(find.byType(AppSwitch)).onChanged, isNotNull);

    await t.tap(find.byType(AppSwitch));
    await t.pumpAndSettle();

    expect(
      (await (db.select(db.settings)
                ..where(($SettingsTable s) => s.key.equals('lock_enabled')))
              .getSingle())
          .value,
      'true',
    );
  });

  testWidgets('asks the phone again every time the app comes back',
      (WidgetTester t) async {
    final _Spy lock = await pump(t, blocked: LockUnavailable.noScreenLock);
    expect(lock.asked, 1);

    // The journey this row sends people on is: leave, set a PIN, come back.
    // Asked once at startup, it would still be telling somebody to set the
    // screen lock they had just finished setting.
    lock.blocked = null;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();

    expect(lock.asked, 2);
    expect(find.byType(AppSwitch), findsOneWidget);
  });
}

/// Counts what the row asked the platform to do.
class _Spy implements AppLock {
  _Spy(this.blocked);

  LockUnavailable? blocked;

  /// Whether the security screen exists to be opened.
  bool opens = true;

  int asked = 0;
  int settingsOpened = 0;

  @override
  Future<LockUnavailable?> unavailableReason() async {
    asked++;
    return blocked;
  }

  @override
  Future<bool> openSecuritySettings() async {
    settingsOpened++;
    return opens;
  }

  @override
  Future<UnlockResult> unlock() async => UnlockResult.unlocked;
}
