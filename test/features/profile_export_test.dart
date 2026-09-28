import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/export/vcard.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/contacts/data/contact_export.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';

/// The user's own card, as a vCard.
///
/// `vCardForProfile` is a mapper, not a serialiser — the escaping, the name
/// split and the TEL types all belong to `buildVCard` and are tested against it
/// in `vcard_test.dart`. What is worth pinning here is the mapping itself, and
/// in particular the two ways it can quietly produce a wrong card: putting the
/// same website in twice, and putting the same number in twice.
void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProfileRepository(db);
  });
  tearDown(() async => db.close());

  Future<ProfileDetail> saved(List<ProfileEntry> entries, {String? tagline}) async {
    await repo.save(ProfileDraft(tagline: tagline, entries: entries));
    return (await repo.watchDefault().first)!;
  }

  test('a filled card maps to every vCard line', () async {
    final ProfileDetail detail = await saved(
      const <ProfileEntry>[
        ProfileEntry(fieldKey: FieldKeys.personName, value: 'Nusrat Jahan'),
        ProfileEntry(fieldKey: FieldKeys.designation, value: 'Founder'),
        ProfileEntry(fieldKey: FieldKeys.company, value: 'Aquarius'),
        ProfileEntry(
          fieldKey: FieldKeys.phone,
          value: '01711363991',
          label: 'mobile',
        ),
        ProfileEntry(fieldKey: FieldKeys.email, value: 'nusrat@aquarius.bd'),
        ProfileEntry(fieldKey: FieldKeys.address, value: 'Dhaka New Market'),
      ],
      tagline: 'cheap t-shirt printing, low quantity',
    );

    final String card = buildVCard(vCardForProfile(detail));

    expect(card, contains('FN:Nusrat Jahan'));
    expect(card, contains('ORG:Aquarius'));
    expect(card, contains('TITLE:Founder'));
    expect(card, contains('EMAIL;TYPE=INTERNET:nusrat@aquarius.bd'));
    expect(card, contains('Dhaka New Market'));
    // The tagline is the whole reason this feature is RecallOS's and not a
    // form: it has to land in the other person's address book.
    expect(card, contains('NOTE:cheap t-shirt printing'));
    // A label the user gave becomes a real TYPE, which is only possible
    // because `profile_fields.label` is actually written — unlike
    // `contact_points.label`, which never is.
    expect(card, contains('TEL;TYPE=CELL:01711363991'));
  });

  test('the website appears exactly once', () async {
    final ProfileDetail detail = await saved(
      const <ProfileEntry>[
        ProfileEntry(fieldKey: FieldKeys.personName, value: 'Someone'),
        ProfileEntry(fieldKey: FieldKeys.website, value: 'aquarius.com.bd'),
      ],
    );

    // `buildVCard` writes `VCardData.website` as a URL line *and* writes every
    // website contact as one. Setting both would put the same address in the
    // card twice, and a contacts app shows both.
    final String card = buildVCard(vCardForProfile(detail));
    expect(RegExp('^URL:', multiLine: true).allMatches(card), hasLength(1));
  });

  test('one number typed two ways is exported once', () async {
    final ProfileDetail detail = await saved(
      const <ProfileEntry>[
        ProfileEntry(fieldKey: FieldKeys.personName, value: 'Someone'),
        ProfileEntry(fieldKey: FieldKeys.phone, value: '01711363991'),
        ProfileEntry(fieldKey: FieldKeys.phone, value: '01711-363991'),
      ],
    );

    // Both normalise to the same E.164, so the address book gets one number
    // rather than two that dial the same person.
    final String card = buildVCard(vCardForProfile(detail));
    expect(RegExp('^TEL', multiLine: true).allMatches(card), hasLength(1));
  });

  test('a card with no name falls back to the company', () async {
    final ProfileDetail detail = await saved(
      const <ProfileEntry>[
        ProfileEntry(fieldKey: FieldKeys.company, value: 'Aquarius Pet Shop'),
        ProfileEntry(fieldKey: FieldKeys.phone, value: '01711363991'),
      ],
    );

    // The fallback lives in `buildVCard`, so the mapper hands it an empty name
    // rather than inventing a second fallback that could disagree.
    expect(vCardForProfile(detail).displayName, '');
    expect(buildVCard(vCardForProfile(detail)), contains('FN:Aquarius Pet Shop'));
  });

  test('an empty card is recognised as empty rather than exported', () async {
    await repo.save(const ProfileDraft(entries: <ProfileEntry>[]));
    final ProfileDetail detail = (await repo.watchDefault().first)!;

    // "This contact is no longer here" is the wrong sentence for a card you
    // simply have not filled in, which is why `ContactExportResult.empty`
    // exists.
    expect(detail.isEmpty, isTrue);
  });
}
