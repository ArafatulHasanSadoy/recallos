import 'dart:io';
import 'dart:ui' show Rect;

// `isNull` and `isNotNull` are exported by both drift and matcher; the matcher
// ones are meant.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/field_validator.dart';
import 'package:recallos/core/extraction/phone.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';

/// Exercises the persistence side of the save flow against a real database.
///
/// The file-copy half of `CardRepository` needs a platform path provider, so
/// these drive the database operations directly with the same statements the
/// repository issues. What is being protected here is the *ordering* guarantee:
/// a card exists before OCR runs, and survives OCR failing.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> createPending() => db.into(db.cards).insert(
        CardsCompanion.insert(
          imagePath: '/tmp/cards/card_1.jpg',
          capturedAt: DateTime(2026, 8, 8),
        ),
      );

  Future<CardRow> load(int id) => (db.select(db.cards)
        ..where(($CardsTable c) => c.id.equals(id)))
      .getSingle();

  group('save-first ordering', () {
    test('a card exists and is pending before any recognition runs', () async {
      final int id = await createPending();
      final CardRow card = await load(id);

      expect(card.extractionStatus, ExtractionStatus.pending);
      expect(card.imagePath, isNotEmpty);
      expect(card.rawOcrText, isNull);
    });

    test('a card whose OCR found nothing is still saved and still findable',
        () async {
      final int id = await createPending();

      // OCR returns nothing at all.
      await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
          .write(const CardsCompanion(
        extractionStatus: Value<ExtractionStatus>(ExtractionStatus.failed),
      ));
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              subjectType: 'card',
              subjectId: id,
              body: const Value<String?>('cheap t-shirt printer from CSE fest'),
            ),
          );

      final CardRow card = await load(id);
      expect(card.extractionStatus, ExtractionStatus.failed);
      expect(card.imagePath, isNotEmpty);

      // The note alone is what makes it retrievable, which is the point.
      final List<Note> notes = await (db.select(db.notes)
            ..where(($NotesTable n) => n.subjectId.equals(id)))
          .get();
      expect(notes.single.body, contains('t-shirt printer'));
    });
  });

  group('attaching an extraction', () {
    // The real card from the device, including the phone number ML Kit
    // truncated and the fields it misassigned before the fix.
    List<OcrBlock> shopCardBlocks() => <OcrBlock>[
          _rotated('G AHMED', across: 62, along: 300, offset: 40),
          _rotated('President', across: 60, along: 290, offset: 170),
          _rotated('01673465717', across: 34, along: 250, offset: 250),
          _rotated('1714066410', across: 34, along: 235, offset: 300),
          _rotated('Shop No:278', across: 24, along: 150, offset: 380),
          _rotated('New Market', across: 24, along: 150, offset: 420),
          _rotated('bKash', across: 14, along: 50, offset: 600),
        ];

    test('stores every block, assigned or not', () async {
      final int id = await createPending();
      final List<OcrBlock> blocks = shopCardBlocks();
      final CardExtraction extraction = CardFieldExtractor.extract(blocks);

      final Set<int> assigned = <int>{
        for (final ExtractedField f in extraction.fields)
          if (f.sourceBlockIndex != null) f.sourceBlockIndex!,
      };

      await db.batch((Batch batch) {
        batch.insertAll(db.ocrBlocks, <OcrBlocksCompanion>[
          for (int i = 0; i < blocks.length; i++)
            OcrBlocksCompanion.insert(
              cardId: id,
              blockText: blocks[i].text,
              rect: '0,0,1,1',
              confidence: blocks[i].confidence,
              script: blocks[i].script.name,
              assignedFieldKey:
                  Value<String?>(assigned.contains(i) ? 'x' : null),
              orderIndex: Value<int>(i),
            ),
        ]);
      });

      final List<OcrBlockRow> stored = await db.select(db.ocrBlocks).get();
      expect(stored, hasLength(blocks.length));

      // The unassigned ones are what tap-to-assign will offer later, so losing
      // them would make a bad layout unrecoverable without retyping.
      final List<OcrBlockRow> unassigned = stored
          .where((OcrBlockRow b) => b.assignedFieldKey == null)
          .toList();
      expect(
        unassigned.map((OcrBlockRow b) => b.blockText),
        contains('bKash'),
      );
    });

    test('persists the corrected phone number, not the OCR mistake', () async {
      final int id = await createPending();
      final CardExtraction extraction =
          CardFieldExtractor.extract(shopCardBlocks());

      await db.batch((Batch batch) {
        batch.insertAll(db.cardFields, <CardFieldsCompanion>[
          for (final ExtractedField f in extraction.fields)
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: f.fieldKey,
              value: f.value,
              normalizedValue: Value<String?>(f.normalizedValue),
              source: FactSource.printed,
              validationIssue: Value<String?>(f.issue),
            ),
        ]);
      });

      final List<CardField> phones = await (db.select(db.cardFields)
            ..where(($CardFieldsTable f) => f.fieldKey.equals(FieldKeys.phone)))
          .get();

      expect(
        phones.map((CardField f) => f.value),
        containsAll(<String>['01673465717', '01714066410']),
      );
      expect(
        phones.map((CardField f) => f.normalizedValue),
        containsAll(<String>['+8801673465717', '+8801714066410']),
      );

      // The restored digit is recorded as an inference, not as printed fact.
      final CardField restored = phones
          .firstWhere((CardField f) => f.value == '01714066410');
      expect(restored.validationIssue, 'digit_restored');
    });

    test('re-extracting replaces rather than duplicates', () async {
      final int id = await createPending();

      Future<void> attach() async {
        await (db.delete(db.cardFields)
              ..where(($CardFieldsTable f) => f.cardId.equals(id)))
            .go();
        await db.into(db.cardFields).insert(
              CardFieldsCompanion.insert(
                cardId: id,
                fieldKey: FieldKeys.phone,
                value: '01711223344',
                source: FactSource.printed,
              ),
            );
      }

      await attach();
      await attach();

      expect(await db.select(db.cardFields).get(), hasLength(1));
    });
  });

  // Cards scanned before `PhoneExtractor.restoresDigit` carry "digit restored"
  // on any phone whose dialable form differed from the printed text — a
  // country code or a dash was enough. The label is stored, so these are rows
  // written the way the old rule wrote them, repaired in place.
  group('repairing stored "digit restored" labels', () {
    late CardRepository repo;
    late int cardId;

    setUp(() async {
      repo = CardRepository(db);
      cardId = await createPending();
    });

    Future<CardField> field(int id) => (db.select(db.cardFields)
          ..where(($CardFieldsTable f) => f.id.equals(id)))
        .getSingle();

    /// A phone row and the block it was read from, as the old rule left them.
    Future<int> stored(
      String printed, {
      required String e164,
      String issue = 'digit_restored',
      FactSource source = FactSource.printed,
      bool verified = false,
      bool linked = true,
    }) async {
      final int id = await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: FieldKeys.phone,
              value: PhoneExtractor.formatNational(e164),
              normalizedValue: Value<String?>(e164),
              source: source,
              verifiedByUser: Value<bool>(verified),
              validationIssue: Value<String?>(issue),
            ),
          );
      await db.into(db.ocrBlocks).insert(
            OcrBlocksCompanion.insert(
              cardId: cardId,
              blockText: printed,
              rect: '0,0,1,1',
              confidence: 0.9,
              script: 'latin',
              assignedFieldKey:
                  Value<String?>(linked ? FieldKeys.phone : null),
              fieldId: Value<int?>(linked ? id : null),
            ),
          );
      return id;
    }

    test('a printed number shown in its dialable form is on the card again',
        () async {
      // The shape of "Test Card Printing Ltd" in the device's wallet, stored
      // through the real save path so the blocks point at their fields the way
      // they do on the phone.
      final List<OcrBlock> blocks = <OcrBlock>[
        _line('Test Card Printing Ltd', top: 10, height: 40),
        _line('+880 1711-223344', top: 200, height: 16),
        _line('1714066410', top: 240, height: 16),
      ];
      await repo.attachExtraction(
        cardId: cardId,
        result: OcrResult(
          blocks: blocks,
          engine: 'test',
          duration: const Duration(milliseconds: 20),
        ),
        extraction: CardFieldExtractor.extract(blocks),
      );
      // What the old rule stored on both.
      await (db.update(db.cardFields)
            ..where(($CardFieldsTable f) => f.fieldKey.equals(FieldKeys.phone)))
          .write(const CardFieldsCompanion(
        validationIssue: Value<String?>('digit_restored'),
      ));

      expect(await repo.repairDigitRestoredLabels(), 1);

      final List<CardField> phones = await (db.select(db.cardFields)
            ..where(($CardFieldsTable f) => f.fieldKey.equals(FieldKeys.phone)))
          .get();
      final CardField printed = phones.firstWhere(
        (CardField f) => f.normalizedValue == '+8801711223344',
      );
      expect(printed.validationIssue, isNull);
      expect(printed.source, FactSource.printed);
      // Only the label moves; what the user sees and dials does not.
      expect(printed.value, '01711223344');

      // The zero this one never printed is still an inference.
      final CardField lost = phones.firstWhere(
        (CardField f) => f.normalizedValue == '+8801714066410',
      );
      expect(lost.validationIssue, 'digit_restored');
      expect(lost.value, '01714066410');
    });

    test('separators and a written-out country code are formatting', () async {
      final int dashed = await stored('01711-223344', e164: '+8801711223344');
      final int intl =
          await stored('00880 1911 556677', e164: '+8801911556677');

      expect(await repo.repairDigitRestoredLabels(), 2);
      expect((await field(dashed)).validationIssue, isNull);
      expect((await field(intl)).validationIssue, isNull);
    });

    test('finds its own number in a block that prints two', () async {
      // Keyed on the stored E.164, not on the first number in the block: the
      // first here is printed in full, the second lost its zero.
      final int second = await stored(
        '+880 1711-223344, 1911556677',
        e164: '+8801911556677',
      );

      expect(await repo.repairDigitRestoredLabels(), 0);
      expect((await field(second)).validationIssue, 'digit_restored');
    });

    test('leaves a row alone when there is nothing to judge it by', () async {
      final int orphan = await stored(
        '+880 1711-223344',
        e164: '+8801711223344',
        linked: false,
      );
      // The block no longer parses to the stored number.
      final int moved = await stored(
        '+880 1811-998877',
        e164: '+8801911556677',
      );

      expect(await repo.repairDigitRestoredLabels(), 0);
      expect((await field(orphan)).validationIssue, 'digit_restored');
      expect((await field(moved)).validationIssue, 'digit_restored');
    });

    test('touches nothing a person settled or another rule decided', () async {
      final int confirmed = await stored(
        '+880 1711-223344',
        e164: '+8801711223344',
        verified: true,
      );
      final int typed = await stored(
        '+880 1911-556677',
        e164: '+8801911556677',
        source: FactSource.user,
      );
      final int repaired = await stored(
        '+880 1811-998877',
        e164: '+8801811998877',
        issue: 'ocr_repaired',
      );

      expect(await repo.repairDigitRestoredLabels(), 0);
      expect((await field(confirmed)).validationIssue, 'digit_restored');
      expect((await field(typed)).validationIssue, 'digit_restored');
      expect((await field(repaired)).validationIssue, 'ocr_repaired');
    });

    test('runs once', () async {
      final int first = await stored('01711-223344', e164: '+8801711223344');
      expect(await repo.repairDigitRestoredLabels(), 1);

      // Anything labelled after the repair was labelled by the new rule, so a
      // second launch has no business second-guessing it.
      final int later = await stored('01911-556677', e164: '+8801911556677');
      expect(await repo.repairDigitRestoredLabels(), 0);

      expect((await field(first)).validationIssue, isNull);
      expect((await field(later)).validationIssue, 'digit_restored');
    });
  });

  // Before `_findPerson` learned what a tagline looks like, a shop card filed
  // the line under its brand as a person, and promotion made a contact of it.
  // These store cards the way that extractor left them — the same blocks, with
  // the tagline's block owned by a `person_name` row — and repair them in
  // place.
  group('repairing people invented from a tagline', () {
    late CardRepository repo;
    late IdentityRepository identity;
    int seq = 0;

    setUp(() {
      repo = CardRepository(db);
      identity = IdentityRepository(db);
    });

    Future<int> card() => db.into(db.cards).insert(
          CardsCompanion.insert(
            imagePath: '/tmp/cards/card_${++seq}.jpg',
            capturedAt: DateTime(2026, 9, 1, 0, seq),
          ),
        );

    /// Saves [blocks] as an older extractor filed them — each key off the
    /// blocks at those indices — and promotes the card, as capture does.
    Future<void> readBefore(
      int cardId,
      List<OcrBlock> blocks,
      Map<String, List<int>> filed, {
      CardSide side = CardSide.front,
    }) async {
      await repo.attachExtraction(
        cardId: cardId,
        result: OcrResult(
          blocks: blocks,
          engine: 'test',
          duration: const Duration(milliseconds: 20),
        ),
        extraction: CardExtraction(
          fields: <ExtractedField>[
            for (final MapEntry<String, List<int>> f in filed.entries)
              () {
                final String value =
                    f.value.map((int i) => blocks[i].text.trim()).join(', ');
                return ExtractedField(
                  fieldKey: f.key,
                  value: value,
                  normalizedValue: validateField(f.key, value).normalized,
                  confidence: 0.6,
                  sourceBlockIndices: f.value,
                );
              }(),
          ],
          unassignedBlockIndices: const <int>[],
        ),
        side: side,
      );
      await identity.promote(cardId);
    }

    /// Saves [blocks] as today's extractor reads them, and promotes the card.
    Future<void> readNow(
      int cardId,
      List<OcrBlock> blocks, {
      CardSide side = CardSide.front,
    }) async {
      await repo.attachExtraction(
        cardId: cardId,
        result: OcrResult(
          blocks: blocks,
          engine: 'test',
          duration: const Duration(milliseconds: 20),
        ),
        extraction: CardFieldExtractor.extract(blocks),
        side: side,
      );
      await identity.promote(cardId);
    }

    List<OcrBlock> shopCard(
      String tagline, {
      String phone = '+880 1617-223311',
    }) =>
        <OcrBlock>[
          _line('TechFix Repair Centre', top: 10, height: 60),
          _line(tagline, top: 80, height: 26),
          _line(phone, top: 116, height: 28),
          _line('Shop 14, Elephant Road, Dhaka', top: 154, height: 28),
        ];

    /// What the old extractor made of [shopCard].
    const Map<String, List<int>> taglineAsPerson = <String, List<int>>{
      FieldKeys.company: <int>[0],
      FieldKeys.personName: <int>[1],
      FieldKeys.phone: <int>[2],
      FieldKeys.address: <int>[3],
    };

    Future<List<String>> contacts() async => <String>[
          for (final Person p in await (db.select(db.people)
                ..where(($PeopleTable t) => t.mergedIntoId.isNull()))
              .get())
            p.displayName,
        ];

    Future<List<CardField>> names(int cardId) => (db.select(db.cardFields)
          ..where(
            ($CardFieldsTable f) =>
                f.cardId.equals(cardId) &
                f.fieldKey.equals(FieldKeys.personName),
          ))
        .get();

    Future<CardRow> row(int cardId) => (db.select(db.cards)
          ..where(($CardsTable c) => c.id.equals(cardId)))
        .getSingle();

    Future<String?> valueOf(int cardId, String key) async =>
        (await repo.watchCard(cardId).first)!.valueOf(key);

    test('takes the tagline off the card and out of contacts', () async {
      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );

      // Why this is a repair and not a rules bump: rebuilding the graph from
      // stored fields keeps the contact, because the field is still there and
      // a tagline is shaped like a name.
      await identity.backfill();
      expect(await contacts(), <String>['Laptop and Mobile Servicing']);

      expect(await repo.repairInventedPeople(identity), 1);

      expect(await names(shop), isEmpty);
      expect(await contacts(), isEmpty);

      final CardRow repaired = await row(shop);
      expect(repaired.personId, isNull);
      expect(repaired.orgId, isNotNull);
      expect(repaired.extractionStatus, ExtractionStatus.complete);

      // The number was the shop's all along, and now hangs off the shop.
      final ContactPoint phone = await (db.select(db.contactPoints)
            ..where(
              ($ContactPointsTable c) =>
                  c.normalizedValue.equals('+8801617223311'),
            ))
          .getSingle();
      expect(phone.ownerType, 'organization');
      expect(phone.ownerId, repaired.orgId);

      // Nothing else on the card moved.
      expect(await valueOf(shop, FieldKeys.company), 'TechFix Repair Centre');
      expect(
        await valueOf(shop, FieldKeys.address),
        'Shop 14, Elephant Road, Dhaka',
      );
    });

    test('commits on a database opened the way the app opens one', () async {
      // The app's connection lives on a background isolate, and the repair
      // promotes inside its own transaction — a nested one. An executor that
      // refused that would throw, the repair would swallow it, and every
      // launch would quietly change nothing.
      final Directory dir = Directory.systemTemp.createTempSync('recallos_');
      addTearDown(() => dir.deleteSync(recursive: true));
      await db.close();
      db = AppDatabase(
        NativeDatabase.createInBackground(File(p.join(dir.path, 'w.sqlite'))),
      );
      repo = CardRepository(db);
      identity = IdentityRepository(db);

      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );

      expect(await repo.repairInventedPeople(identity), 1);
      expect(await names(shop), isEmpty);
      expect(await contacts(), isEmpty);
    });

    test('puts the line back in the picker', () async {
      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );

      await repo.repairInventedPeople(identity);

      final OcrBlockRow line = await (db.select(db.ocrBlocks)
            ..where(
              ($OcrBlocksTable b) =>
                  b.blockText.equals('Laptop and Mobile Servicing'),
            ))
          .getSingle();
      expect(line.fieldId, isNull);
      expect(line.assignedFieldKey, isNull);
      expect(
        (await repo.watchCard(shop).first)!.unassignedText,
        <String>['Laptop and Mobile Servicing'],
      );
    });

    test('keeps a name the extractor still reads as one', () async {
      final int id = await card();
      await readNow(id, <OcrBlock>[
        _line('Medica Books Ltd', top: 10, height: 34),
        _line('Rahim Uddin', top: 60, height: 26),
        _line('01711-223344', top: 100, height: 16),
        _line('House 42, Road 7, Dhanmondi, Dhaka', top: 122, height: 16),
      ]);

      expect(await repo.repairInventedPeople(identity), 0);
      expect(await valueOf(id, FieldKeys.personName), 'Rahim Uddin');
      expect(await contacts(), <String>['Rahim Uddin']);
    });

    test('keeps a name somebody confirmed, whatever the extractor says',
        () async {
      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );
      // Saved from the field editor, as it stands.
      await repo.updateField(
        fieldId: (await names(shop)).single.id,
        value: 'Laptop and Mobile Servicing',
      );
      // And the flag alone, on a row still marked as printed: it is the
      // confirmation that counts, not how the row came by it.
      final int ticked = await card();
      await readBefore(
        ticked,
        shopCard('All brands repaired', phone: '+880 1911-556677'),
        taglineAsPerson,
      );
      await (db.update(db.cardFields)
            ..where(
              ($CardFieldsTable f) =>
                  f.cardId.equals(ticked) &
                  f.fieldKey.equals(FieldKeys.personName),
            ))
          .write(const CardFieldsCompanion(verifiedByUser: Value<bool>(true)));

      expect(await repo.repairInventedPeople(identity), 0);
      expect(await names(shop), hasLength(1));
      expect(await names(ticked), hasLength(1));
      expect(
        await contacts(),
        unorderedEquals(<String>[
          'Laptop and Mobile Servicing',
          'All brands repaired',
        ]),
      );
    });

    test('does not write a different name in its place', () async {
      // The owner's name is on the card too, under the tagline. Today's
      // extractor would file it; the old one filed the tagline instead.
      final List<OcrBlock> blocks = <OcrBlock>[
        _line('TechFix Repair Centre', top: 10, height: 40),
        _line('Laptop and Mobile Servicing', top: 56, height: 24),
        _line('Kamal Hossain', top: 90, height: 20),
        _line('Proprietor', top: 116, height: 14),
        _line('01617-223311', top: 136, height: 14),
      ];
      expect(
        CardFieldExtractor.extract(blocks)
            .firstOfKey(FieldKeys.personName)
            ?.value,
        'Kamal Hossain',
      );
      final int shop = await card();
      await readBefore(shop, blocks, <String, List<int>>{
        FieldKeys.company: <int>[0],
        FieldKeys.personName: <int>[1],
        FieldKeys.designation: <int>[3],
        FieldKeys.phone: <int>[4],
      });

      expect(await repo.repairInventedPeople(identity), 1);

      // Nobody reviewed "Kamal Hossain" as this card's person. Both lines are
      // one tap away instead.
      expect(await names(shop), isEmpty);
      expect(await contacts(), isEmpty);
      expect(
        (await repo.watchCard(shop).first)!.unassignedText,
        <String>['Laptop and Mobile Servicing', 'Kamal Hossain'],
      );
    });

    test('leaves the company and address of a brand named after a place',
        () async {
      // The old extractor joined "Dhaka Tech Repair" onto the address and
      // filed the tagline as the company; today's reads the brand as the
      // company. Only the person is repaired, and here the two agree on it.
      final List<OcrBlock> blocks = <OcrBlock>[
        _line('Dhaka Tech Repair', top: 10, height: 40),
        _line('Laptop and Mobile Servicing', top: 56, height: 24),
        _line('Kamal Hossain', top: 90, height: 20),
        _line('Proprietor', top: 116, height: 14),
        _line('01617-223311', top: 136, height: 14),
        _line('Shop 14, Elephant Road, Dhaka', top: 156, height: 14),
      ];
      final int shop = await card();
      await readBefore(shop, blocks, <String, List<int>>{
        FieldKeys.address: <int>[0, 5],
        FieldKeys.company: <int>[1],
        FieldKeys.personName: <int>[2],
        FieldKeys.designation: <int>[3],
        FieldKeys.phone: <int>[4],
      });

      expect(await repo.repairInventedPeople(identity), 0);
      expect(
        await valueOf(shop, FieldKeys.company),
        'Laptop and Mobile Servicing',
      );
      expect(
        await valueOf(shop, FieldKeys.address),
        'Dhaka Tech Repair, Shop 14, Elephant Road, Dhaka',
      );
      expect(await valueOf(shop, FieldKeys.personName), 'Kamal Hossain');
    });

    test("gives a contact the owner's own card joined back its real name",
        () async {
      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );
      // The owner's own card, with the shop's number on it, scanned later. It
      // joins the invented contact through the number, and the contact keeps
      // the invented name because one of its cards still carries it.
      final int owner = await card();
      await readNow(owner, <OcrBlock>[
        _line('TechFix Repair Centre', top: 10, height: 34),
        _line('Kamal Hossain', top: 56, height: 26),
        _line('Proprietor', top: 90, height: 16),
        _line('01617-223311', top: 112, height: 16),
      ]);
      expect(await contacts(), <String>['Laptop and Mobile Servicing']);

      expect(await repo.repairInventedPeople(identity), 1);

      expect(await contacts(), <String>['Kamal Hossain']);
      expect((await row(owner)).personId, isNotNull);
      expect((await row(shop)).personId, isNull);
    });

    test('judges each side on its own blocks', () async {
      // Shaped like a name, so only its size says it is not one — and the
      // size rule is off wherever a job title is in sight. The back has one.
      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Genuine Spare Parts'),
        taglineAsPerson,
      );
      // The back names the owner, and today's extractor agrees.
      await readNow(
        shop,
        <OcrBlock>[
          _line('TechFix Repair Centre', top: 10, height: 30),
          _line('Kamal Hossain', top: 50, height: 24),
          _line('Proprietor', top: 80, height: 14),
          _line('01711-223344', top: 100, height: 14),
        ],
        side: CardSide.back,
      );

      expect(await repo.repairInventedPeople(identity), 1);

      final CardField left = (await names(shop)).single;
      expect(left.value, 'Kamal Hossain');
      expect(left.side, CardSide.back);
      expect(await contacts(), <String>['Kamal Hossain']);
    });

    test('leaves a contact the user merged with somebody', () async {
      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );
      final int owner = await card();
      await readNow(owner, <OcrBlock>[
        _line('TechFix Repair Centre', top: 10, height: 34),
        _line('Kamal Hossain', top: 56, height: 26),
        _line('Proprietor', top: 90, height: 16),
        _line('01711-998877', top: 112, height: 16),
      ]);
      final List<Person> people = await db.select(db.people).get();
      final int invented = people
          .firstWhere(
            (Person p) => p.displayName == 'Laptop and Mobile Servicing',
          )
          .id;
      final int kamal =
          people.firstWhere((Person p) => p.displayName == 'Kamal Hossain').id;
      // The user said the shop's card is Kamal's.
      await identity.merge(survivor: kamal, loser: invented);

      expect(await repo.repairInventedPeople(identity), 0);
      expect(await names(shop), hasLength(1));
      expect((await row(shop)).personId, invented);
      expect(await contacts(), <String>['Kamal Hossain']);
    });

    test('leaves a side with nothing faithful to re-read', () async {
      final int unboxed = await card();
      await readBefore(
        unboxed,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );
      await (db.update(db.ocrBlocks)
            ..where(($OcrBlocksTable b) => b.cardId.equals(unboxed)))
          .write(const OcrBlocksCompanion(rect: Value<String>('')));

      // A name with no blocks behind it on its side at all.
      final int blank = await card();
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: blank,
              fieldKey: FieldKeys.personName,
              value: 'Laptop and Mobile Servicing',
              source: FactSource.printed,
            ),
          );

      expect(await repo.repairInventedPeople(identity), 0);
      expect(await names(unboxed), hasLength(1));
      expect(await names(blank), hasLength(1));
    });

    test('repairs a card in Recently deleted, so restoring it brings no one '
        'back', () async {
      final int shop = await card();
      await readBefore(
        shop,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );
      // Deleted the way the library does it.
      await repo.softDelete(shop);
      await identity.detach(shop);
      expect(await contacts(), isEmpty);

      expect(await repo.repairInventedPeople(identity), 1);
      expect(await names(shop), isEmpty);

      await repo.restore(shop);
      await identity.promote(shop);
      expect(await contacts(), isEmpty);
    });

    test('sends a card only the invented name made useful back to Needs '
        'Attention', () async {
      final int shop = await card();
      await readBefore(
        shop,
        <OcrBlock>[
          _line('TechFix Repair Centre', top: 10, height: 60),
          _line('Laptop and Mobile Servicing', top: 80, height: 26),
        ],
        <String, List<int>>{
          FieldKeys.company: <int>[0],
          FieldKeys.personName: <int>[1],
        },
      );
      expect((await row(shop)).extractionStatus, ExtractionStatus.complete);

      expect(await repo.repairInventedPeople(identity), 1);

      expect((await row(shop)).extractionStatus, ExtractionStatus.partial);
    });

    test('runs once', () async {
      final int first = await card();
      await readBefore(
        first,
        shopCard('Laptop and Mobile Servicing'),
        taglineAsPerson,
      );
      expect(await repo.repairInventedPeople(identity), 1);

      // Anything filed after the repair was filed by today's extractor, so a
      // second launch has no business second-guessing it.
      final int later = await card();
      await readBefore(
        later,
        shopCard('All brands repaired'),
        taglineAsPerson,
      );
      expect(await repo.repairInventedPeople(identity), 0);
      expect(await names(first), isEmpty);
      expect(await names(later), hasLength(1));
    });
  });

  // These drive the real repository. Only `createPending` and `purge` need a
  // platform path provider; correcting a field does not.
  group('correcting a field', () {
    late CardRepository repo;
    late int cardId;

    /// A card whose brand and descriptor were read as separate blocks, with
    /// the descriptor wrongly filed as the company.
    Future<void> scan() async {
      final List<OcrBlock> blocks = <OcrBlock>[
        _line('AQUARIUS', top: 10, height: 40),
        _line('Pet Shop', top: 200, height: 18),
        _line('01711223344', top: 260, height: 16),
      ];
      await repo.attachExtraction(
        cardId: cardId,
        result: OcrResult(
          blocks: blocks,
          engine: 'test',
          duration: const Duration(milliseconds: 20),
        ),
        extraction: CardFieldExtractor.extract(blocks),
      );
    }

    Future<List<CardField>> fields() => (db.select(db.cardFields)
          ..where(($CardFieldsTable f) => f.cardId.equals(cardId)))
        .get();

    Future<CardField> fieldOf(String key) async =>
        (await fields()).firstWhere((CardField f) => f.fieldKey == key);

    Future<List<OcrBlockRow>> blocks() => (db.select(db.ocrBlocks)
          ..where(($OcrBlocksTable b) => b.cardId.equals(cardId))
          ..orderBy(<OrderClauseGenerator<$OcrBlocksTable>>[
            ($OcrBlocksTable b) => OrderingTerm(expression: b.orderIndex),
          ]))
        .get();

    setUp(() async {
      repo = CardRepository(db);
      cardId = await createPending();
      await scan();
    });

    test('records a typed correction as the user\'s own', () async {
      final CardField company = await fieldOf(FieldKeys.company);
      await repo.updateField(
        fieldId: company.id,
        value: 'AQUARIUS Pet Shop',
      );

      final CardField fixed = await fieldOf(FieldKeys.company);
      expect(fixed.value, 'AQUARIUS Pet Shop');
      expect(fixed.source, FactSource.user);
      expect(fixed.verifiedByUser, isTrue);
    });

    test('joins several blocks into one value without typing', () async {
      final List<OcrBlockRow> all = await blocks();
      final CardField company = await fieldOf(FieldKeys.company);

      await repo.updateField(
        fieldId: company.id,
        blockIds: <int>[all[0].id, all[1].id],
      );

      expect((await fieldOf(FieldKeys.company)).value, 'AQUARIUS Pet Shop');
    });

    test('releases a block the field no longer uses', () async {
      final List<OcrBlockRow> before = await blocks();
      final CardField company = await fieldOf(FieldKeys.company);

      // The company was sourced from "Pet Shop"; move it to "AQUARIUS" alone.
      await repo.updateField(
        fieldId: company.id,
        blockIds: <int>[before[0].id],
      );

      final List<OcrBlockRow> after = await blocks();
      // "Pet Shop" must go back to being offered, or its text is unreachable.
      expect(after[1].fieldId, isNull);
      expect(after[1].assignedFieldKey, isNull);
      expect(after[0].fieldId, company.id);
    });

    test('re-labelling a value moves it to the new key', () async {
      final CardField company = await fieldOf(FieldKeys.company);
      await repo.updateField(
        fieldId: company.id,
        fieldKey: FieldKeys.designation,
      );

      final List<CardField> all = await fields();
      expect(all.where((CardField f) => f.fieldKey == FieldKeys.company),
          isEmpty);
      expect((await fieldOf(FieldKeys.designation)).value, 'Pet Shop');

      // The block's label follows the field, so the picker stays honest.
      final OcrBlockRow moved = (await blocks())
          .firstWhere((OcrBlockRow b) => b.fieldId == company.id);
      expect(moved.assignedFieldKey, FieldKeys.designation);
    });

    test('flags a correction that does not validate', () async {
      final CardField phone = await fieldOf(FieldKeys.phone);
      await repo.updateField(fieldId: phone.id, value: '01711');

      final CardField edited = await fieldOf(FieldKeys.phone);
      // Confirmed by the user, but still wrong — and it has to say so, or a
      // number nobody can dial looks settled.
      expect(edited.verifiedByUser, isTrue);
      expect(edited.validationIssue, isNotNull);
      expect(edited.normalizedValue, isNull);
    });

    test('adds a field extraction missed entirely', () async {
      await repo.addField(
        cardId: cardId,
        fieldKey: FieldKeys.email,
        value: 'Info@Aquarius.com.bd',
      );

      final CardField added = await fieldOf(FieldKeys.email);
      expect(added.normalizedValue, 'info@aquarius.com.bd');
      expect(added.source, FactSource.user);
    });

    test('deleting a field hands its blocks back to the picker', () async {
      final CardField company = await fieldOf(FieldKeys.company);
      await repo.deleteField(company.id);

      expect(
        (await fields()).where((CardField f) => f.fieldKey == FieldKeys.company),
        isEmpty,
      );
      expect((await blocks()).every((OcrBlockRow b) => b.fieldId != company.id),
          isTrue);
    });

    test('records the correction as an interaction', () async {
      final CardField company = await fieldOf(FieldKeys.company);
      await repo.updateField(fieldId: company.id, value: 'AQUARIUS Pet Shop');

      // This is where the manual-correction-rate metric comes from, with no
      // extra instrumentation.
      final List<Interaction> log = await (db.select(db.interactions)
            ..where(($InteractionsTable i) =>
                i.subjectId.equals(cardId) &
                i.kind.equalsValue(InteractionKind.edited)))
          .get();
      expect(log, isNotEmpty);
    });

    test('a correction reaches anything watching the card', () async {
      // The bug this exists for: the value was written correctly and the
      // screen never showed it. Drift re-runs a stream only when the tables of
      // *its own* query change, and this stream's query is over `cards` while
      // the payload comes from `card_fields` — so Save looked like it did
      // nothing. Writing to the database is only half of saving.
      final CardField company = await fieldOf(FieldKeys.company);

      final Future<CardDetail?> next = repo
          .watchCard(cardId)
          .skip(1)
          .first
          .timeout(const Duration(seconds: 5));

      await repo.updateField(
        fieldId: company.id,
        value: 'AQUARIUS Pet Shop',
      );

      final CardDetail? seen = await next;
      expect(
        seen?.fields.firstWhere((CardField f) => f.id == company.id).value,
        'AQUARIUS Pet Shop',
      );
    });

    test('a correction reaches the library list too', () async {
      final CardField company = await fieldOf(FieldKeys.company);

      final Future<List<CardSummary>> next = repo
          .watchCards()
          .skip(1)
          .first
          .timeout(const Duration(seconds: 5));

      await repo.updateField(
        fieldId: company.id,
        value: 'AQUARIUS Pet Shop',
      );

      expect((await next).single.title, 'AQUARIUS Pet Shop');
    });

    test('re-extraction does not destroy a correction', () async {
      final CardField company = await fieldOf(FieldKeys.company);
      await repo.updateField(fieldId: company.id, value: 'AQUARIUS Pet Shop');

      // A retry, a better engine, an upgraded device — all re-run extraction
      // over a card the user has already repaired.
      await scan();

      final List<CardField> companies = (await fields())
          .where((CardField f) => f.fieldKey == FieldKeys.company)
          .toList();
      expect(companies, hasLength(1), reason: 'must not duplicate the key');
      expect(companies.single.value, 'AQUARIUS Pet Shop');
      expect(companies.single.verifiedByUser, isTrue);
    });

    test('re-extraction still adds facts the user never touched', () async {
      final CardField company = await fieldOf(FieldKeys.company);
      await repo.updateField(fieldId: company.id, value: 'AQUARIUS Pet Shop');
      await scan();

      // The phone was never corrected, so a fresh read is free to supply it.
      expect((await fieldOf(FieldKeys.phone)).normalizedValue,
          '+8801711223344');
    });
  });

  group('downscaled images and thumbnails', () {
    late CardRepository repo;
    late Directory dir;

    setUp(() async {
      repo = CardRepository(db);
      dir = await Directory.systemTemp.createTemp('recallos_images');
    });
    tearDown(() async => dir.delete(recursive: true));

    File write(String name) {
      final File file = File(p.join(dir.path, name));
      file.writeAsStringSync(name);
      return file;
    }

    test('swaps in the resized card and drops the oversized copy', () async {
      final File original = write('original.jpg');
      final int id = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: original.path,
              capturedAt: DateTime(2026, 8, 15),
            ),
          );

      final File resized = write('card.jpg');
      final File thumb = write('card_thumb.jpg');
      await repo.attachImages(
        cardId: id,
        imagePath: resized.path,
        thumbPath: thumb.path,
      );

      final CardRow card = await load(id);
      expect(card.imagePath, resized.path);
      expect(card.thumbPath, thumb.path);
      // The full-resolution first copy exists only to make the save survive a
      // crash; leaving it behind would double storage on every card.
      expect(original.existsSync(), isFalse);
    });

    test('surfaces the thumbnail to the library list', () async {
      final File resized = write('card.jpg');
      final File thumb = write('card_thumb.jpg');
      final int id = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: resized.path,
              capturedAt: DateTime(2026, 8, 15),
              thumbPath: Value<String?>(thumb.path),
            ),
          );

      final List<CardSummary> cards = await repo.watchCards().first;
      final CardSummary summary =
          cards.firstWhere((CardSummary c) => c.id == id);

      expect(summary.thumbPath, thumb.path);
      // A list row decodes the thumbnail, not the card.
      expect(summary.displayPath, thumb.path);
    });

    test('falls back to the full image for cards saved before thumbnails',
        () async {
      final File resized = write('legacy.jpg');
      final int id = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: resized.path,
              capturedAt: DateTime(2026, 8, 15),
            ),
          );

      final List<CardSummary> cards = await repo.watchCards().first;
      final CardSummary summary =
          cards.firstWhere((CardSummary c) => c.id == id);

      expect(summary.thumbPath, isNull);
      expect(summary.displayPath, resized.path);
    });

    test('purging takes the thumbnail with it', () async {
      final File resized = write('card.jpg');
      final File thumb = write('card_thumb.jpg');
      final int id = await db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: resized.path,
              capturedAt: DateTime(2026, 8, 15),
              thumbPath: Value<String?>(thumb.path),
            ),
          );

      await repo.purge(id);

      expect(resized.existsSync(), isFalse);
      // Without this every deleted card leaves a file behind on a phone that
      // was short of space to begin with.
      expect(thumb.existsSync(), isFalse);
    });
  });

  group('the back of the card', () {
    late CardRepository repo;
    late Directory dir;

    setUp(() async {
      repo = CardRepository(db);
      dir = await Directory.systemTemp.createTemp('recallos_backs');
    });
    tearDown(() async => dir.delete(recursive: true));

    File write(String name) {
      final File file = File(p.join(dir.path, name));
      file.writeAsStringSync(name);
      return file;
    }

    Future<int> cardWithFront() async {
      final File front = write('front.jpg');
      return db.into(db.cards).insert(
            CardsCompanion.insert(
              imagePath: front.path,
              capturedAt: DateTime(2026, 8, 23),
            ),
          );
    }

    test('attaches a back without disturbing the front', () async {
      final int id = await cardWithFront();
      final CardRow before = await load(id);
      final File back = write('back.jpg');

      await repo.attachBackImage(cardId: id, backImagePath: back.path);

      final CardRow after = await load(id);
      expect(after.backImagePath, back.path);
      // The front is what OCR read and what every region is measured against.
      // Adding a back must not touch it.
      expect(after.imagePath, before.imagePath);
      expect(File(before.imagePath).existsSync(), isTrue);
    });

    test('re-taking the back replaces it rather than accumulating', () async {
      final int id = await cardWithFront();
      final File first = write('back_1.jpg');
      final File second = write('back_2.jpg');

      await repo.attachBackImage(cardId: id, backImagePath: first.path);
      await repo.attachBackImage(cardId: id, backImagePath: second.path);

      expect((await load(id)).backImagePath, second.path);
      // Otherwise every retry of a badly cropped back leaves a full-size photo
      // on disk with nothing pointing at it.
      expect(first.existsSync(), isFalse);
      expect(second.existsSync(), isTrue);
    });

    test('removing the back deletes the photo and keeps the card', () async {
      final int id = await cardWithFront();
      final File back = write('back.jpg');
      await repo.attachBackImage(cardId: id, backImagePath: back.path);

      await repo.removeBackImage(id);

      final CardRow after = await load(id);
      expect(after.backImagePath, isNull);
      expect(back.existsSync(), isFalse);
      // Removing a side is not removing the card.
      expect(File(after.imagePath).existsSync(), isTrue);
    });

    test('purging takes the back with it', () async {
      final int id = await cardWithFront();
      final File back = write('back.jpg');
      await repo.attachBackImage(cardId: id, backImagePath: back.path);

      await repo.purge(id);

      // The largest thing a deleted card can leave behind: a second full-size
      // image, which nothing else in the schema points at.
      expect(back.existsSync(), isFalse);
    });
  });

  group('discarding an abandoned scan', () {
    test('removes the card and everything hanging off it', () async {
      final int id = await createPending();
      await db.into(db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: FieldKeys.phone,
              value: '01711223344',
              source: FactSource.printed,
            ),
          );
      await db.into(db.ocrBlocks).insert(
            OcrBlocksCompanion.insert(
              cardId: id,
              blockText: 'x',
              rect: '0,0,1,1',
              confidence: 0.5,
              script: 'latin',
            ),
          );

      await (db.delete(db.cards)..where(($CardsTable c) => c.id.equals(id)))
          .go();

      expect(await db.select(db.cards).get(), isEmpty);
      expect(await db.select(db.cardFields).get(), isEmpty);
      expect(await db.select(db.ocrBlocks).get(), isEmpty);
    });
  });

  // The note used to be writable exactly once, in the save sheet. "Skip for
  // now" was therefore permanent, and a note typed in a hurry at an event
  // could never be corrected — on the one field that makes a card findable by
  // need.
  group('the note after saving', () {
    late CardRepository repo;
    setUp(() => repo = CardRepository(db));

    Future<List<Note>> notesOf(int cardId) => (db.select(db.notes)
          ..where(($NotesTable n) =>
              n.subjectType.equals('card') & n.subjectId.equals(cardId)))
        .get();

    test('a card saved without a note can be given one', () async {
      final int id = await createPending();

      await repo.setNote(cardId: id, body: '  printing guy from CSE fest  ');

      final List<Note> notes = await notesOf(id);
      expect(notes, hasLength(1));
      expect(notes.single.body, 'printing guy from CSE fest');
    });

    test('editing replaces the note rather than adding a second', () async {
      final int id = await createPending();
      await repo.addNote(cardId: id, body: 'tshirt');

      await repo.setNote(cardId: id, body: 'cheap t-shirt printing, low MOQ');

      final List<Note> notes = await notesOf(id);
      expect(notes, hasLength(1));
      expect(notes.single.body, 'cheap t-shirt printing, low MOQ');
    });

    test('clearing the text removes the note', () async {
      final int id = await createPending();
      await repo.addNote(cardId: id, body: 'tshirt');

      await repo.setNote(cardId: id, body: '   ');

      expect(await notesOf(id), isEmpty);
    });

    test('the open card sees the edit without being reopened', () async {
      // watchCard names `notes` in its readsFrom; if it did not, the edit
      // would be written and never reach the screen.
      final int id = await createPending();
      await repo.addNote(cardId: id, body: 'tshirt');

      final Stream<CardDetail?> stream = repo.watchCard(id);
      final Future<void> sawEdit = stream.firstWhere(
        (CardDetail? d) =>
            d != null && d.notes.any((Note n) => n.body == 'printing'),
      );
      await repo.setNote(cardId: id, body: 'printing');

      await sawEdit.timeout(const Duration(seconds: 2));
    });

    test('the edit is recorded as an interaction', () async {
      final int id = await createPending();

      await repo.setNote(cardId: id, body: 'printing');

      final List<Interaction> edits = await (db.select(db.interactions)
            ..where(($InteractionsTable i) =>
                i.subjectId.equals(id) &
                i.kind.equalsValue(InteractionKind.edited)))
          .get();
      expect(edits, hasLength(1));
    });
  });
}

/// A block laid out like a line of text, `height` standing in for font size.
OcrBlock _line(String text, {required double top, required double height}) =>
    OcrBlock(
      text: text,
      rect: Rect.fromLTWH(10, top, 300, height),
      confidence: 0.9,
      script: Script.latin,
    );

OcrBlock _rotated(
  String text, {
  required double across,
  required double along,
  required double offset,
}) =>
    OcrBlock(
      text: text,
      rect: Rect.fromLTWH(offset, 100, across, along),
      confidence: 0.9,
      script: Script.latin,
    );
