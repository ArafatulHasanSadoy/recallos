/// Opens, checks and stages a backup for restore.
///
/// A backup file is untrusted input — it arrives from a file picker and could
/// be anything. Nothing here touches the live wallet: [openBackup] reads and
/// checks, and [stageRestore] builds a complete replacement next to the live
/// wallet, which `restore_swap.dart` swaps in on the next launch.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../imaging/photo_vault.dart';
import 'backup_crypto.dart';
import 'backup_format.dart';
import 'restore_swap.dart';

/// A backup whose passphrase has been checked. Holds the content key so the
/// slow key derivation is not paid twice.
class OpenedBackup {
  const OpenedBackup({
    required this.manifest,
    required this.contentKey,
    required this.headerBytes,
  });

  final BackupManifest manifest;
  final Uint8List contentKey;
  final Uint8List headerBytes;

  BackupPreview get preview => BackupPreview(manifest: manifest);
}

/// Checks the file, the passphrase and the manifest. Fast apart from the key
/// derivation; does not decrypt the photographs.
OpenedBackup openBackup({
  required String archivePath,
  required String passphrase,
  required int appSchemaVersion,
  BackupLimits limits = const BackupLimits(),
}) {
  final _Zip zip = _Zip.open(archivePath, limits);
  try {
    final Uint8List headerBytes = zip.read(kHeaderEntry, limits.maxHeaderBytes);
    final BackupHeader header = BackupHeader.parse(headerBytes);

    final Uint8List contentKey;
    try {
      contentKey = open(
        deriveKey(passphrase, header.kdf),
        header.wrappedKey,
        wrapAad(header.archiveId),
      );
    } on BackupAuthError {
      throw const BackupException(BackupProblem.wrongPassphraseOrDamaged);
    }

    final BackupManifest manifest = _readManifest(
      zip,
      header,
      headerBytes,
      contentKey,
      limits,
    );
    if (manifest.schemaVersion > appSchemaVersion) {
      throw const BackupException(BackupProblem.tooNew, 'schema version');
    }
    return OpenedBackup(
      manifest: manifest,
      contentKey: contentKey,
      headerBytes: headerBytes,
    );
  } finally {
    zip.close();
  }
}

/// Decrypts every entry and checks it against the manifest, writing nothing.
void verifyContents(
  String archivePath,
  OpenedBackup opened, {
  BackupLimits limits = const BackupLimits(),
}) {
  final _Zip zip = _Zip.open(archivePath, limits);
  try {
    _readData(zip, opened, limits);
    for (final BackupAsset asset in opened.manifest.assets) {
      _readAsset(zip, opened, asset, limits);
    }
  } finally {
    zip.close();
  }
}

/// Everything a staging run needs, as plain data so it can cross an isolate.
class StageJob {
  const StageJob({
    required this.archivePath,
    required this.contentKey,
    required this.headerBytes,
    required this.documentsDir,
    required this.databaseKey,
    required this.appSchemaVersion,
    this.photoKey,
    this.limits = const BackupLimits(),
  });

  final String archivePath;
  final Uint8List contentKey;
  final Uint8List headerBytes;
  final String documentsDir;
  final String? databaseKey;
  final int appSchemaVersion;

  /// The restoring phone's photo key; restored photographs are sealed with it.
  final Uint8List? photoKey;
  final BackupLimits limits;
}

/// Builds the restored wallet beside the live one and records that it is
/// ready. Returns the number of cards staged.
///
/// Leaves the live wallet exactly as it was whatever happens; on any failure
/// the half-built copy is deleted and the error rethrown.
int stageRestore(StageJob job) {
  final RestorePaths paths = RestorePaths(job.documentsDir);
  paths.clearLeftovers();
  paths.writeJournal(<String, Object?>{'state': 'staging'});

  final _Zip zip = _Zip.open(job.archivePath, job.limits);
  try {
    final BackupHeader header = BackupHeader.parse(
      zip.read(kHeaderEntry, job.limits.maxHeaderBytes),
    );
    final BackupManifest manifest = _readManifest(
      zip,
      header,
      job.headerBytes,
      job.contentKey,
      job.limits,
    );
    if (manifest.schemaVersion > job.appSchemaVersion) {
      throw const BackupException(BackupProblem.tooNew, 'schema version');
    }
    final OpenedBackup opened = OpenedBackup(
      manifest: manifest,
      contentKey: job.contentKey,
      headerBytes: job.headerBytes,
    );

    // The folders exist even when empty, so the swap always replaces them —
    // a restore replaces the wallet, and that includes its photographs.
    for (final String folder in kManagedFolders) {
      Directory(p.join(paths.staged.path, folder)).createSync(recursive: true);
    }

    final Map<String, String> remap = <String, String>{};
    for (final BackupAsset asset in manifest.assets) {
      final Uint8List bytes = _readAsset(zip, opened, asset, job.limits);
      final String relative = p.joinAll(p.posix.split(asset.relativePath));
      writePhotoSync(p.join(paths.staged.path, relative), bytes, job.photoKey);
      remap[asset.originalPath] = p.join(job.documentsDir, relative);
    }

    final Map<String, Object?> data = _readData(zip, opened, job.limits);
    _buildDatabase(
      File(p.join(paths.staged.path, kDatabaseFileName)).path,
      job.databaseKey,
      data,
      manifest,
      remap,
    );

    paths.writeJournal(<String, Object?>{
      'state': 'staged',
      'archiveId': manifest.archiveId,
      'cards': manifest.count('cards'),
      'createdAt': manifest.createdAt.toIso8601String(),
    });
    return manifest.count('cards');
  } on Object {
    paths.abandonStaging();
    rethrow;
  } finally {
    zip.close();
  }
}

BackupManifest _readManifest(
  _Zip zip,
  BackupHeader header,
  Uint8List headerBytes,
  Uint8List contentKey,
  BackupLimits limits,
) {
  final Uint8List bytes;
  try {
    bytes = open(
      contentKey,
      zip.read(kManifestEntry, limits.maxManifestBytes),
      entryAad(header.archiveId, kManifestEntry, headerBytes: headerBytes),
    );
  } on BackupAuthError {
    // The passphrase already opened the key, so this is tampering.
    throw const BackupException(BackupProblem.damaged, 'manifest seal');
  }
  final BackupManifest manifest = BackupManifest.parse(
    bytes,
    header.archiveId,
  );

  final Set<String> listed = <String>{};
  for (final BackupAsset asset in manifest.assets) {
    if (!_isSafeRelative(asset.relativePath)) {
      throw const BackupException(BackupProblem.damaged, 'asset path');
    }
    if (!listed.add(asset.entry) || !zip.has(asset.entry)) {
      throw const BackupException(BackupProblem.damaged, 'asset entry');
    }
  }
  final Set<String> present = zip.names.where((String n) => n.startsWith('assets/')).toSet();
  if (present.length != listed.length) {
    throw const BackupException(BackupProblem.damaged, 'unlisted assets');
  }
  return manifest;
}

Map<String, Object?> _readData(_Zip zip, OpenedBackup opened, BackupLimits limits) {
  final BackupManifest m = opened.manifest;
  final Uint8List bytes = _openEntry(zip, opened, kDataEntry, limits.maxDataBytes);
  if (bytes.length != m.dataSize || sha256Hex(bytes) != m.dataSha256) {
    throw const BackupException(BackupProblem.damaged, 'data digest');
  }
  final Object? json = jsonDecode(utf8.decode(bytes));
  if (json is! Map<String, Object?>) {
    throw const BackupException(BackupProblem.damaged, 'data shape');
  }
  return json;
}

Uint8List _readAsset(
  _Zip zip,
  OpenedBackup opened,
  BackupAsset asset,
  BackupLimits limits,
) {
  final Uint8List bytes = _openEntry(zip, opened, asset.entry, limits.maxAssetBytes);
  if (bytes.length != asset.size || sha256Hex(bytes) != asset.sha256) {
    throw const BackupException(BackupProblem.damaged, 'photo digest');
  }
  return bytes;
}

Uint8List _openEntry(_Zip zip, OpenedBackup opened, String entry, int max) {
  try {
    return open(
      opened.contentKey,
      zip.read(entry, max + 64),
      entryAad(opened.manifest.archiveId, entry),
    );
  } on BackupAuthError {
    throw BackupException(BackupProblem.damaged, 'seal: $entry');
  }
}

/// A relative path inside one of the folders RecallOS manages, and nothing
/// that could climb out of it.
bool _isSafeRelative(String relative) {
  if (relative.isEmpty || relative.contains('\\')) return false;
  if (p.posix.isAbsolute(relative)) return false;
  final List<String> parts = p.posix.split(relative);
  if (parts.length < 2 || !kManagedFolders.contains(parts.first)) return false;
  return !parts.any((String s) => s == '..' || s == '.' || s.isEmpty) &&
      p.posix.normalize(relative) == relative;
}

final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Only statements that create schema objects. The schema travels inside the
/// authenticated payload, but a restore still does not run arbitrary SQL from
/// a file: `ATTACH` or a `PRAGMA` has no business in it.
final RegExp _allowedDdl = RegExp(
  r'^CREATE\s+(TABLE|VIRTUAL\s+TABLE|INDEX|UNIQUE\s+INDEX|TRIGGER|VIEW)\s',
  caseSensitive: false,
);

void _buildDatabase(
  String path,
  String? key,
  Map<String, Object?> data,
  BackupManifest manifest,
  Map<String, String> remap,
) {
  BackupException bad(String why) =>
      BackupException(BackupProblem.damaged, 'database: $why');

  final Object? schema = data['schema'];
  final Object? tables = data['tables'];
  if (schema is! List<Object?> || tables is! Map<String, Object?>) {
    throw bad('shape');
  }

  final Database db = sqlite3.open(path);
  try {
    if (key != null) db.execute('PRAGMA key = "x\'$key\'";');
    db.execute('PRAGMA foreign_keys = OFF');
    db.execute('BEGIN');

    for (final Object? statement in schema) {
      if (statement is! String || !_allowedDdl.hasMatch(statement.trimLeft())) {
        throw bad('schema statement');
      }
      // `checkNoTail` refuses a second statement smuggled after the first.
      final PreparedStatement s = db.prepare(statement, checkNoTail: true);
      try {
        s.execute();
      } finally {
        s.close();
      }
    }

    final Set<String> known = <String>{
      for (final Row r in db.select(
        "SELECT name FROM pragma_table_list WHERE schema = 'main' "
        "AND type = 'table'",
      ))
        r['name']! as String,
    };

    tables.forEach((String table, Object? body) {
      if (!_identifier.hasMatch(table) || !known.contains(table)) {
        throw bad('table $table');
      }
      if (body is! Map<String, Object?>) throw bad('table body');
      final Object? columns = body['columns'];
      final Object? rows = body['rows'];
      if (columns is! List<Object?> || rows is! List<Object?>) {
        throw bad('columns/rows');
      }
      final Set<String> real = <String>{
        for (final Row r in db.select('PRAGMA table_info("$table")'))
          r['name']! as String,
      };
      final List<String> names = <String>[];
      for (final Object? c in columns) {
        if (c is! String || !_identifier.hasMatch(c) || !real.contains(c)) {
          throw bad('column');
        }
        names.add(c);
      }
      if (names.isEmpty) return;

      final PreparedStatement insert = db.prepare(
        'INSERT INTO "$table" (${names.map((String n) => '"$n"').join(', ')}) '
        'VALUES (${List<String>.filled(names.length, '?').join(', ')})',
      );
      try {
        for (final Object? row in rows) {
          if (row is! List<Object?> || row.length != names.length) {
            throw bad('row');
          }
          insert.execute(<Object?>[
            for (int i = 0; i < names.length; i++)
              _decode(names[i], row[i], remap),
          ]);
        }
      } finally {
        insert.close();
      }
    });

    db.execute('COMMIT');
    db.execute('PRAGMA user_version = ${manifest.schemaVersion}');

    if (db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw bad('foreign keys');
    }
    final String integrity = '${db.select('PRAGMA integrity_check').first.values.first}';
    if (integrity != 'ok') throw bad('integrity: $integrity');

    // A payload cut short would otherwise pass as a smaller wallet.
    for (final String table in tables.keys) {
      final int n = db.select('SELECT count(*) AS n FROM "$table"').first['n']! as int;
      if (n != manifest.count(table)) throw bad('count $table');
    }
  } finally {
    db.close();
  }
}

Object? _decode(String column, Object? value, Map<String, String> remap) {
  if (value is Map<String, Object?>) {
    final Object? b = value['b'];
    if (b is! String) {
      throw const BackupException(BackupProblem.damaged, 'cell');
    }
    return base64.decode(b);
  }
  // A photograph's path on the phone that made the backup becomes its path
  // on this one.
  if (value is String && column.endsWith('_path')) {
    return remap[value] ?? value;
  }
  if (value == null || value is int || value is double || value is String) {
    return value;
  }
  throw const BackupException(BackupProblem.damaged, 'cell type');
}

/// The archive's entries, read lazily from disk and bounded before reading.
class _Zip {
  _Zip._(this._input, this._entries);

  factory _Zip.open(String path, BackupLimits limits) {
    final File file = File(path);
    if (!file.existsSync()) {
      throw const BackupException(BackupProblem.notABackup, 'missing file');
    }
    if (file.lengthSync() > limits.maxArchiveBytes) {
      throw const BackupException(BackupProblem.tooLarge, 'archive size');
    }
    final InputFileStream input = InputFileStream(path);
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } on Object {
      input.closeSync();
      throw const BackupException(BackupProblem.notABackup, 'not a zip');
    }
    final Map<String, ArchiveFile> entries = <String, ArchiveFile>{};
    try {
      if (archive.files.length > limits.maxEntries) {
        throw const BackupException(BackupProblem.tooLarge, 'entry count');
      }
      for (final ArchiveFile f in archive.files) {
        if (!f.isFile || !kAllowedEntry.hasMatch(f.name)) {
          throw BackupException(BackupProblem.notABackup, 'entry ${f.name}');
        }
        if (f.compression != CompressionType.none) {
          throw const BackupException(BackupProblem.notABackup, 'compressed');
        }
        if (entries.containsKey(f.name)) {
          throw const BackupException(BackupProblem.notABackup, 'duplicate');
        }
        entries[f.name] = f;
      }
      for (final String required in <String>[
        kHeaderEntry,
        kManifestEntry,
        kDataEntry,
      ]) {
        if (!entries.containsKey(required)) {
          throw BackupException(BackupProblem.notABackup, 'no $required');
        }
      }
    } on Object {
      input.closeSync();
      rethrow;
    }
    return _Zip._(input, entries);
  }

  final InputFileStream _input;
  final Map<String, ArchiveFile> _entries;

  Iterable<String> get names => _entries.keys;
  bool has(String name) => _entries.containsKey(name);

  Uint8List read(String name, int max) {
    final ArchiveFile? f = _entries[name];
    if (f == null) throw BackupException(BackupProblem.damaged, 'no $name');
    if (f.size > max) throw BackupException(BackupProblem.tooLarge, name);
    final Uint8List? bytes;
    try {
      bytes = f.readBytes();
    } on Object {
      throw BackupException(BackupProblem.damaged, 'read $name');
    }
    if (bytes == null || bytes.length != f.size || bytes.length > max) {
      throw BackupException(BackupProblem.damaged, 'truncated $name');
    }
    return bytes;
  }

  void close() => _input.closeSync();
}
