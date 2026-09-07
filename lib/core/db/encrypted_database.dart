/// Encryption at rest for the wallet.
///
/// The threat this answers is the ordinary one, not a sophisticated one: a
/// phone that is lost, sold, repaired, or handed to somebody for a minute. Up
/// to now every number, address and note anyone had collected sat in a plain
/// SQLite file that any file browser with root, any backup, or anyone with the
/// phone unlocked could read straight out. The biometric lock keeps people out
/// of the *app*; this keeps them out of the *file*.
///
/// Three parts, and each is load-bearing:
///
/// 1. **SQLCipher instead of SQLite**, selected by the `hooks:` block in
///    `pubspec.yaml`. Page-level AES-256, transparent to every query already
///    written.
/// 2. **A key the app never chooses and never stores itself.** 32 random bytes
///    generated once on the phone and kept in the Android Keystore through
///    `flutter_secure_storage`, where the OS wraps it with hardware-backed RSA.
///    Not derived from a password, because there is no password — the wallet
///    has to open on a cold start before anyone has typed anything.
/// 3. **A one-way migration** of the plaintext database people already have,
///    which is the part with something to lose and is written accordingly.
///
/// What this does **not** cover, stated plainly because a half-understood
/// guarantee is worse than none: the card photographs are still ordinary JPEGs
/// in the app's documents directory. Android's own app-sandbox and full-disk
/// encryption protect them; this does not. Doing better means encrypting the
/// image files too, which is a separate change.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

/// Whether what is on disk is actually encrypted.
enum StorageProtection {
  /// SQLCipher is in the build and the file is ciphertext.
  encrypted,

  /// It is not, and the app is saying so rather than implying otherwise.
  plaintext,

  /// The file is encrypted and this phone's key does not open it.
  ///
  /// Should be unreachable — the key is made on the phone that made the file,
  /// and neither is backed up, so they cannot be separated. Named anyway,
  /// because the alternative to naming it is a crash on launch with no
  /// explanation at all.
  unreadable,
}

/// What happened when the database was opened, for the screen that reports it.
typedef StorageStatus = ({StorageProtection protection, String? reason});

/// Resolves once the database has actually been opened.
///
/// A future rather than a value because opening is lazy — nothing touches the
/// file until the first query, which is a fraction of a second into launch.
Future<StorageStatus> get storageStatus => _reported.future;
final Completer<StorageStatus> _reported = Completer<StorageStatus>();

void _report(StorageProtection protection, [String? reason]) {
  if (!_reported.isCompleted) {
    _reported.complete((protection: protection, reason: reason));
  }
}

const String _keyName = 'db_key_v1';

/// Where the wallet lives. The same path `driftDatabase(name: 'recallos')`
/// resolves, spelled out because the migration has to find the existing file
/// before drift is given a chance to open it.
Future<File> databaseFile() async {
  final Directory dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'recallos.sqlite'));
}

/// Opens the wallet, encrypted, migrating it across the first time.
///
/// Returns a delayed connection rather than doing any of this eagerly: the app
/// is built around `AppDatabase()` being cheap to construct, and a key read
/// plus a possible file copy is neither.
QueryExecutor openEncryptedDatabase() {
  return DatabaseConnection.delayed(
    Future<DatabaseConnection>(() async {
      final File file = await databaseFile();

      if (!_cipherAvailable()) {
        // The build has no SQLCipher in it. Opening anyway and pretending is the
        // one thing not to do here — `PRAGMA key` is silently ignored by plain
        // SQLite, so it would look identical and encrypt nothing.
        _report(
          StorageProtection.plaintext,
          'This build does not include SQLCipher.',
        );
        return driftDatabase(name: 'recallos');
      }

      final String? key = await _key();
      if (key == null) {
        _report(
          StorageProtection.plaintext,
          'The phone would not hand back the key.',
        );
        return driftDatabase(name: 'recallos');
      }

      if (!_opensWith(file, key)) {
        _report(
          StorageProtection.unreadable,
          'This wallet was encrypted with a key that is not on this phone. '
          'It cannot be opened here.',
        );
        // Handed to drift regardless of the verdict, so the failure arrives as
        // the error state the screens already draw rather than as a crash on the
        // first frame.
        return driftDatabase(
          name: 'recallos',
          native: DriftNativeOptions(
            setup: (CommonDatabase db) =>
                db.execute('PRAGMA key = "x\'$key\'";'),
          ),
        );
      }

      final String? trouble = await _encryptExisting(file, key);
      if (trouble != null) {
        // The plaintext file is untouched — see [_encryptExisting], which only
        // swaps a copy in once it has verified it. Carrying on unencrypted keeps
        // the user's cards reachable, and the settings screen says what
        // happened rather than leaving them to assume.
        _report(StorageProtection.plaintext, trouble);
        return driftDatabase(name: 'recallos');
      }

      _report(StorageProtection.encrypted);
      return driftDatabase(
        name: 'recallos',
        native: DriftNativeOptions(
          // Runs on every connection, before drift issues anything else — which
          // is the only place it can go: SQLCipher needs the key before the
          // first read of the header.
          setup: (CommonDatabase db) => db.execute('PRAGMA key = "x\'$key\'";'),
        ),
      );
    }),
  );
}

/// Whether this build can encrypt at all.
///
/// Checked rather than assumed. `PRAGMA cipher_version` returns a row on a
/// SQLCipher build and nothing on a plain one, and it is the only honest way
/// to tell the two apart from inside the app — a missing `PRAGMA key` raises
/// no error, it simply does nothing.
bool _cipherAvailable() {
  Database? probe;
  try {
    probe = sqlite3.openInMemory();
    final ResultSet rows = probe.select('PRAGMA cipher_version');
    return rows.isNotEmpty && '${rows.first.values.first}'.trim().isNotEmpty;
  } on Object {
    return false;
  } finally {
    probe?.close();
  }
}

/// The database key: read it, or make one and keep it.
///
/// 32 bytes from [Random.secure], hex-encoded, handed to SQLCipher in its raw
/// form so no key derivation happens at open time. A passphrase would be the
/// other option and is the wrong one here: there is nobody to ask for it on a
/// cold start, and a key people would have to remember is a key people would
/// choose badly.
Future<String?> _key() async {
  const FlutterSecureStorage store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // The default is to wipe the entry when it cannot be decrypted. For a
      // password that would be a helpful recovery; for this it is the wallet,
      // deleted — the data is still there and permanently unreadable. Fail
      // loudly instead.
      resetOnError: false,
    ),
  );

  try {
    final String? existing = await store.read(key: _keyName);
    if (existing != null && existing.length == 64) return existing;

    final Random random = Random.secure();
    final String fresh = <String>[
      for (int i = 0; i < 32; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await store.write(key: _keyName, value: fresh);
    return fresh;
  } on Object {
    return null;
  }
}

/// Converts a plaintext wallet into an encrypted one, once.
///
/// Returns null when there is nothing to do or the move succeeded, and a
/// sentence to show the user when it did not.
///
/// The order is the whole design. Nothing destructive happens until an
/// encrypted copy exists, opens with the key, and has been checked against the
/// original — so every failure path leaves the user exactly where they started,
/// with all of their cards.
Future<String?> _encryptExisting(File file, String key) async {
  // Left over from a swap that was interrupted. Safe to drop now: its
  // replacement is in place and open.
  final File stale = File('${file.path}.plain');
  if (stale.existsSync() && file.existsSync() && !_looksPlaintext(file)) {
    try {
      await stale.delete();
    } on Object {
      // A file we cannot delete is not worth failing a launch over.
    }
  }

  if (!file.existsSync()) return null; // A fresh install. Born encrypted.
  if (!_looksPlaintext(file)) return null; // Already done.

  final File temporary = File('${file.path}.encrypting');
  if (temporary.existsSync()) await temporary.delete();

  final int cards;
  final int version;
  try {
    final Database plain = sqlite3.open(file.path);
    try {
      cards = _countCards(plain);
      version = plain.select('PRAGMA user_version').first.values.first! as int;

      plain.execute('ATTACH DATABASE ? AS enc KEY "x\'$key\'"', <Object?>[
        temporary.path,
      ]);
      plain.execute("SELECT sqlcipher_export('enc')");
      // `sqlcipher_export` copies tables, indexes and rows — and not
      // `user_version`. Drift keeps its schema version there, so without this
      // line the encrypted copy would look like a brand new database and get
      // `onCreate` run over the top of a full wallet.
      plain.execute('PRAGMA enc.user_version = $version');
      plain.execute('DETACH DATABASE enc');
    } finally {
      plain.close();
    }
  } on Object catch (e) {
    await _quietlyDelete(temporary);
    return 'The wallet could not be encrypted: $e';
  }

  // Open the copy the way the app will, and count the same thing. A file that
  // exists proves nothing; a file that opens with this key and holds every
  // card proves what is about to be relied on.
  try {
    final Database check = sqlite3.open(temporary.path);
    try {
      check.execute('PRAGMA key = "x\'$key\'";');
      final int copied = _countCards(check);
      final int copiedVersion =
          check.select('PRAGMA user_version').first.values.first! as int;
      if (copied != cards || copiedVersion != version) {
        throw StateError('copied $copied of $cards cards, v$copiedVersion');
      }
    } finally {
      check.close();
    }
  } on Object catch (e) {
    await _quietlyDelete(temporary);
    return 'The encrypted copy did not check out, so nothing was changed: $e';
  }

  try {
    // The journal belongs to the file being replaced. Left behind, SQLite
    // would try to replay plaintext pages into a ciphertext database on the
    // next open, which is how a wallet gets destroyed by a feature meant to
    // protect it.
    await _quietlyDelete(File('${file.path}-wal'));
    await _quietlyDelete(File('${file.path}-shm'));

    await file.rename(stale.path);
    await temporary.rename(file.path);
    await _quietlyDelete(stale);
  } on Object catch (e) {
    return 'The encrypted wallet could not be put in place: $e';
  }

  return null;
}

/// Whether an already-encrypted wallet actually opens with [key].
///
/// True for a file that is not encrypted yet and for one that does not exist —
/// both are the migration's business, not this check's. What it is looking for
/// is the one case that would otherwise be a crash with no message: ciphertext
/// on the disk and the wrong key in the Keystore.
bool _opensWith(File file, String key) {
  if (!file.existsSync() || _looksPlaintext(file)) return true;

  Database? db;
  try {
    db = sqlite3.open(file.path);
    db.execute('PRAGMA key = "x\'$key\'";');
    // The first read of a page is what actually tests the key; opening the
    // file and setting the pragma both succeed regardless of whether it is
    // right.
    db.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on Object {
    return false;
  } finally {
    db?.close();
  }
}

/// True when the file begins the way an unencrypted SQLite database does.
///
/// Every plain database starts with the literal bytes `SQLite format 3\0`. An
/// encrypted one starts with its salt, which is random. Cheaper and safer than
/// opening the file to find out, and it cannot be confused by a wrong key.
bool _looksPlaintext(File file) {
  try {
    final RandomAccessFile handle = file.openSync();
    try {
      final List<int> head = handle.readSync(16);
      return String.fromCharCodes(head) == 'SQLite format 3\u0000';
    } finally {
      handle.closeSync();
    }
  } on Object {
    return false;
  }
}

/// How many cards the wallet holds, or zero if it has no cards table yet.
int _countCards(Database db) {
  final ResultSet exists = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'cards'",
  );
  if (exists.isEmpty) return 0;
  return db.select('SELECT count(*) AS n FROM cards').first['n']! as int;
}

Future<void> _quietlyDelete(File file) async {
  try {
    if (file.existsSync()) await file.delete();
  } on Object {
    // Tidying up is not worth failing over; see the callers.
  }
}
