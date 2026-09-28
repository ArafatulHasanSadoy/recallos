import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/encrypted_database.dart';
import '../../../core/imaging/photo_keyring.dart';
import '../../../core/imaging/photo_vault.dart';

/// Whether the photographs on this phone are actually sealed.
enum PhotoProtection {
  /// Every stored photograph is encrypted.
  encrypted,

  /// Some are not yet — a file that changed mid-pass, or one that would not
  /// convert. The next launch tries again.
  partial,

  /// The phone would not provide a photo key, so photographs are stored as
  /// they are. Said plainly rather than implied otherwise.
  unavailable,
}

typedef PhotoStatus = ({PhotoProtection protection, int plaintextLeft});

/// Seals any photograph still stored in the clear — every one taken before
/// photo encryption, the first time — and reports what is true afterwards.
///
/// Read once per launch, from the home screen after the retention sweep, and
/// watched by Settings. It reports the outcome of the pass that just ran, not
/// an intention: the settings row must never claim more than happened.
final photoProtectionProvider = FutureProvider<PhotoStatus>((Ref ref) async {
  // A restore is swapped in when the database opens; seal after that, so the
  // restored photographs are the ones checked.
  await storageStatus;
  final Uint8List? key = await PhotoKeyring.instance.key;
  if (key == null) {
    return (protection: PhotoProtection.unavailable, plaintextLeft: 0);
  }
  final File db = await databaseFile();
  final String documents = db.parent.path;
  final SealReport report = await Isolate.run(
    () => sealPlaintextPhotos(documents, key),
  );
  return (
    protection: report.plaintextLeft == 0
        ? PhotoProtection.encrypted
        : PhotoProtection.partial,
    plaintextLeft: report.plaintextLeft,
  );
});
