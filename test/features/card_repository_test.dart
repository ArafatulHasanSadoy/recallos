import 'dart:ui' show Rect;

// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';

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
