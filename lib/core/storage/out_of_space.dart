import 'package:flutter/material.dart';

/// What a full phone looks like, and what to say about it.
///
/// Most writes in the app are not wrapped in anything, so a full phone used
/// to mean a sheet that closed as if it had saved, with nothing on the screen
/// and nothing in the wallet.

/// The app's own messenger, so a failure can be reported from outside any
/// screen.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const String kOutOfSpaceNotice =
    'Your phone is out of storage, so that was not saved. Free up some space '
    'and try again.';

/// Whether [error] is the phone having run out of room: a file that could not
/// be written, or the database's own word for it. Matched on the text because
/// the database's error can arrive wrapped.
bool isOutOfSpace(Object error) {
  final String text = '$error';
  return text.contains('No space left') || text.contains('disk is full');
}

/// The sentence for a failed save: plain words for a full phone, and
/// [otherwise] with the detail for anything else.
String failureWords(Object error, String otherwise) =>
    isOutOfSpace(error) ? kOutOfSpaceNotice : '$otherwise: $error';

/// Says so when an error nobody caught was a full phone. True when it was.
bool noticeOutOfSpace(Object error) {
  if (!isOutOfSpace(error)) return false;
  appMessengerKey.currentState?.showSnackBar(
    const SnackBar(content: Text(kOutOfSpaceNotice)),
  );
  return true;
}
