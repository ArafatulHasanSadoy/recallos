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
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/features/capture/data/card_repository.dart';

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
