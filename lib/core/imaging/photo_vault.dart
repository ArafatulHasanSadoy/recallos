/// Photographs at rest, encrypted.
///
/// The database has been SQLCipher since September; the card photographs sat
/// beside it as ordinary JPEGs, so anyone who could read the app's files saw
/// every card anyway. This seals each photograph with ChaCha20-Poly1305 — the
/// same construction the backup uses, pinned to RFC 8439 in
/// `test/core/backup_crypto_test.dart` — under a key that is not the database
/// key (one key per purpose) and lives only in the Android Keystore.
///
/// A sealed file is `RCPH` · version byte · nonce · ciphertext · tag. Anything
/// without that header is read as it is, which is what lets photographs taken
/// before this change keep working until [sealPlaintextPhotos] has converted
/// them, and lets the same reading code handle a gallery picture that was never
/// stored at all.
///
/// Pure Dart with no Flutter import: the image processor, the backup and the
/// migration all run it inside isolates.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../backup/backup_crypto.dart';
import '../backup/backup_format.dart' show kManagedFolders;

const List<int> _magic = <int>[0x52, 0x43, 0x50, 0x48]; // "RCPH"
const int _version = 1;
const int _headerLength = 5;
final Uint8List _aad = Uint8List.fromList(utf8.encode('recallos-photo/v1'));

/// File-name prefix of the short-lived plain copies OCR reads (ML Kit needs a
/// real JPEG on disk). They live in the app's private cache, are deleted as
/// soon as OCR returns, and the retention sweep removes any a crash left.
const String kPlainTempPrefix = 'recallos_plain_';

/// A sealed photograph could not be opened: no key on this phone, or its
/// bytes were changed.
class PhotoLockedException implements Exception {
  const PhotoLockedException(this.reason);
  final String reason;
  @override
  String toString() => 'PhotoLockedException: $reason';
}

/// Whether [bytes] begin like a photograph sealed by [sealPhoto].
bool isSealedPhoto(List<int> bytes) {
  if (bytes.length < _headerLength) return false;
  for (int i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return false;
  }
  return bytes[4] == _version;
}

/// Encrypts [plain] (JPEG bytes) under [key].
Uint8List sealPhoto(Uint8List key, Uint8List plain) {
  final Uint8List body = seal(key, plain, _aad);
  return Uint8List(_headerLength + body.length)
    ..setRange(0, _magic.length, _magic)
    ..[4] = _version
    ..setRange(_headerLength, _headerLength + body.length, body);
}

/// The JPEG inside [bytes]. Unsealed bytes come back unchanged.
///
/// Throws [PhotoLockedException] for a sealed photograph with no [key], the
/// wrong key, or a single changed byte.
Uint8List openPhoto(Uint8List? key, Uint8List bytes) {
  if (!isSealedPhoto(bytes)) return bytes;
  if (key == null) {
    throw const PhotoLockedException('no photo key on this phone');
  }
  try {
    return open(key, Uint8List.sublistView(bytes, _headerLength), _aad);
  } on BackupAuthError {
    throw const PhotoLockedException('photo does not open with this key');
  }
}

/// Reads a stored photograph, decrypted.
Uint8List readPhotoSync(String path, Uint8List? key) =>
    openPhoto(key, File(path).readAsBytesSync());

/// Writes a photograph, sealed when there is a [key].
///
/// Written beside the target and renamed over it, so a reader — or a crash —
/// never sees half a file.
void writePhotoSync(String path, Uint8List plain, Uint8List? key) {
  final Uint8List bytes = key == null ? plain : sealPhoto(key, plain);
  final File temp = File('$path.writing')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes, flush: true);
  temp.renameSync(path);
}

/// Copies a photograph into app storage, sealed. [from] may be sealed or
/// plain — a scanner's cache file is plain, a stored copy is sealed.
void sealCopySync(String from, String to, Uint8List? key) =>
    writePhotoSync(to, readPhotoSync(from, key), key);

/// What one pass of [sealPlaintextPhotos] found.
class SealReport {
  const SealReport({required this.sealed, required this.plaintextLeft});

  /// Photographs converted on this pass.
  final int sealed;

  /// Photographs still readable without a key afterwards — should be zero.
  final int plaintextLeft;
}

/// Encrypts every photograph still stored in the clear, in place.
///
/// Runs at launch until nothing is left to do, so it is written to be
/// interrupted: each file is sealed to a temporary copy, the copy is opened
/// and compared with the original, and only then renamed over it. A file that
/// changed while this was working is left for the next pass rather than
/// overwritten with a stale version.
SealReport sealPlaintextPhotos(String documentsDir, Uint8List key) {
  int sealed = 0;
  int left = 0;
  for (final String folder in kManagedFolders) {
    final Directory dir = Directory(p.join(documentsDir, folder));
    if (!dir.existsSync()) continue;
    for (final FileSystemEntity entry in dir.listSync(recursive: true)) {
      if (entry is! File) continue;
      if (entry.path.endsWith('.writing')) {
        // A write that never finished. The file it was meant to replace is
        // still there, whole.
        _quietlyDelete(entry);
        continue;
      }
      try {
        final FileStat before = entry.statSync();
        final Uint8List plain = entry.readAsBytesSync();
        if (plain.isEmpty || isSealedPhoto(plain)) continue;

        final Uint8List sealedBytes = sealPhoto(key, plain);
        if (!_same(openPhoto(key, sealedBytes), plain)) {
          left++;
          continue;
        }
        final File temp = File('${entry.path}.writing')
          ..writeAsBytesSync(sealedBytes, flush: true);
        final FileStat now = entry.statSync();
        if (now.modified != before.modified || now.size != before.size) {
          _quietlyDelete(temp);
          left++;
          continue;
        }
        temp.renameSync(entry.path);
        sealed++;
      } on Object {
        left++;
      }
    }
  }
  return SealReport(sealed: sealed, plaintextLeft: left);
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _quietlyDelete(File file) {
  try {
    if (file.existsSync()) file.deleteSync();
  } on Object {
    // Tidying up is not worth failing over.
  }
}
