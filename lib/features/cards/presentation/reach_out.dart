import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/enums.dart';
import '../../../core/platform/external_opener.dart';
import '../data/interaction_log.dart';

/// Opens [uri] in another app — the dialler, WhatsApp, mail, maps — and,
/// when it is about the person on [cardId], records that it opened.
///
/// Recorded only once Android has taken the hand-off, and only as *opened*
/// ([kind] is one of the `…Opened` kinds): a call placed or a message sent
/// happens out of RecallOS's sight. Search ranks people the user has reached
/// out to a little higher. A map has no [kind]: finding an office is not
/// reaching a person.
Future<void> reachOut(
  BuildContext context,
  WidgetRef ref,
  Uri uri, {
  int? cardId,
  InteractionKind? kind,
  String? detail,
}) async {
  // Resolved before the await: the screen can be gone when the app returns.
  final Future<bool> Function(Uri) open = ref.read(externalOpenerProvider);
  final InteractionLog log = ref.read(interactionLogProvider);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);

  final bool ok = await open(uri);
  if (!ok) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Nothing on this phone can open $uri')),
    );
    return;
  }
  if (cardId != null && kind != null) {
    await log.opened(cardId, kind, detail: detail);
  }
}
