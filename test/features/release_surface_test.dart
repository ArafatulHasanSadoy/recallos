import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the shipped build is allowed to contain.
///
/// These read source rather than running it, which is unusual and deliberate.
/// Both facts below are only false in a *release* build, and the test suite
/// runs in debug: `kDebugMode` is a compile-time `true` here, so a widget test
/// asserting "the Development group is absent" would fail on a correct app and
/// pass on a broken one. There is no runtime seam to grab.
///
/// The regression that matters is somebody deleting a guard — while tidying an
/// `if`, or moving a route — and nothing anywhere noticing until a user has a
/// developer tool in their settings, or Play asks why a card scanner wants the
/// microphone. Reading the source catches exactly that, and it is the only
/// thing that can.
///
/// The manifest assertions are a first line, not the last one: the merged
/// manifest is what ships, and `aapt dump permissions` on the built artifact
/// is still the check before any upload. This one runs in four milliseconds on
/// every commit, which is the difference.
void main() {
  String source(String path) => File(path).readAsStringSync();

  group('the developer spike screen never ships', () {
    test('the /spike route is registered only when evaluation tools are on', () {
      final String router = source('lib/router.dart');

      expect(
        router,
        contains(
          RegExp(r'if \(kEvaluationTools\)\s*\n?\s*GoRoute\(path: Routes\.spike'),
        ),
        reason: 'the spike route must be behind kEvaluationTools — it reads '
            "the user's gallery and writes raw OCR to a file",
      );
    });

    test('the Development settings group is offered only with the tools', () {
      final String settings =
          source('lib/features/settings/presentation/settings_screen.dart');

      final int guard = settings.indexOf('if (kEvaluationTools) ...<Widget>[');
      final int group = settings.indexOf("label: 'Development'");

      expect(guard, isNonNegative, reason: 'the kEvaluationTools guard is gone');
      expect(group, isNonNegative, reason: 'the Development group is gone');
      expect(
        guard,
        lessThan(group),
        reason: 'the Development group must sit inside the guard',
      );
    });

    test('evaluation tools are debug, or an explicit benchmark build — never '
        'on by default', () {
      // The benchmark build is the one way the spike reaches a release APK:
      // `--dart-define=RECALLOS_BENCH=true`, for measuring OCR under R8. That
      // APK is never uploaded. What must hold is that a plain
      // `flutter build appbundle` leaves the flag off — so no defaultValue,
      // and the tools flag is exactly debug-or-bench.
      final String flags = source('lib/core/build_flags.dart');

      expect(
        flags,
        contains("const bool kBenchBuild = bool.fromEnvironment('RECALLOS_BENCH');"),
        reason: 'kBenchBuild must read RECALLOS_BENCH with no default — a '
            'defaultValue: true would put the spike in every Play build',
      );
      expect(
        flags,
        contains('const bool kEvaluationTools = kDebugMode || kBenchBuild;'),
      );
    });
  });

  group('the manifest asks for nothing the app does not use', () {
    late String manifest;
    setUp(() => manifest = source('android/app/src/main/AndroidManifest.xml'));

    test('no RECORD_AUDIO', () {
      // Declared once for a voice-note feature that was never built. A
      // dangerous permission with nothing behind it is a Play rejection, and
      // it forces an audio disclosure on the Data Safety form for data the
      // app never touches. It comes back when recording does.
      expect(manifest, isNot(contains('RECORD_AUDIO')));
    });

    test('no INTERNET, and the removal is explicit', () {
      // Omitting it was not enough: ML Kit merges one in. The line has to be
      // present *and* carry tools:node="remove", so this asserts the removal
      // rather than the absence.
      final RegExp removed = RegExp(
        r'<uses-permission[^>]*android\.permission\.INTERNET[^>]*'
        r'tools:node="remove"',
      );
      expect(manifest, matches(removed));
    });

    test('the camera is asked for, because the app is a scanner', () {
      // The other half of the same rule: a permission the app genuinely needs
      // going missing would break capture, not tighten anything.
      expect(manifest, contains('android.permission.CAMERA'));
    });

    test('the wallet is not backed up to Google Drive', () {
      // Android's default is to back the app's files up, which for a while
      // shipped the whole plaintext wallet off the device — the largest hole
      // the zero-egress claim ever had.
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
    });
  });

  group('release signing', () {
    test('a release build refuses the debug key unless explicitly allowed', () {
      // It used to fall back silently: a bundle built on a machine without
      // the upload key looked finished and failed only when Play rejected
      // it. The refusal has to stay wired to the tasks that actually sign.
      final String gradle = source('android/app/build.gradle.kts');

      expect(gradle, contains('RECALLOS_ALLOW_DEBUG_SIGNING'));
      expect(
        gradle,
        contains(
          'val refuseReleaseSigning = !hasUploadKey && !allowDebugSigning',
        ),
      );
      expect(gradle, contains('"signReleaseBundle"'));
      expect(gradle, contains('"packageRelease"'));
      expect(gradle, contains('if (refuseReleaseSigning)'));
    });
  });

  group('the iOS purpose strings match what the app does', () {
    test('no microphone promise without a microphone feature', () {
      expect(
        source('ios/Runner/Info.plist'),
        isNot(contains('NSMicrophoneUsageDescription')),
      );
    });
  });
}
