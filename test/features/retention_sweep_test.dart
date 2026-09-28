import 'dart:io';

// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/imaging/photo_vault.dart';
import 'package:recallos/core/storage/hand_offs.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/data/retention_sweep.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';

/// Recently deleted is thirty days, then gone.
///
/// Before the sweep, both delete paths were soft and nothing ever compared
/// `deleted_at` to a date — every deleted card and its full-size photographs
/// stayed on the phone for good. The sweep may destroy only what the user
/// already deleted, so most of these tests are about what it must *not* touch.
void main() {
  late AppDatabase db;
  late Directory documents;
  late RetentionSweep sweep;
  late int scannerCleans;
  final DateTime today = DateTime(2026, 10, 30, 12);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('recallos_sweep');
    PathProviderPlatform.instance = _FakePathProvider(documents.path);
    scannerCleans = 0;
    sweep = RetentionSweep(
      db: db,
      cards: CardRepository(db),
      identity: IdentityRepository(db),
      profiles: ProfileRepository(db),
      now: () => today,
      temporaryDirectory: () async =>
          Directory(p.join(documents.path, 'cache'))..createSync(),
      cleanScanner: () async => scannerCleans++,
    );
  });
  tearDown(() async {
    await db.close();
    if (documents.existsSync()) await documents.delete(recursive: true);
  });

  /// A card with a real photo on disk, deleted [daysAgo] days before today
  /// (or never, when null).
  Future<({int id, File photo})> card({int? daysAgo}) async {
    final File photo = File(
      p.join(documents.path, 'cards', 'card_${daysAgo ?? 'live'}.jpg'),
    )..createSync(recursive: true);
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: photo.path,
            capturedAt: DateTime(2026, 9, 1),
            deletedAt: Value<DateTime?>(
              daysAgo == null ? null : today.subtract(Duration(days: daysAgo)),
            ),
          ),
        );
    return (id: id, photo: photo);
  }

  Future<bool> exists(int id) async =>
      await (db.select(db.cards)..where(($CardsTable c) => c.id.equals(id)))
          .getSingleOrNull() !=
      null;

  test('a card deleted more than thirty days ago is purged, photo and all',
      () async {
    final ({int id, File photo}) old = await card(daysAgo: 31);

    expect(await sweep.purgeExpired(), 1);

    expect(await exists(old.id), isFalse);
    expect(old.photo.existsSync(), isFalse);
  });

  test('a card still inside the thirty days is left alone', () async {
    final ({int id, File photo}) recent = await card(daysAgo: 29);

    expect(await sweep.purgeExpired(), 0);

    expect(await exists(recent.id), isTrue);
    expect(recent.photo.existsSync(), isTrue);
  });

  test('a card that was never deleted is never touched', () async {
    final ({int id, File photo}) live = await card();

    await sweep.run();

    expect(await exists(live.id), isTrue);
    expect(live.photo.existsSync(), isTrue);
  });

  group('copies left in the cache', () {
    // Every way a photograph or an export passes through the cache on its way
    // somewhere. Android empties a cache only when storage runs low, so each
    // of these used to stay for good — the scanner's picture of a card, in the
    // clear, while Settings said the photographs were encrypted.
    late Directory cache;
    setUp(() => cache = Directory(p.join(documents.path, 'cache'))..createSync());

    File put(String relative, Duration age) =>
        File(p.join(cache.path, relative))
          ..createSync(recursive: true)
          ..writeAsBytesSync(<int>[1])
          ..setLastModifiedSync(today.subtract(age));

    test("the scanner's own copy of a card is cleared", () async {
      final File scan = put('$kScannerFolder/361176403615839.jpg',
          const Duration(hours: 20));

      await sweep.removeStaleHandOffs();

      expect(scan.existsSync(), isFalse);
      expect(Directory(p.join(cache.path, kScannerFolder)).existsSync(), isTrue,
          reason: 'the folder is the scanner\'s; only its contents go');
      expect(scannerCleans, 1,
          reason: 'the plugin keeps its own copies outside the cache');
    });

    test('plain copies OCR left behind are cleared, fresh ones kept', () async {
      final File stale = put('${kPlainTempPrefix}1.jpg', const Duration(hours: 2));
      final File crop =
          put('${kPlainTempPrefix}crop_1.png', const Duration(hours: 2));
      final File fresh =
          put('${kPlainTempPrefix}2.jpg', const Duration(minutes: 1));

      await sweep.removeStaleHandOffs();

      expect(stale.existsSync(), isFalse);
      expect(crop.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'OCR may be reading it now');
    });

    test("the pickers' copies are cleared, folder and all", () async {
      final File portrait = put(
        '0f9d3c1e-7a42-4b8e-9c55-1d2e3f4a5b6c/IMG_0042.jpg',
        const Duration(hours: 1),
      );
      final File scaled = put('scaled_IMG_0042.jpg', const Duration(hours: 1));

      await sweep.removeStaleHandOffs();

      expect(portrait.existsSync(), isFalse);
      expect(portrait.parent.existsSync(), isFalse);
      expect(scaled.existsSync(), isFalse);
    });

    test('a shared file is kept a day for the app that received it', () async {
      final File recent =
          put('$kShareFolder/recallos-2026-10-30.zip', const Duration(hours: 3));
      final File old =
          put('$kShareFolder/recallos-2026-10-28.zip', const Duration(days: 2));
      final File outbox =
          put('$kOutboxFolder/Rahim_Ahmed.vcf', const Duration(days: 2));
      final File legacy = put('RecallOS backup 2026-09-29.recallos',
          const Duration(days: 2));

      await sweep.removeStaleHandOffs();

      expect(recent.existsSync(), isTrue,
          reason: 'an email draft may still be reading it');
      expect(old.existsSync(), isFalse);
      expect(outbox.existsSync(), isFalse);
      expect(legacy.existsSync(), isFalse,
          reason: 'written to the cache root before the outbox existed');
    });

    test('anything not declared as a hand-off is left alone', () async {
      final List<File> others = <File>[
        put('oat_primary/arm64/base.art', const Duration(days: 90)),
        put('scanner_cache.jpg', const Duration(days: 90)),
        put('not-a-uuid/photo.jpg', const Duration(days: 90)),
      ];

      await sweep.removeStaleHandOffs();

      for (final File f in others) {
        expect(f.existsSync(), isTrue, reason: f.path);
      }
    });
  });

  group('portrait files', () {
    Future<File> portrait(String name, {required Duration age}) async {
      final Directory dir = await ProfileRepository(db).profileDirectory();
      final File f = File(p.join(dir.path, name))..writeAsBytesSync(<int>[1]);
      f.setLastModifiedSync(today.subtract(age));
      return f;
    }

    test('an old portrait no card points at is removed', () async {
      final File orphan = await portrait('old.jpg', age: const Duration(days: 3));

      expect(await sweep.removeOrphanPortraits(), 1);
      expect(orphan.existsSync(), isFalse);
    });

    test('the portrait a card uses is kept, even on a deleted card', () async {
      final File used = await portrait('used.jpg', age: const Duration(days: 90));
      final File onDeleted =
          await portrait('deleted.jpg', age: const Duration(days: 90));
      await db
          .into(db.profiles)
          .insert(ProfilesCompanion.insert(photoPath: Value<String?>(used.path)));
      await db.into(db.profiles).insert(
            ProfilesCompanion.insert(
              photoPath: Value<String?>(onDeleted.path),
              deletedAt: Value<DateTime?>(today),
            ),
          );

      expect(await sweep.removeOrphanPortraits(), 0);
      expect(used.existsSync(), isTrue);
      expect(onDeleted.existsSync(), isTrue);
    });

    test('a fresh one is left for an editor that may still be open', () async {
      final File fresh =
          await portrait('fresh.jpg', age: const Duration(minutes: 5));

      expect(await sweep.removeOrphanPortraits(), 0);
      expect(fresh.existsSync(), isTrue);
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}
