import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/data/app_settings.dart';
import 'features/settings/presentation/lock_gate.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class RecallOsApp extends ConsumerWidget {
  const RecallOsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RecallOS',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Frame 15: dark is not an inversion, and one widget tree serves both,
      // so the only thing this switch decides is which palette is installed.
      themeMode: ref.watch(appSettingsProvider).themeMode,
      routerConfig: ref.watch(routerProvider),
      // The lock lives inside the app rather than above it, so it wears the
      // same palette and the router below keeps its place. See [LockGate].
      builder: (BuildContext context, Widget? child) =>
          LockGate(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
    );
  }
}
