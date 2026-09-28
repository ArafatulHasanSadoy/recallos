/// Puts a staged restore in place of the live wallet.
///
/// Runs at launch, before the database is opened — the one moment nothing is
/// holding the files — from `openEncryptedDatabase`. A restore is staged while
/// the app runs (`backup_reader.dart`), then the app restarts and this does
/// the swap.
///
/// **Every step can be interrupted.** The journal records how far the swap
/// got, each move is a single rename, and each is checked before it is made,
/// so running this again after a crash finishes the job rather than doing it
/// twice. The original wallet is moved aside, never deleted, until the restored
/// one has opened with this phone's key and holds the cards the backup said it
/// would. If it does not, the original goes back.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'backup_format.dart';

/// The wallet database's file name under the documents directory.
const String kDatabaseFileName = 'recallos.sqlite';

/// Where a restore keeps its working files.
class RestorePaths {
  RestorePaths(this.documentsDir);

  final String documentsDir;

  Directory get root => Directory(p.join(documentsDir, 'restore'));
  Directory get staged => Directory(p.join(root.path, 'staged'));
  Directory get previous => Directory(p.join(root.path, 'previous'));
  File get journal => File(p.join(root.path, 'journal.json'));
  File get result => File(p.join(documentsDir, 'restore-result.json'));

  /// Everything a restore replaces: the database and the photograph folders.
  List<String> get items => <String>[kDatabaseFileName, ...kManagedFolders];

  Map<String, Object?>? readJournal() {
    if (!journal.existsSync()) return null;
    try {
      final Object? json = jsonDecode(journal.readAsStringSync());
      return json is Map<String, Object?> ? json : null;
    } on Object {
      return null;
    }
  }

  void writeJournal(Map<String, Object?> state) {
    root.createSync(recursive: true);
    // Written to a temporary file and renamed, so a crash mid-write leaves the
    // previous journal intact rather than half a JSON document.
    final File temp = File('${journal.path}.tmp')
      ..writeAsStringSync(jsonEncode(state), flush: true);
    temp.renameSync(journal.path);
  }

  /// Drops anything a previous, finished or abandoned restore left behind.
  void clearLeftovers() {
    _delete(staged);
    _delete(previous);
    if (journal.existsSync()) journal.deleteSync();
  }

  /// A staging run failed or was abandoned before it finished.
  void abandonStaging() {
    _delete(staged);
    if (journal.existsSync()) journal.deleteSync();
  }
}

/// What the last restore did, for the one screen that tells the user.
class RestoreOutcome {
  const RestoreOutcome({required this.ok, required this.cards});
  final bool ok;
  final int cards;

  Map<String, Object?> toJson() => <String, Object?>{'ok': ok, 'cards': cards};
}

/// Finishes a staged restore, if there is one. Safe to call on every launch:
/// with no journal it does nothing.
///
/// [databaseKey] is this phone's SQLCipher key — the staged copy was
/// encrypted with it, and the check after the swap opens with it.
RestoreOutcome? finishPendingRestore({
  required String documentsDir,
  required String? databaseKey,
}) {
  final RestorePaths paths = RestorePaths(documentsDir);
  final Map<String, Object?>? journal = paths.readJournal();

  if (journal == null) {
    // Nothing pending. A root with no journal is debris from a staging run
    // that died before writing one.
    if (paths.root.existsSync() && !paths.journal.existsSync()) {
      _delete(paths.root);
    }
    return null;
  }

  final Object? state = journal['state'];
  if (state == 'staging') {
    // The app stopped while the backup was still being unpacked. The live
    // wallet was never touched; throw the half-built copy away.
    paths.abandonStaging();
    return null;
  }
  if (state != 'staged' && state != 'swapping') {
    paths.abandonStaging();
    return null;
  }

  final int expectedCards = journal['cards'] is int ? journal['cards']! as int : -1;
  paths.writeJournal(<String, Object?>{...journal, 'state': 'swapping'});
  paths.previous.createSync(recursive: true);

  for (final String item in paths.items) {
    _swapIn(paths, item);
  }

  final bool verified = _opensAndHolds(
    p.join(documentsDir, kDatabaseFileName),
    databaseKey,
    expectedCards,
  );

  if (verified) {
    _delete(paths.root);
    final RestoreOutcome outcome = RestoreOutcome(ok: true, cards: expectedCards);
    paths.result.writeAsStringSync(jsonEncode(outcome.toJson()), flush: true);
    return outcome;
  }

  // The restored wallet did not check out. Put the original back exactly.
  for (final String item in paths.items) {
    _rollBack(paths, item);
  }
  _delete(paths.root);
  const RestoreOutcome failed = RestoreOutcome(ok: false, cards: 0);
  paths.result.writeAsStringSync(jsonEncode(failed.toJson()), flush: true);
  return failed;
}

/// Reads and clears the result of the last restore, so it is reported once.
RestoreOutcome? takeRestoreOutcome(String documentsDir) {
  final File file = RestorePaths(documentsDir).result;
  if (!file.existsSync()) return null;
  try {
    final Object? json = jsonDecode(file.readAsStringSync());
    file.deleteSync();
    if (json is! Map<String, Object?>) return null;
    return RestoreOutcome(
      ok: json['ok'] == true,
      cards: json['cards'] is int ? json['cards']! as int : 0,
    );
  } on Object {
    return null;
  }
}

/// Moves the live [item] aside and the staged one into its place. Each half
/// is skipped if it has already happened, which is what makes a rerun safe.
void _swapIn(RestorePaths paths, String item) {
  final String live = p.join(paths.documentsDir, item);
  final String staged = p.join(paths.staged.path, item);
  final String aside = p.join(paths.previous.path, item);

  if (!_exists(staged)) return; // Already swapped in.

  if (_exists(live) && !_exists(aside)) {
    _move(live, aside);
    if (item == kDatabaseFileName) {
      // The write-ahead log belongs to the file it was written for. Moved with
      // it, so the original is complete if it has to come back; left behind,
      // SQLite would replay it into the restored database.
      for (final String suffix in <String>['-wal', '-shm', '-journal']) {
        if (_exists('$live$suffix')) _move('$live$suffix', '$aside$suffix');
      }
    }
  }
  _move(staged, live);
}

void _rollBack(RestorePaths paths, String item) {
  final String live = p.join(paths.documentsDir, item);
  final String aside = p.join(paths.previous.path, item);
  if (!_exists(aside)) return;
  if (_exists(live)) _deletePath(live);
  _move(aside, live);
  if (item == kDatabaseFileName) {
    for (final String suffix in <String>['-wal', '-shm', '-journal']) {
      if (_exists('$aside$suffix')) _move('$aside$suffix', '$live$suffix');
    }
  }
}

/// The restored database opens with this phone's key, is intact, and holds
/// the number of cards the backup promised.
bool _opensAndHolds(String path, String? key, int expectedCards) {
  if (!File(path).existsSync()) return false;
  Database? db;
  try {
    db = sqlite3.open(path);
    if (key != null) db.execute('PRAGMA key = "x\'$key\'";');
    final String check = '${db.select('PRAGMA quick_check').first.values.first}';
    if (check != 'ok') return false;
    if (expectedCards < 0) return true;
    final int cards = db.select('SELECT count(*) AS n FROM cards').first['n']! as int;
    return cards == expectedCards;
  } on Object {
    return false;
  } finally {
    db?.close();
  }
}

bool _exists(String path) =>
    FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

void _move(String from, String to) {
  Directory(p.dirname(to)).createSync(recursive: true);
  if (FileSystemEntity.isDirectorySync(from)) {
    Directory(from).renameSync(to);
  } else {
    File(from).renameSync(to);
  }
}

void _deletePath(String path) {
  if (FileSystemEntity.isDirectorySync(path)) {
    Directory(path).deleteSync(recursive: true);
  } else if (File(path).existsSync()) {
    File(path).deleteSync();
  }
}

void _delete(Directory dir) {
  if (dir.existsSync()) dir.deleteSync(recursive: true);
}
