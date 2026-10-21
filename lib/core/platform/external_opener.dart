import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a link to the app that handles it — the dialler, WhatsApp, mail,
/// maps. Returns false when nothing on the phone could take it.
///
/// A provider, and the only way the app opens another app on a contact's
/// behalf, so a test can see what would have opened without leaving the test
/// and so every one of those hand-offs can be recorded in the same way.
final externalOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (Ref ref) =>
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
