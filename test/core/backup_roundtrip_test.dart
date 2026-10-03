import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/backup/backup_crypto.dart';
import 'package:recallos/core/backup/backup_format.dart';
import 'package:recallos/core/backup/backup_reader.dart';
import 'package:recallos/core/backup/backup_writer.dart';
import 'package:recallos/core/backup/restore_swap.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/imaging/photo_vault.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

/// A backup is only as good as the restore on a phone that is not the one
/// that made it.
///
/// So these tests build a real wallet on "phone A" — cards with photographs,
/// notes, the identity graph, a profile portrait, a deleted card — back it up,
/// and restore it onto "phone B", which has a different database key and a
/// different documents directory. Every row must come back, every photograph
/// must come back byte for byte at B's own paths, and B's previous wallet must
/// be gone. Then the ways it must fail: each one leaves B's wallet untouched.
void main() {
  /// The schema the app on the restoring phone runs: this build's own, read
  /// from the database class rather than written here, which went stale the
  /// first time the schema moved and failed every restore as "too new".
  late final int appSchema;
  setUpAll(() async {
    final AppDatabase probe = AppDatabase(NativeDatabase.memory());
    appSchema = probe.schemaVersion;
    await probe.close();
  });

  const String passphrase = 'correct horse battery staple';
  // Light parameters keep the suite fast; production uses KdfParams.fresh().
  final KdfParams fastKdf = KdfParams(
    memoryKiB: 8192,
    iterations: 1,
    lanes: 1,
    salt: randomBytes(16),
  );
  final String keyA = sha256Hex(utf8.encode('phone A'));
  final String keyB = sha256Hex(utf8.encode('phone B'));

  late Directory root;
  late Directory docsA;
  late Directory docsB;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('recallos_backup');
    docsA = Directory(p.join(root.path, 'a'))..createSync();
    docsB = Directory(p.join(root.path, 'b'))..createSync();
  });
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  AppDatabase openApp(Directory docs, String key) => AppDatabase(
    NativeDatabase(
      File(p.join(docs.path, kDatabaseFileName)),
      setup: (s3.Database db) => db.execute('PRAGMA key = "x\'$key\'";'),
    ),
  );

  File photo(Directory docs, String relative, List<int> bytes) =>
      File(p.join(docs.path, relative))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  /// Phone A's wallet: three cards (one deleted), notes, people and
  /// organisations through the real identity code, and a profile portrait.
  Future<void> buildWalletA() async {
    final AppDatabase db = openApp(docsA, keyA);
    final CardRepository cards = CardRepository(db);
    final IdentityRepository identity = IdentityRepository(db);

    Future<int> card(String name, String company, String phone, String note) async {
      final File front = photo(docsA, 'cards/card_$name.jpg', utf8.encode('front of $name'));
      final File thumb = photo(docsA, 'cards/card_${name}_thumb.jpg', utf8.encode('thumb $name'));
      final int id = await db.into(db.cards).insert(
        CardsCompanion.insert(
          imagePath: front.path,
          thumbPath: Value<String?>(thumb.path),
          capturedAt: DateTime(2026, 9, 20),
          extractionStatus: const Value<ExtractionStatus>(ExtractionStatus.complete),
        ),
      );
      for (final (String key, String value) in <(String, String)>[
        ('person_name', name),
        ('company', company),
        ('phone', phone),
      ]) {
        await db.into(db.cardFields).insert(
          CardFieldsCompanion.insert(
            cardId: id,
            fieldKey: key,
            value: value,
            source: FactSource.printed,
          ),
        );
      }
      await cards.addNote(cardId: id, body: note);
      await identity.promote(id);
      return id;
    }

    await card('Rahim Ahmed', 'Sonar Bangla Press', '01711223344', 'printing guy');
    await card('Nadia Chowdhury', 'Target Center', '01811556677', 'sponsor lead');
    final int gone = await card('Old Contact', 'Gone Ltd', '01911000000', 'deleted');
    await cards.softDelete(gone);

    final File portrait = photo(docsA, 'profile/portrait_1.jpg', <int>[1, 2, 3, 4]);
    await ProfileRepository(db).save(
      ProfileDraft(
        photoPath: portrait.path,
        entries: const <ProfileEntry>[
          ProfileEntry(fieldKey: 'person_name', value: 'Arafatul Hasan Sadoy'),
        ],
      ),
    );
    await db.close();
  }

  /// Phone B already has a wallet of its own, which a restore must replace.
  Future<void> buildWalletB() async {
    final AppDatabase db = openApp(docsB, keyB);
    final File mine = photo(docsB, 'cards/card_mine.jpg', utf8.encode('B only'));
    await db.into(db.cards).insert(
      CardsCompanion.insert(imagePath: mine.path, capturedAt: DateTime(2026, 1, 1)),
    );
    await db.close();
  }

  File backupOfA({Uint8List? photoKey}) {
    final File out = File(p.join(root.path, 'wallet.recallos'));
    writeBackup(
      BackupWriteJob(
        databasePath: p.join(docsA.path, kDatabaseFileName),
        databaseKey: keyA,
        documentsDir: docsA.path,
        outputPath: out.path,
        passphrase: passphrase,
        appVersion: '1.0.0 (1) · test',
        photoKey: photoKey,
        kdf: fastKdf,
      ),
    );
    return out;
  }

  Future<RestoreOutcome?> restoreOnB(
    File backup, {
    String pass = passphrase,
    Uint8List? photoKey,
  }) async {
    final OpenedBackup opened = openBackup(
      archivePath: backup.path,
      passphrase: pass,
      appSchemaVersion: appSchema,
    );
    stageRestore(
      StageJob(
        archivePath: backup.path,
        contentKey: opened.contentKey,
        headerBytes: opened.headerBytes,
        documentsDir: docsB.path,
        databaseKey: keyB,
        appSchemaVersion: appSchema,
        photoKey: photoKey,
      ),
    );
    return finishPendingRestore(documentsDir: docsB.path, databaseKey: keyB);
  }

  /// Every row of every user table, with paths made relative so A and B can
  /// be compared.
  Map<String, List<List<Object?>>> dump(Directory docs, String key) {
    final s3.Database db = s3.sqlite3.open(p.join(docs.path, kDatabaseFileName));
    try {
      db.execute('PRAGMA key = "x\'$key\'";');
      final Map<String, List<List<Object?>>> out = <String, List<List<Object?>>>{};
      for (final s3.Row t in db.select(
        "SELECT name FROM pragma_table_list WHERE schema = 'main' "
        "AND type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'embeddings'",
      )) {
        final String table = t['name']! as String;
        out[table] = <List<Object?>>[
          for (final s3.Row r in db.select('SELECT * FROM "$table" ORDER BY rowid'))
            <Object?>[
              for (final Object? v in r.values)
                v is String && v.startsWith(docs.path) ? p.relative(v, from: docs.path) : v,
            ],
        ];
      }
      return out;
    } finally {
      db.close();
    }
  }

  int cardsOn(Directory docs, String key) {
    final s3.Database db = s3.sqlite3.open(p.join(docs.path, kDatabaseFileName));
    try {
      db.execute('PRAGMA key = "x\'$key\'";');
      return db.select('SELECT count(*) AS n FROM cards').first['n']! as int;
    } finally {
      db.close();
    }
  }

  group('a full round trip onto another phone', () {
    test('every row and every photograph comes back', () async {
      await buildWalletA();
      await buildWalletB();
      final File backup = backupOfA();

      final RestoreOutcome? outcome = await restoreOnB(backup);
      expect(outcome?.ok, isTrue);
      expect(outcome?.cards, 3, reason: 'the deleted card is part of the wallet too');

      final Map<String, List<List<Object?>>> a = dump(docsA, keyA);
      final Map<String, List<List<Object?>>> b = dump(docsB, keyB);
      expect(b.keys.toSet(), a.keys.toSet());
      for (final String table in a.keys) {
        expect(b[table], a[table], reason: 'table $table differs after restore');
      }

      for (final String relative in <String>[
        'cards/card_Rahim Ahmed.jpg',
        'cards/card_Rahim Ahmed_thumb.jpg',
        'cards/card_Nadia Chowdhury.jpg',
        'profile/portrait_1.jpg',
      ]) {
        expect(
          File(p.join(docsB.path, relative)).readAsBytesSync(),
          File(p.join(docsA.path, relative)).readAsBytesSync(),
          reason: relative,
        );
      }
      expect(
        File(p.join(docsB.path, 'cards/card_mine.jpg')).existsSync(),
        isFalse,
        reason: "B's own wallet is replaced, photographs included",
      );
      expect(Directory(p.join(docsB.path, 'restore')).existsSync(), isFalse);
    });

    test('sealed photographs are re-sealed for the phone that restores them', () async {
      // Each phone's photographs are sealed with its own key. A backup that
      // copied the sealed bytes across would restore photographs the new
      // phone can never open.
      await buildWalletA();
      final Uint8List photoKeyA = randomBytes(32);
      final Uint8List photoKeyB = randomBytes(32);
      sealPlaintextPhotos(docsA.path, photoKeyA);

      await restoreOnB(backupOfA(photoKey: photoKeyA), photoKey: photoKeyB);

      for (final String relative in <String>[
        'cards/card_Rahim Ahmed.jpg',
        'profile/portrait_1.jpg',
      ]) {
        final Uint8List onB = File(p.join(docsB.path, relative)).readAsBytesSync();
        expect(isSealedPhoto(onB), isTrue, reason: relative);
        expect(
          openPhoto(photoKeyB, onB),
          readPhotoSync(p.join(docsA.path, relative), photoKeyA),
          reason: relative,
        );
        expect(
          () => openPhoto(photoKeyA, onB),
          throwsA(isA<PhotoLockedException>()),
          reason: "phone A's key must not open phone B's copy",
        );
      }
    });

    test('the restored wallet opens in the app and migrates normally', () async {
      await buildWalletA();
      await restoreOnB(backupOfA());

      final AppDatabase db = openApp(docsB, keyB);
      final List<CardSummary> live = await CardRepository(db).watchCards().first;
      expect(
        live.map((CardSummary c) => c.title).toSet(),
        <String>{'Sonar Bangla Press', 'Target Center'},
      );
      await db.close();
    });

    test('the backup holds no plaintext and no search index', () async {
      await buildWalletA();
      final Uint8List raw = backupOfA().readAsBytesSync();
      final String text = latin1.decode(raw);
      expect(text, isNot(contains('Rahim Ahmed')));
      expect(text, isNot(contains('printing guy')));
      expect(text, isNot(contains('front of')));

      final Archive archive = ZipDecoder().decodeBytes(raw);
      expect(
        archive.files.map((ArchiveFile f) => f.name).where((String n) => !kAllowedEntry.hasMatch(n)),
        isEmpty,
      );
    });

    test('the preview says what is in it before anything changes', () async {
      await buildWalletA();
      await buildWalletB();
      final OpenedBackup opened = openBackup(
        archivePath: backupOfA().path,
        passphrase: passphrase,
        appSchemaVersion: appSchema,
      );
      expect(opened.preview.cards, 3);
      expect(opened.preview.photos, 7);
      expect(cardsOn(docsB, keyB), 1, reason: 'opening must not touch the wallet');
    });
  });

  group('failures leave the current wallet untouched', () {
    Future<void> expectProblem(
      Future<void> Function() action,
      BackupProblem problem,
    ) async {
      try {
        await action();
        fail('expected $problem');
      } on BackupException catch (e) {
        expect(e.problem, problem, reason: e.detail);
      }
      expect(cardsOn(docsB, keyB), 1);
      expect(File(p.join(docsB.path, 'cards/card_mine.jpg')).existsSync(), isTrue);
    }

    File rewrite(File backup, String name, Uint8List Function(Uint8List) change) {
      final Archive old = ZipDecoder().decodeBytes(backup.readAsBytesSync());
      final Archive fresh = Archive();
      for (final ArchiveFile f in old.files) {
        final Uint8List bytes = f.readBytes()!;
        fresh.add(
          ArchiveFile.bytes(f.name, f.name == name ? change(bytes) : bytes)
            ..compression = CompressionType.none,
        );
      }
      final File out = File(p.join(root.path, 'tampered.recallos'))
        ..writeAsBytesSync(ZipEncoder().encode(fresh));
      return out;
    }

    test('a wrong passphrase', () async {
      await buildWalletA();
      await buildWalletB();
      final File backup = backupOfA();
      await expectProblem(
        () => restoreOnB(backup, pass: 'not the passphrase'),
        BackupProblem.wrongPassphraseOrDamaged,
      );
    });

    test('an edited header', () async {
      await buildWalletA();
      await buildWalletB();
      final File tampered = rewrite(backupOfA(), kHeaderEntry, (Uint8List b) {
        final Map<String, Object?> json =
            jsonDecode(utf8.decode(b)) as Map<String, Object?>;
        json['note'] = 'added by someone else';
        return Uint8List.fromList(utf8.encode(jsonEncode(json)));
      });
      await expectProblem(() => restoreOnB(tampered), BackupProblem.damaged);
    });

    test('one changed byte in a photograph', () async {
      await buildWalletA();
      await buildWalletB();
      final File tampered = rewrite(
        backupOfA(),
        'assets/0.bin',
        (Uint8List b) => Uint8List.fromList(b)..[20] ^= 0x01,
      );
      await expectProblem(() => restoreOnB(tampered), BackupProblem.damaged);
    });

    test('a photograph swapped for another entry', () async {
      await buildWalletA();
      await buildWalletB();
      final File original = backupOfA();
      final Uint8List other = ZipDecoder()
          .decodeBytes(original.readAsBytesSync())
          .findFile('assets/1.bin')!
          .readBytes()!;
      final File tampered = rewrite(original, 'assets/0.bin', (_) => other);
      await expectProblem(() => restoreOnB(tampered), BackupProblem.damaged);
    });

    test('a truncated file', () async {
      await buildWalletA();
      await buildWalletB();
      final Uint8List raw = backupOfA().readAsBytesSync();
      final File cut = File(p.join(root.path, 'cut.recallos'))
        ..writeAsBytesSync(raw.sublist(0, raw.length ~/ 2));
      await expectProblem(() => restoreOnB(cut), BackupProblem.notABackup);
    });

    test('an entry that tries to climb out of the backup', () async {
      await buildWalletA();
      await buildWalletB();
      final Archive old = ZipDecoder().decodeBytes(backupOfA().readAsBytesSync());
      final Archive evil = Archive();
      for (final ArchiveFile f in old.files) {
        evil.add(ArchiveFile.bytes(f.name, f.readBytes()!)..compression = CompressionType.none);
      }
      evil.add(ArchiveFile.bytes('../../evil.txt', <int>[1])..compression = CompressionType.none);
      final File out = File(p.join(root.path, 'evil.recallos'))
        ..writeAsBytesSync(ZipEncoder().encode(evil));
      await expectProblem(() => restoreOnB(out), BackupProblem.notABackup);
    });

    test('a file that is not a backup at all', () async {
      await buildWalletB();
      final File junk = File(p.join(root.path, 'junk.recallos'))
        ..writeAsStringSync('hello');
      await expectProblem(() => restoreOnB(junk), BackupProblem.notABackup);
    });

    test('a backup from a newer RecallOS', () async {
      await buildWalletA();
      await buildWalletB();
      final s3.Database db = s3.sqlite3.open(p.join(docsA.path, kDatabaseFileName));
      db.execute('PRAGMA key = "x\'$keyA\'";');
      db.execute('PRAGMA user_version = 99');
      db.close();
      final File backup = backupOfA();
      await expectProblem(() => restoreOnB(backup), BackupProblem.tooNew);
    });

    test('a file over the size limit', () async {
      await buildWalletA();
      await buildWalletB();
      final File backup = backupOfA();
      await expectProblem(
        () async => openBackup(
          archivePath: backup.path,
          passphrase: passphrase,
          appSchemaVersion: appSchema,
          limits: const BackupLimits(maxArchiveBytes: 100),
        ),
        BackupProblem.tooLarge,
      );
    });
  });

  group('the swap survives being interrupted', () {
    Future<void> stageOnly() async {
      await buildWalletA();
      await buildWalletB();
      final File backup = backupOfA();
      final OpenedBackup opened = openBackup(
        archivePath: backup.path,
        passphrase: passphrase,
        appSchemaVersion: appSchema,
      );
      stageRestore(
        StageJob(
          archivePath: backup.path,
          contentKey: opened.contentKey,
          headerBytes: opened.headerBytes,
          documentsDir: docsB.path,
          databaseKey: keyB,
          appSchemaVersion: appSchema,
        ),
      );
    }

    test('staging alone changes nothing live', () async {
      await stageOnly();
      expect(cardsOn(docsB, keyB), 1);
      expect(RestorePaths(docsB.path).readJournal()?['state'], 'staged');
    });

    test('a crash halfway through the swap is finished on the next launch', () async {
      await stageOnly();
      final RestorePaths paths = RestorePaths(docsB.path);
      // As if the app died after moving the old database aside and before
      // anything else: the journal says swapping, the live file is gone.
      paths.writeJournal(<String, Object?>{
        ...paths.readJournal()!,
        'state': 'swapping',
      });
      paths.previous.createSync(recursive: true);
      File(p.join(docsB.path, kDatabaseFileName))
          .renameSync(p.join(paths.previous.path, kDatabaseFileName));

      final RestoreOutcome? outcome =
          finishPendingRestore(documentsDir: docsB.path, databaseKey: keyB);
      expect(outcome?.ok, isTrue);
      expect(cardsOn(docsB, keyB), 3);
    });

    test('a staging run that died is thrown away, not swapped in', () async {
      await buildWalletB();
      final RestorePaths paths = RestorePaths(docsB.path);
      paths.writeJournal(<String, Object?>{'state': 'staging'});
      paths.staged.createSync(recursive: true);
      File(p.join(paths.staged.path, kDatabaseFileName)).writeAsStringSync('half');

      expect(finishPendingRestore(documentsDir: docsB.path, databaseKey: keyB), isNull);
      expect(cardsOn(docsB, keyB), 1);
      expect(paths.staged.existsSync(), isFalse);
    });

    test('a restored wallet that does not open is rolled back', () async {
      await stageOnly();
      // Damage the staged database after staging checked it.
      File(p.join(RestorePaths(docsB.path).staged.path, kDatabaseFileName))
          .writeAsStringSync('not a database');

      final RestoreOutcome? outcome =
          finishPendingRestore(documentsDir: docsB.path, databaseKey: keyB);
      expect(outcome?.ok, isFalse);
      expect(cardsOn(docsB, keyB), 1, reason: 'the original wallet is back');
      expect(File(p.join(docsB.path, 'cards/card_mine.jpg')).existsSync(), isTrue);
    });

    test('with nothing pending, launch does nothing', () async {
      await buildWalletB();
      expect(finishPendingRestore(documentsDir: docsB.path, databaseKey: keyB), isNull);
      expect(cardsOn(docsB, keyB), 1);
    });
  });
}
