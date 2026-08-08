import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/intelligence/ocr_engine.dart' as ocr;

final databaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final cardRepositoryProvider = Provider<CardRepository>(
  (Ref ref) => CardRepository(ref.watch(databaseProvider)),
);

/// A saved card, flattened for list display.
class CardSummary {
  const CardSummary({
    required this.id,
    required this.imagePath,
    required this.capturedAt,
    required this.status,
    this.title,
    this.subtitle,
    this.note,
  });

  final int id;
  final String imagePath;
  final DateTime capturedAt;
  final ExtractionStatus status;

  /// Company, or the person, or a fallback — never empty.
  final String? title;
  final String? subtitle;
  final String? note;

  /// True when nothing useful was extracted and only the note makes this
  /// findable. The library surfaces these differently so they can be repaired.
  bool get needsAttention =>
      status == ExtractionStatus.failed || status == ExtractionStatus.partial;
}

/// Everything on one card, for the detail screen.
class CardDetail {
  const CardDetail({
    required this.card,
    required this.fields,
    required this.notes,
    required this.unassignedText,
  });

  final CardRow card;

  /// In display order rather than insertion order, so the screen does not
  /// reshuffle when a card is re-extracted.
  final List<CardField> fields;

  final List<Note> notes;

  /// Text OCR read but no field claimed. Shown so the user can see everything
  /// that was on the card, and — once tap-to-assign lands — fix a bad layout
  /// without retyping.
  final List<String> unassignedText;

  String? valueOf(String key) {
    for (final CardField f in fields) {
      if (f.fieldKey == key) return f.value;
    }
    return null;
  }

  List<CardField> allOf(String key) =>
      fields.where((CardField f) => f.fieldKey == key).toList();

  String get title =>
      valueOf(FieldKeys.company) ??
      valueOf(FieldKeys.personName) ??
      valueOf(FieldKeys.phone) ??
      'Unread card';
}

/// Persistence for scanned cards.
///
/// The ordering here is the point. `createPending` writes the image and the row
/// **before** OCR runs, so a crash, a killed app or a failed engine leaves a
/// recoverable card rather than nothing. Extraction results are folded in
/// afterwards by [attachExtraction]; if that never happens the card is still
/// there, still has its photo, and still gets found by its note.
class CardRepository {
  CardRepository(this._db);

  final AppDatabase _db;

  /// Copies [source] into app storage and opens a pending card row.
  ///
  /// Returns before any recognition has been attempted. That is deliberate:
  /// everything after this point can fail without losing the card.
  Future<int> createPending(File source) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory cards = Directory(p.join(dir.path, 'cards'));
    if (!cards.existsSync()) {
      await cards.create(recursive: true);
    }

    final String name =
        'card_${DateTime.now().microsecondsSinceEpoch}${p.extension(source.path)}';
    final File stored = await source.copy(p.join(cards.path, name));

    return _db.into(_db.cards).insert(
          CardsCompanion.insert(
            imagePath: stored.path,
            capturedAt: DateTime.now(),
          ),
        );
  }

  /// Folds OCR output into an existing card.
  ///
  /// Every recognised block is stored, not only the ones that became fields —
  /// the unassigned ones are what tap-to-assign offers later, so a card whose
  /// layout defeated the parser can be repaired without retyping.
  Future<void> attachExtraction({
    required int cardId,
    required ocr.OcrResult result,
    required CardExtraction extraction,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.ocrBlocks)
            ..where(($OcrBlocksTable b) => b.cardId.equals(cardId)))
          .go();
      await (_db.delete(_db.cardFields)
            ..where(($CardFieldsTable f) => f.cardId.equals(cardId)))
          .go();

      final Set<int> assigned = <int>{
        for (final ExtractedField f in extraction.fields)
          if (f.sourceBlockIndex != null) f.sourceBlockIndex!,
      };

      await _db.batch((Batch batch) {
        batch.insertAll(_db.ocrBlocks, <OcrBlocksCompanion>[
          for (int i = 0; i < result.blocks.length; i++)
            OcrBlocksCompanion.insert(
              cardId: cardId,
              blockText: result.blocks[i].text,
              rect: _rectOf(result.blocks[i]),
              confidence: result.blocks[i].confidence,
              script: result.blocks[i].script.name,
              engine: Value<String?>(result.blocks[i].engine),
              assignedFieldKey: Value<String?>(
                assigned.contains(i) ? _keyForBlock(extraction, i) : null,
              ),
              orderIndex: Value<int>(i),
            ),
        ]);

        batch.insertAll(_db.cardFields, <CardFieldsCompanion>[
          for (final ExtractedField f in extraction.fields)
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: f.fieldKey,
              value: f.value,
              normalizedValue: Value<String?>(f.normalizedValue),
              source: FactSource.printed,
              confidence: Value<double?>(f.confidence),
              validationIssue: Value<String?>(f.issue),
              regionRect: Value<String?>(f.regionRect),
            ),
        ]);
      });

      await (_db.update(_db.cards)
            ..where(($CardsTable c) => c.id.equals(cardId)))
          .write(
        CardsCompanion(
          rawOcrText: Value<String?>(result.plainText),
          ocrEngine: Value<String?>(result.engine),
          extractionStatus: Value<ExtractionStatus>(
            extraction.isEmpty
                ? ExtractionStatus.failed
                : extraction.isUseful
                    ? ExtractionStatus.complete
                    : ExtractionStatus.partial,
          ),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
    });

    await _db.into(_db.extractionAttempts).insert(
          ExtractionAttemptsCompanion.insert(
            cardId: cardId,
            engine: result.engine,
            startedAt: DateTime.now().subtract(result.duration),
            durationMs: result.duration.inMilliseconds,
            status: extraction.isEmpty
                ? AttemptStatus.failed
                : extraction.isUseful
                    ? AttemptStatus.success
                    : AttemptStatus.partial,
            fieldsFound: Value<int>(extraction.fields.length),
            errorCode: Value<String?>(result.failure?.name),
          ),
        );
  }

  /// Attaches the user's answer to "why are you saving this?".
  ///
  /// The single most valuable column in the database: a card with nothing but a
  /// note is still findable by need, which is the whole product thesis.
  Future<void> addNote({required int cardId, required String body}) async {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) return;

    await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            subjectType: 'card',
            subjectId: cardId,
            body: Value<String?>(trimmed),
          ),
        );
    await _db.into(_db.interactions).insert(
          InteractionsCompanion.insert(
            subjectType: 'card',
            subjectId: cardId,
            kind: InteractionKind.scanned,
            detail: const Value<String?>('note added at save'),
          ),
        );
  }

  /// Discards a card the user backed out of, and its image with it.
  ///
  /// Called when a scan is abandoned rather than saved. Without this, every
  /// retake would leave an orphaned row and a photo on disk.
  Future<void> discard(int cardId) => purge(cardId);

  /// Hides a card without destroying it.
  ///
  /// Deleting something a user spent effort capturing deserves a way back, so
  /// removal is two-stage: this sets the tombstone the library already filters
  /// on, and [purge] finishes the job once the undo window closes. Nothing is
  /// unrecoverable until they have had a chance to change their mind.
  Future<void> softDelete(int cardId) async {
    await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
        .write(
      CardsCompanion(
        deletedAt: Value<DateTime?>(DateTime.now()),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<void> restore(int cardId) async {
    await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
        .write(
      const CardsCompanion(
        deletedAt: Value<DateTime?>(null),
      ),
    );
  }

  /// Permanently removes a card, its image and its notes.
  ///
  /// Fields, OCR blocks and extraction attempts go with it through the schema's
  /// cascades; notes and embeddings hang off a polymorphic subject rather than a
  /// foreign key, so they are cleaned up explicitly.
  Future<void> purge(int cardId) async {
    final CardRow? card = await (_db.select(_db.cards)
          ..where(($CardsTable c) => c.id.equals(cardId)))
        .getSingleOrNull();

    if (card != null) {
      final File image = File(card.imagePath);
      if (image.existsSync()) {
        try {
          await image.delete();
        } on Object {
          // A file we cannot delete is not worth failing the flow over — the
          // row still goes, so it stops being reachable.
        }
      }
    }

    await _db.transaction(() async {
      await (_db.delete(_db.notes)
            ..where(($NotesTable n) =>
                n.subjectType.equals('card') & n.subjectId.equals(cardId)))
          .go();
      await (_db.delete(_db.interactions)
            ..where(($InteractionsTable i) =>
                i.subjectType.equals('card') & i.subjectId.equals(cardId)))
          .go();
      await (_db.delete(_db.embeddings)
            ..where(($EmbeddingsTable e) =>
                e.subjectType.equals('card') & e.subjectId.equals(cardId)))
          .go();
      await _db.customStatement(
        'DELETE FROM search_index WHERE subject_type = ? AND subject_id = ?',
        <Object?>['card', cardId],
      );
      await (_db.delete(_db.cards)
            ..where(($CardsTable c) => c.id.equals(cardId)))
          .go();
    });
  }

  /// Saved cards, newest first, as a live stream so the library updates itself.
  Stream<List<CardSummary>> watchCards() {
    final query = _db.select(_db.cards)
      ..where(($CardsTable c) => c.deletedAt.isNull())
      ..orderBy(<OrderClauseGenerator<$CardsTable>>[
        ($CardsTable c) =>
            OrderingTerm(expression: c.capturedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap((List<CardRow> rows) async {
      final List<CardSummary> out = <CardSummary>[];
      for (final CardRow row in rows) {
        final List<CardField> fields = await (_db.select(_db.cardFields)
              ..where(($CardFieldsTable f) => f.cardId.equals(row.id)))
            .get();
        final Note? note = await (_db.select(_db.notes)
              ..where(($NotesTable n) =>
                  n.subjectType.equals('card') & n.subjectId.equals(row.id))
              ..limit(1))
            .getSingleOrNull();

        String? valueOf(String key) {
          for (final CardField f in fields) {
            if (f.fieldKey == key) return f.value;
          }
          return null;
        }

        out.add(CardSummary(
          id: row.id,
          imagePath: row.imagePath,
          capturedAt: row.capturedAt,
          status: row.extractionStatus,
          title: valueOf(FieldKeys.company) ??
              valueOf(FieldKeys.personName) ??
              valueOf(FieldKeys.phone),
          subtitle: valueOf(FieldKeys.personName) ?? valueOf(FieldKeys.phone),
          note: note?.body,
        ));
      }
      return out;
    });
  }

  /// Watches one card and everything attached to it.
  ///
  /// A stream rather than a one-shot read so that editing a note or deleting
  /// the card updates the detail screen without it having to re-query.
  Stream<CardDetail?> watchCard(int cardId) {
    final query = _db.select(_db.cards)
      ..where(($CardsTable c) => c.id.equals(cardId) & c.deletedAt.isNull());

    return query.watchSingleOrNull().asyncMap((CardRow? card) async {
      if (card == null) return null;

      final List<CardField> fields = await (_db.select(_db.cardFields)
            ..where(($CardFieldsTable f) => f.cardId.equals(cardId)))
          .get();
      final List<Note> notes = await (_db.select(_db.notes)
            ..where(($NotesTable n) =>
                n.subjectType.equals('card') & n.subjectId.equals(cardId)))
          .get();
      final List<OcrBlockRow> blocks = await (_db.select(_db.ocrBlocks)
            ..where(($OcrBlocksTable b) =>
                b.cardId.equals(cardId) & b.assignedFieldKey.isNull())
            ..orderBy(<OrderClauseGenerator<$OcrBlocksTable>>[
              ($OcrBlocksTable b) => OrderingTerm(expression: b.orderIndex),
            ]))
          .get();

      // Ordered so the screen reads the way a card does: who and what first,
      // then how to reach them, then where they are.
      const List<String> order = <String>[
        FieldKeys.company,
        FieldKeys.personName,
        FieldKeys.designation,
        FieldKeys.phone,
        FieldKeys.email,
        FieldKeys.website,
        FieldKeys.address,
      ];
      fields.sort((CardField a, CardField b) {
        final int ai = order.indexOf(a.fieldKey);
        final int bi = order.indexOf(b.fieldKey);
        return (ai < 0 ? order.length : ai).compareTo(bi < 0 ? order.length : bi);
      });

      return CardDetail(
        card: card,
        fields: fields,
        notes: notes,
        unassignedText: blocks
            .map((OcrBlockRow b) => b.blockText.trim())
            .where((String t) => t.isNotEmpty)
            .toList(),
      );
    });
  }

  static String _rectOf(ocr.OcrBlock b) =>
      '${b.rect.left.round()},${b.rect.top.round()},'
      '${b.rect.right.round()},${b.rect.bottom.round()}';

  static String? _keyForBlock(CardExtraction extraction, int index) {
    for (final ExtractedField f in extraction.fields) {
      if (f.sourceBlockIndex == index) return f.fieldKey;
    }
    return null;
  }
}
