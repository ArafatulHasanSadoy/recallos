import 'dart:ui' show Rect;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/features/capture/data/card_repository.dart';

/// Schema v11 keeps a field's provenance in two forms — the old `source` and
/// `verified_by_user`, and the new `origin`, `review` and `validity` — until
/// nothing reads the old one. They must never disagree, so this drives every
/// path that writes a field and checks both.
void main() {
  late AppDatabase db;
  late CardRepository repo;
  late int cardId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CardRepository(db);
    cardId = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/tmp/card.jpg',
            capturedAt: DateTime(2026, 10, 8),
          ),
        );
  });
  tearDown(() async => db.close());

  OcrBlock line(String text, double top, double height) => OcrBlock(
    text: text,
    rect: Rect.fromLTWH(10, top, 300, height),
    confidence: 0.9,
    script: Script.latin,
  );

  Future<void> extract() async {
    final List<OcrBlock> blocks = <OcrBlock>[
      line('Star Tech & Engineering', 10, 40),
      line('Rafiq Islam', 70, 24),
      line('01711-223344', 200, 16),
    ];
    await repo.attachExtraction(
      cardId: cardId,
      result: OcrResult(
        blocks: blocks,
        engine: 'test',
        duration: const Duration(milliseconds: 10),
      ),
      extraction: CardFieldExtractor.extract(blocks),
    );
  }

  Future<List<CardField>> fields() => (db.select(
    db.cardFields,
  )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();

  void agree(CardField f) {
    expect(
      f.review == FactReview.confirmed,
      f.verifiedByUser,
      reason: '${f.fieldKey}: review and verified_by_user disagree',
    );
    expect(
      f.origin,
      f.source == FactSource.user ? FactOrigin.user : FactOrigin.printed,
      reason: '${f.fieldKey}: origin and source disagree',
    );
    expect(f.validity, FactValidity.current);
  }

  test('read off the card: printed, unreviewed, in both forms', () async {
    await extract();
    final List<CardField> all = await fields();
    expect(all, isNotEmpty);
    for (final CardField f in all) {
      expect(f.origin, FactOrigin.printed);
      expect(f.review, FactReview.unreviewed);
      agree(f);
    }
  });

  test('corrected by the user: theirs and confirmed, in both forms', () async {
    await extract();
    final CardField phone = (await fields()).firstWhere(
      (CardField f) => f.fieldKey == FieldKeys.phone,
    );
    await repo.updateField(fieldId: phone.id, value: '01711-223355');

    final CardField after = (await fields()).firstWhere(
      (CardField f) => f.id == phone.id,
    );
    expect(after.origin, FactOrigin.user);
    expect(after.review, FactReview.confirmed);
    agree(after);
  });

  test('added by the user: theirs and confirmed, in both forms', () async {
    await repo.addField(
      cardId: cardId,
      fieldKey: FieldKeys.email,
      value: 'rafiq@startech.com.bd',
    );
    final CardField added = (await fields()).single;
    expect(added.origin, FactOrigin.user);
    expect(added.review, FactReview.confirmed);
    agree(added);
  });

  test('a confirmed field outlives a fresh reading, as before', () async {
    await extract();
    final CardField phone = (await fields()).firstWhere(
      (CardField f) => f.fieldKey == FieldKeys.phone,
    );
    await repo.updateField(fieldId: phone.id, value: '01711-223355');

    await extract();

    final List<CardField> phones = (await fields())
        .where((CardField f) => f.fieldKey == FieldKeys.phone)
        .toList();
    expect(
      phones.where((CardField f) => f.review == FactReview.confirmed),
      hasLength(1),
    );
    expect(
      phones
          .firstWhere((CardField f) => f.review == FactReview.confirmed)
          .value,
      '01711-223355',
    );
    for (final CardField f in await fields()) {
      agree(f);
    }
  });
}
