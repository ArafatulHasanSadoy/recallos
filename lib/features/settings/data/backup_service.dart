import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/backup/backup_format.dart';
import '../../../core/backup/backup_reader.dart';
import '../../../core/backup/backup_writer.dart';
import '../../../core/backup/restore_swap.dart';
import '../../../core/db/database.dart';
import '../../../core/db/encrypted_database.dart';
import '../../../core/imaging/photo_keyring.dart';
import '../../../core/storage/hand_offs.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;
import 'app_info.dart';

/// Resolved at construction, not through a `Ref` — a backup runs across many
/// awaits (CLAUDE.md: "A service must not hold a Ref across an await").
final backupServiceProvider = Provider<BackupService>(
  (Ref ref) => BackupService(
    db: ref.watch(databaseProvider),
    appInfo: ref.watch(appInfoProvider),
  ),
);

/// The outcome of a restore finished at this launch, reported once.
///
/// Waits for the database to have been opened, because opening is what
/// finishes a staged restore and writes the outcome.
final restoreOutcomeProvider = FutureProvider<RestoreOutcome?>((Ref ref) async {
  await storageStatus;
  final File db = await databaseFile();
  return takeRestoreOutcome(db.parent.path);
});

/// A finished backup, ready to hand to the share sheet.
class CreatedBackup {
  const CreatedBackup({required this.file, required this.manifest});
  final File file;
  final BackupManifest manifest;
}

/// The platform half of backup and restore: where files are, the key, the
/// share sheet, the file picker, the restart. The work itself is in
/// `lib/core/backup/`, runs in background isolates, and is tested on its own.
class BackupService {
  BackupService({required this.db, required this.appInfo});

  final AppDatabase db;
  final AppInfo appInfo;

  /// Writes and verifies an encrypted backup. Slow — key derivation plus every
  /// photograph — so it runs off the UI isolate.
  Future<CreatedBackup> create(String passphrase) async {
    final File database = await databaseFile();
    final String? key = await databaseKey();
    final Directory temp = await outboxDirectory();
    final AppVersion? version = await appInfo.version();

    final DateTime now = DateTime.now();
    final String day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final String out = p.join(temp.path, 'RecallOS backup $day.$kBackupExtension');

    final BackupWriteJob job = BackupWriteJob(
      databasePath: database.path,
      databaseKey: key,
      documentsDir: database.parent.path,
      outputPath: out,
      passphrase: passphrase,
      appVersion: version?.buildId ?? 'unknown',
      photoKey: await PhotoKeyring.instance.key,
    );
    final BackupManifest manifest = await Isolate.run(() => writeBackup(job));
    return CreatedBackup(file: File(out), manifest: manifest);
  }

  /// Hands the file to wherever the user wants to keep it. No storage
  /// permission: share_plus exposes it through its own FileProvider.
  ///
  /// Ours is deleted afterwards: share_plus hands over a copy of its own, and
  /// a backup is the size of the whole wallet.
  Future<void> share(CreatedBackup backup) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(backup.file.path, mimeType: 'application/octet-stream'),
          ],
          subject: 'RecallOS backup',
        ),
      );
    } finally {
      await discardHandOff(backup.file);
    }
  }

  /// The system file picker. Returns a readable copy's path, or null if the
  /// user backed out. No storage permission: the picker grants this one file.
  Future<String?> pickBackup() async {
    final XFile? file = await openFile();
    return file?.path;
  }

  /// Checks the passphrase and reads what is in the backup.
  Future<OpenedBackup> open(String path, String passphrase) {
    final int schema = db.schemaVersion;
    return Isolate.run(
      () => openBackup(
        archivePath: path,
        passphrase: passphrase,
        appSchemaVersion: schema,
      ),
    );
  }

  /// Cards on this phone now, for the "this replaces …" sentence — counting
  /// Recently deleted too, because a restore replaces those as well, and a
  /// phone holding only deleted cards must not be told nothing will be lost.
  Future<int> liveCards() async {
    final QueryRow row = await db
        .customSelect('SELECT count(*) AS n FROM cards')
        .getSingle();
    return row.read<int>('n');
  }

  /// Builds the restored wallet beside the live one, then restarts the app so
  /// the swap happens before anything opens the database. Returns false if the
  /// restart could not be requested — the swap then happens on the next open.
  Future<bool> stageAndRestart(String path, OpenedBackup opened) async {
    final File database = await databaseFile();
    final StageJob job = StageJob(
      archivePath: path,
      contentKey: opened.contentKey,
      headerBytes: opened.headerBytes,
      documentsDir: database.parent.path,
      databaseKey: await databaseKey(),
      appSchemaVersion: db.schemaVersion,
      photoKey: await PhotoKeyring.instance.key,
    );
    await Isolate.run(() => stageRestore(job));

    // Closed so its last writes are on disk before the process ends. Nothing
    // else runs between here and the restart.
    await db.close();
    return appInfo.restart();
  }
}
