import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// The move from a plaintext wallet to an encrypted one.
///
/// The migration in `encrypted_database.dart` is the one piece of this app
/// with somebody's real scanned cards to lose, and the parts most likely to
/// lose them are SQLCipher behaviours rather than Dart logic. Three are pinned
/// here, each of which would destroy or silently expose a wallet:
///
///  * `sqlcipher_export` copies tables and rows and **not** `user_version`.
///    Drift keeps its schema version there, so a copy that lost it would look
///    like a brand new database and get `onCreate` run over the top of a full
///    library.
///  * the exported file is real ciphertext, not a plain database with a pragma
///    that went nowhere.
///  * a wrong key opens the file and setting it raises nothing. Only reading a
///    page fails — so a verification that stopped short of a read would pass
///    on any key at all.
///
/// The first check is that SQLCipher is here to be tested. `PRAGMA key` is
/// silently ignored by plain SQLite, so on a build without it every test below
/// would pass while proving nothing — which is the same failure the app checks
/// for at startup, for the same reason.
void main() {
  late Directory dir;

  setUpAll(() {
    final Database probe = sqlite3.openInMemory();
    final ResultSet version = probe.select('PRAGMA cipher_version');
    probe.close();
    expect(
      version.isNotEmpty && '${version.first.values.first}'.trim().isNotEmpty,
      isTrue,
      reason: 'No SQLCipher in this build. Check the `hooks:` block in '
          'pubspec.yaml — without it the app writes the wallet in the clear '
          'and nothing here would notice.',
    );
  });

  setUp(() async => dir = await Directory.systemTemp.createTemp('recallos_enc'));
  tearDown(() async => dir.delete(recursive: true));

  const String key =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

  String path(String name) => p.join(dir.path, name);

  /// A plaintext wallet with cards in it and a schema version drift set.
  void seed(String at, {int cards = 3, int version = 8}) {
    final Database db = sqlite3.open(at);
    db.execute('CREATE TABLE cards (id INTEGER PRIMARY KEY, image_path TEXT)');
    for (int i = 0; i < cards; i++) {
      db.execute('INSERT INTO cards (image_path) VALUES (?)', <Object?>[
        '/cards/card_$i.jpg',
      ]);
    }
    db.execute('PRAGMA user_version = $version');
    db.close();
  }

  test('a plaintext file is recognisable by its header', () {
    final String at = path('plain.sqlite');
    seed(at);

    final RandomAccessFile handle = File(at).openSync();
    final String head = String.fromCharCodes(handle.readSync(16));
    handle.closeSync();

    expect(head, 'SQLite format 3\u0000');
  });

  test('sqlcipher_export carries the rows and drops the schema version', () {
    final String from = path('plain.sqlite');
    final String to = path('enc.sqlite');
    seed(from, cards: 3, version: 8);

    final Database plain = sqlite3.open(from);
    plain.execute('ATTACH DATABASE ? AS enc KEY "x\'$key\'"', <Object?>[to]);
    plain.execute("SELECT sqlcipher_export('enc')");
    // Deliberately *not* copying user_version here, to show what the migration
    // is compensating for.
    plain.execute('DETACH DATABASE enc');
    plain.close();

    final Database copy = sqlite3.open(to);
    copy.execute('PRAGMA key = "x\'$key\'";');
    expect(copy.select('SELECT count(*) AS n FROM cards').first['n'], 3);
    // This is the whole reason the migration has an extra line in it. Left
    // like this, drift would read 0, decide the database is new, and create
    // every table over a full wallet.
    expect(copy.select('PRAGMA user_version').first.values.first, 0);
    copy.close();

    // And the file really is ciphertext, not a plain database with a pragma
    // that went nowhere.
    final RandomAccessFile handle = File(to).openSync();
    final String head = String.fromCharCodes(handle.readSync(16));
    handle.closeSync();
    expect(head, isNot('SQLite format 3\u0000'));
  });

  test('the copy is whole once the schema version goes with it', () {
    final String from = path('plain.sqlite');
    final String to = path('enc.sqlite');
    seed(from, cards: 5, version: 8);

    final Database plain = sqlite3.open(from);
    final int version =
        plain.select('PRAGMA user_version').first.values.first! as int;
    plain.execute('ATTACH DATABASE ? AS enc KEY "x\'$key\'"', <Object?>[to]);
    plain.execute("SELECT sqlcipher_export('enc')");
    plain.execute('PRAGMA enc.user_version = $version');
    plain.execute('DETACH DATABASE enc');
    plain.close();

    final Database copy = sqlite3.open(to);
    copy.execute('PRAGMA key = "x\'$key\'";');
    expect(copy.select('SELECT count(*) AS n FROM cards').first['n'], 5);
    expect(copy.select('PRAGMA user_version').first.values.first, 8);
    expect(
      copy.select('SELECT image_path FROM cards ORDER BY id').first.values.first,
      '/cards/card_0.jpg',
    );
    copy.close();
  });

  test('the wrong key opens the file and fails on the first read', () {
    final String from = path('plain.sqlite');
    final String to = path('enc.sqlite');
    seed(from);

    final Database plain = sqlite3.open(from);
    plain.execute('ATTACH DATABASE ? AS enc KEY "x\'$key\'"', <Object?>[to]);
    plain.execute("SELECT sqlcipher_export('enc')");
    plain.execute('DETACH DATABASE enc');
    plain.close();

    final Database wrong = sqlite3.open(to);
    // Neither of these throws, which is the point: the key is only tested when
    // a page is actually read. A check that stopped here would pass on any key
    // at all.
    wrong.execute('PRAGMA key = "x\'${'ff' * 32}\'";');
    expect(
      () => wrong.select('SELECT count(*) FROM sqlite_master'),
      throwsA(isA<SqliteException>()),
    );
    wrong.close();
  });
}
