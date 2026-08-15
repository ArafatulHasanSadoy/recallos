import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/field_validator.dart';
import '../../../core/intelligence/ocr_engine.dart' as ocr;

final databaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final cardRepositoryProvider = Provider<CardRepository>(
  (Ref ref) => CardRepository(ref.watch(databaseProvider)),
);

/// One card and everything attached to it, as a live stream.
///
/// Watched by both the review screen and the detail screen: a card is in the
/// database from the moment its photo is, so reviewing a fresh scan and
/// revisiting an old one are the same view over the same rows.
final cardDetailProvider =
    StreamProvider.family<CardDetail?, int>((Ref ref, int id) {
  return ref.watch(cardRepositoryProvider).watchCard(id);
});

/// A saved card, flattened for list display.
class CardSummary {
  const CardSummary({
    required this.id,
    required this.imagePath,
    required this.capturedAt,
    required this.status,
    this.thumbPath,
    this.title,
    this.subtitle,
    this.note,
  });

  final int id;
  final String imagePath;

  /// Smaller copy for list rows. Null for cards saved before thumbnails
  /// existed, which fall back to the full image.
  final String? thumbPath;

  final DateTime capturedAt;
  final ExtractionStatus status;

  /// What a list row should decode: the thumbnail when there is one.
  String get displayPath => thumbPath ?? imagePath;

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
    required this.blocks,
  });

  final CardRow card;

  /// In display order rather than insertion order, so the screen does not
  /// reshuffle when a card is re-extracted.
  final List<CardField> fields;

  final List<Note> notes;

  /// Every region OCR read, in reading order — claimed or not.
  ///
  /// The whole list rather than only the leftovers, because the picker offers
  /// all of them: repairing a bad layout usually means taking a block *away*
  /// from the field that wrongly claimed it.
  final List<OcrBlockRow> blocks;

  /// Blocks no field claimed. Shown so the user can see everything that was on
  /// the card, and pick from it without retyping.
  List<OcrBlockRow> get unassignedBlocks => blocks
      .where((OcrBlockRow b) =>
          b.fieldId == null && b.blockText.trim().isNotEmpty)
      .toList();

  List<String> get unassignedText =>
      unassignedBlocks.map((OcrBlockRow b) => b.blockText.trim()).toList();

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
  /// Returns the new row's id and the copy now under our control — the scanner
  /// hands back a cache file the system is free to reclaim.
  Future<({int id, File image})> createPending(File source) async {
    final Directory cards = await cardsDirectory();

    final String name =
        'card_${DateTime.now().microsecondsSinceEpoch}${p.extension(source.path)}';
    final File stored = await source.copy(p.join(cards.path, name));

    final int id = await _db.into(_db.cards).insert(
          CardsCompanion.insert(
            imagePath: stored.path,
            capturedAt: DateTime.now(),
          ),
        );
    return (id: id, image: stored);
  }

  /// Where card images live, created on first use.
  ///
  /// Public because capture hands this to the resize isolate as its output
  /// directory — the isolate cannot call platform channels itself.
  Future<Directory> cardsDirectory() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory cards = Directory(p.join(dir.path, 'cards'));
    if (!cards.existsSync()) {
      await cards.create(recursive: true);
    }
    return cards;
  }

  /// Swaps in the downscaled card and its thumbnail.
  ///
  /// Capture copies the scanner's full-resolution output and opens the row
  /// *before* resizing, so that a crash between the two still leaves a
  /// recoverable card. This replaces that oversized first copy and deletes it.
  Future<void> attachImages({
    required int cardId,
    required String imagePath,
    required String thumbPath,
  }) async {
    final CardRow? card = await (_db.select(_db.cards)
          ..where(($CardsTable c) => c.id.equals(cardId)))
        .getSingleOrNull();
    if (card == null) return;

    await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
        .write(CardsCompanion(
      imagePath: Value<String>(imagePath),
      thumbPath: Value<String?>(thumbPath),
      updatedAt: Value<DateTime>(DateTime.now()),
    ));

    if (card.imagePath != imagePath) {
      await _deleteFile(card.imagePath);
    }
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
      // Anything the user confirmed or corrected outlives re-extraction. The
      // engine may change its mind freely; a human answer is not something it
      // gets to overwrite, or a retry would silently undo every repair.
      final List<CardField> verified = await (_db.select(_db.cardFields)
            ..where(($CardFieldsTable f) =>
                f.cardId.equals(cardId) & f.verifiedByUser.equals(true)))
          .get();

      await (_db.delete(_db.ocrBlocks)
            ..where(($OcrBlocksTable b) => b.cardId.equals(cardId)))
          .go();
      await (_db.delete(_db.cardFields)
            ..where(($CardFieldsTable f) =>
                f.cardId.equals(cardId) & f.verifiedByUser.equals(false)))
          .go();

      final List<ExtractedField> incoming =
          _withoutSuperseded(verified, extraction.fields);

      // Fields before blocks: a block records the field row that owns it, so
      // those ids have to exist first.
      final Map<int, int> fieldIdOfBlock = <int, int>{};
      for (final ExtractedField f in incoming) {
        final int fieldId = await _db.into(_db.cardFields).insert(
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
            );
        for (final int i in f.sourceBlockIndices) {
          fieldIdOfBlock[i] = fieldId;
        }
      }

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
              assignedFieldKey: Value<String?>(_keyForBlock(incoming, i)),
              fieldId: Value<int?>(fieldIdOfBlock[i]),
              orderIndex: Value<int>(i),
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
            // A card the user has already repaired is never "failed", however
            // little this particular run managed to read.
            (extraction.isEmpty && verified.isEmpty)
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
      await _deleteFile(card.imagePath);
      // The thumbnail goes too, or every deleted card leaves one behind on a
      // phone that was short of space to begin with.
      final String? thumb = card.thumbPath;
      if (thumb != null) await _deleteFile(thumb);
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
  ///
  /// Driven by an explicit [readsFrom] rather than `select(cards).watch()`, for
  /// the reason spelled out on [watchCard]: the title of a row comes out of
  /// `card_fields`, so a stream watching only `cards` never notices it change.
  Stream<List<CardSummary>> watchCards() {
    return _db
        .customSelect(
          'SELECT id FROM cards WHERE deleted_at IS NULL '
          'ORDER BY captured_at DESC',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.cards,
            _db.cardFields,
            _db.notes,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> ids) async {
      final List<CardSummary> out = <CardSummary>[];
      for (final QueryRow id in ids) {
        final CardRow? row = await (_db.select(_db.cards)
              ..where(($CardsTable c) => c.id.equals(id.read<int>('id'))))
            .getSingleOrNull();
        if (row == null) continue;

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
          thumbPath: row.thumbPath,
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
  /// The [readsFrom] set is load-bearing, not decoration. Drift re-runs a
  /// stream when the tables of *its own query* change — and if this were the
  /// obvious `select(cards).watch()`, it would only ever fire for writes to
  /// `cards`. Almost everything on the screen lives elsewhere: fields, notes
  /// and OCR blocks. Without naming them, a corrected field is written to the
  /// database and never reaches the screen, so Save appears to do nothing.
  Stream<CardDetail?> watchCard(int cardId) {
    return _db
        .customSelect(
          'SELECT id FROM cards WHERE id = ? AND deleted_at IS NULL',
          variables: <Variable<Object>>[Variable<int>(cardId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.cards,
            _db.cardFields,
            _db.notes,
            _db.ocrBlocks,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> ids) async {
      if (ids.isEmpty) return null;

      final CardRow? card = await (_db.select(_db.cards)
            ..where(($CardsTable c) => c.id.equals(cardId)))
          .getSingleOrNull();
      if (card == null) return null;

      final List<CardField> fields = await (_db.select(_db.cardFields)
            ..where(($CardFieldsTable f) => f.cardId.equals(cardId)))
          .get();
      final List<Note> notes = await (_db.select(_db.notes)
            ..where(($NotesTable n) =>
                n.subjectType.equals('card') & n.subjectId.equals(cardId)))
          .get();
      final List<OcrBlockRow> blocks = await (_db.select(_db.ocrBlocks)
            ..where(($OcrBlocksTable b) => b.cardId.equals(cardId))
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
        blocks: blocks,
      );
    });
  }

  // --- Corrections ---------------------------------------------------------
  //
  // Every method here records the result as the user's own — `source = user`,
  // `verifiedByUser = true` — which is also where the manual correction rate
  // comes from, straight out of real usage and with no extra instrumentation.
  //
  // Callers must re-index the card afterwards, the same way capture does after
  // attaching a note: a corrected value that search cannot find is not much of
  // a correction.

  /// Applies a correction to one field.
  ///
  /// [blockIds] re-sources the field from the card's own OCR text — the value
  /// becomes those blocks joined in reading order, and the highlighted region
  /// follows them. That is the repair worth offering first: it costs taps
  /// rather than typing, and typing is where people give up. [value] is the
  /// fallback for text OCR never read correctly in the first place, and
  /// [fieldKey] re-labels a value that was read fine but filed wrong.
  Future<void> updateField({
    required int fieldId,
    String? value,
    String? fieldKey,
    List<int>? blockIds,
  }) async {
    final CardField? existing = await (_db.select(_db.cardFields)
          ..where(($CardFieldsTable f) => f.id.equals(fieldId)))
        .getSingleOrNull();
    if (existing == null) return;

    final String key = fieldKey ?? existing.fieldKey;
    final List<OcrBlockRow> blocks = blockIds == null
        ? const <OcrBlockRow>[]
        : await _blocksByIds(existing.cardId, blockIds);

    final String text = blocks.isNotEmpty
        ? _joinBlocks(blocks)
        : (value ?? existing.value).trim();
    // An empty correction is a deletion the user did not ask for.
    if (text.isEmpty) return;

    final FieldValidation check = validateField(key, text);

    await _db.transaction(() async {
      await (_db.update(_db.cardFields)
            ..where(($CardFieldsTable f) => f.id.equals(fieldId)))
          .write(CardFieldsCompanion(
        fieldKey: Value<String>(key),
        value: Value<String>(text),
        normalizedValue: Value<String?>(check.normalized),
        source: const Value<FactSource>(FactSource.user),
        verifiedByUser: const Value<bool>(true),
        validationIssue: Value<String?>(check.issue),
        regionRect: blocks.isEmpty
            ? const Value<String?>.absent()
            : Value<String?>(_unionRect(blocks)),
        updatedAt: Value<DateTime>(DateTime.now()),
      ));

      if (blocks.isNotEmpty) {
        await _claimBlocks(fieldId: fieldId, key: key, blocks: blocks);
      } else {
        // Sources unchanged, but the label may not be.
        await (_db.update(_db.ocrBlocks)
              ..where(($OcrBlocksTable b) => b.fieldId.equals(fieldId)))
            .write(OcrBlocksCompanion(assignedFieldKey: Value<String?>(key)));
      }

      await _logEdit(existing.cardId);
    });
  }

  /// Adds a field extraction missed entirely.
  Future<void> addField({
    required int cardId,
    required String fieldKey,
    String? value,
    List<int>? blockIds,
  }) async {
    final List<OcrBlockRow> blocks = blockIds == null
        ? const <OcrBlockRow>[]
        : await _blocksByIds(cardId, blockIds);

    final String text =
        blocks.isNotEmpty ? _joinBlocks(blocks) : (value ?? '').trim();
    if (text.isEmpty) return;

    final FieldValidation check = validateField(fieldKey, text);

    await _db.transaction(() async {
      final int fieldId = await _db.into(_db.cardFields).insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: fieldKey,
              value: text,
              normalizedValue: Value<String?>(check.normalized),
              source: FactSource.user,
              verifiedByUser: const Value<bool>(true),
              validationIssue: Value<String?>(check.issue),
              regionRect: Value<String?>(
                blocks.isEmpty ? null : _unionRect(blocks),
              ),
            ),
          );

      if (blocks.isNotEmpty) {
        await _claimBlocks(fieldId: fieldId, key: fieldKey, blocks: blocks);
      }
      await _logEdit(cardId);
    });
  }

  /// Removes a field that is not on the card at all.
  ///
  /// The blocks behind it go back to the picker rather than staying spoken
  /// for, so nothing the engine read becomes unreachable.
  Future<void> deleteField(int fieldId) async {
    final CardField? existing = await (_db.select(_db.cardFields)
          ..where(($CardFieldsTable f) => f.id.equals(fieldId)))
        .getSingleOrNull();
    if (existing == null) return;

    await _db.transaction(() async {
      await _releaseBlocks(fieldId);
      await (_db.delete(_db.cardFields)
            ..where(($CardFieldsTable f) => f.id.equals(fieldId)))
          .go();
      await _logEdit(existing.cardId);
    });
  }

  Future<List<OcrBlockRow>> _blocksByIds(int cardId, List<int> ids) async {
    if (ids.isEmpty) return const <OcrBlockRow>[];
    final List<OcrBlockRow> rows = await (_db.select(_db.ocrBlocks)
          ..where(($OcrBlocksTable b) =>
              b.cardId.equals(cardId) & b.id.isIn(ids))
          ..orderBy(<OrderClauseGenerator<$OcrBlocksTable>>[
            ($OcrBlocksTable b) => OrderingTerm(expression: b.orderIndex),
          ]))
        .get();
    return rows;
  }

  /// Hands [blocks] to one field, releasing whatever it held before.
  ///
  /// The release is the part that matters. Without it a block the user moved
  /// away from a field would stay marked as used, vanish from the picker, and
  /// never be offered again.
  Future<void> _claimBlocks({
    required int fieldId,
    required String key,
    required List<OcrBlockRow> blocks,
  }) async {
    await _releaseBlocks(fieldId);
    for (final OcrBlockRow b in blocks) {
      await (_db.update(_db.ocrBlocks)
            ..where(($OcrBlocksTable t) => t.id.equals(b.id)))
          .write(OcrBlocksCompanion(
        fieldId: Value<int?>(fieldId),
        assignedFieldKey: Value<String?>(key),
      ));
    }
  }

  Future<void> _releaseBlocks(int fieldId) =>
      (_db.update(_db.ocrBlocks)
            ..where(($OcrBlocksTable b) => b.fieldId.equals(fieldId)))
          .write(const OcrBlocksCompanion(
        fieldId: Value<int?>(null),
        assignedFieldKey: Value<String?>(null),
      ));

  Future<void> _logEdit(int cardId) async {
    await _db.into(_db.interactions).insert(
          InteractionsCompanion.insert(
            subjectType: 'card',
            subjectId: cardId,
            kind: InteractionKind.edited,
            detail: const Value<String?>('field corrected'),
          ),
        );
    // A card whose fields changed did change. Stage 2 sync will read this, and
    // it keeps `cards` honest rather than only its children.
    await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
        .write(CardsCompanion(updatedAt: Value<DateTime>(DateTime.now())));
  }

  // --- Helpers -------------------------------------------------------------

  /// Removes a file if it is there, and shrugs if it will not go.
  ///
  /// A file we cannot delete is not worth failing a flow over — the row goes
  /// either way, so the card stops being reachable.
  static Future<void> _deleteFile(String path) async {
    final File file = File(path);
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } on Object {
      // Deliberately ignored; see above.
    }
  }

  static String _joinBlocks(List<OcrBlockRow> blocks) => blocks
      .map((OcrBlockRow b) => b.blockText.trim())
      .where((String t) => t.isNotEmpty)
      .join(' ');

  /// Keys where several values on one card are normal.
  ///
  /// This matters when re-extraction meets a field the user has already fixed:
  /// a second phone number is a new fact worth keeping, while a second company
  /// name is just the engine contradicting a human.
  static const Set<String> _repeatableKeys = <String>{
    FieldKeys.phone,
    FieldKeys.email,
  };

  /// Drops incoming fields that a verified one has already answered.
  static List<ExtractedField> _withoutSuperseded(
    List<CardField> verified,
    List<ExtractedField> incoming,
  ) {
    if (verified.isEmpty) return incoming;

    String identity(String key, String? normalized, String value) =>
        '$key ${normalized ?? value.toLowerCase()}';

    final Set<String> settledKeys = <String>{
      for (final CardField f in verified)
        if (!_repeatableKeys.contains(f.fieldKey)) f.fieldKey,
    };
    final Set<String> settledValues = <String>{
      for (final CardField f in verified)
        identity(f.fieldKey, f.normalizedValue, f.value),
    };

    return incoming
        .where((ExtractedField f) =>
            !settledKeys.contains(f.fieldKey) &&
            !settledValues
                .contains(identity(f.fieldKey, f.normalizedValue, f.value)))
        .toList();
  }

  static String _rectOf(ocr.OcrBlock b) =>
      '${b.rect.left.round()},${b.rect.top.round()},'
      '${b.rect.right.round()},${b.rect.bottom.round()}';

  /// The box enclosing every block behind a field, so highlighting a merged
  /// value boxes all of it rather than only its first line.
  static String? _unionRect(List<OcrBlockRow> blocks) {
    double? left, top, right, bottom;
    for (final OcrBlockRow b in blocks) {
      final List<double> v = b.rect
          .split(',')
          .map((String s) => double.tryParse(s.trim()))
          .whereType<double>()
          .toList();
      if (v.length != 4) continue;

      left = left == null ? v[0] : math.min(left, v[0]);
      top = top == null ? v[1] : math.min(top, v[1]);
      right = right == null ? v[2] : math.max(right, v[2]);
      bottom = bottom == null ? v[3] : math.max(bottom, v[3]);
    }
    if (left == null) return null;
    return '${left.round()},${top!.round()},'
        '${right!.round()},${bottom!.round()}';
  }

  static String? _keyForBlock(List<ExtractedField> fields, int index) {
    for (final ExtractedField f in fields) {
      if (f.sourceBlockIndices.contains(index)) return f.fieldKey;
    }
    return null;
  }
}
