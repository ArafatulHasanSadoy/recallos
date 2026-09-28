/// What a RecallOS backup file is.
///
/// A zip of stored (uncompressed) entries — ciphertext does not compress, and
/// a zip is something a curious person can list with ordinary tools:
///
/// | Entry | Contents |
/// |---|---|
/// | `header.json` | plain: format, archive id, KDF parameters, wrapped key |
/// | `manifest.bin` | sealed: versions, counts, asset list with digests |
/// | `data.bin` | sealed: the schema and every row |
/// | `assets/<n>.bin` | sealed: one photograph each |
///
/// **Keys.** A random 256-bit content key seals everything. It is itself
/// sealed ("wrapped") under a key derived from the passphrase with Argon2id,
/// and the wrapped copy sits in the header. Wrapping rather than deriving the
/// content key directly means a recovery key could later wrap the same
/// content key without re-encrypting anything.
///
/// **Binding.** Every sealed entry's associated data names the archive and
/// the entry, so a valid entry cannot be moved between backups or swapped for
/// another name. The manifest's associated data also carries a digest of the
/// header, so the one plaintext part cannot be edited either. The manifest
/// lists each asset's SHA-256, checked after decryption.
///
/// **What is not in it:** the search index and embeddings (rebuilt on first
/// launch), and anything that is not the user's data.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'backup_crypto.dart';

const String kBackupFormat = 'recallos-backup';
const int kBackupFormatVersion = 1;

/// The extension the share sheet and the file picker see.
const String kBackupExtension = 'recallos';

const String kHeaderEntry = 'header.json';
const String kManifestEntry = 'manifest.bin';
const String kDataEntry = 'data.bin';
String assetEntry(int index) => 'assets/$index.bin';

/// Every entry name a valid backup may contain. Anything else — a path with
/// `..`, an absolute path, a stray file — means the archive was not written
/// by RecallOS, and it is refused before any of it is read.
final RegExp kAllowedEntry = RegExp(
  r'^(header\.json|manifest\.bin|data\.bin|assets/[0-9]{1,6}\.bin)$',
);

/// Top-level folders, under the app's documents directory, that a backup may
/// restore files into. Everything the app stores photographs in, and nothing
/// else.
const Set<String> kManagedFolders = <String>{'cards', 'profile'};

/// Bounds on untrusted input. Generous for a real wallet, small enough that a
/// hostile file cannot exhaust the phone.
class BackupLimits {
  const BackupLimits({
    this.maxArchiveBytes = 1024 * 1024 * 1024,
    this.maxEntries = 20000,
    this.maxHeaderBytes = 64 * 1024,
    this.maxManifestBytes = 16 * 1024 * 1024,
    this.maxDataBytes = 256 * 1024 * 1024,
    this.maxAssetBytes = 64 * 1024 * 1024,
  });

  final int maxArchiveBytes;
  final int maxEntries;
  final int maxHeaderBytes;
  final int maxManifestBytes;
  final int maxDataBytes;
  final int maxAssetBytes;
}

/// Why a backup could not be opened or restored, in terms a person can act
/// on. The current wallet is never touched by any of these.
enum BackupProblem {
  /// Not a RecallOS backup at all, or damaged beyond reading.
  notABackup,

  /// The passphrase does not open it — or the file was altered. The two
  /// cannot be told apart, on purpose; see [BackupAuthError].
  wrongPassphraseOrDamaged,

  /// It opened, and something inside does not match what the manifest
  /// promised: a changed photograph, a missing entry, a count that is off.
  damaged,

  /// Made by a newer RecallOS than this one.
  tooNew,

  /// Bigger than this phone will read, or asking for more than it should.
  tooLarge,
}

class BackupException implements Exception {
  const BackupException(this.problem, [this.detail]);
  final BackupProblem problem;

  /// For logs and tests, never shown to the user.
  final String? detail;

  @override
  String toString() => 'BackupException(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// The plaintext header.
class BackupHeader {
  const BackupHeader({
    required this.archiveId,
    required this.kdf,
    required this.wrappedKey,
  });

  final String archiveId;
  final KdfParams kdf;
  final Uint8List wrappedKey;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': kBackupFormat,
    'formatVersion': kBackupFormatVersion,
    'archiveId': archiveId,
    'kdf': kdf.toJson(),
    'wrappedKey': base64.encode(wrappedKey),
  };

  static BackupHeader parse(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupException(BackupProblem.notABackup, 'header is not JSON');
    }
    if (json is! Map<String, Object?> || json['format'] != kBackupFormat) {
      throw const BackupException(BackupProblem.notABackup, 'wrong format');
    }
    final Object? version = json['formatVersion'];
    if (version is! int) {
      throw const BackupException(BackupProblem.notABackup, 'no version');
    }
    if (version > kBackupFormatVersion) {
      throw const BackupException(BackupProblem.tooNew, 'format version');
    }
    final Object? id = json['archiveId'];
    final Object? wrapped = json['wrappedKey'];
    final KdfParams? kdf = KdfParams.fromJson(json['kdf']);
    if (id is! String || id.isEmpty || id.length > 64 || wrapped is! String) {
      throw const BackupException(BackupProblem.notABackup, 'header fields');
    }
    if (kdf == null) {
      throw const BackupException(BackupProblem.notABackup, 'kdf');
    }
    if (!kdf.isWithinBounds) {
      throw const BackupException(BackupProblem.tooLarge, 'kdf bounds');
    }
    try {
      return BackupHeader(
        archiveId: id,
        kdf: kdf,
        wrappedKey: base64.decode(wrapped),
      );
    } on FormatException {
      throw const BackupException(BackupProblem.notABackup, 'wrapped key');
    }
  }
}

/// Associated data for the wrapped content key.
Uint8List wrapAad(String archiveId) =>
    _aad('$kBackupFormat/v$kBackupFormatVersion|wrap|$archiveId');

/// Associated data for a sealed entry. The manifest's also carries the
/// header's digest, which is what makes the plaintext header tamper-evident.
Uint8List entryAad(String archiveId, String entry, {Uint8List? headerBytes}) {
  final String headerDigest = headerBytes == null
      ? ''
      : '|${crypto.sha256.convert(headerBytes)}';
  return _aad(
    '$kBackupFormat/v$kBackupFormatVersion|$archiveId|$entry$headerDigest',
  );
}

Uint8List _aad(String s) => Uint8List.fromList(utf8.encode(s));

String sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// One photograph in the backup.
class BackupAsset {
  const BackupAsset({
    required this.entry,
    required this.originalPath,
    required this.relativePath,
    required this.sha256,
    required this.size,
  });

  final String entry;

  /// Where the file was on the phone that made the backup. Rows are rewritten
  /// from this to the restoring phone's own directory.
  final String originalPath;

  /// Its place under the documents directory, e.g. `cards/card_12.jpg`.
  final String relativePath;
  final String sha256;
  final int size;

  Map<String, Object?> toJson() => <String, Object?>{
    'entry': entry,
    'originalPath': originalPath,
    'relativePath': relativePath,
    'sha256': sha256,
    'size': size,
  };

  static BackupAsset? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final Object? e = json['entry'];
    final Object? o = json['originalPath'];
    final Object? r = json['relativePath'];
    final Object? h = json['sha256'];
    final Object? s = json['size'];
    if (e is! String || o is! String || r is! String) return null;
    if (h is! String || s is! int) return null;
    return BackupAsset(
      entry: e,
      originalPath: o,
      relativePath: r,
      sha256: h,
      size: s,
    );
  }
}

/// What is in the backup, sealed.
class BackupManifest {
  const BackupManifest({
    required this.archiveId,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.counts,
    required this.dataSha256,
    required this.dataSize,
    required this.assets,
    required this.missingFiles,
  });

  final String archiveId;
  final DateTime createdAt;

  /// "1.0.0 (7) · a1b2c3d" — which build wrote it, for the preview.
  final String appVersion;

  /// The database schema the rows were written under. A restore into a newer
  /// app migrates from here; a restore into an older one is refused.
  final int schemaVersion;

  /// Rows per table, checked after staging so a truncated payload cannot pass
  /// as a smaller wallet.
  final Map<String, int> counts;
  final String dataSha256;
  final int dataSize;
  final List<BackupAsset> assets;

  /// Rows pointed at photographs that were already gone from the phone.
  final int missingFiles;

  int count(String table) => counts[table] ?? 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': kBackupFormat,
    'formatVersion': kBackupFormatVersion,
    'archiveId': archiveId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
    'counts': counts,
    'data': <String, Object?>{'sha256': dataSha256, 'size': dataSize},
    'assets': <Object?>[for (final BackupAsset a in assets) a.toJson()],
    'missingFiles': missingFiles,
  };

  static BackupManifest parse(Uint8List bytes, String expectedArchiveId) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupException(BackupProblem.damaged, 'manifest JSON');
    }
    BackupException bad(String why) =>
        BackupException(BackupProblem.damaged, 'manifest: $why');

    if (json is! Map<String, Object?>) throw bad('shape');
    if (json['archiveId'] != expectedArchiveId) throw bad('archive id');
    final Object? created = json['createdAt'];
    final Object? app = json['appVersion'];
    final Object? schema = json['schemaVersion'];
    final Object? counts = json['counts'];
    final Object? data = json['data'];
    final Object? assets = json['assets'];
    final Object? missing = json['missingFiles'];
    if (created is! String || app is! String || schema is! int) {
      throw bad('fields');
    }
    if (counts is! Map<String, Object?> || data is! Map<String, Object?>) {
      throw bad('counts/data');
    }
    if (assets is! List<Object?> || missing is! int) throw bad('assets');
    final Object? dataHash = data['sha256'];
    final Object? dataSize = data['size'];
    if (dataHash is! String || dataSize is! int) throw bad('data digest');

    final Map<String, int> countMap = <String, int>{};
    counts.forEach((String k, Object? v) {
      if (v is! int) throw bad('count $k');
      countMap[k] = v;
    });

    final List<BackupAsset> assetList = <BackupAsset>[];
    for (final Object? a in assets) {
      final BackupAsset? asset = BackupAsset.fromJson(a);
      if (asset == null) throw bad('asset entry');
      assetList.add(asset);
    }

    final DateTime? at = DateTime.tryParse(created);
    if (at == null) throw bad('date');

    return BackupManifest(
      archiveId: expectedArchiveId,
      createdAt: at,
      appVersion: app,
      schemaVersion: schema,
      counts: countMap,
      dataSha256: dataHash,
      dataSize: dataSize,
      assets: assetList,
      missingFiles: missing,
    );
  }
}

/// What the user sees before choosing to replace their wallet.
class BackupPreview {
  const BackupPreview({required this.manifest});
  final BackupManifest manifest;

  int get cards => manifest.count('cards');
  int get people => manifest.count('people');
  int get organizations => manifest.count('organizations');
  int get photos => manifest.assets.length;
  DateTime get createdAt => manifest.createdAt;
  String get appVersion => manifest.appVersion;
}
