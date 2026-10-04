import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs around every test file.
///
/// The Android Keystore, as a fresh phone has it: asked for something, it
/// holds nothing. Without this, a read waits on a real platform that a
/// widget test's fake clock never runs, so any screen that asks whether
/// RecallOS Plus is on — the step sheet does, before it opens — waits
/// forever. Every other call still fails as "no plugin", exactly as it did
/// before, so the wallet's own key handling meets the same test world as
/// always. Tests about Plus override the grant store and never reach here.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'read') return null;
          throw MissingPluginException('No Keystore in tests');
        },
      );
  await testMain();
}
