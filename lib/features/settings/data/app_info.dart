import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/build_flags.dart';

/// Where feedback goes — the privacy contact in `docs/privacy-policy.html`.
const String kFeedbackEmail = 'arafatsadoy@gmail.com';

/// The published policy. Opened in the browser, so the app itself needs no
/// network permission to show it.
final Uri kPrivacyPolicyUrl = Uri.parse(
  'https://arafatulhasansadoy.github.io/recallos/privacy-policy.html',
);

/// Which build this is, and on what phone.
class AppVersion {
  const AppVersion({
    required this.name,
    required this.code,
    required this.device,
    required this.android,
  });

  final String name;
  final int code;
  final String device;
  final String android;

  /// "1.0.0 (1) · a1b2c3d" — one line a tester can paste into a report.
  String get buildId => '$name ($code) · $kBuildCommit';
}

final appInfoProvider = Provider<AppInfo>((Ref ref) => AppInfo());

/// Null when the platform did not answer — the About rows then say so rather
/// than inventing a version.
final appVersionProvider = FutureProvider<AppVersion?>(
  (Ref ref) => ref.watch(appInfoProvider).version(),
);

/// Asks Android for the installed version; see `MainActivity.version()`.
class AppInfo {
  static const MethodChannel _channel = MethodChannel('recallos/app_info');

  Future<AppVersion?> version() async {
    try {
      final Map<String, Object?>? m = await _channel
          .invokeMapMethod<String, Object?>('version');
      if (m == null) return null;
      return AppVersion(
        name: m['name'] as String? ?? '',
        code: (m['code'] as num?)?.toInt() ?? 0,
        device: m['device'] as String? ?? '',
        android: m['android'] as String? ?? '',
      );
    } on Object {
      return null;
    }
  }

  /// Relaunches the app in a fresh process. Used once: to finish a restore
  /// before anything opens the database. False when the platform said no.
  Future<bool> restart() async {
    try {
      await _channel.invokeMethod<void>('restart');
      return true;
    } on Object {
      return false;
    }
  }

  /// A mailto with the build already filled in, so the first question a bug
  /// report gets asked is answered before it is sent. The user sees and edits
  /// all of it before anything leaves the phone.
  static Uri feedbackEmail(AppVersion? v) {
    final String build = v == null
        ? 'RecallOS · $kBuildCommit'
        : 'RecallOS ${v.buildId}\n${v.device}, Android ${v.android}';
    // Encoded by hand: `Uri.queryParameters` turns spaces into "+", which mail
    // apps show literally.
    final String subject = Uri.encodeComponent('RecallOS feedback');
    final String body = Uri.encodeComponent(
      'What happened:\n\n\nWhat you expected:\n\n\n—\n$build\n',
    );
    return Uri.parse('mailto:$kFeedbackEmail?subject=$subject&body=$body');
  }
}
