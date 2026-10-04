import 'package:flutter/foundation.dart';

/// Set only by a benchmark build:
///
/// ```bash
/// flutter build apk --release --dart-define=RECALLOS_BENCH=true
/// ```
///
/// OCR has to be measured on a release build — R8 once made release OCR
/// return zero blocks while debug was fine, so a debug score says nothing about
/// what users get. But the evaluation screen reads whatever is picked out of
/// the gallery and writes raw OCR to a file, which must never reach Play. This
/// flag is how both hold: the benchmark APK is release-optimised with the
/// screen compiled in, and is never uploaded; the Play bundle is built without
/// the define, so the default below is what ships.
///
/// `test/features/release_surface_test.dart` pins that default to false.
const bool kBenchBuild = bool.fromEnvironment('RECALLOS_BENCH');

/// Whether developer evaluation tools — the OCR spike screen and its Settings
/// entry — exist in this build. A compile-time constant, so in a Play build the
/// route and the row are not merely hidden; they are not compiled at all.
const bool kEvaluationTools = kDebugMode || kBenchBuild;

/// The commit this build was made from, stamped by the build:
///
/// ```bash
/// flutter build appbundle --dart-define=RECALLOS_COMMIT=$(git rev-parse --short HEAD)
/// ```
///
/// Shown in Settings → About and put into feedback emails, so a report from a
/// closed tester names the exact code it is about. "local" means nobody
/// stamped it — a build from a laptop, not a release.
const String kBuildCommit = String.fromEnvironment(
  'RECALLOS_COMMIT',
  defaultValue: 'local',
);

/// Treats RecallOS Plus as bought, to walk paid features on a phone before
/// Play can sell them — Play's licence testing needs the app on a track and
/// the product created, and a feature should be walked before either:
///
/// ```bash
/// flutter build apk --release --dart-define=RECALLOS_BENCH=true \
///   --dart-define=RECALLOS_PLUS_PREVIEW=true
/// ```
///
/// Only inside an evaluation build, which is never uploaded: in a Play bundle
/// `kEvaluationTools` is false, so this is false whatever is defined.
/// `test/features/release_surface_test.dart` pins that.
const bool kPlusPreview =
    kEvaluationTools && bool.fromEnvironment('RECALLOS_PLUS_PREVIEW');
