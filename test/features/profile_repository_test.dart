import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';

/// The user's own card, stored.
///
/// The one test here that is worth more than the others is
/// "the stream fires when only the fields change". Drift re-runs a stream when
/// the tables its *own query* names change, and `watchDefault`'s query names
/// only `profiles` while everything on screen lives in `profile_fields`. Get
/// the `readsFrom` set wrong and every write succeeds, every assertion about
/// the database passes, and Save silently does nothing on the phone —
/// the same failure `CardRepository.watchCard` carries a comment about.
void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProfileRepository(db);
  });
  tearDown(() async => db.close());

  ProfileDraft draft({
    int? id,
    String name = 'Arafatul Hasan Sadoy',
    String phone = '01711363991',
    String? tagline,
    String? email,
  }) => ProfileDraft(
    id: id,
    tagline: tagline,
    entries: <ProfileEntry>[
      ProfileEntry(fieldKey: FieldKeys.personName, value: name),
      ProfileEntry(fieldKey: FieldKeys.designation, value: 'Founder'),
      ProfileEntry(fieldKey: FieldKeys.company, value: 'EnationX'),
      ProfileEntry(fieldKey: FieldKeys.phone, value: phone, label: 'mobile'),
      if (email != null) ProfileEntry(fieldKey: FieldKeys.email, value: email),
    ],
  );

  test('a saved card comes back whole', () async {
    final int id = await repo.save(draft(tagline: 'cheap t-shirt printing'));

    final ProfileDetail? detail = await repo.watchDefault().first;
    expect(detail, isNotNull);
    expect(detail!.profile.id, id);
    expect(detail.name, 'Arafatul Hasan Sadoy');
    expect(detail.valueOf(FieldKeys.company), 'EnationX');
    expect(detail.profile.tagline, 'cheap t-shirt printing');
  });

  test('the first card is the one you hand over', () async {
    await repo.save(draft());
    final ProfileDetail detail = (await repo.watchDefault().first)!;
    expect(detail.profile.isDefault, isTrue);
  });

  test('saving again replaces rather than accumulates', () async {
    final int id = await repo.save(draft());
    await repo.save(draft(id: id, name: 'A. H. Sadoy'));

    expect(await db.select(db.profiles).get(), hasLength(1));
    final ProfileDetail detail = (await repo.watchDefault().first)!;
    expect(detail.name, 'A. H. Sadoy');
    // Four entries in, four rows out — not eight.
    expect(detail.fields, hasLength(4));
  });

  test('the stream fires when only the fields change', () async {
    final int id = await repo.save(draft());

    // Two emissions: the card as it stands, then the card after an edit that
    // touches `profile_fields` and nothing else. Without `profile_fields` in
    // the stream's `readsFrom`, the second never arrives.
    final Future<List<ProfileDetail?>> seen = repo
        .watchDefault()
        .take(2)
        .toList();

    await Future<void>.delayed(Duration.zero);
    await repo.save(draft(id: id, name: 'Someone Else'));

    final List<ProfileDetail?> emissions = await seen;
    expect(emissions.last!.name, 'Someone Else');
  });

  test('a number is canonicalised the way a scanned one is', () async {
    await repo.save(draft(phone: '01711-363991'));

    final ProfileDetail detail = (await repo.watchDefault().first)!;
    final ProfileField phone = detail.allOf(FieldKeys.phone).single;
    // The same `validateField` the correction path uses, so a number the
    // scanner would reject cannot be accepted because it arrived by hand.
    expect(phone.normalizedValue, '+8801711363991');
    // What the user typed is what the card shows.
    expect(phone.value, '01711-363991');
  });

  test('an empty slot is not written', () async {
    await repo.save(
      const ProfileDraft(
        entries: <ProfileEntry>[
          ProfileEntry(fieldKey: FieldKeys.personName, value: 'Someone'),
          ProfileEntry(fieldKey: FieldKeys.email, value: '   '),
          ProfileEntry(fieldKey: FieldKeys.website, value: ''),
        ],
      ),
    );

    // The editor always offers every field, so most cards commit with several
    // of them blank; a blank one is not a fact about anybody.
    final ProfileDetail detail = (await repo.watchDefault().first)!;
    expect(detail.fields, hasLength(1));
    expect(detail.valueOf(FieldKeys.email), isNull);
  });

  test('fields come back in reading order, not insertion order', () async {
    await repo.save(
      const ProfileDraft(
        entries: <ProfileEntry>[
          ProfileEntry(fieldKey: FieldKeys.address, value: 'Dhaka'),
          ProfileEntry(fieldKey: FieldKeys.personName, value: 'Someone'),
          ProfileEntry(fieldKey: FieldKeys.phone, value: '01711363991'),
        ],
      ),
    );

    final ProfileDetail detail = (await repo.watchDefault().first)!;
    expect(
      detail.fields.map((ProfileField f) => f.fieldKey),
      <String>[FieldKeys.personName, FieldKeys.phone, FieldKeys.address],
    );
  });

  test('the card face is built from the stored rows', () async {
    await repo.save(draft(email: 'sadoy@enationx.com', tagline: 'printing'));

    final ProfileCard card = (await repo.watchDefault().first)!.toCard();
    expect(card.name, 'Arafatul Hasan Sadoy');
    expect(card.designation, 'Founder');
    expect(card.company, 'EnationX');
    expect(card.tagline, 'printing');
    // The heading fields are not repeated as contact lines; only the ways to
    // reach somebody are.
    expect(
      card.lines.map((ProfileLine l) => l.value),
      <String>['01711363991', 'sadoy@enationx.com'],
    );
    // A label the user gave wins over the generic one.
    expect(card.lines.first.label, 'mobile');
  });

  test('a deleted card stops being handed over and stops being found',
      () async {
    final int id = await repo.save(draft());
    await repo.softDelete(id);

    expect(await repo.watchDefault().first, isNull);
    // The tombstone gives up the default flag on its way out, or the partial
    // unique index would refuse the next card the user made.
    final Profile row = await (db.select(db.profiles)
          ..where(($ProfilesTable t) => t.id.equals(id)))
        .getSingle();
    expect(row.isDefault, isFalse);
    expect(row.deletedAt, isNotNull);

    await repo.save(draft());
    expect((await repo.watchDefault().first)!.profile.isDefault, isTrue);
  });

  test('replacing the portrait drops the file it replaced', () async {
    final int id = await repo.save(draft());
    await repo.attachPhoto(id, '/tmp/does-not-exist-a.jpg');
    await repo.attachPhoto(id, '/tmp/does-not-exist-b.jpg');

    // The old path is gone from the row whether or not the file was there —
    // a file that will not delete must not fail the save.
    expect(
      (await repo.watchDefault().first)!.profile.photoPath,
      '/tmp/does-not-exist-b.jpg',
    );

    await repo.removePhoto(id);
    expect((await repo.watchDefault().first)!.profile.photoPath, isNull);
  });

  // The editor saves through `save`, never `attachPhoto` — so the file
  // lifecycle has to hold there, with real files, or every portrait the user
  // ever replaced stays on the phone.
  group('portrait files through save', () {
    late Directory documents;

    setUp(() async {
      documents = await Directory.systemTemp.createTemp('recallos_profile');
      PathProviderPlatform.instance = _FakePathProvider(documents.path);
    });
    tearDown(() async {
      if (documents.existsSync()) await documents.delete(recursive: true);
    });

    Future<String> portrait(String name) async {
      final Directory dir = await repo.profileDirectory();
      final File f = File(p.join(dir.path, name))
        ..writeAsBytesSync(<int>[0xFF, 0xD8, 0xFF, 0xD9]);
      return f.path;
    }

    ProfileDraft withPhoto(int? id, String? photo) => ProfileDraft(
      id: id,
      photoPath: photo,
      entries: const <ProfileEntry>[
        ProfileEntry(fieldKey: FieldKeys.personName, value: 'Arafatul Hasan Sadoy'),
      ],
    );

    test('replacing the portrait on Save deletes the old file', () async {
      final String first = await portrait('portrait_1.jpg');
      final String second = await portrait('portrait_2.jpg');

      final int id = await repo.save(withPhoto(null, first));
      await repo.save(withPhoto(id, second));

      expect(File(first).existsSync(), isFalse);
      expect(File(second).existsSync(), isTrue);
    });

    test('removing the portrait on Save deletes the file', () async {
      final String only = await portrait('portrait_1.jpg');

      final int id = await repo.save(withPhoto(null, only));
      await repo.save(withPhoto(id, null));

      expect(File(only).existsSync(), isFalse);
    });

    test('saving other changes keeps the portrait', () async {
      final String only = await portrait('portrait_1.jpg');

      final int id = await repo.save(withPhoto(null, only));
      await repo.save(withPhoto(id, only));

      expect(File(only).existsSync(), isTrue);
    });

    test('an unsaved pick is deleted, and nothing outside the folder is',
        () async {
      final String pick = await portrait('portrait_unsaved.jpg');
      final File outside = File(p.join(documents.path, 'cards', 'card.jpg'))
        ..createSync(recursive: true);

      await repo.discardUnsavedPortrait(pick);
      await repo.discardUnsavedPortrait(outside.path);

      expect(File(pick).existsSync(), isFalse);
      expect(outside.existsSync(), isTrue,
          reason: 'only portraits the editor made may be discarded');
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
