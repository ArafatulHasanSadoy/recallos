// `isNull`/`isNotNull` are exported by both drift and matcher; the matcher
// ones are meant.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/field_validator.dart';
import 'package:recallos/core/identity/resolution.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';

/// Exercises promotion against a real database.
///
/// What is being protected here is the pair of asymmetries the design rests
/// on: a shared endpoint links two cards to one person automatically, and a
/// shared *name* never does. Getting the first wrong makes the identity graph
/// pointless; getting the second wrong merges two strangers irreversibly.
void main() {
  late AppDatabase db;
  late IdentityRepository identity;
  late CardRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    identity = IdentityRepository(db);
    repo = CardRepository(db);
  });
  tearDown(() async => db.close());

  int cardSeq = 0;

  /// Saves a card carrying the given fields, and promotes it.
  Future<int> scan({
    String? name,
    String? company,
    String? designation,
    String? phone,
    String? email,
    String? website,
    String? address,
    FactSource source = FactSource.printed,
  }) async {
    final int cardId = await db.into(db.cards).insert(
          CardsCompanion.insert(
            imagePath: '/tmp/cards/card_${++cardSeq}.jpg',
            capturedAt: DateTime(2026, 8, 22, 0, cardSeq),
          ),
        );

    Future<void> put(String key, String? value) async {
      if (value == null) return;
      final FieldValidation check = validateField(key, value);
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: key,
              value: value,
              normalizedValue: Value<String?>(check.normalized),
              // Carried through exactly as `attachExtraction` does, or these
              // tests would be exercising a row shape production never writes.
              validationIssue: Value<String?>(check.issue),
              source: source,
            ),
          );
    }

    await put(FieldKeys.personName, name);
    await put(FieldKeys.company, company);
    await put(FieldKeys.designation, designation);
    await put(FieldKeys.phone, phone);
    await put(FieldKeys.email, email);
    await put(FieldKeys.website, website);
    await put(FieldKeys.address, address);

    await identity.promote(cardId);
    return cardId;
  }

  Future<List<Person>> people() => db.select(db.people).get();
  Future<List<Role>> roles() => db.select(db.roles).get();
  Future<List<ContactPoint>> points() => db.select(db.contactPoints).get();

  group('linking', () {
    test('two cards sharing a phone number resolve to one person', () async {
      await scan(
        name: 'Md. Abul Bashar Sarker',
        company: 'Olympus Hospital',
        phone: '01819104376',
      );
      await scan(
        name: 'Abul Bashar Sarker',
        company: 'Green Specialized Hospital',
        phone: '01819104376',
      );

      expect(await people(), hasLength(1));
      // Same human, two employers — the case a flat contacts table cannot
      // represent at all.
      expect(await roles(), hasLength(2));
    });

    test('a shared name alone never merges, and is offered instead', () async {
      await scan(name: 'Md. Rahman', company: 'Rahman Traders', phone: '01711363991');
      await scan(name: 'Rahman', company: 'Rahman Motors', phone: '01712000000');

      expect(await people(), hasLength(2),
          reason: 'two strangers who share a name must stay separate');

      final List<DuplicateCandidate> proposed =
          await db.select(db.duplicateCandidates).get();
      expect(proposed, hasLength(1));
      expect(proposed.single.status, 'pending');
      expect(proposed.single.score, lessThan(MatchVerdict.linkThreshold));
    });

    test('an email links as strongly as a phone', () async {
      await scan(name: 'Asif Ahmed Peal', email: 'p_eal@yahoo.com');
      await scan(name: 'A. A. Peal', email: 'P_Eal@Yahoo.com');

      expect(await people(), hasLength(1),
          reason: 'the normalised email is the same endpoint');
    });
  });

  group('rejected values', () {
    test('a number the validator refused does not become an endpoint',
        () async {
      // Three digits short — a real read off a real card. It cannot be
      // dialled and it cannot match anything, so it must not end up in the
      // graph or in an exported contact.
      await scan(name: 'Truncated Number', phone: '017098227');

      expect(await points(), isEmpty);
      // The person still exists; only the bad endpoint is withheld.
      expect(await people(), hasLength(1));
    });

    test('a good number on the same card still promotes', () async {
      await scan(name: 'Mixed Card', phone: '01819104376');
      expect(await points(), hasLength(1));
    });

    test('a repaired number is still a way to reach somebody', () async {
      // `digit_restored` and `ocr_repaired` are notes on a value that came out
      // fine — the number was reformatted, or a digit inferred — and both
      // carry a good E.164. An earlier filter keyed on the issue rather than
      // the canonical form and discarded every one of them, which on a real
      // card is most of the numbers on it.
      final int cardId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/cards/repaired.jpg',
              capturedAt: DateTime(2026, 8, 22),
            ),
          );
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: FieldKeys.personName,
              value: 'Repaired Number',
              source: FactSource.printed,
            ),
          );
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: FieldKeys.phone,
              value: '01819 10 4376',
              normalizedValue: const Value<String?>('+8801819104376'),
              validationIssue: const Value<String?>('digit_restored'),
              source: FactSource.printed,
            ),
          );
      await identity.promote(cardId);

      expect(await points(), hasLength(1),
          reason: 'a reformatted number is not a rejected one');
      expect((await points()).single.normalizedValue, '+8801819104376');
    });
  });

  group('organizations', () {
    test('a shared website domain links two companies', () async {
      await scan(company: 'Techland BD', website: 'www.techlandbd.com');
      await scan(company: 'Techland Bangladesh Ltd', website: 'techlandbd.com');

      expect(await db.select(db.organizations).get(), hasLength(1));
    });

    test('legal suffixes do not split one company in two', () async {
      await scan(company: 'Aquarius Pet Shop');
      await scan(company: 'Aquarius Pet Shop Ltd.');

      expect(await db.select(db.organizations).get(), hasLength(1));
    });
  });

  group('per-role endpoints', () {
    test('each business keeps its own number', () async {
      await scan(name: 'Kamal Hossain', company: 'Kamal Watch House', phone: '01711111111');
      await scan(name: 'Kamal Hossain', company: 'Kamal Watch House', phone: '01711111111');
      // Linked by the shared number, then a second business appears.
      await scan(name: 'Kamal Hossain', company: 'Kamal Electronics', phone: '01711111111');

      final List<Person> found = await people();
      expect(found, hasLength(1));

      final PersonDetail? detail =
          await identity.watchPerson(found.single.id).first;
      expect(detail, isNotNull);
      expect(detail!.roles, hasLength(2));
      for (final RoleDetail r in detail.roles) {
        expect(r.contacts, isNotEmpty,
            reason: 'every role must be reachable on its own');
      }
    });
  });

  group('idempotency', () {
    test('re-promoting the same card does not duplicate endpoints', () async {
      final int cardId = await scan(
        name: 'Rasel Ahmed Apon',
        company: 'Techland',
        phone: '01324294326',
        email: 'techlandsalse8@gmail.com',
      );

      final int before = (await points()).length;
      await identity.promote(cardId);
      await identity.promote(cardId);

      expect((await points()).length, before);
    });

    test('a corrected number replaces the old one rather than joining it',
        () async {
      final int cardId = await scan(name: 'Nusrat Jahan', phone: '01711111111');

      final CardField phone = (await (db.select(db.cardFields)
                ..where(($CardFieldsTable f) => f.fieldKey.equals(FieldKeys.phone)))
              .get())
          .single;
      final FieldValidation fixed = validateField(FieldKeys.phone, '01722222222');
      await (db.update(db.cardFields)
            ..where(($CardFieldsTable f) => f.id.equals(phone.id)))
          .write(CardFieldsCompanion(
        value: const Value<String>('01722222222'),
        normalizedValue: Value<String?>(fixed.normalized),
        source: const Value<FactSource>(FactSource.user),
        verifiedByUser: const Value<bool>(true),
      ));
      await identity.promote(cardId);

      final List<ContactPoint> after = await points();
      expect(after, hasLength(1));
      expect(after.single.value, '01722222222');
    });
  });

  group('teardown', () {
    test('detaching the last card removes the person it created', () async {
      final int cardId = await scan(name: 'One Off', phone: '01799999999');
      expect(await people(), hasLength(1));

      await identity.detach(cardId);

      expect(await people(), isEmpty);
      expect(await points(), isEmpty);
    });

    test('a person held up by another card survives', () async {
      final int first = await scan(name: 'Shared Person', phone: '01788888888');
      await scan(name: 'Shared Person', phone: '01788888888');

      await identity.detach(first);

      expect(await people(), hasLength(1));
      expect(await points(), hasLength(1),
          reason: 'only the detached card\'s own endpoint goes');
    });

    test('an endpoint the user typed in outlives the card beside it', () async {
      final int cardId = await scan(name: 'Typed By Hand', phone: '01777777777');
      final int personId = (await people()).single.id;

      // No source card: this is the shape a hand-added number takes.
      await db.into(db.contactPoints).insert(
            ContactPointsCompanion.insert(
              ownerType: 'person',
              ownerId: personId,
              kind: ContactKind.phone,
              value: '01766666666',
              normalizedValue: const Value<String?>('+8801766666666'),
              source: FactSource.user,
            ),
          );

      await identity.detach(cardId);

      final List<ContactPoint> left = await points();
      expect(left, hasLength(1));
      expect(left.single.value, '01766666666');
      expect(await people(), hasLength(1),
          reason: 'the person is still held up by the hand-added number');
    });
  });

  group('correcting a mislabelled field', () {
    test('re-labelling a job title as the designation removes the contact',
        () async {
      // Exactly what happens on the review screen: extraction reads the job
      // title as the person, and the user re-labels it before saving.
      final int cardId = await scan(
        name: 'Operations and Sales Manager',
        company: 'Aquarius Pet Shop',
        phone: '01711363991',
      );
      expect(await people(), hasLength(1));

      final CardField wrong = (await (db.select(db.cardFields)
                ..where(($CardFieldsTable f) =>
                    f.fieldKey.equals(FieldKeys.personName)))
              .get())
          .single;
      await repo.updateField(
        fieldId: wrong.id,
        fieldKey: FieldKeys.designation,
      );
      await identity.promote(cardId);

      expect(await people(), isEmpty,
          reason: 'a job title is not a person');
    });

    test('correcting the value renames the contact', () async {
      // The other way to fix it on the review screen: leave the label alone
      // and type the right name over the wrong one.
      final int cardId = await scan(
        name: 'Operations and Sales Manager',
        company: 'Aquarius Pet Shop',
        phone: '01711363991',
      );
      expect((await people()).single.displayName,
          'Operations and Sales Manager');

      final CardField wrong = (await (db.select(db.cardFields)
                ..where(($CardFieldsTable f) =>
                    f.fieldKey.equals(FieldKeys.personName)))
              .get())
          .single;
      await repo.updateField(fieldId: wrong.id, value: 'Asif Ahmed Peal');
      await identity.promote(cardId);

      expect((await people()).single.displayName, 'Asif Ahmed Peal',
          reason: 'the contact has to follow the card it was made from');
    });

    test('the live contacts list sees the correction', () async {
      final int cardId = await scan(
        name: 'Operations and Sales Manager',
        company: 'Aquarius Pet Shop',
        phone: '01711363991',
      );

      final List<List<PersonSummary>> seen = <List<PersonSummary>>[];
      final StreamSubscription<List<PersonSummary>> sub =
          identity.watchPeople().listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, hasLength(1));

      final CardField wrong = (await (db.select(db.cardFields)
                ..where(($CardFieldsTable f) =>
                    f.fieldKey.equals(FieldKeys.personName)))
              .get())
          .single;
      await repo.updateField(
        fieldId: wrong.id,
        fieldKey: FieldKeys.designation,
      );
      await identity.promote(cardId);
      await pumpEventQueue();

      expect(seen.last, isEmpty,
          reason: 'the correction has to reach the screen, not just the rows');
      await sub.cancel();
    });
  });

  group('removing the person from a card', () {
    test('clearing the name detaches the contact', () async {
      final int cardId = await scan(
        name: 'Wrongly Read Name',
        company: 'Target Center',
        phone: '01747157741',
      );
      expect(await people(), hasLength(1));

      // What the user does: open the card, clear the name, save. The card
      // keeps its numbers.
      await (db.delete(db.cardFields)
            ..where(($CardFieldsTable f) =>
                f.cardId.equals(cardId) &
                f.fieldKey.equals(FieldKeys.personName)))
          .go();
      await identity.promote(cardId);

      expect(await people(), isEmpty,
          reason: 'a card with no name is not about anybody');
      // The numbers are still reachable — they belong to the company now.
      expect(await points(), isNotEmpty);
      expect(
        (await points()).every((ContactPoint c) => c.ownerType == 'organization'),
        isTrue,
      );
    });

    test('adding the name back re-links it', () async {
      final int cardId = await scan(company: 'Target Center', phone: '01747157741');
      expect(await people(), isEmpty);

      final FieldValidation check =
          validateField(FieldKeys.personName, 'A Real Name');
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: FieldKeys.personName,
              value: 'A Real Name',
              normalizedValue: Value<String?>(check.normalized),
              source: FactSource.user,
            ),
          );
      await identity.promote(cardId);

      expect(await people(), hasLength(1));
    });
  });

  group('deleting a card', () {
    test('leaves no contact or company behind', () async {
      final int cardId = await scan(
        name: 'Only Card',
        company: 'Only Company',
        phone: '01711363991',
        address: 'Somewhere',
      );
      expect(await people(), hasLength(1));
      expect(await db.select(db.organizations).get(), hasLength(1));

      await identity.detach(cardId);

      expect(await people(), isEmpty);
      expect(await db.select(db.organizations).get(), isEmpty);
      expect(await db.select(db.roles).get(), isEmpty);
      expect(await db.select(db.orgBranches).get(), isEmpty);
      expect(await points(), isEmpty);
    });

    test('a combined company does not outlive its cards', () async {
      // The residue that survived everything: two scans of one shop sign,
      // combined, then both cards deleted. Protecting the tombstone so the
      // merge could be undone also made the pair immortal — the company sat
      // in the list forever with nothing behind it.
      final int first = await scan(company: 'TARGET, CENTER,');
      final int second = await scan(company: 'CTARGEI. CENTER');
      final List<Organization> both = await db.select(db.organizations).get();
      expect(both, hasLength(2));
      await identity.mergeOrganizations(
          survivor: both.first.id, loser: both.last.id);
      expect(await identity.watchOrganizations().first, hasLength(1));

      await identity.detach(first);
      await identity.detach(second);

      expect(await db.select(db.organizations).get(), isEmpty,
          reason: 'neither half of a merged pair may outlive its cards');
    });

    test('a merged pair still standing on one card survives', () async {
      await scan(company: 'TARGET, CENTER,');
      final int second = await scan(company: 'CTARGEI. CENTER');
      final List<Organization> both = await db.select(db.organizations).get();
      await identity.mergeOrganizations(
          survivor: both.first.id, loser: both.last.id);

      await identity.detach(second);

      // One card left, so the combined company stays — and so does the record
      // of the merge, or it could never be separated again.
      expect(await identity.watchOrganizations().first, hasLength(1));
      expect(await db.select(db.organizations).get(), hasLength(2));

    });
  });

  group('implausible names', () {
    test('a stray line does not become a contact', () async {
      // Off the email row of a shop card whose text ran together — extraction
      // files it as a name because it is the best candidate on the card.
      await scan(
        name: 'OE-mgil: targetbrand2015@gm',
        company: 'Target Center',
        phone: '01747157741',
      );

      expect(await people(), isEmpty,
          reason: 'an email is not somebody to put in an address book');
      // The company on the same card is unaffected.
      expect(await db.select(db.organizations).get(), hasLength(1));
    });

    test('one made before the rule existed is cleared on backfill', () async {
      // After the scan, or promotion's garbage collection removes the row
      // before the card can point at it.
      final int cardId = await scan(company: 'Target Center');
      final int personId = await db.into(db.people).insert(
            PeopleCompanion.insert(displayName: 'OE-mgil: targetbrand2015@gm'),
          );
      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .write(CardsCompanion(personId: Value<int?>(personId)));

      await identity.backfill();

      expect(await people(), isEmpty);
    });
  });

  group('duplicate companies', () {
    test('two scans of one shop sign become one company', () async {
      // The pair that started this: one card photographed twice, read
      // differently each time. Exact-equality matching finds nothing here and
      // the library ends up with two companies. A similar name *and* the same
      // address is strong enough to join without asking — two shops do not
      // share a door.
      await scan(company: 'TARGET, CENTER,', address: 'Shop No:300, Dhaka New Market');
      await scan(company: 'CTARGEI. CENTER', address: 'O Shop No:300, Dhaka New Markel');

      expect(await identity.watchOrganizations().first, hasLength(1));
    });

    test('a similar name with no shared address is proposed, not merged',
        () async {
      // Without the address there is nothing to corroborate the name, and a
      // similar name on its own could as easily be a second branch or a rival.
      await scan(company: 'TARGET, CENTER,');
      await scan(company: 'CTARGEI. CENTER');

      expect(await db.select(db.organizations).get(), hasLength(2),
          reason: 'nothing may be joined on a name alone');

      final List<DuplicatePair> orgs = (await identity.watchDuplicates().first)
          .where((DuplicatePair p) => p.kind == DuplicateKind.organization)
          .toList();
      expect(orgs, hasLength(1));
      expect(orgs.single.signals, contains('a similar name'));
    });

    test('two genuinely different companies are left alone', () async {
      await scan(company: 'Rahman Traders', address: 'New Market, Dhaka');
      await scan(company: 'Olympus Hospital', address: 'West Panthapath');

      final List<DuplicatePair> pending =
          await identity.watchDuplicates().first;
      expect(
        pending.where((DuplicatePair p) => p.kind == DuplicateKind.organization),
        isEmpty,
      );
    });

    test('combining two companies gathers their cards under one', () async {
      await scan(company: 'TARGET, CENTER,');
      await scan(company: 'CTARGEI. CENTER');
      final List<Organization> before =
          await db.select(db.organizations).get();
      expect(before, hasLength(2));

      await identity.mergeOrganizations(
          survivor: before.first.id, loser: before.last.id);

      final List<OrgSummary> listed =
          await identity.watchOrganizations().first;
      expect(listed, hasLength(1));

      final OrgDetail? detail =
          await identity.watchOrganization(before.first.id).first;
      expect(detail!.cardIds, hasLength(2),
          reason: 'both scans belong to the one company now');
    });
  });

  group('duplicate cards', () {
    test('the same card scanned twice is proposed', () async {
      // Every number on both, and the same company: this is one piece of
      // paper, not two people at one firm.
      await scan(
        company: 'Target Center',
        phone: '01747157741',
        email: 'targetbrand2015@gmail.com',
      );
      await scan(
        company: 'Target Center',
        phone: '01747157741',
        email: 'targetbrand2015@gmail.com',
      );

      final List<DuplicatePair> cards = (await identity.watchDuplicates().first)
          .where((DuplicatePair p) => p.kind == DuplicateKind.card)
          .toList();
      expect(cards, hasLength(1));
    });

    test('two colleagues sharing one office line are not a duplicate card',
        () async {
      // The office number is on both cards, but each person has a mobile the
      // other does not. Only *every* endpoint matching means one card.
      await scan(
        name: 'First Colleague',
        company: 'Olympus Hospital',
        phone: '01819104376',
      );
      await scan(
        name: 'Second Colleague',
        company: 'Olympus Hospital',
        phone: '01819104376',
        email: 'second@example.com',
      );

      final List<DuplicatePair> cards = (await identity.watchDuplicates().first)
          .where((DuplicatePair p) => p.kind == DuplicateKind.card)
          .toList();
      expect(cards, isEmpty);
    });

    test('discarding the newer scan is a soft delete, not a destruction',
        () async {
      final int first = await scan(
          company: 'Target Center', phone: '01747157741');
      final int second = await scan(
          company: 'Target Center', phone: '01747157741');

      await identity.discardDuplicateCard(keep: first, discard: second);

      final CardRow gone = await (db.select(db.cards)
            ..where(($CardsTable c) => c.id.equals(second)))
          .getSingle();
      expect(gone.deletedAt, isNotNull,
          reason: 'it must be recoverable from Recently deleted');
      // And it stops holding up anything in the graph.
      expect(
        (await points()).where((ContactPoint c) => c.sourceCardId == second),
        isEmpty,
      );
    });
  });

  group('merging', () {
    Future<(int, int)> twoRahmans() async {
      await scan(name: 'Md. Rahman', company: 'Rahman Traders', phone: '01711363991');
      await scan(name: 'Rahman', company: 'Rahman Motors', phone: '01712000000');
      final List<Person> both = await people();
      expect(both, hasLength(2));
      return (both.first.id, both.last.id);
    }

    test('a merged person stops being a separate contact', () async {
      final (int a, int b) = await twoRahmans();

      await identity.merge(survivor: a, loser: b);

      final List<PersonSummary> listed = await identity.watchPeople().first;
      expect(listed.map((PersonSummary p) => p.id), <int>[a]);
      // The row survives so the merge can be undone.
      expect(await people(), hasLength(2));
    });

    test('the survivor gains the other one\'s businesses and numbers',
        () async {
      final (int a, int b) = await twoRahmans();
      await identity.merge(survivor: a, loser: b);

      final PersonDetail? detail = await identity.watchPerson(a).first;
      expect(detail!.roles, hasLength(2),
          reason: 'both businesses belong to the one man now');
      expect(
        detail.roles.expand((RoleDetail r) => r.contacts).length,
        2,
        reason: 'and both numbers are reachable under him',
      );
    });

    test('un-merging puts them back exactly as they were', () async {
      final (int a, int b) = await twoRahmans();
      final PersonDetail? beforeA = await identity.watchPerson(a).first;
      final PersonDetail? beforeB = await identity.watchPerson(b).first;

      await identity.merge(survivor: a, loser: b);
      await identity.unmerge(b);

      final PersonDetail? afterA = await identity.watchPerson(a).first;
      final PersonDetail? afterB = await identity.watchPerson(b).first;

      // Nothing moved during the merge, so nothing has to be guessed on the
      // way back — which is the whole reason it is a pointer.
      expect(afterA!.roles.length, beforeA!.roles.length);
      expect(afterB!.roles.length, beforeB!.roles.length);
      expect(afterA.roles.single.orgName, beforeA.roles.single.orgName);
      expect(afterB.roles.single.orgName, beforeB.roles.single.orgName);
      expect(await identity.watchPeople().first, hasLength(2));
    });

    test('a new card matching the merged-away row joins the survivor',
        () async {
      final (int a, int b) = await twoRahmans();
      await identity.merge(survivor: a, loser: b);

      // The same number as the row that was merged away.
      await scan(name: 'Rahman', company: 'Rahman Motors', phone: '01712000000');

      expect(await identity.watchPeople().first, hasLength(1),
          reason: 'a merged-away row must not come back to life');
    });

    test('the survivor can say who was merged into it', () async {
      final (int a, int b) = await twoRahmans();
      await identity.merge(survivor: a, loser: b);

      final PersonDetail? detail = await identity.watchPerson(a).first;
      // Without this the screen cannot offer a way back, and the prompt that
      // promised one would be lying.
      expect(detail!.mergedFrom.map((PersonSummary p) => p.id), <int>[b]);

      await identity.unmerge(b);
      final PersonDetail? after = await identity.watchPerson(a).first;
      expect(after!.mergedFrom, isEmpty);
    });

    test('a merge survives re-promotion', () async {
      // The loser's card has no *usable* endpoint — its number is three
      // digits short, so it is withheld. That is the case that broke: with
      // nothing to match on, re-promotion fell through to the name, landed on
      // a brand-new row, and the pair came back as a fresh duplicate of the
      // person the user had just finished combining. A card with a good
      // number of its own would have re-matched by endpoint and hidden it.
      await scan(name: 'Md. Rahman', company: 'Rahman Traders', phone: '01711363991');
      await scan(name: 'Rahman', company: 'Rahman Motors', phone: '017098227');
      final List<Person> both = await people();
      expect(both, hasLength(2));
      final int a = both.first.id;
      final int b = both.last.id;

      await identity.merge(survivor: a, loser: b);

      // Backfill re-promotes, which used to re-derive identity from scratch:
      // the merged-away row lost its cards to the survivor, garbage
      // collection then removed the row and its business, and the pair came
      // back as a fresh duplicate. Everything the user decided was undone by
      // opening the contacts screen.
      await identity.backfill();

      expect(await identity.watchPeople().first, hasLength(1),
          reason: 'the merge must not come apart on its own');

      final PersonDetail? detail = await identity.watchPerson(a).first;
      expect(detail!.roles, hasLength(2),
          reason: 'neither business may be collected away');
      expect(detail.mergedFrom, hasLength(1),
          reason: 'and the way back has to survive too');
      expect(await identity.watchDuplicates().first, isEmpty,
          reason: 'a settled pair does not come back as a new question');
    });

    test('keeping them separate settles the question for good', () async {
      final (int a, int b) = await twoRahmans();
      expect(await identity.watchDuplicates().first, hasLength(1));

      await identity.keepSeparate(a: a, b: b);

      expect(await identity.watchDuplicates().first, isEmpty);
      // And re-promoting must not raise it again.
      await identity.backfill();
      expect(await identity.watchDuplicates().first, isEmpty);
    });

    test('the pair explains itself', () async {
      await twoRahmans();
      final DuplicatePair pair =
          (await identity.watchDuplicates().first).single;

      expect(pair.signals, contains('same name'));
      expect(pair.score, lessThan(MatchVerdict.linkThreshold));
    });
  });

  group('soft-deleted cards', () {
    test('one in Recently deleted does not stop the graph being maintained',
        () async {
      // The card that broke everything on the device: soft-deleted long ago,
      // still holding foreign keys to a person and a company. Collecting them
      // failed on a constraint, and because that runs at the top of backfill,
      // nothing after it ran — no re-promotion, no cleanup, for any card.
      final int stranded = await scan(
        name: 'Stranded Person',
        company: 'Stranded Company',
        phone: '01711363991',
      );
      await (db.update(db.cards)
            ..where(($CardsTable c) => c.id.equals(stranded)))
          .write(CardsCompanion(deletedAt: Value<DateTime?>(DateTime.now())));

      // Its endpoints would otherwise keep the entities alive, so clear them
      // the way a delete does — leaving exactly the dangling links.
      await (db.delete(db.contactPoints)
            ..where(($ContactPointsTable c) =>
                c.sourceCardId.equals(stranded)))
          .go();

      await identity.backfill();

      expect(await people(), isEmpty);
      expect(await db.select(db.organizations).get(), isEmpty);
      // And the card itself survives, still recoverable.
      final CardRow still = await (db.select(db.cards)
            ..where(($CardsTable c) => c.id.equals(stranded)))
          .getSingle();
      expect(still.deletedAt, isNotNull);
      expect(still.personId, isNull);
    });
  });

  group('a card deleted but not yet purged', () {
    test('stops holding its company in the contacts list', () async {
      // The residue the user actually saw: two cards in the library, three
      // companies beside them. Deleting soft-deletes at once but only tears
      // the graph down when the undo window closes, so a card deleted while
      // the app was closing kept its endpoints — and those kept its company.
      final int cardId = await scan(
        company: 'Deleted Company',
        phone: '01711363991',
      );
      expect(await db.select(db.organizations).get(), hasLength(1));

      // Soft-deleted and nothing else: the state the app is left in mid-undo.
      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .write(CardsCompanion(deletedAt: Value<DateTime?>(DateTime.now())));

      await identity.backfill();

      expect(await db.select(db.organizations).get(), isEmpty);
      expect(await points(), isEmpty);
    });

    test('restoring it brings the company back', () async {
      final int cardId = await scan(
        company: 'Restored Company',
        phone: '01711363991',
      );
      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .write(CardsCompanion(deletedAt: Value<DateTime?>(DateTime.now())));
      await identity.backfill();
      expect(await db.select(db.organizations).get(), isEmpty);

      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .write(const CardsCompanion(deletedAt: Value<DateTime?>(null)));
      await identity.promote(cardId);

      expect(await db.select(db.organizations).get(), hasLength(1));
      expect(await points(), isNotEmpty);
    });
  });

  group('the screens see the change', () {
    test('collecting a company updates the live list', () async {
      // Garbage collection is raw SQL, which Drift does not observe. Without
      // being told, the rows go and every stream on them keeps serving what
      // it last read — the database correct, the contacts list still showing
      // a company that is no longer in it, and the cleanup looking broken
      // when it has already run.
      final int cardId = await scan(
        company: 'Vanishing Company',
        phone: '01711363991',
      );

      final List<List<OrgSummary>> seen = <List<OrgSummary>>[];
      final StreamSubscription<List<OrgSummary>> sub =
          identity.watchOrganizations().listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, hasLength(1));

      await identity.detach(cardId);
      await pumpEventQueue();

      expect(seen.last, isEmpty,
          reason: 'the list has to hear about it, not just the database');
      await sub.cancel();
    });
  });

  group('rules version', () {
    test('a graph built by older rules is rebuilt', () async {
      final int cardId = await scan(
        company: 'Target Center',
        phone: '01747157741',
      );
      // The shape an older rule left: a person on a card that names nobody.
      final int personId = await db.into(db.people).insert(
            PeopleCompanion.insert(displayName: 'Left Over'),
          );
      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .write(CardsCompanion(personId: Value<int?>(personId)));
      await db.into(db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: 'identity_rules_version',
              value: '0',
            ),
          );

      await identity.backfill();

      expect(await people(), isEmpty,
          reason: 'the whole graph is rebuilt under the current rules');
      // And it records what built it, so the next run is cheap.
      final Setting stored = await (db.select(db.settings)
            ..where(($SettingsTable t) =>
                t.key.equals('identity_rules_version')))
          .getSingle();
      expect(stored.value, IdentityRepository.rulesVersion.toString());
    });

    test('a graph already current is left alone', () async {
      await scan(name: 'Kept Person', phone: '01711363991');
      await db.into(db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: 'identity_rules_version',
              value: IdentityRepository.rulesVersion.toString(),
            ),
          );

      await identity.backfill();

      expect(await people(), hasLength(1));
    });
  });

  group('backfill', () {
    test('re-promotes a card left behind by a tightened rule', () async {
      final int cardId = await scan(name: 'Stale', phone: '01819104376');
      // The shape an older, looser rule left behind: an endpoint with no
      // canonical form, which today's rules would never create.
      await db.into(db.contactPoints).insert(
            ContactPointsCompanion.insert(
              ownerType: 'person',
              ownerId: (await people()).single.id,
              kind: ContactKind.phone,
              value: '017098227',
              sourceCardId: Value<int?>(cardId),
              source: FactSource.printed,
            ),
          );
      expect(await points(), hasLength(2));

      await identity.backfill();

      final List<ContactPoint> after = await points();
      expect(after, hasLength(1),
          reason: 'the stale endpoint should not survive a backfill');
      expect(after.single.value, '01819104376');
    });

    test('promotes cards saved before the graph existed', () async {
      // Written straight to the tables, the way a pre-existing row looks.
      final int cardId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/cards/legacy.jpg',
              capturedAt: DateTime(2026, 8, 1),
            ),
          );
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: FieldKeys.personName,
              value: 'Legacy Contact',
              source: FactSource.printed,
            ),
          );

      expect(await people(), isEmpty);
      await identity.backfill();
      expect(await people(), hasLength(1));
    });
  });

  group('cards that carry no identity', () {
    test('a note-only card creates nothing and is left alone', () async {
      final int cardId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/cards/unreadable.jpg',
              capturedAt: DateTime(2026, 8, 22),
            ),
          );
      await identity.promote(cardId);

      expect(await people(), isEmpty);
      expect(await db.select(db.organizations).get(), isEmpty);

      final CardRow card = await (db.select(db.cards)
            ..where(($CardsTable c) => c.id.equals(cardId)))
          .getSingle();
      expect(card.personId, isNull);
    });
  });
}
