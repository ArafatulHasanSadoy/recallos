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

  group('backfill', () {
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
