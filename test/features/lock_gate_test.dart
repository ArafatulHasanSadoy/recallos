import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/settings/data/app_lock.dart';
import 'package:recallos/features/settings/data/app_settings.dart';
import 'package:recallos/features/settings/presentation/lock_gate.dart';

/// The gate in front of the wallet.
///
/// Almost everything here is a failure that renders perfectly. A gate that
/// opens for one frame before it shuts, or one that stays open after the app
/// has been away, looks completely correct in a screenshot — the only way to
/// see it is to drive the lifecycle and look at what is on stage.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// The wallet, standing in for the whole app below the gate.
  const Widget wallet = Text('the wallet', textDirection: TextDirection.ltr);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool locked,
    UnlockResult answer = UnlockResult.unlocked,
    Duration? grace = Duration.zero,
  }) async {
    if (locked) {
      await db.into(db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(key: 'lock_enabled', value: 'true'),
          );
    }

    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appLockProvider.overrideWithValue(_ScriptedLock(answer)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: LockGate(grace: grace, child: wallet)),
        ),
      ),
    );
    // One pump for the first frame, one for the settings read to land.
    await tester.pump();
    await tester.pump();
    return container;
  }

  /// Whether the app below the gate is actually being shown.
  ///
  /// `findsOneWidget` is not enough on its own: the gate keeps the app built
  /// while it is shut, so the widget is in the tree either way. What matters is
  /// whether it is on stage.
  bool walletVisible(WidgetTester tester) {
    final Finder offstage = find.ancestor(
      // `skipOffstage: false`, or this finds nothing at all in exactly the
      // case it is being asked about.
      of: find.text('the wallet', skipOffstage: false),
      matching: find.byType(Offstage, skipOffstage: false),
    );
    return !tester.widget<Offstage>(offstage.first).offstage;
  }

  /// Sends the app away and brings it straight back.
  ///
  /// The elapsed time is effectively zero, which is the honest thing a widget
  /// test can do: the gate stamps `DateTime.now()`, and the real clock is not
  /// something `pump` moves. Length of absence is expressed by the grace the
  /// gate was given instead — a zero grace is "gone long enough", the shipped
  /// minute is "back in a moment".
  Future<void> leaveAndReturn(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets('the lock screen has a Material above it', (WidgetTester t) async {
    await db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'lock_enabled', value: 'true'),
        );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appLockProvider.overrideWithValue(_ScriptedLock(UnlockResult.unlocked)),
      ],
    );
    addTearDown(container.dispose);

    // Built the way the app builds it — through `MaterialApp.builder`, which
    // puts the gate *beside* the navigator rather than inside it. Every other
    // screen gets its `Material` from a `Scaffold`; this one has none above it
    // at all, and Flutter marks text with no `Material` ancestor by striping a
    // yellow double underline under every line. It shipped like that: the one
    // screen meant to look composed and trustworthy, in warning yellow.
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (BuildContext _, Widget? child) =>
              LockGate(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: wallet),
        ),
      ),
    );
    await t.pump();
    await t.pump();

    expect(find.text('Only you.'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Only you.'),
        matching: find.byType(Material),
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('opens straight onto the wallet when no lock is set',
      (WidgetTester t) async {
    await pump(t, locked: false);

    expect(walletVisible(t), isTrue);
    expect(find.text('Only you.'), findsNothing);
  });

  test('the default delay is a minute', () {
    // The gate takes its grace as a parameter so a test can express "gone long
    // enough" without waiting. This is what a user who has never chosen gets.
    expect(AppSettings.defaultLockAfter, const Duration(seconds: 60));
    expect(AppSettings.lockAfterChoices.first, Duration.zero);
  });

  testWidgets('never shows the wallet before the setting has been read',
      (WidgetTester t) async {
    await db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'lock_enabled', value: 'true'),
        );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appLockProvider.overrideWithValue(_ScriptedLock(UnlockResult.unlocked)),
      ],
    );
    addTearDown(container.dispose);

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: LockGate(child: wallet)),
        ),
      ),
    );

    // The very first frame, before the asynchronous read lands. This is the
    // frame a naive gate leaks the wallet on — the stored value is not back
    // yet, and the default is "not locked".
    expect(find.text('the wallet'), findsNothing);
    expect(find.text('Only you.'), findsNothing);
  });

  testWidgets('is shut on a cold start when the lock is armed',
      (WidgetTester t) async {
    await pump(t, locked: true);

    expect(walletVisible(t), isFalse);
    expect(find.text('Only you.'), findsOneWidget);
    // Says nothing about what is behind it. A count of cards or the newest
    // name would hand the contents to whoever is holding the phone.
    expect(find.textContaining('card'), findsNothing);
  });

  testWidgets('opens once the phone says who is holding it',
      (WidgetTester t) async {
    await pump(t, locked: true);

    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();

    expect(walletVisible(t), isTrue);
  });

  testWidgets('stays shut when the prompt is dismissed',
      (WidgetTester t) async {
    await pump(t, locked: true, answer: UnlockResult.refused);

    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();

    expect(walletVisible(t), isFalse);
    // An ordinary cancel is not an error and says nothing. The shut wallet is
    // the whole message.
    expect(find.textContaining('did not work'), findsNothing);
  });

  testWidgets('says so when the sensor has locked itself out',
      (WidgetTester t) async {
    await pump(t, locked: true, answer: UnlockResult.lockedOut);

    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();

    // A person who did nothing wrong is told what happened and what still
    // works, rather than being left tapping a button that does nothing.
    expect(find.textContaining('screen PIN'), findsOneWidget);
  });

  testWidgets('a quick trip to another app does not shut it',
      (WidgetTester t) async {
    await pump(t, locked: true, grace: const Duration(seconds: 60));
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();
    expect(walletVisible(t), isTrue);

    // The scanner, the dialler and the share sheet are all separate
    // activities. Demanding a fingerprint after every scan is how a lock gets
    // switched off within a day.
    await leaveAndReturn(t);

    expect(walletVisible(t), isTrue);
  });

  testWidgets('shuts on the spot when told to', (WidgetTester t) async {
    final ProviderContainer container = await pump(t, locked: true);
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();
    expect(walletVisible(t), isTrue);

    // What the "Lock now" row in Settings does. No absence, no timer — the
    // moment somebody wants their wallet shut is the moment they are about to
    // hand the phone over.
    container.read(walletLockProvider.notifier).shut();
    await t.pumpAndSettle();

    expect(walletVisible(t), isFalse);
    expect(find.text('Only you.'), findsOneWidget);
  });

  testWidgets('takes the delay from the setting when given none',
      (WidgetTester t) async {
    // No `grace` override, so the gate uses whatever the user chose — here,
    // "Immediately". A gate that ignored the setting would look identical
    // until somebody changed it and nothing happened.
    await db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'lock_after_seconds', value: '0'),
        );
    final ProviderContainer container = await pump(t, locked: true, grace: null);
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();
    expect(walletVisible(t), isTrue);
    expect(container.read(appSettingsProvider).lockAfter, Duration.zero);

    await leaveAndReturn(t);

    expect(walletVisible(t), isFalse);
  });

  testWidgets('a stored delay of a minute survives a quick trip away',
      (WidgetTester t) async {
    await db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'lock_after_seconds', value: '60'),
        );
    await pump(t, locked: true, grace: null);
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();

    await leaveAndReturn(t);

    expect(walletVisible(t), isTrue);
  });

  testWidgets('shuts again after a real absence', (WidgetTester t) async {
    await pump(t, locked: true, grace: Duration.zero);
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();

    await leaveAndReturn(t);

    expect(walletVisible(t), isFalse);
    expect(find.text('Only you.'), findsOneWidget);
  });

  testWidgets('never shuts on an app that was never locked',
      (WidgetTester t) async {
    // Away long enough to shut a locked wallet, but this one was never armed.
    await pump(t, locked: false, grace: Duration.zero);

    await leaveAndReturn(t);

    expect(walletVisible(t), isTrue);
  });

  testWidgets('switching the lock off opens the wallet on the spot',
      (WidgetTester t) async {
    final ProviderContainer container = await pump(t, locked: true);
    expect(walletVisible(t), isFalse);

    await container.read(appSettingsProvider.notifier).setLockEnabled(false);
    await t.pumpAndSettle();

    expect(walletVisible(t), isTrue);
  });

  testWidgets('switching the lock on does not throw the user out',
      (WidgetTester t) async {
    final ProviderContainer container = await pump(t, locked: false);
    expect(walletVisible(t), isTrue);

    // They are standing right there and just chose it. Shutting the wallet in
    // their face would make the switch feel like a mistake.
    await container.read(appSettingsProvider.notifier).setLockEnabled(true);
    await t.pumpAndSettle();

    expect(walletVisible(t), isTrue);
  });
}

/// Answers the way a phone would, without one.
class _ScriptedLock implements AppLock {
  _ScriptedLock(this.answer);

  final UnlockResult answer;

  @override
  Future<LockUnavailable?> unavailableReason() async => null;

  @override
  Future<bool> openSecuritySettings() async => true;

  @override
  Future<UnlockResult> unlock() async => answer;
}
