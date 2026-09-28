import 'package:flutter/foundation.dart';

import '../db/encrypted_database.dart';

/// Where everything that reads or writes a photograph gets the photo key.
///
/// A process-wide holder rather than a provider, because the one reader that
/// matters most — [SealedFileImage], inside Flutter's image cache — has no
/// `ref` to read one with. The key is fetched from the Keystore once and kept
/// for the life of the process; isolates are handed the bytes.
class PhotoKeyring {
  PhotoKeyring._();

  static final PhotoKeyring instance = PhotoKeyring._();

  Future<Uint8List?>? _key;

  /// This phone's photo key, or null when the platform has none to give —
  /// which is also what a unit test sees, so tests read and write plain files.
  Future<Uint8List?> get key => _key ??= _load();

  static Future<Uint8List?> _load() async {
    try {
      return await photoKey();
    } on Object {
      return null;
    }
  }

  /// For tests that exercise sealed photographs end to end.
  @visibleForTesting
  void debugUseKey(Uint8List? key) => _key = Future<Uint8List?>.value(key);
}
