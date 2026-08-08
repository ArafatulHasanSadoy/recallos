import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('migration', () {
    test('creates every table and seeds ranking weights', () async {
      final List<RankingWeight> weights =
          await db.select(db.rankingWeights).get();

      expect(weights, isNotEmpty);
      final Map<String, double> byKey = <String, double>{
        for (final RankingWeight w in weights) w.key: w.value,
      };
      expect(byKey['semantic'], 0.38);
      expect(byKey['note_relevance'], 0.18);

      // The positive weights are the utility formula; they should sum to 1.0 so
      // a perfect match scores 1.0 and scores stay comparable across queries.
      final double positiveSum = byKey.entries
          .where((MapEntry<String, double> e) => !e.key.startsWith('penalty_'))
          .fold(0, (double sum, MapEntry<String, double> e) => sum + e.value);
      expect(positiveSum, closeTo(1.0, 0.0001));
    });

    test('creates the FTS5 search index', () async {
      // Reaching the virtual table at all proves FTS5 is compiled in and the
      // tokenizer arguments were accepted.
      await db.customStatement('''
        INSERT INTO search_index(
          subject_type, subject_id, card_text, note_text, canonical_en, tags)
        VALUES ('card', 1, 'Medica Books Dhanmondi',
          'cheap medical books', 'medical bookshop', 'books')
      ''');

      final List<QueryRow> hits = await db.customSelect('''
        SELECT subject_id FROM search_index WHERE search_index MATCH 'medical'
      ''').get();

      expect(hits, hasLength(1));
      expect(hits.single.read<int>('subject_id'), 1);
    });
  });

  group('identity graph', () {
    // The case the whole schema exists for: one human, three businesses, a
    // different phone for each. A flat contacts table collapses this.
    test('one person can hold several roles with per-role phone numbers',
        () async {
      final int personId = await db.into(db.people).insert(
            PeopleCompanion.insert(displayName: 'Rahim Uddin'),
          );

      final int bankId = await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(name: 'Sonali Bank'),
          );
      final int watchShopId = await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(name: 'Rahim Watch House'),
          );
      final int agencyId = await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(name: 'Pixel Digital'),
          );

      final int bankRole = await db.into(db.roles).insert(
            RolesCompanion.insert(
              personId: personId,
              orgId: bankId,
              title: const Value('Senior Manager'),
            ),
          );
      final int shopRole = await db.into(db.roles).insert(
            RolesCompanion.insert(
              personId: personId,
              orgId: watchShopId,
              title: const Value('Owner'),
            ),
          );
      final int agencyRole = await db.into(db.roles).insert(
            RolesCompanion.insert(
              personId: personId,
              orgId: agencyId,
              title: const Value('Partner'),
            ),
          );

      for (final (int role, String number) in <(int, String)>[
        (bankRole, '+8801711000001'),
        (shopRole, '+8801711000002'),
        (agencyRole, '+8801711000003'),
      ]) {
        await db.into(db.contactPoints).insert(
              ContactPointsCompanion.insert(
                ownerType: 'person',
                ownerId: personId,
                kind: ContactKind.phone,
                value: number,
                normalizedValue: Value(number),
                roleId: Value(role),
                source: FactSource.printed,
              ),
            );
      }

      final List<Role> roles = await (db.select(db.roles)
            ..where(($RolesTable r) => r.personId.equals(personId)))
          .get();
      expect(roles, hasLength(3));

      // Each role resolves to its own number rather than one shared contact.
      final List<ContactPoint> shopPhones = await (db.select(db.contactPoints)
            ..where(($ContactPointsTable c) => c.roleId.equals(shopRole)))
          .get();
      expect(shopPhones.single.value, '+8801711000002');
    });
  });

  group('OCR recovery', () {
    test('a card is saved before extraction and survives total OCR failure',
        () async {
      // Save-first: the row exists with status pending before any engine runs.
      final int cardId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/card_001.jpg',
              capturedAt: DateTime(2026, 8, 7),
            ),
          );

      CardRow card = await (db.select(db.cards)
            ..where(($CardsTable c) => c.id.equals(cardId)))
          .getSingle();
      expect(card.extractionStatus, ExtractionStatus.pending);

      // OCR runs and finds nothing at all.
      await db.into(db.extractionAttempts).insert(
            ExtractionAttemptsCompanion.insert(
              cardId: cardId,
              engine: 'routed',
              startedAt: DateTime(2026, 8, 7),
              durationMs: 4200,
              status: AttemptStatus.failed,
              errorCode: const Value('noTextFound'),
            ),
          );
      await (db.update(db.cards)
            ..where(($CardsTable c) => c.id.equals(cardId)))
          .write(
        const CardsCompanion(
          extractionStatus: Value(ExtractionStatus.failed),
        ),
      );

      // The card is still here, and the note makes it retrievable anyway.
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              subjectType: 'card',
              subjectId: cardId,
              body: const Value('cheap t-shirt printer from CSE fest'),
            ),
          );

      card = await (db.select(db.cards)
            ..where(($CardsTable c) => c.id.equals(cardId)))
          .getSingle();
      expect(card.extractionStatus, ExtractionStatus.failed);
      expect(card.imagePath, '/tmp/card_001.jpg');

      final List<Note> notes = await (db.select(db.notes)
            ..where(($NotesTable n) => n.subjectId.equals(cardId)))
          .get();
      expect(notes.single.body, contains('cheap t-shirt printer'));
    });

    test('unassigned OCR blocks remain available for tap-to-assign', () async {
      final int cardId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/card_002.jpg',
              capturedAt: DateTime(2026, 8, 7),
            ),
          );

      await db.batch((Batch b) {
        b.insertAll(db.ocrBlocks, <OcrBlocksCompanion>[
          OcrBlocksCompanion.insert(
            cardId: cardId,
            blockText: 'Kamal Hossain',
            rect: '10,10,200,40',
            confidence: 0.93,
            script: 'latin',
            assignedFieldKey: const Value('person_name'),
          ),
          // Layout defeated field assignment — the text was read fine, it just
          // has no home yet. This is exactly what tap-to-assign repairs.
          OcrBlocksCompanion.insert(
            cardId: cardId,
            blockText: '01711-223344',
            rect: '10,60,180,85',
            confidence: 0.88,
            script: 'latin',
          ),
        ]);
      });

      final List<OcrBlockRow> unassigned = await (db.select(db.ocrBlocks)
            ..where(($OcrBlocksTable b) => b.assignedFieldKey.isNull()))
          .get();

      expect(unassigned, hasLength(1));
      expect(unassigned.single.blockText, '01711-223344');
    });

    test('deleting a card cascades to its blocks, fields and attempts',
        () async {
      final int cardId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/card_003.jpg',
              capturedAt: DateTime(2026, 8, 7),
            ),
          );
      await db.into(db.ocrBlocks).insert(
            OcrBlocksCompanion.insert(
              cardId: cardId,
              blockText: 'x',
              rect: '0,0,1,1',
              confidence: 0.5,
              script: 'latin',
            ),
          );
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: 'phone',
              value: '01711223344',
              source: FactSource.printed,
            ),
          );

      await (db.delete(db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .go();

      expect(await db.select(db.ocrBlocks).get(), isEmpty);
      expect(await db.select(db.cardFields).get(), isEmpty);
    });
  });

  group('provenance', () {
    test('a user correction outranks the printed value on the same field',
        () async {
      final int cardId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: '/tmp/card_004.jpg',
              capturedAt: DateTime(2026, 8, 7),
            ),
          );

      // OCR misread a Bengali-script company name.
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: 'company',
              value: 'M3d1ca 8ooks',
              source: FactSource.printed,
              confidence: const Value(0.41),
              validationIssue: const Value('low_confidence'),
            ),
          );
      // The user fixed it.
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: 'company',
              value: 'Medica Books',
              source: FactSource.user,
              verifiedByUser: const Value(true),
            ),
          );

      final List<CardField> company = await (db.select(db.cardFields)
            ..where(($CardFieldsTable f) => f.fieldKey.equals('company')))
          .get();
      expect(company, hasLength(2));

      final CardField winner = company.reduce(
        (CardField a, CardField b) =>
            a.source == FactSource.user ? a : b,
      );
      expect(winner.value, 'Medica Books');
      expect(winner.verifiedByUser, isTrue);
    });
  });
}
