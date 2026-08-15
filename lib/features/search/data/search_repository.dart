import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/intelligence/embedding/static_embedder.dart';
import '../../../core/intelligence/embedding/wordpiece.dart';
import '../../../core/search/fts_query.dart';
import '../../../core/search/fusion.dart';
import '../../../core/search/utility_score.dart';
import '../../capture/data/card_repository.dart';

/// The 7.3 MB static embedding table, loaded once.
///
/// Costs about 3 ms — the matrix is mapped as a typed-data view rather than
/// copied — but it does read the asset off disk, so it is held for the life of
/// the app rather than rebuilt per search.
final embedderProvider = FutureProvider<StaticEmbedder>((Ref ref) async {
  final String vocab = await rootBundle.loadString('assets/embedding/vocab.txt');
  final String normalizer =
      await rootBundle.loadString('assets/embedding/normalizer.json');
  final ByteData matrix = await rootBundle.load('assets/embedding/matrix.bin');

  return StaticEmbedder.fromBytes(
    matrixBytes:
        matrix.buffer.asUint8List(matrix.offsetInBytes, matrix.lengthInBytes),
    tokenizer: WordPieceTokenizer.fromAssets(
      vocabText: vocab,
      normalizerJson: normalizer,
    ),
  );
});

final searchRepositoryProvider = Provider<SearchRepository>(
  (Ref ref) => SearchRepository(
    ref.watch(databaseProvider),
    () async => ref.read(embedderProvider.future),
  ),
);

/// One card that matched, with the reason it did.
class SearchHit {
  const SearchHit({
    required this.card,
    required this.score,
    required this.reasons,
    required this.matchedOnMeaningOnly,
  });

  final CardSummary card;

  /// Utility score, 0..1.
  final double score;

  /// Human-readable, derived from the arithmetic that actually ranked this —
  /// never generated after the fact.
  final List<String> reasons;

  /// True when only the vector arm found it: the card shares no wording with
  /// the query. These are the results the embedding exists to produce.
  final bool matchedOnMeaningOnly;
}

/// Indexing and retrieval.
///
/// Both retrieval arms run on every device — FTS5 needs no model, and the
/// vector arm is a lookup table — so there is no tier where search silently
/// degrades to something worse.
class SearchRepository {
  SearchRepository(this._db, this._loadEmbedder);

  final AppDatabase _db;
  final Future<StaticEmbedder> Function() _loadEmbedder;

  StaticEmbedder? _embedder;

  Future<StaticEmbedder?> _embedderOrNull() async {
    if (_embedder != null) return _embedder;
    try {
      return _embedder = await _loadEmbedder();
    } on Object {
      // Missing or corrupt assets must not take search down; the lexical arm
      // still works on its own.
      return null;
    }
  }

  /// Rebuilds the search rows for one card.
  ///
  /// Called after extraction and again after the note is added, because the
  /// note is usually the most valuable text on the record and the index is
  /// worthless without it.
  Future<void> reindexCard(int cardId) async {
    final CardRow? card = await (_db.select(_db.cards)
          ..where(($CardsTable c) => c.id.equals(cardId)))
        .getSingleOrNull();
    if (card == null) return;

    final List<CardField> fields = await (_db.select(_db.cardFields)
          ..where(($CardFieldsTable f) => f.cardId.equals(cardId)))
        .get();
    final List<Note> notes = await (_db.select(_db.notes)
          ..where(($NotesTable n) =>
              n.subjectType.equals('card') & n.subjectId.equals(cardId)))
        .get();

    // Field values as well as the raw OCR dump: extraction corrects things the
    // raw text got wrong, most visibly phone numbers with a restored digit.
    final String cardText = <String>[
      card.rawOcrText ?? '',
      for (final CardField f in fields) f.value,
    ].where((String s) => s.trim().isNotEmpty).join('\n');

    final String noteText = notes
        .map((Note n) => <String?>[n.body, n.transcript].whereType<String>().join(' '))
        .where((String s) => s.trim().isNotEmpty)
        .join('\n');

    await _deleteIndexRows(cardId);

    await _db.customStatement(
      'INSERT INTO search_index(subject_type, subject_id, card_text, '
      'note_text, canonical_en, tags) VALUES (?, ?, ?, ?, ?, ?)',
      <Object?>['card', cardId, cardText, noteText, '', ''],
    );

    final StaticEmbedder? embedder = await _embedderOrNull();
    if (embedder == null) return;

    final String embedText = <String>[cardText, noteText]
        .where((String s) => s.trim().isNotEmpty)
        .join('\n');
    if (embedText.trim().isEmpty) return;

    final Float32List vector = embedder.embed(embedText);
    if (!StaticEmbedder.isUsable(vector)) return;

    await _db.into(_db.embeddings).insert(
          EmbeddingsCompanion.insert(
            subjectType: 'card',
            subjectId: cardId,
            vector: StaticEmbedder.toBlob(vector),
            dim: vector.length,
            model: StaticEmbedder.modelId,
          ),
        );
  }

  /// Indexes anything that has no index rows yet.
  ///
  /// Cards saved before search existed have no entries, and without this they
  /// would stay invisible forever — the failure looks exactly like "search is
  /// broken" from the outside.
  Future<void> backfill() async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT c.id AS id FROM cards c '
      'WHERE c.deleted_at IS NULL AND c.id NOT IN '
      '(SELECT subject_id FROM search_index WHERE subject_type = ?)',
      variables: <Variable<Object>>[Variable<String>('card')],
    ).get();

    for (final QueryRow row in rows) {
      await reindexCard(row.read<int>('id'));
    }
  }

  Future<void> _deleteIndexRows(int cardId) async {
    await _db.customStatement(
      'DELETE FROM search_index WHERE subject_type = ? AND subject_id = ?',
      <Object?>['card', cardId],
    );
    await (_db.delete(_db.embeddings)
          ..where(($EmbeddingsTable e) =>
              e.subjectType.equals('card') & e.subjectId.equals(cardId)))
        .go();
  }

  /// Removes a card from the index. Called when one is purged.
  Future<void> removeFromIndex(int cardId) => _deleteIndexRows(cardId);

  /// Runs a query.
  ///
  /// Returns an empty list for a query with nothing searchable in it, which the
  /// UI shows differently from "searched and found nothing".
  Future<List<SearchHit>> search(String rawQuery, {int limit = 20}) async {
    final String? match = buildFtsQuery(rawQuery);
    if (match == null) return const <SearchHit>[];

    final List<ScoredCandidate> lexical = await _lexicalArm(match);
    final List<ScoredCandidate> vector = await _vectorArm(rawQuery);

    final List<FusedResult> fused = reciprocalRankFusion(
      lexical: lexical,
      vector: vector,
      limit: limit,
    );
    if (fused.isEmpty) return const <SearchHit>[];

    final RankingWeightSet weights = await _weights();
    final List<SearchHit> hits = <SearchHit>[];

    for (final FusedResult f in fused) {
      final CardSummary? summary = await _summaryOf(f.subjectId);
      if (summary == null) continue;

      final String haystack = <String>[
        summary.title ?? '',
        summary.subtitle ?? '',
        summary.note ?? '',
      ].join(' ');

      final List<String> terms = matchedTerms(rawQuery, haystack);
      final bool noteMatched = summary.note != null &&
          matchedTerms(rawQuery, summary.note!).isNotEmpty;

      final UtilityScore score = computeUtility(
        weights: weights,
        signals: RankingSignals(
          semantic: normalizeFusedScore(f.fusedScore),
          noteRelevance: noteMatched ? 1 : 0,
          freshness: freshnessFromAge(
            DateTime.now().difference(summary.capturedAt),
          ),
        ),
      );

      hits.add(SearchHit(
        card: summary,
        score: score.value,
        reasons: _explain(f, terms, noteMatched),
        matchedOnMeaningOnly: f.semanticOnly,
      ));
    }

    hits.sort((SearchHit a, SearchHit b) => b.score.compareTo(a.score));
    return hits;
  }

  Future<List<ScoredCandidate>> _lexicalArm(String match) async {
    try {
      final List<QueryRow> rows = await _db.customSelect(
        'SELECT subject_id, bm25(search_index) AS score FROM search_index '
        'WHERE search_index MATCH ? AND subject_type = ? '
        'ORDER BY score LIMIT 50',
        variables: <Variable<Object>>[
          Variable<String>(match),
          Variable<String>('card'),
        ],
      ).get();

      return fromBm25(<int, double>{
        for (final QueryRow r in rows)
          r.read<int>('subject_id'): r.read<double>('score'),
      });
    } on Object {
      // A malformed MATCH should be impossible after buildFtsQuery, but a
      // thrown query must not blank the screen — the vector arm can carry it.
      return const <ScoredCandidate>[];
    }
  }

  Future<List<ScoredCandidate>> _vectorArm(String rawQuery) async {
    final StaticEmbedder? embedder = await _embedderOrNull();
    if (embedder == null) return const <ScoredCandidate>[];

    final Float32List query = embedder.embed(rawQuery);
    if (!StaticEmbedder.isUsable(query)) return const <ScoredCandidate>[];

    final List<Embedding> stored = await (_db.select(_db.embeddings)
          ..where(($EmbeddingsTable e) =>
              e.subjectType.equals('card') &
              e.model.equals(StaticEmbedder.modelId)))
        .get();

    return rankByCosine(
      queryVector: query,
      candidates: <int, List<double>>{
        for (final Embedding e in stored)
          e.subjectId: StaticEmbedder.fromBlob(e.vector),
      },
      // Below this two strings are unrelated, and including them makes every
      // query look like it matched everything.
      minScore: 0.25,
      limit: 50,
    );
  }

  Future<RankingWeightSet> _weights() async {
    final List<RankingWeight> rows = await _db.select(_db.rankingWeights).get();
    return RankingWeightSet.fromMap(<String, double>{
      for (final RankingWeight w in rows) w.key: w.value,
    });
  }

  static List<String> _explain(
    FusedResult f,
    List<String> terms,
    bool noteMatched,
  ) {
    final List<String> reasons = <String>[];
    if (noteMatched) reasons.add('your note');
    if (terms.isNotEmpty) {
      reasons.add(terms.take(3).join(', '));
    }
    if (f.semanticOnly && reasons.isEmpty) {
      reasons.add('similar meaning');
    }
    return reasons;
  }

  Future<CardSummary?> _summaryOf(int cardId) async {
    final CardRow? card = await (_db.select(_db.cards)
          ..where(($CardsTable c) =>
              c.id.equals(cardId) & c.deletedAt.isNull()))
        .getSingleOrNull();
    if (card == null) return null;

    final List<CardField> fields = await (_db.select(_db.cardFields)
          ..where(($CardFieldsTable f) => f.cardId.equals(cardId)))
        .get();
    final Note? note = await (_db.select(_db.notes)
          ..where(($NotesTable n) =>
              n.subjectType.equals('card') & n.subjectId.equals(cardId))
          ..limit(1))
        .getSingleOrNull();

    String? valueOf(String key) {
      for (final CardField f in fields) {
        if (f.fieldKey == key) return f.value;
      }
      return null;
    }

    return CardSummary(
      id: card.id,
      imagePath: card.imagePath,
      thumbPath: card.thumbPath,
      capturedAt: card.capturedAt,
      status: card.extractionStatus,
      title: valueOf('company') ?? valueOf('person_name') ?? valueOf('phone'),
      subtitle: valueOf('person_name') ?? valueOf('phone'),
      note: note?.body,
    );
  }
}
