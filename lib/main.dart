import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only. Every screen is a one-handed, hurried, card-shaped layout
  // and none of them were designed sideways. The Android manifest pins the
  // activity as well — that is the half that stops the rotation happening at
  // all, rather than being undone a frame later.
  unawaited(SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  ));
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
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
