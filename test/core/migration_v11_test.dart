import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../support/schema_compare.dart';

/// Upgrading from v10 — the schema every phone and every backup made before
/// Release B has — measured against a fresh install.
///
/// The starting point is `test/fixtures/schema_v10.sql`, frozen from the v10
/// code itself, not a database wound back by hand: a hand-made "v10" is only
/// as right as the person who made it.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recallos_v11');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDown(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    await dir.delete(recursive: true);
  });

  test(
    'a v10 database, opened by this build, is shaped like a fresh install',
    () async {
      final AppDatabase upgraded = AppDatabase(
        NativeDatabase(frozenDatabase(dir, 10)),
      );
      final AppDatabase fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(upgraded.close);
      addTearDown(fresh.close);

      await expectSameSchema(upgraded, fresh);
    },
  );

  /// Writes rows into a frozen v10 file the way a v10 build would have, with
  /// plain SQL — the Dart classes already describe v11.
  void seedV10(File file, void Function(sqlite.Database db) write) {
    final sqlite.Database raw = sqlite.sqlite3.open(file.path);
    try {
      write(raw);
    } finally {
      raw.close();
    }
  }

  test(
    'every old source and confirmation maps to origin, review, validity',
    () async {
      final File file = frozenDatabase(dir, 10);
      const List<String> sources = <String>[
        'printed',
        'user',
        'aiInferred',
        'outdated',
        'verified',
      ];
      seedV10(file, (sqlite.Database db) {
        db.execute(
          "INSERT INTO cards (id, image_path, captured_at) VALUES (1, '/x.jpg', 0)",
        );
        int id = 0;
        for (final String source in sources) {
          for (final int verified in <int>[0, 1]) {
            db.execute(
              'INSERT INTO card_fields (id, card_id, field_key, value, source, '
              "verified_by_user) VALUES (${++id}, 1, 'phone', '$source/$verified', "
              "'$source', $verified)",
            );
          }
        }
      });

      final AppDatabase db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final Map<String, CardField> byValue = <String, CardField>{
        for (final CardField f in await db.select(db.cardFields).get())
          f.value: f,
      };
      expect(byValue, hasLength(10), reason: 'no row may be lost');

      FactOrigin origin(String source) => switch (source) {
        'user' => FactOrigin.user,
        'aiInferred' => FactOrigin.inferred,
        _ => FactOrigin.printed,
      };
      for (final String source in sources) {
        for (final int verified in <int>[0, 1]) {
          final CardField f = byValue['$source/$verified']!;
          expect(f.origin, origin(source), reason: '$source/$verified');
          expect(
            f.review,
            verified == 1 ? FactReview.confirmed : FactReview.unreviewed,
            reason: '$source/$verified',
          );
          expect(
            f.validity,
            source == 'outdated' ? FactValidity.outdated : FactValidity.current,
            reason: '$source/$verified',
          );
          // The old pair is still there, unchanged, for readers not yet moved.
          expect(f.source.name, source);
          expect(f.verifiedByUser, verified == 1);
        }
      }
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('a migration cut off half way runs again and finishes', () async {
    // A crash after some of the v11 columns were added but before the new
    // version was recorded: the next launch runs the step again, and it has
    // to find its own earlier work rather than fail on it.
    final File file = frozenDatabase(dir, 10);
    seedV10(file, (sqlite.Database db) {
      db.execute(
        "INSERT INTO cards (id, image_path, captured_at) VALUES (1, '/x.jpg', 0)",
      );
      db.execute(
        'INSERT INTO card_fields (id, card_id, field_key, value, source, '
        "verified_by_user) VALUES (1, 1, 'phone', '017', 'user', 1)",
      );
      db.execute(
        "ALTER TABLE card_fields ADD COLUMN origin TEXT NOT NULL DEFAULT 'printed'",
      );
      db.execute('ALTER TABLE cards ADD COLUMN title TEXT NULL');
    });

    final AppDatabase upgraded = AppDatabase(NativeDatabase(file));
    final AppDatabase fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(upgraded.close);
    addTearDown(fresh.close);
    final CardField f = await upgraded.select(upgraded.cardFields).getSingle();
    expect(f.origin, FactOrigin.user);
    expect(f.review, FactReview.confirmed);
    await expectSameSchema(upgraded, fresh);
  });

  test('new rows take the defaults: printed, unreviewed, current', () async {
    final AppDatabase db = AppDatabase(NativeDatabase(frozenDatabase(dir, 10)));
    addTearDown(db.close);
    final int card = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/y.jpg',
            capturedAt: DateTime(2026),
          ),
        );
    await db
        .into(db.cardFields)
        .insert(
          CardFieldsCompanion.insert(
            cardId: card,
            fieldKey: 'company',
            value: 'Star Tech',
            source: FactSource.printed,
          ),
        );
    final CardField f = await db.select(db.cardFields).getSingle();
    expect(f.origin, FactOrigin.printed);
    expect(f.review, FactReview.unreviewed);
    expect(f.validity, FactValidity.current);
    final CardRow row = await db.select(db.cards).getSingle();
    expect(row.captureSource, CaptureSource.unknown);
  });

  test('a link between two cards goes with either card', () async {
    final AppDatabase db = AppDatabase(NativeDatabase(frozenDatabase(dir, 10)));
    addTearDown(db.close);
    Future<int> card() => db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/z.jpg',
            capturedAt: DateTime(2026),
          ),
        );
    final int warranty = await card();
    final int receipt = await card();
    await db
        .into(db.itemLinks)
        .insert(
          ItemLinksCompanion.insert(
            fromCardId: warranty,
            toCardId: receipt,
            kind: LinkKind.warrantyOf,
          ),
        );
    // The same suggestion twice is refused, not stored twice.
    await expectLater(
      db
          .into(db.itemLinks)
          .insert(
            ItemLinksCompanion.insert(
              fromCardId: warranty,
              toCardId: receipt,
              kind: LinkKind.warrantyOf,
            ),
          ),
      throwsA(anything),
    );
    final ItemLink link = await db.select(db.itemLinks).getSingle();
    expect(link.status, LinkStatus.suggested);
    expect(link.reasons, '[]');

    await (db.delete(
      db.cards,
    )..where(($CardsTable c) => c.id.equals(receipt))).go();
    expect(await db.select(db.itemLinks).get(), isEmpty);
  });

  // The comparison has to be able to fail, or every test built on it passes
  // whatever the migration does.
  test(
    'the comparison notices a missing index, column default or table',
    () async {
      final AppDatabase a = AppDatabase(NativeDatabase.memory());
      final AppDatabase b = AppDatabase(NativeDatabase.memory());
      addTearDown(a.close);
      addTearDown(b.close);
      final Map<String, Object?> same = await describeSchema(b);
      expect(await describeSchema(a), equals(same));

      await a.customStatement('DROP INDEX idx_encounters_card');
      expect(await describeSchema(a), isNot(equals(same)));

      final AppDatabase c = AppDatabase(NativeDatabase.memory());
      addTearDown(c.close);
      await c.customStatement('ALTER TABLE cards ADD COLUMN stray TEXT');
      expect(await describeSchema(c), isNot(equals(same)));
    },
  );
}
