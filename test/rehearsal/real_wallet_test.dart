import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/backup/backup_crypto.dart';
import 'package:recallos/core/backup/backup_format.dart';
import 'package:recallos/core/backup/backup_reader.dart';
import 'package:recallos/core/backup/restore_swap.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

import '../support/schema_compare.dart';

/// The migration, rehearsed on the owner's real wallet before it reaches
/// the phone (CLAUDE.md: back up before any migration; PLAN §5: rehearse on
/// a copy).
///
/// The phone runs a non-debuggable build, so `run-as` cannot copy its
/// database. What can leave the phone is an in-app backup — Settings → Back
/// up the wallet — which is the real wallet, encrypted. This restores it
/// into a temporary folder, exactly as a new phone would, opens it with this
/// build, and checks that the upgrade kept everything.
///
/// Skipped unless pointed at a backup — the file and its passphrase never
/// enter the repository:
///
/// ```bash
/// RECALLOS_REHEARSAL_BACKUP=~/Dev/recallos-db-backups/<file>.recallos \
/// RECALLOS_REHEARSAL_PASSPHRASE_FILE=~/Dev/recallos-db-backups/<file>.pass \
/// flutter test test/rehearsal/real_wallet_test.dart
/// ```
///
/// It prints counts only — never a name, a number or a note — and deletes
/// its temporary folder, photographs included, when it finishes.
void main() {
  final String? backupPath = Platform.environment['RECALLOS_REHEARSAL_BACKUP'];
  final String? passFile =
      Platform.environment['RECALLOS_REHEARSAL_PASSPHRASE_FILE'];
  final bool configured = backupPath != null && passFile != null;

  test(
    'the real wallet restores, upgrades to this build and keeps every row',
    () async {
      final Directory work = await Directory.systemTemp.createTemp(
        'recallos_rehearsal',
      );
      addTearDown(() => work.delete(recursive: true));
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final int appSchema = AppDatabase(NativeDatabase.memory()).schemaVersion;
      final String passphrase = File(passFile!).readAsStringSync().trim();
      final String key = sha256Hex(utf8.encode('rehearsal'));

      final OpenedBackup opened = openBackup(
        archivePath: backupPath!,
        passphrase: passphrase,
        appSchemaVersion: appSchema,
      );
      final Map<String, int> promised = opened.manifest.counts;
      stdout.writeln(
        'Backup: schema v${opened.manifest.schemaVersion}, '
        '${opened.manifest.appVersion}, '
        '${opened.manifest.createdAt.toIso8601String()}',
      );

      stageRestore(
        StageJob(
          archivePath: backupPath,
          contentKey: opened.contentKey,
          headerBytes: opened.headerBytes,
          documentsDir: work.path,
          databaseKey: key,
          appSchemaVersion: appSchema,
          // Photographs land sealed, under a key that dies with the test.
          photoKey: randomBytes(32),
        ),
      );
      final RestoreOutcome? outcome = finishPendingRestore(
        documentsDir: work.path,
        databaseKey: key,
      );
      expect(outcome?.ok, isTrue, reason: 'the restore itself failed');

      final AppDatabase db = AppDatabase(
        NativeDatabase(
          File(p.join(work.path, kDatabaseFileName)),
          setup: (s3.Database raw) => raw.execute('PRAGMA key = "x\'$key\'";'),
        ),
      );
      addTearDown(db.close);
      final AppDatabase fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);

      // The upgrade ran, and left the shape a fresh install has.
      final int version =
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          );
      expect(version, appSchema);
      await expectSameSchema(db, fresh);

      // Every row the backup promised is still there.
      stdout.writeln('Rows after the upgrade, by table:');
      for (final MapEntry<String, int> e in promised.entries) {
        if (e.value == 0) continue;
        final int now =
            (await db
                    .customSelect('SELECT count(*) AS n FROM "${e.key}"')
                    .getSingle())
                .read<int>('n');
        stdout.writeln('  ${e.key}: ${e.value} -> $now');
        expect(now, e.value, reason: '${e.key} lost or gained rows');
      }

      // Nothing points at something that is not there.
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );

      // The provenance split agrees with the old pair on every real field.
      final List<CardField> fields = await db.select(db.cardFields).get();
      int confirmed = 0;
      for (final CardField f in fields) {
        expect(
          f.review == FactReview.confirmed,
          f.verifiedByUser,
          reason: 'field ${f.id}: review and verified_by_user disagree',
        );
        if (f.review == FactReview.confirmed) confirmed++;
      }
      stdout.writeln(
        'Fields: ${fields.length}, of which the user confirmed $confirmed.',
      );
    },
    skip: configured
        ? false
        : 'Set RECALLOS_REHEARSAL_BACKUP and '
              'RECALLOS_REHEARSAL_PASSPHRASE_FILE to rehearse on a real backup.',
  );
}
