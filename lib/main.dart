import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage/out_of_space.dart';
import 'core/theme/app_theme.dart';
import 'features/followup/presentation/reminder_responder.dart';
import 'features/plus/presentation/plus_watch.dart';
import 'features/settings/data/app_settings.dart';
import 'features/settings/data/licences.dart';
import 'features/settings/presentation/lock_gate.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A write that fails on a full phone reaches no screen by itself.
  PlatformDispatcher.instance.onError = (Object e, StackTrace _) =>
      noticeOutOfSpace(e);
  // The fonts and the search model are files, not packages, so their
  // licences reach Settings → Licences only by being added here.
  registerBundledLicences();
  // Portrait only. Every screen is a one-handed, hurried, card-shaped layout
  // and none of them were designed sideways. The Android manifest pins the
  // activity as well — that is the half that stops the rotation happening at
  // all, rather than being undone a frame later.
  unawaited(
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]),
  );
  runApp(const ProviderScope(child: RecallOsApp()));
}

/// The app's language: English, written day-first (M7½). The app's own
/// words already put the day first ("Fri, 16 Oct"), the way dates are
/// written in Bangladesh; Material's date picker followed US English and
/// wrote "Fri, Oct 16" above the same calendar. In GB English it writes
/// "Fri 16 Oct".
const Locale kAppLocale = Locale('en', 'GB');

/// What gives Material, the widgets and Cupertino that language.
const List<LocalizationsDelegate<dynamic>> kAppLocalizations =
    GlobalMaterialLocalizations.delegates;

class RecallOsApp extends ConsumerWidget {
  const RecallOsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RecallOS',
      scaffoldMessengerKey: appMessengerKey,
      locale: kAppLocale,
      supportedLocales: const <Locale>[kAppLocale],
      localizationsDelegates: kAppLocalizations,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Frame 15: dark is not an inversion, and one widget tree serves both,
      // so the only thing this switch decides is which palette is installed.
      themeMode: ref.watch(appSettingsProvider).themeMode,
      routerConfig: ref.watch(routerProvider),
      // The lock lives inside the app rather than above it, so it wears the
      // same palette and the router below keeps its place. See [LockGate].
      //
      // Reminder taps are answered from here too: above every route, so a
      // notification can open a card from wherever the app happens to be.
      // Plus is kept in step with Google Play from the same place.
      builder: (BuildContext context, Widget? child) => LockGate(
        child: ReminderResponder(
          child: PlusWatch(child: child ?? const SizedBox.shrink()),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
