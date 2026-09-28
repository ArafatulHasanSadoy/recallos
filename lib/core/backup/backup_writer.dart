/// Writes an encrypted backup of the wallet. See `backup_format.dart` for
/// what the file is.
///
/// Pure Dart with no platform channels, so it runs inside `Isolate.run` and
/// inside tests unchanged. The caller supplies everything the platform knows:
/// where the database is, its key, the documents directory.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../imaging/photo_vault.dart';
import 'backup_crypto.dart';
import 'backup_format.dart';
import 'backup_reader.dart';

/// Everything a backup run needs, as plain data so it can cross an isolate.
class BackupWriteJob {
  const BackupWriteJob({
    required this.databasePath,
    required this.databaseKey,
    required this.documentsDir,
    required this.outputPath,
    required this.passphrase,
    required this.appVersion,
    this.photoKey,
    this.kdf,
  });

  final String databasePath;

  /// The SQLCipher key as 64 hex characters, or null for a plain database.
  final String? databaseKey;
  final String documentsDir;
  final String outputPath;
  final String passphrase;
  final String appVersion;

  /// This phone's photo key. Photographs are opened with it on the way out, so
  /// the backup holds the pictures themselves — sealed under the backup's own
  /// key — and a restoring phone seals them again under its own.
  final Uint8List? photoKey;

  /// Overridden by tests to keep them fast; production uses fresh defaults.
  final KdfParams? kdf;
}

/// Tables whose rows are not user data and are rebuilt after a restore. The
/// search index is a virtual table and never appears in the table list at all.
const Set<String> _derivedTables = <String>{'embeddings'};

/// Writes the backup to [BackupWriteJob.outputPath], then opens it again and
/// checks every entry before returning. A backup that has not been read back
/// is a hope, not a backup.
BackupManifest writeBackup(BackupWriteJob job) {
  final _Snapshot snapshot = _readSnapshot(job);

  final String archiveId = sha256Hex(randomBytes(32)).substring(0, 32);
  final Uint8List contentKey = randomBytes(32);
  final KdfParams kdf = job.kdf ?? KdfParams.fresh();
  final Uint8List kek = deriveKey(job.passphrase, kdf);

  final BackupHeader header = BackupHeader(
    archiveId: archiveId,
    kdf: kdf,
    wrappedKey: seal(kek, contentKey, wrapAad(archiveId)),
  );
  final Uint8List headerBytes = Uint8List.fromList(
    utf8.encode(jsonEncode(header.toJson())),
  );

  final Uint8List dataBytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'schema': snapshot.schema,
        'tables': snapshot.tables,
      }),
    ),
  );

  final File out = File(job.outputPath);
  if (out.existsSync()) out.deleteSync();
  final ZipFileEncoder zip = ZipFileEncoder()
    ..create(job.outputPath, level: ZipFileEncoder.store);

  final List<BackupAsset> assets = <BackupAsset>[];
  try {
    zip.addArchiveFile(_stored(kHeaderEntry, headerBytes));
    zip.addArchiveFile(
      _stored(
        kDataEntry,
        seal(contentKey, dataBytes, entryAad(archiveId, kDataEntry)),
      ),
    );

    for (final _AssetFile file in snapshot.assets) {
      final Uint8List bytes = readPhotoSync(file.path, job.photoKey);
      final String entry = assetEntry(assets.length);
      zip.addArchiveFile(
        _stored(entry, seal(contentKey, bytes, entryAad(archiveId, entry))),
      );
      assets.add(
        BackupAsset(
          entry: entry,
          originalPath: file.path,
          relativePath: file.relativePath,
          sha256: sha256Hex(bytes),
          size: bytes.length,
        ),
      );
    }

    final BackupManifest manifest = BackupManifest(
      archiveId: archiveId,
      createdAt: DateTime.now().toUtc(),
      appVersion: job.appVersion,
      schemaVersion: snapshot.schemaVersion,
      counts: snapshot.counts,
      dataSha256: sha256Hex(dataBytes),
      dataSize: dataBytes.length,
      assets: assets,
      missingFiles: snapshot.missingFiles,
    );
    zip.addArchiveFile(
      _stored(
        kManifestEntry,
        seal(
          contentKey,
          Uint8List.fromList(utf8.encode(jsonEncode(manifest.toJson()))),
          entryAad(archiveId, kManifestEntry, headerBytes: headerBytes),
        ),
      ),
    );
    zip.closeSync();

    // Read it back exactly as a restore would, down to every photograph's
    // digest. Anything wrong here fails the backup rather than leaving the
    // user with a file that looks fine and restores nothing.
    final OpenedBackup check = openBackup(
      archivePath: job.outputPath,
      passphrase: job.passphrase,
      appSchemaVersion: snapshot.schemaVersion,
    );
    verifyContents(job.outputPath, check);
    return manifest;
  } on Object {
    try {
      zip.closeSync();
    } on Object {
      // Already closed.
    }
    if (out.existsSync()) out.deleteSync();
    rethrow;
  }
}

ArchiveFile _stored(String name, Uint8List bytes) =>
    ArchiveFile.bytes(name, bytes)..compression = CompressionType.none;

class _AssetFile {
  const _AssetFile(this.path, this.relativePath);
  final String path;
  final String relativePath;
}

class _Snapshot {
  const _Snapshot({
    required this.schemaVersion,
    required this.schema,
    required this.tables,
    required this.counts,
    required this.assets,
    required this.missingFiles,
  });

  final int schemaVersion;
  final List<String> schema;
  final Map<String, Object?> tables;
  final Map<String, int> counts;
  final List<_AssetFile> assets;
  final int missingFiles;
}

/// Reads the whole wallet inside one read transaction, so a card saved
/// halfway through a backup is either in it completely or not at all.
_Snapshot _readSnapshot(BackupWriteJob job) {
  // Opened read-write but only read from: a read-only connection cannot
  // always attach to a database another connection has open, and this one is
  // open in the app while the backup runs.
  final Database db = sqlite3.open(job.databasePath);
  try {
    final String? key = job.databaseKey;
    if (key != null) db.execute('PRAGMA key = "x\'$key\'";');
    db.execute('BEGIN');
    try {
      final int version =
          db.select('PRAGMA user_version').first.values.first! as int;

      final Set<String> shadow = <String>{
        for (final Row r in db.select(
          "SELECT name FROM pragma_table_list WHERE schema = 'main' "
          "AND type = 'shadow'",
        ))
          r['name']! as String,
      };
      // Tables first, then everything that refers to them.
      final List<String> schema = <String>[
        for (final Row r in db.select(
          'SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL '
          "AND name NOT LIKE 'sqlite_%' ORDER BY "
          "CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 "
          "WHEN 'view' THEN 2 ELSE 3 END, rowid",
        ))
          if (!shadow.contains(r['name']))
            r['sql']! as String,
      ];

      final List<String> tableNames = <String>[
        for (final Row r in db.select(
          "SELECT name FROM pragma_table_list WHERE schema = 'main' "
          "AND type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        ))
          r['name']! as String,
      ];

      final Map<String, Object?> tables = <String, Object?>{};
      final Map<String, int> counts = <String, int>{};
      final Set<String> paths = <String>{};

      for (final String table in tableNames) {
        final ResultSet rows = db.select('SELECT * FROM "$table"');
        counts[table] = _derivedTables.contains(table) ? 0 : rows.length;
        if (_derivedTables.contains(table)) continue;

        final List<String> columns = rows.columnNames;
        tables[table] = <String, Object?>{
          'columns': columns,
          'rows': <Object?>[
            for (final Row row in rows)
              <Object?>[for (final Object? v in row.values) _encode(v)],
          ],
        };
        for (int c = 0; c < columns.length; c++) {
          if (!columns[c].endsWith('_path')) continue;
          for (final Row row in rows) {
            final Object? v = row.values[c];
            if (v is String && v.isNotEmpty) paths.add(v);
          }
        }
      }

      final List<_AssetFile> assets = <_AssetFile>[];
      int missing = 0;
      for (final String path in paths.toList()..sort()) {
        final String? relative = _managedRelative(job.documentsDir, path);
        if (relative == null || !File(path).existsSync()) {
          missing++;
          continue;
        }
        assets.add(_AssetFile(path, relative));
      }

      return _Snapshot(
        schemaVersion: version,
        schema: schema,
        tables: tables,
        counts: counts,
        assets: assets,
        missingFiles: missing,
      );
    } finally {
      db.execute('COMMIT');
    }
  } finally {
    db.close();
  }
}

/// `cards/card_12.jpg` for a file inside a folder RecallOS manages, null for
/// anything else.
String? _managedRelative(String documentsDir, String path) {
  if (!p.isWithin(documentsDir, path)) return null;
  final String relative = p.relative(path, from: documentsDir);
  final List<String> parts = p.split(relative);
  if (parts.length < 2 || !kManagedFolders.contains(parts.first)) return null;
  return p.posix.joinAll(parts);
}

/// Blobs cannot be JSON; everything else a SQLite cell holds can.
Object? _encode(Object? value) {
  if (value is Uint8List) return <String, Object?>{'b': base64.encode(value)};
  if (value is List<int>) return <String, Object?>{'b': base64.encode(value)};
  return value;
}
