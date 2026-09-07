import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';
import 'package:recallos/features/settings/data/wallet_export.dart';

/// The export is the only way anything leaves this phone.
///
/// That is not a figure of speech: Android backup is off, there is no server,
/// and the database key lives in the Android Keystore, which is destroyed when
/// the app is uninstalled. A copied `.sqlite` file restores to nothing. So an
/// export that quietly drops a table, or writes a vCard the user's address
/// book will not read, loses somebody's wallet — and they find out long after
/// the phone it came from is gone.
///
/// These tests therefore open the real archive and read what is actually in
/// it, rather than checking that a method was called.
void main() {
  late AppDatabase db;
  late IdentityRepository identity;
  late WalletExport export;
  late Directory photos;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    identity = IdentityRepository(db);
    export = WalletExport(db: db, identity: identity);
    photos = await Directory.systemTemp.createTemp('recallos_export_test');
  });
  tearDown(() async {
    await db.close();
    if (photos.existsSync()) await photos.delete(recursive: true);
  });

  /// Saves one card with a photo on disk, and promotes it into the graph.
  Future<int> scan({
    required String name,
    String? company,
    String? phone,
    String? note,
  }) async {
    final File image = File('${photos.path}/card_$name.jpg')
      ..writeAsBytesSync(<int>[0xFF, 0xD8, 0xFF, 0xD9]);

    final int cardId = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: image.path,
            capturedAt: DateTime(2026, 9, 7),
          ),
        );

    Future<void> put(String key, String? value) async {
      if (value == null) return;
      await db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: key,
              value: value,
              normalizedValue: Value<String?>(value),
              source: FactSource.printed,
            ),
          );
    }

    await put(FieldKeys.personName, name);
    await put(FieldKeys.company, company);
    await put(FieldKeys.phone, phone);

    if (note != null) {
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              subjectType: 'card',
              subjectId: cardId,
              body: Value<String?>(note),
            ),
          );
    }

    await identity.promote(cardId);
    return cardId;
  }

  Archive open(List<int> bytes) => ZipDecoder().decodeBytes(bytes);

  String read(Archive archive, String name) =>
      utf8.decode(archive.findFile(name)!.content as List<int>);

  test('an empty wallet exports nothing at all', () async {
    // Not an empty archive — the row says "Nothing saved yet" instead, and
    // handing someone a zip with no cards in it is a worse answer.
    expect(await export.buildArchive(), isNull);
  });

  test('the archive carries the three files a person needs', () async {
    await scan(name: 'Md Abul Bashar', company: 'Olympus Hospital', phone: '01819104376');

    final Archive archive = open((await export.buildArchive())!);
    final List<String> names = archive.files.map((ArchiveFile f) => f.name).toList();

    expect(names, contains('wallet.json'));
    expect(names, contains('contacts.vcf'));
    expect(names, contains('README.txt'));
  });

  test('the contacts file is a vCard an address book will import', () async {
    await scan(name: 'Md Abul Bashar', company: 'Olympus Hospital', phone: '01819104376');

    final String vcf = read(open((await export.buildArchive())!), 'contacts.vcf');

    expect(vcf, startsWith('BEGIN:VCARD'));
    expect(vcf, contains('FN:Md Abul Bashar'));
    expect(vcf, contains('01819104376'));
    expect(vcf.trimRight(), endsWith('END:VCARD'));
  });

  test('the note survives, because a vCard has nowhere to put it', () async {
    // The whole premise of the app is that the note is why the card mattered.
    // A backup that keeps the phone number and loses the reason has kept the
    // half that any contacts app already had.
    await scan(
      name: 'Md Abul Bashar',
      phone: '01819104376',
      note: 'cheap t-shirt printer from CSE fest',
    );

    final String json = read(open((await export.buildArchive())!), 'wallet.json');
    expect(json, contains('cheap t-shirt printer from CSE fest'));
  });

  test('the card photograph is in the archive', () async {
    await scan(name: 'Md Abul Bashar', phone: '01819104376');

    final Archive archive = open((await export.buildArchive())!);
    final Iterable<String> pictures = archive.files
        .map((ArchiveFile f) => f.name)
        .where((String n) => n.startsWith('photos/'));

    expect(pictures, hasLength(1));
  });

  test('a card whose photo has been deleted still exports', () async {
    // Failing the whole archive over one missing thumbnail would strand
    // everything else, which is the opposite of what a rescue is for.
    await scan(name: 'Md Abul Bashar', phone: '01819104376');
    for (final FileSystemEntity f in photos.listSync()) {
      f.deleteSync();
    }

    final Archive archive = open((await export.buildArchive())!);
    expect(read(archive, 'contacts.vcf'), contains('Md Abul Bashar'));
    expect(
      archive.files.where((ArchiveFile f) => f.name.startsWith('photos/')),
      isEmpty,
    );
  });

  test('every user table is exported, including ones added later', () async {
    // The dump reads `sqlite_master` rather than a hand-written list, so a
    // table added in a future migration comes along without anybody editing
    // the exporter. This asserts that mechanism, not today's table list: a
    // forgotten table is a silently incomplete backup, and silence is the
    // problem.
    await scan(name: 'Md Abul Bashar', company: 'Olympus Hospital', phone: '01819104376');

    final Map<String, Object?> parsed =
        jsonDecode(read(open((await export.buildArchive())!), 'wallet.json'))
            as Map<String, Object?>;
    final Map<String, Object?> tables = parsed['tables']! as Map<String, Object?>;

    final List<String> live = (await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name NOT LIKE 'sqlite_%'",
            )
            .get())
        .map((QueryRow r) => r.read<String>('name'))
        .where((String n) => !n.startsWith('cards_fts') && !n.endsWith('_fts'))
        .where((String n) => n != 'embeddings' && n != 'ranking_weights')
        .toList();

    for (final String table in live) {
      expect(
        tables.keys,
        contains(table),
        reason: '$table exists in the database but is missing from the export',
      );
    }
  });

  test('the schema version travels with the data', () async {
    // Without it, a future reader cannot know what the rows meant.
    await scan(name: 'Md Abul Bashar', phone: '01819104376');

    final Map<String, Object?> parsed =
        jsonDecode(read(open((await export.buildArchive())!), 'wallet.json'))
            as Map<String, Object?>;

    expect(parsed['schemaVersion'], db.schemaVersion);
  });

  test('the README says the archive is not encrypted', () async {
    // The wallet on the phone is encrypted and the app says so plainly. A copy
    // that is not, handed over without a word, would let the user carry that
    // assurance somewhere it stopped being true.
    await scan(name: 'Md Abul Bashar', phone: '01819104376');

    final String readme = read(open((await export.buildArchive())!), 'README.txt');
    expect(readme.toLowerCase(), contains('not encrypted'));
  });
}
