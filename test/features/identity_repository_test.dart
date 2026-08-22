// `isNull`/`isNotNull` are exported by both drift and matcher; the matcher
// ones are meant.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/field_validator.dart';
import 'package:recallos/core/identity/resolution.dart';
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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    identity = IdentityRepository(db);
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
