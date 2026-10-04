import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/field_validator.dart';
import '../../../core/extraction/phone.dart';
import '../../../core/imaging/photo_keyring.dart';
import '../../../core/imaging/photo_vault.dart';
import '../../../core/intelligence/ocr_engine.dart' as ocr;
import '../../contacts/data/identity_repository.dart';

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
final cardDetailProvider = StreamProvider.family<CardDetail?, int>((
  Ref ref,
  int id,
) {
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
      .where(
        (OcrBlockRow b) => b.fieldId == null && b.blockText.trim().isNotEmpty,
      )
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
    // Sealed on the way in, off the UI thread: a full-resolution scan is
    // megabytes, and this is the moment the user is watching.
    final String target = p.join(cards.path, name);
    final String from = source.path;
    final Uint8List? key = await PhotoKeyring.instance.key;
    await Isolate.run(() => sealCopySync(from, target, key));
    final File stored = File(target);

    final int id = await _db
        .into(_db.cards)
        .insert(
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
    String? thumbPath,
  }) async {
    final CardRow? card = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();
    if (card == null) return;

    await (_db.update(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).write(
      CardsCompanion(
        imagePath: Value<String>(imagePath),
        thumbPath: Value<String?>(thumbPath),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );

    if (card.imagePath != imagePath) {
      await _deleteFile(card.imagePath);
    }
  }

  /// Stores the back of the card.
  ///
  /// Separate from [attachImages] because the two sides are captured in
  /// separate sessions and mean different things. The front is still the card:
  /// it is what the library shows, what a hero animation flies from, and which
  /// side wins when both faces print the same number.
  ///
  /// Reading it is a separate step. This writes the pixels and the pointer;
  /// [attachExtraction] with `side: CardSide.back` folds in what the engine
  /// makes of them, and `BackCaptureService` runs the two in order. Splitting
  /// them keeps the rule the front already follows — the image is saved before
  /// anything is recognised, so a failed or crashed read leaves a card with a
  /// back on it rather than nothing.
  ///
  /// Re-capturing replaces: the previous back is deleted rather than
  /// accumulating a file per attempt. Its fields and blocks are replaced by the
  /// next extraction, which is scoped to the same side.
  Future<void> attachBackImage({
    required int cardId,
    required String backImagePath,
  }) async {
    final CardRow? card = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();
    if (card == null) return;

    await (_db.update(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).write(
      CardsCompanion(
        backImagePath: Value<String?>(backImagePath),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );

    final String? previous = card.backImagePath;
    if (previous != null && previous != backImagePath) {
      await _deleteFile(previous);
    }
  }

  /// Drops the back — image, text, fields and all.
  ///
  /// The counterpart to [attachBackImage]: a back photographed by mistake — a
  /// blank side, the desk, the wrong card — should be removable without
  /// deleting the card it is attached to.
  ///
  /// Everything read off it goes with it, including fields the user verified.
  /// That is the one place a human answer does not survive, and it has to be:
  /// those rows carry a `region_rect` into an image that no longer exists, so
  /// keeping them would leave values pointing at nothing. The caller re-indexes
  /// and re-promotes afterwards, the same as any other change to a card's
  /// fields.
  Future<void> removeBackImage(int cardId) async {
    final CardRow? card = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();
    if (card == null) return;

    await _db.transaction(() async {
      await (_db.delete(_db.ocrBlocks)..where(
            ($OcrBlocksTable b) =>
                b.cardId.equals(cardId) & b.side.equalsValue(CardSide.back),
          ))
          .go();
      await (_db.delete(_db.cardFields)..where(
            ($CardFieldsTable f) =>
                f.cardId.equals(cardId) & f.side.equalsValue(CardSide.back),
          ))
          .go();

      final List<CardField> settled = await (_db.select(
        _db.cardFields,
      )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();

      await (_db.update(
        _db.cards,
      )..where(($CardsTable c) => c.id.equals(cardId))).write(
        CardsCompanion(
          backImagePath: const Value<String?>(null),
          backOcrText: const Value<String?>(null),
          extractionStatus: Value<ExtractionStatus>(_statusOf(settled)),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
    });

    final String? previous = card.backImagePath;
    if (previous != null) await _deleteFile(previous);
  }

  /// Folds OCR output for one side into an existing card.
  ///
  /// Every recognised block is stored, not only the ones that became fields —
  /// the unassigned ones are what tap-to-assign offers later, so a card whose
  /// layout defeated the parser can be repaired without retyping.
  ///
  /// Scoped to [side], and that scoping is the whole reason the back can be
  /// read at all. Each side is recognised in its own pass against its own
  /// image, so a re-read of one must leave the other's rows exactly where they
  /// were — otherwise retaking the front would quietly throw away everything
  /// the back contributed, and reading the back would throw away the card.
  Future<void> attachExtraction({
    required int cardId,
    required ocr.OcrResult result,
    required CardExtraction extraction,
    CardSide side = CardSide.front,
  }) async {
    await _db.transaction(() async {
      final List<CardField> existing = await (_db.select(
        _db.cardFields,
      )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();

      // Anything the user confirmed or corrected outlives re-extraction, on
      // either side. The engine may change its mind freely; a human answer is
      // not something it gets to overwrite, or a retry would silently undo
      // every repair.
      final List<CardField> verified = existing
          .where((CardField f) => f.verifiedByUser)
          .toList();

      // What the *other* side is currently claiming on its own account. Both
      // faces of a card usually print the same phone number, so without this
      // every two-sided card would show each endpoint twice.
      final List<CardField> otherSide = existing
          .where((CardField f) => f.side != side && !f.verifiedByUser)
          .toList();

      await (_db.delete(_db.ocrBlocks)..where(
            ($OcrBlocksTable b) =>
                b.cardId.equals(cardId) & b.side.equalsValue(side),
          ))
          .go();
      await (_db.delete(_db.cardFields)..where(
            ($CardFieldsTable f) =>
                f.cardId.equals(cardId) &
                f.side.equalsValue(side) &
                f.verifiedByUser.equals(false),
          ))
          .go();

      final List<ExtractedField> incoming = _withoutSuperseded(
        verified,
        // Only the back defers. The front is the card — it is the image every
        // region is measured against and the one the library shows — so when
        // both faces print the same value, the front's row is the one that
        // keeps it. Ties are broken the other way below.
        side == CardSide.back ? otherSide : const <CardField>[],
        extraction.fields,
      );

      // Fields before blocks: a block records the field row that owns it, so
      // those ids have to exist first.
      final Map<int, int> fieldIdOfBlock = <int, int>{};
      final Set<String> claimed = <String>{};
      for (final ExtractedField f in incoming) {
        final int fieldId = await _db
            .into(_db.cardFields)
            .insert(
              CardFieldsCompanion.insert(
                cardId: cardId,
                fieldKey: f.fieldKey,
                value: f.value,
                normalizedValue: Value<String?>(f.normalizedValue),
                source: FactSource.printed,
                confidence: Value<double?>(f.confidence),
                validationIssue: Value<String?>(f.issue),
                regionRect: Value<String?>(f.regionRect),
                side: Value<CardSide>(side),
              ),
            );
        claimed.add(_identity(f.fieldKey, f.normalizedValue, f.value));
        for (final int i in f.sourceBlockIndices) {
          fieldIdOfBlock[i] = fieldId;
        }
      }

      // The other half of the tie-break: a value the front has just asserted
      // for itself no longer needs the back's copy of it. The back's blocks
      // survive — the delete only nulls their `field_id` — so the words stay
      // in the picker rather than becoming unreachable.
      if (side == CardSide.front) {
        for (final CardField f in otherSide) {
          if (claimed.contains(
            _identity(f.fieldKey, f.normalizedValue, f.value),
          )) {
            await (_db.delete(
              _db.cardFields,
            )..where(($CardFieldsTable t) => t.id.equals(f.id))).go();
          }
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
              side: Value<CardSide>(side),
            ),
        ]);
      });

      // Judged over the card rather than over this run. A blank back is the
      // ordinary case — most backs are blank — and it must not be able to mark
      // a cleanly-read card `failed`.
      final List<CardField> settled = await (_db.select(
        _db.cardFields,
      )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();

      await (_db.update(
        _db.cards,
      )..where(($CardsTable c) => c.id.equals(cardId))).write(
        CardsCompanion(
          rawOcrText: side == CardSide.front
              ? Value<String?>(result.plainText)
              : const Value<String?>.absent(),
          backOcrText: side == CardSide.back
              ? Value<String?>(result.plainText)
              : const Value<String?>.absent(),
          ocrEngine: Value<String?>(result.engine),
          extractionStatus: Value<ExtractionStatus>(_statusOf(settled)),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
    });

    await _db
        .into(_db.extractionAttempts)
        .insert(
          ExtractionAttemptsCompanion.insert(
            cardId: cardId,
            // Which side this run read, kept in the engine identifier rather
            // than in a column of its own: the table is a per-run log for the
            // accuracy report, and a front pass and a back pass are different
            // runs that would otherwise be indistinguishable.
            engine: side == CardSide.front
                ? result.engine
                : '${result.engine}/back',
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

    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            subjectType: 'card',
            subjectId: cardId,
            body: Value<String?>(trimmed),
          ),
        );
    await _db
        .into(_db.interactions)
        .insert(
          InteractionsCompanion.insert(
            subjectType: 'card',
            subjectId: cardId,
            kind: InteractionKind.scanned,
            detail: const Value<String?>('note added at save'),
          ),
        );
  }

  /// Replaces the note on a saved card, adds one, or — given an empty body —
  /// removes it.
  ///
  /// [addNote] only ever ran once, inside the capture flow, so a card saved
  /// with "Skip for now" could never be given the one thing that makes it
  /// findable by need, and a note written in a hurry at an event could never
  /// be corrected. Callers re-index afterwards: the note is the most valuable
  /// text search has.
  Future<void> setNote({required int cardId, required String body}) async {
    final String trimmed = body.trim();

    await _db.transaction(() async {
      final List<Note> existing =
          await (_db.select(_db.notes)
                ..where(
                  ($NotesTable n) =>
                      n.subjectType.equals('card') & n.subjectId.equals(cardId),
                )
                ..orderBy(<OrderClauseGenerator<$NotesTable>>[
                  ($NotesTable n) => OrderingTerm(expression: n.id),
                ]))
              .get();

      if (trimmed.isEmpty) {
        await (_db.delete(_db.notes)..where(
              ($NotesTable n) =>
                  n.subjectType.equals('card') & n.subjectId.equals(cardId),
            ))
            .go();
      } else if (existing.isEmpty) {
        await _db
            .into(_db.notes)
            .insert(
              NotesCompanion.insert(
                subjectType: 'card',
                subjectId: cardId,
                body: Value<String?>(trimmed),
              ),
            );
      } else {
        // The first note is the one every screen shows; edit that one.
        await (_db.update(_db.notes)
              ..where(($NotesTable n) => n.id.equals(existing.first.id)))
            .write(
              NotesCompanion(
                body: Value<String?>(trimmed),
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );
      }

      await _db
          .into(_db.interactions)
          .insert(
            InteractionsCompanion.insert(
              subjectType: 'card',
              subjectId: cardId,
              kind: InteractionKind.edited,
              detail: Value<String?>(
                trimmed.isEmpty ? 'note removed' : 'note edited',
              ),
            ),
          );
      await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .write(CardsCompanion(updatedAt: Value<DateTime>(DateTime.now())));
    });
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
    await (_db.update(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).write(
      CardsCompanion(
        deletedAt: Value<DateTime?>(DateTime.now()),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<void> restore(int cardId) async {
    await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
        .write(const CardsCompanion(deletedAt: Value<DateTime?>(null)));
  }

  /// Permanently removes a card, its image and its notes.
  ///
  /// Fields, OCR blocks and extraction attempts go with it through the schema's
  /// cascades; notes and embeddings hang off a polymorphic subject rather than a
  /// foreign key, so they are cleaned up explicitly.
  Future<void> purge(int cardId) async {
    final CardRow? card = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();

    if (card != null) {
      await _deleteFile(card.imagePath);
      // The thumbnail goes too, or every deleted card leaves one behind on a
      // phone that was short of space to begin with. So does the back, which
      // is a full-size image and the largest thing a card can leave behind.
      final String? thumb = card.thumbPath;
      if (thumb != null) await _deleteFile(thumb);
      final String? back = card.backImagePath;
      if (back != null) await _deleteFile(back);
    }

    await _db.transaction(() async {
      await (_db.delete(_db.notes)..where(
            ($NotesTable n) =>
                n.subjectType.equals('card') & n.subjectId.equals(cardId),
          ))
          .go();
      await (_db.delete(_db.interactions)..where(
            ($InteractionsTable i) =>
                i.subjectType.equals('card') & i.subjectId.equals(cardId),
          ))
          .go();
      await (_db.delete(_db.embeddings)..where(
            ($EmbeddingsTable e) =>
                e.subjectType.equals('card') & e.subjectId.equals(cardId),
          ))
          .go();
      await _db.customStatement(
        'DELETE FROM search_index WHERE subject_type = ? AND subject_id = ?',
        <Object?>['card', cardId],
      );
      await (_db.delete(
        _db.cards,
      )..where(($CardsTable c) => c.id.equals(cardId))).go();
    });
  }

  /// Cards with a back photographed but never read.
  ///
  /// `back_ocr_text` is the marker rather than the presence of blocks: it is
  /// written on every back extraction including one that found nothing, so a
  /// genuinely blank back is read once and then left alone, while a back
  /// attached before the side column existed still reads as unread.
  Future<List<({int id, String path})>> cardsWithUnreadBacks() async {
    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT id, back_image_path FROM cards '
          'WHERE deleted_at IS NULL AND back_image_path IS NOT NULL '
          'AND back_ocr_text IS NULL',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_db.cards},
        )
        .get();

    return <({int id, String path})>[
      for (final QueryRow row in rows)
        (id: row.read<int>('id'), path: row.read<String>('back_image_path')),
    ];
  }

  /// Marks [repairDigitRestoredLabels] as done. In `settings` rather than a
  /// schema migration: nothing about the shape of the data changed, only a
  /// rule that was applied to it — which is what that table is for.
  static const String _digitRestoredRepairKey = 'phone_digit_restored_repair';

  /// Takes "digit restored" off printed phone numbers that were only
  /// reformatted.
  ///
  /// The label used to be set whenever the dialable form differed from the
  /// text on the card, so "+880 1711-223344" shown as "01711223344" read as a
  /// guess although every digit was printed. [PhoneExtractor.restoresDigit]
  /// fixed that for new scans, but the label is stored at scan time, and only
  /// the Needs Attention queue ever re-reads a card — so without this, the
  /// cards somebody already has would carry the wrong chip for good.
  ///
  /// Each row is re-judged from its own OCR text rather than from its stored
  /// value, because the value is the reformatted number and cannot say what
  /// was printed. A row is left alone when there is no evidence to judge it
  /// by: no block points at it, or its blocks no longer parse to its number.
  /// Only a reading the extractor would now store with no issue at all
  /// clears the label, so a number that did need repair never comes out
  /// looking printed.
  ///
  /// Runs once, recorded in `settings`, and swallows its own failure: it is a
  /// label, and a launch must not stop over it. A failed run commits nothing
  /// and is tried again on the next one. Returns how many rows it cleared.
  Future<int> repairDigitRestoredLabels() async {
    try {
      return await _db.transaction(() async {
        final Setting? done =
            await (_db.select(_db.settings)..where(
                  ($SettingsTable s) => s.key.equals(_digitRestoredRepairKey),
                ))
                .getSingleOrNull();
        if (done != null) return 0;

        final List<CardField> flagged =
            await (_db.select(_db.cardFields)..where(
                  ($CardFieldsTable f) =>
                      f.fieldKey.equals(FieldKeys.phone) &
                      f.source.equalsValue(FactSource.printed) &
                      f.verifiedByUser.equals(false) &
                      f.validationIssue.equals('digit_restored'),
                ))
                .get();

        int cleared = 0;
        for (final CardField field in flagged) {
          final String? e164 = field.normalizedValue;
          if (e164 == null) continue;

          final List<OcrBlockRow> blocks = await (_db.select(
            _db.ocrBlocks,
          )..where(($OcrBlocksTable b) => b.fieldId.equals(field.id))).get();
          final List<PhoneMatch> readings = <PhoneMatch>[
            for (final OcrBlockRow b in blocks)
              ...PhoneExtractor.extractAll(
                b.blockText,
              ).where((PhoneMatch m) => m.e164 == e164),
          ];
          if (readings.isEmpty) continue;

          final bool printed = readings.every(
            (PhoneMatch m) =>
                m.isValid &&
                m.issue == null &&
                !m.repaired &&
                !PhoneExtractor.restoresDigit(m.raw, m.e164),
          );
          if (!printed) continue;

          await (_db.update(
            _db.cardFields,
          )..where(($CardFieldsTable f) => f.id.equals(field.id))).write(
            CardFieldsCompanion(
              validationIssue: const Value<String?>(null),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
          );
          cleared++;
        }

        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: _digitRestoredRepairKey,
                value: '1',
              ),
            );
        return cleared;
      });
    } on Object {
      // Deliberately ignored; see above.
      return 0;
    }
  }

  /// Marks [repairInventedPeople] as done, for the same reason as
  /// [_digitRestoredRepairKey].
  static const String _inventedPersonRepairKey = 'invented_person_repair';

  /// Takes away people that extraction made out of a line of copy.
  ///
  /// A shop card — "TechFix Repair Centre" over "Laptop and Mobile Servicing"
  /// — used to give a person called "Laptop and Mobile Servicing". The
  /// extractor no longer does, but the name is a stored `card_fields` row and
  /// promotion has made a contact of it. Bumping
  /// `IdentityRepository.rulesVersion` cannot take that back: it re-runs
  /// promotion over the stored rows, and a tagline passes
  /// `looksLikePersonName` because it is shaped like a name. Only the
  /// extractor can tell the two apart, so this asks it again.
  ///
  /// Each side is re-read from its own stored OCR blocks: no image and no
  /// engine, so it costs a launch almost nothing. A name nobody confirmed that
  /// the extractor would no longer give is deleted, and its lines go back to
  /// the picker, so if the extractor is the one that is wrong now the name is
  /// a tap away. When the re-read names somebody *else*, that name is not
  /// written in its place: an unreviewed person is exactly what this removes,
  /// and the line is in the picker either way.
  ///
  /// **Company and address are left as they are**, although the same fix
  /// changed them for a brand named after a place — "Dhaka Tech Repair" was
  /// joined onto the address and the tagline filed as the company. That is
  /// real text under the wrong label, every word still on the card screen,
  /// not a fact the card never stated. And undoing it is not a delete but a
  /// rewrite of two fields at once, the brand moved out of one and into the
  /// other with their blocks swapped over. Writing values nobody reviewed, on
  /// launch and unasked, is a re-read, and that is the user's call — made on
  /// the card screen, by picking the right line for each field.
  ///
  /// Also left alone: a side with no stored blocks, or one whose boxes no
  /// longer parse, since there is nothing faithful to re-read; and a card
  /// whose contact the user merged with another, because a merge says whose
  /// card this is and taking the name would take the card out of it.
  /// Recently deleted cards are repaired but not promoted: they hold no
  /// contact until they are restored, and restoring promotes them from the
  /// fields this fixes — skipping them would bring the contact back.
  ///
  /// The graph is rebuilt in the same transaction, so a failure cannot leave a
  /// name gone and its contact still standing. Every other card that shared
  /// the contact is promoted again too: when the owner's own card joined the
  /// invented contact through its phone number, the contact kept the invented
  /// name, and only promoting a card that still names somebody puts the real
  /// one back. No re-index: the line is still in the card's OCR text, which
  /// is what search reads.
  ///
  /// Runs once, recorded in `settings`, and swallows its own failure like
  /// [repairDigitRestoredLabels]: a failed run commits nothing and is tried
  /// again on the next launch. Returns how many names it removed.
  Future<int> repairInventedPeople(IdentityRepository identity) async {
    try {
      return await _db.transaction(() async {
        final Setting? done =
            await (_db.select(_db.settings)..where(
                  ($SettingsTable s) => s.key.equals(_inventedPersonRepairKey),
                ))
                .getSingleOrNull();
        if (done != null) return 0;

        final List<CardField> guessed =
            await (_db.select(_db.cardFields)..where(
                  ($CardFieldsTable f) =>
                      f.fieldKey.equals(FieldKeys.personName) &
                      f.source.equalsValue(FactSource.printed) &
                      f.verifiedByUser.equals(false) &
                      f.valueKind.equalsValue(FieldValueKind.text),
                ))
                .get();
        final Map<int, List<CardField>> byCard = <int, List<CardField>>{};
        for (final CardField f in guessed) {
          (byCard[f.cardId] ??= <CardField>[]).add(f);
        }

        int removed = 0;
        final Set<int> repaired = <int>{};
        final Set<int> formerPeople = <int>{};
        for (final MapEntry<int, List<CardField>> entry in byCard.entries) {
          final CardRow? card =
              await (_db.select(_db.cards)
                    ..where(($CardsTable c) => c.id.equals(entry.key)))
                  .getSingleOrNull();
          if (card == null) continue;
          final int? personId = card.personId;
          if (personId != null && await identity.isMerged(personId)) continue;

          final List<CardField> stale = <CardField>[];
          for (final CardSide side in CardSide.values) {
            final List<CardField> onSide = entry.value
                .where((CardField f) => f.side == side)
                .toList();
            if (onSide.isEmpty) continue;
            final List<ocr.OcrBlock>? blocks = await _storedBlocks(
              card.id,
              side,
            );
            if (blocks == null) continue;

            final String? now = CardFieldExtractor.extract(
              blocks,
            ).firstOfKey(FieldKeys.personName)?.value;
            stale.addAll(onSide.where((CardField f) => f.value.trim() != now));
          }
          if (stale.isEmpty) continue;

          for (final CardField f in stale) {
            await _releaseBlocks(f.id);
            await (_db.delete(
              _db.cardFields,
            )..where(($CardFieldsTable t) => t.id.equals(f.id))).go();
          }
          removed += stale.length;

          // The status was judged with the name counted in, and a card whose
          // only claim to being read was a company and an invented person
          // belongs back in Needs Attention.
          final List<CardField> settled = await (_db.select(
            _db.cardFields,
          )..where(($CardFieldsTable f) => f.cardId.equals(card.id))).get();
          await (_db.update(
            _db.cards,
          )..where(($CardsTable c) => c.id.equals(card.id))).write(
            CardsCompanion(
              extractionStatus: Value<ExtractionStatus>(_statusOf(settled)),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
          );

          if (card.deletedAt == null) {
            repaired.add(card.id);
            if (personId != null) formerPeople.add(personId);
          }
        }

        for (final int id in repaired) {
          await identity.promote(id);
        }
        if (formerPeople.isNotEmpty) {
          final List<CardRow> sharers =
              await (_db.select(_db.cards)..where(
                    ($CardsTable c) =>
                        c.personId.isIn(formerPeople) &
                        c.deletedAt.isNull() &
                        c.id.isNotIn(repaired),
                  ))
                  .get();
          for (final CardRow c in sharers) {
            await identity.promote(c.id);
          }
        }

        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: _inventedPersonRepairKey,
                value: '1',
              ),
            );
        return removed;
      });
    } on Object {
      // Deliberately ignored; see above.
      return 0;
    }
  }

  /// One side's OCR blocks as the engine returned them, rebuilt from their
  /// rows in reading order — or null when there are none, or when a box no
  /// longer parses and the rebuilt card would not be the one that was read.
  ///
  /// Every row, blank ones included: the extractor judges prominence against
  /// the largest box on the side, and a blank block is still a box.
  Future<List<ocr.OcrBlock>?> _storedBlocks(int cardId, CardSide side) async {
    final List<OcrBlockRow> rows =
        await (_db.select(_db.ocrBlocks)
              ..where(
                ($OcrBlocksTable b) =>
                    b.cardId.equals(cardId) & b.side.equalsValue(side),
              )
              ..orderBy(<OrderClauseGenerator<$OcrBlocksTable>>[
                ($OcrBlocksTable b) => OrderingTerm(expression: b.orderIndex),
                ($OcrBlocksTable b) => OrderingTerm(expression: b.id),
              ]))
            .get();
    if (rows.isEmpty) return null;

    final List<ocr.OcrBlock> blocks = <ocr.OcrBlock>[];
    for (final OcrBlockRow r in rows) {
      final List<double?> v = r.rect
          .split(',')
          .map((String s) => double.tryParse(s.trim()))
          .toList();
      if (v.length != 4 || v.contains(null)) return null;
      blocks.add(
        ocr.OcrBlock(
          text: r.blockText,
          rect: Rect.fromLTRB(v[0]!, v[1]!, v[2]!, v[3]!),
          confidence: r.confidence,
          script: ocr.Script.values.asNameMap()[r.script] ?? ocr.Script.unknown,
          engine: r.engine,
        ),
      );
    }
    return blocks;
  }

  /// Saved cards, newest first, as a live stream so the library updates itself.
  ///
  /// Driven by an explicit [readsFrom] rather than `select(cards).watch()`, for
  /// the reason spelled out on [watchCard]: the title of a row comes out of
  /// `card_fields`, so a stream watching only `cards` never notices it change.
  Stream<List<CardSummary>> watchCards() => _watchSummaries(
    'SELECT id FROM cards WHERE deleted_at IS NULL '
    'ORDER BY captured_at DESC',
  );

  /// Cards whose extraction went badly, and which the user can still repair.
  ///
  /// Oldest first, deliberately. A failure that has been sitting there for a
  /// week is the one most likely to be forgotten, and a queue that puts the
  /// newest on top buries exactly the rows it exists to surface.
  Stream<List<CardSummary>> watchNeedsAttention() => _watchSummaries(
    'SELECT id FROM cards WHERE deleted_at IS NULL '
    r"AND extraction_status IN ('failed', 'partial') "
    'ORDER BY captured_at ASC',
  );

  /// Cards deleted but not yet destroyed.
  ///
  /// The undo window lives in a snackbar, so a card whose window was
  /// interrupted — app killed, phone out of battery — stays soft-deleted with
  /// nothing left pointing at it. Without this it is unreachable forever while
  /// still occupying the disk. Newest first: recovering something is almost
  /// always about the thing you just lost.
  Stream<List<CardSummary>> watchDeleted() => _watchSummaries(
    'SELECT id FROM cards WHERE deleted_at IS NOT NULL '
    'ORDER BY deleted_at DESC',
  );

  Stream<List<CardSummary>> _watchSummaries(String sql) {
    return _db
        .customSelect(
          sql,
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
            final CardRow? row =
                await (_db.select(_db.cards)..where(
                      ($CardsTable c) => c.id.equals(id.read<int>('id')),
                    ))
                    .getSingleOrNull();
            if (row == null) continue;

            final List<CardField> fields = await (_db.select(
              _db.cardFields,
            )..where(($CardFieldsTable f) => f.cardId.equals(row.id))).get();
            final Note? note =
                await (_db.select(_db.notes)
                      ..where(
                        ($NotesTable n) =>
                            n.subjectType.equals('card') &
                            n.subjectId.equals(row.id),
                      )
                      ..limit(1))
                    .getSingleOrNull();

            String? valueOf(String key) {
              for (final CardField f in fields) {
                if (f.fieldKey == key) return f.value;
              }
              return null;
            }

            out.add(
              CardSummary(
                id: row.id,
                imagePath: row.imagePath,
                thumbPath: row.thumbPath,
                capturedAt: row.capturedAt,
                status: row.extractionStatus,
                title:
                    valueOf(FieldKeys.company) ??
                    valueOf(FieldKeys.personName) ??
                    valueOf(FieldKeys.phone),
                subtitle:
                    valueOf(FieldKeys.personName) ?? valueOf(FieldKeys.phone),
                note: note?.body,
              ),
            );
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

          final CardRow? card = await (_db.select(
            _db.cards,
          )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();
          if (card == null) return null;

          final List<CardField> fields = await (_db.select(
            _db.cardFields,
          )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();
          final List<Note> notes =
              await (_db.select(_db.notes)..where(
                    ($NotesTable n) =>
                        n.subjectType.equals('card') &
                        n.subjectId.equals(cardId),
                  ))
                  .get();
          final List<OcrBlockRow> blocks =
              await (_db.select(_db.ocrBlocks)
                    ..where(($OcrBlocksTable b) => b.cardId.equals(cardId))
                    ..orderBy(<OrderClauseGenerator<$OcrBlocksTable>>[
                      ($OcrBlocksTable b) =>
                          OrderingTerm(expression: b.orderIndex),
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
            final int byKey = (ai < 0 ? order.length : ai).compareTo(
              bi < 0 ? order.length : bi,
            );
            if (byKey != 0) return byKey;
            // Within a key, the front comes first. A card with a number on each
            // face should read as the card does: the printed front, then whatever
            // the back adds. Ties go to insertion order, spelled out because
            // `List.sort` gives no stability guarantee.
            final int bySide = a.side.index.compareTo(b.side.index);
            return bySide != 0 ? bySide : a.id.compareTo(b.id);
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
    final CardField? existing = await (_db.select(
      _db.cardFields,
    )..where(($CardFieldsTable f) => f.id.equals(fieldId))).getSingleOrNull();
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
    final _Sourcing sourced = _Sourcing.of(blocks);

    await _db.transaction(() async {
      await (_db.update(
        _db.cardFields,
      )..where(($CardFieldsTable f) => f.id.equals(fieldId))).write(
        CardFieldsCompanion(
          fieldKey: Value<String>(key),
          value: Value<String>(text),
          normalizedValue: Value<String?>(check.normalized),
          source: const Value<FactSource>(FactSource.user),
          verifiedByUser: const Value<bool>(true),
          validationIssue: Value<String?>(check.issue),
          regionRect: blocks.isEmpty
              ? const Value<String?>.absent()
              : Value<String?>(sourced.rect),
          side: blocks.isEmpty
              ? const Value<CardSide>.absent()
              : Value<CardSide>(sourced.side),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );

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

    final String text = blocks.isNotEmpty
        ? _joinBlocks(blocks)
        : (value ?? '').trim();
    if (text.isEmpty) return;

    final FieldValidation check = validateField(fieldKey, text);
    final _Sourcing sourced = _Sourcing.of(blocks);

    await _db.transaction(() async {
      final int fieldId = await _db
          .into(_db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: cardId,
              fieldKey: fieldKey,
              value: text,
              normalizedValue: Value<String?>(check.normalized),
              source: FactSource.user,
              verifiedByUser: const Value<bool>(true),
              validationIssue: Value<String?>(check.issue),
              regionRect: Value<String?>(sourced.rect),
              side: Value<CardSide>(sourced.side),
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
    final CardField? existing = await (_db.select(
      _db.cardFields,
    )..where(($CardFieldsTable f) => f.id.equals(fieldId))).getSingleOrNull();
    if (existing == null) return;

    await _db.transaction(() async {
      await _releaseBlocks(fieldId);
      await (_db.delete(
        _db.cardFields,
      )..where(($CardFieldsTable f) => f.id.equals(fieldId))).go();
      await _logEdit(existing.cardId);
    });
  }

  Future<List<OcrBlockRow>> _blocksByIds(int cardId, List<int> ids) async {
    if (ids.isEmpty) return const <OcrBlockRow>[];
    final List<OcrBlockRow> rows =
        await (_db.select(_db.ocrBlocks)
              ..where(
                ($OcrBlocksTable b) => b.cardId.equals(cardId) & b.id.isIn(ids),
              )
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
      await (_db.update(
        _db.ocrBlocks,
      )..where(($OcrBlocksTable t) => t.id.equals(b.id))).write(
        OcrBlocksCompanion(
          fieldId: Value<int?>(fieldId),
          assignedFieldKey: Value<String?>(key),
        ),
      );
    }
  }

  Future<void> _releaseBlocks(int fieldId) =>
      (_db.update(
        _db.ocrBlocks,
      )..where(($OcrBlocksTable b) => b.fieldId.equals(fieldId))).write(
        const OcrBlocksCompanion(
          fieldId: Value<int?>(null),
          assignedFieldKey: Value<String?>(null),
        ),
      );

  Future<void> _logEdit(int cardId) async {
    await _db
        .into(_db.interactions)
        .insert(
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

  /// What makes two facts the same fact: a key and a canonical value.
  static String _identity(String key, String? normalized, String value) =>
      '$key ${normalized ?? value.toLowerCase()}';

  /// Drops incoming fields something already on the card has answered.
  ///
  /// [verified] outranks the engine outright, so it settles the whole key for
  /// anything a card only has one of — a second company name is the engine
  /// contradicting a human. [alreadyAsserted] is weaker: it suppresses only the
  /// exact same value, because the other face of a card carrying a *different*
  /// phone number is a new fact worth keeping.
  static List<ExtractedField> _withoutSuperseded(
    List<CardField> verified,
    List<CardField> alreadyAsserted,
    List<ExtractedField> incoming,
  ) {
    if (verified.isEmpty && alreadyAsserted.isEmpty) return incoming;

    final Set<String> settledKeys = <String>{
      for (final CardField f in verified)
        if (!_repeatableKeys.contains(f.fieldKey)) f.fieldKey,
    };
    final Set<String> settledValues = <String>{
      for (final CardField f in <CardField>[...verified, ...alreadyAsserted])
        _identity(f.fieldKey, f.normalizedValue, f.value),
    };

    return incoming
        .where(
          (ExtractedField f) =>
              !settledKeys.contains(f.fieldKey) &&
              !settledValues.contains(
                _identity(f.fieldKey, f.normalizedValue, f.value),
              ),
        )
        .toList();
  }

  /// What a card's fields add up to, judged over the whole card rather than
  /// over whichever run or repair last touched it.
  static ExtractionStatus _statusOf(List<CardField> settled) => settled.isEmpty
      ? ExtractionStatus.failed
      : CardExtraction.isUsefulSet(settled.map((CardField f) => f.fieldKey))
      ? ExtractionStatus.complete
      : ExtractionStatus.partial;

  static String _rectOf(ocr.OcrBlock b) =>
      '${b.rect.left.round()},${b.rect.top.round()},'
      '${b.rect.right.round()},${b.rect.bottom.round()}';

  /// The box enclosing every block behind a field, so highlighting a merged
  /// value boxes all of it rather than only its first line.
  ///
  /// Only meaningful for blocks from one side: see [_Sourcing].
  static String? unionRect(List<OcrBlockRow> blocks) {
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

/// Where a hand-repaired field's value came from: which face, and which box.
///
/// The picker offers blocks from both sides of the card, so a repair can end up
/// sourced from either — or, when somebody picks a line from each, from a pair
/// of images with nothing in common but the card they were printed on. Two
/// rectangles in two coordinate spaces have no union, so that case gets the
/// text the user chose and no box at all: no highlight is honest, a box drawn
/// over the wrong side is not.
class _Sourcing {
  const _Sourcing({required this.side, required this.rect});

  final CardSide side;

  /// "left,top,right,bottom" in [side]'s pixel space, or null when there is no
  /// single space to express it in.
  final String? rect;

  factory _Sourcing.of(List<OcrBlockRow> blocks) {
    if (blocks.isEmpty) {
      return const _Sourcing(side: CardSide.front, rect: null);
    }
    final CardSide side = blocks.first.side;
    final bool mixed = blocks.any((OcrBlockRow b) => b.side != side);
    return _Sourcing(
      side: side,
      rect: mixed ? null : CardRepository.unionRect(blocks),
    );
  }
}
