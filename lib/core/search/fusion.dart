/// Combining the two retrieval arms — FTS5 lexical and vector cosine.
///
/// Both run on every device: the lexical arm needs no model, and the vector arm
/// is a lookup table. So unlike most hybrid-search designs, there is no tier
/// where one arm silently disappears.
library;

import 'dart:math' as math;

/// One candidate from one retrieval arm.
class ScoredCandidate {
  const ScoredCandidate({
    required this.subjectId,
    required this.score,
  });

  final int subjectId;

  /// Arm-native score: BM25 rank for lexical, cosine for vector. Not comparable
  /// across arms, which is exactly why fusion works on ranks instead.
  final double score;

  @override
  String toString() => '#$subjectId(${score.toStringAsFixed(3)})';
}

/// A fused result, carrying enough detail to explain itself.
class FusedResult {
  const FusedResult({
    required this.subjectId,
    required this.fusedScore,
    required this.lexicalRank,
    required this.vectorRank,
    required this.lexicalScore,
    required this.vectorScore,
  });

  final int subjectId;
  final double fusedScore;

  /// 1-based rank in each arm, or null when that arm did not return it. Kept
  /// because "matched on wording" and "matched on meaning" are different things
  /// to tell the user, and the "why matched" chip says which.
  final int? lexicalRank;
  final int? vectorRank;

  final double? lexicalScore;
  final double? vectorScore;

  bool get foundByBoth => lexicalRank != null && vectorRank != null;

  /// True when only the vector arm found it — the card shares no wording with
  /// the query. These are the results that justify shipping the embedding.
  bool get semanticOnly => lexicalRank == null && vectorRank != null;

  @override
  String toString() => '#$subjectId rrf=${fusedScore.toStringAsFixed(4)} '
      'lex=$lexicalRank vec=$vectorRank';
}

/// Reciprocal Rank Fusion.
///
/// Ranks are fused rather than scores because BM25 and cosine are on
/// incomparable scales — BM25 is unbounded and corpus-dependent, cosine sits in
/// [-1, 1]. Normalising them against each other needs per-query calibration
/// that would have to be re-tuned every time the corpus changes. RRF needs
/// none: it only asks which arm ranked a document higher.
///
/// [k] damps the influence of top ranks. 60 is the value from the original
/// paper and the one most systems use; it is exposed mainly so the evaluation
/// harness can confirm the choice rather than assume it.
List<FusedResult> reciprocalRankFusion({
  required List<ScoredCandidate> lexical,
  required List<ScoredCandidate> vector,
  double k = 60,
  int? limit,
}) {
  final Map<int, int> lexicalRanks = <int, int>{};
  final Map<int, double> lexicalScores = <int, double>{};
  for (int i = 0; i < lexical.length; i++) {
    lexicalRanks[lexical[i].subjectId] = i + 1;
    lexicalScores[lexical[i].subjectId] = lexical[i].score;
  }

  final Map<int, int> vectorRanks = <int, int>{};
  final Map<int, double> vectorScores = <int, double>{};
  for (int i = 0; i < vector.length; i++) {
    vectorRanks[vector[i].subjectId] = i + 1;
    vectorScores[vector[i].subjectId] = vector[i].score;
  }

  final List<FusedResult> fused = <FusedResult>[
    for (final int id in <int>{...lexicalRanks.keys, ...vectorRanks.keys})
      FusedResult(
        subjectId: id,
        fusedScore: (lexicalRanks[id] == null ? 0 : 1 / (k + lexicalRanks[id]!)) +
            (vectorRanks[id] == null ? 0 : 1 / (k + vectorRanks[id]!)),
        lexicalRank: lexicalRanks[id],
        vectorRank: vectorRanks[id],
        lexicalScore: lexicalScores[id],
        vectorScore: vectorScores[id],
      ),
  ];

  fused.sort((FusedResult a, FusedResult b) {
    final int byScore = b.fusedScore.compareTo(a.fusedScore);
    // Deterministic ordering for ties, so results do not shuffle between runs
    // and so tests are stable.
    return byScore != 0 ? byScore : a.subjectId.compareTo(b.subjectId);
  });

  if (limit != null && fused.length > limit) {
    return fused.sublist(0, limit);
  }
  return fused;
}

/// Ranks [candidates] by cosine against [queryVector].
///
/// Brute force on purpose. A personal card collection is hundreds to low
/// thousands of 256-dim vectors, and scanning that in Dart costs about a
/// millisecond — cheaper than maintaining an index, and with no build step to
/// keep in sync as cards are added and edited.
List<ScoredCandidate> rankByCosine({
  required List<double> queryVector,
  required Map<int, List<double>> candidates,
  double minScore = 0.0,
  int? limit,
}) {
  final List<ScoredCandidate> scored = <ScoredCandidate>[];

  for (final MapEntry<int, List<double>> e in candidates.entries) {
    if (e.value.length != queryVector.length) continue;

    double dot = 0;
    for (int i = 0; i < queryVector.length; i++) {
      dot += queryVector[i] * e.value[i];
    }
    final double score = dot.clamp(-1.0, 1.0);
    if (score >= minScore) {
      scored.add(ScoredCandidate(subjectId: e.key, score: score));
    }
  }

  scored.sort((ScoredCandidate a, ScoredCandidate b) {
    final int byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.subjectId.compareTo(b.subjectId);
  });

  if (limit != null && scored.length > limit) {
    return scored.sublist(0, limit);
  }
  return scored;
}

/// Turns SQLite's bm25() output into descending-is-better candidates.
///
/// FTS5 returns bm25 as a *negative* number where more negative means a better
/// match, which is the opposite of every other score in this file. Normalising
/// at the boundary keeps that quirk from leaking into the ranker.
List<ScoredCandidate> fromBm25(Map<int, double> rawBm25) {
  final List<ScoredCandidate> out = <ScoredCandidate>[
    for (final MapEntry<int, double> e in rawBm25.entries)
      ScoredCandidate(subjectId: e.key, score: -e.value),
  ];
  out.sort((ScoredCandidate a, ScoredCandidate b) {
    final int byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.subjectId.compareTo(b.subjectId);
  });
  return out;
}

/// Maps a fused RRF score into roughly [0, 1] for the utility formula.
///
/// RRF scores are tiny (about 1/k) and depend on how many arms matched, so they
/// cannot be mixed directly with the other weighted signals. Dividing by the
/// best possible score — both arms ranking it first — puts them on a comparable
/// footing.
double normalizeFusedScore(double fusedScore, {double k = 60}) {
  final double best = 2 / (k + 1);
  return best <= 0 ? 0 : math.min(1.0, fusedScore / best);
}
