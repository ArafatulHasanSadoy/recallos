import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/search/fusion.dart';
import 'package:recallos/core/search/utility_score.dart';

void main() {
  group('fromBm25', () {
    test('flips SQLite sign convention so higher is better', () {
      // FTS5 returns bm25 negative, more negative = better match. Every other
      // score in the system is the opposite way round.
      final List<ScoredCandidate> ranked = fromBm25(<int, double>{
        1: -0.5,
        2: -9.1,
        3: -3.2,
      });
      expect(ranked.map((ScoredCandidate c) => c.subjectId), <int>[2, 3, 1]);
      expect(ranked.first.score, 9.1);
    });

    test('handles an empty result', () {
      expect(fromBm25(const <int, double>{}), isEmpty);
    });
  });

  group('rankByCosine', () {
    test('orders by similarity', () {
      final List<ScoredCandidate> ranked = rankByCosine(
        queryVector: <double>[1, 0, 0],
        candidates: <int, List<double>>{
          1: <double>[0, 1, 0],
          2: <double>[1, 0, 0],
          3: <double>[0.7071, 0.7071, 0],
        },
      );
      expect(ranked.map((ScoredCandidate c) => c.subjectId), <int>[2, 3, 1]);
      expect(ranked.first.score, closeTo(1.0, 1e-6));
    });

    test('drops candidates below the floor', () {
      final List<ScoredCandidate> ranked = rankByCosine(
        queryVector: <double>[1, 0],
        candidates: <int, List<double>>{
          1: <double>[1, 0],
          2: <double>[-1, 0],
        },
        minScore: 0.1,
      );
      expect(ranked, hasLength(1));
      expect(ranked.single.subjectId, 1);
    });

    test('skips vectors of the wrong dimension rather than throwing', () {
      // Guards the case where the embedding model changed and old rows remain.
      final List<ScoredCandidate> ranked = rankByCosine(
        queryVector: <double>[1, 0, 0],
        candidates: <int, List<double>>{
          1: <double>[1, 0],
          2: <double>[1, 0, 0],
        },
      );
      expect(ranked.map((ScoredCandidate c) => c.subjectId), <int>[2]);
    });

    test('ties break deterministically', () {
      final List<ScoredCandidate> ranked = rankByCosine(
        queryVector: <double>[1, 0],
        candidates: <int, List<double>>{
          7: <double>[1, 0],
          3: <double>[1, 0],
          5: <double>[1, 0],
        },
      );
      expect(ranked.map((ScoredCandidate c) => c.subjectId), <int>[3, 5, 7]);
    });
  });

  group('reciprocalRankFusion', () {
    test('ranks a document found by both arms above one found by either', () {
      final List<FusedResult> fused = reciprocalRankFusion(
        lexical: const <ScoredCandidate>[
          ScoredCandidate(subjectId: 1, score: 9),
          ScoredCandidate(subjectId: 2, score: 5),
        ],
        vector: const <ScoredCandidate>[
          ScoredCandidate(subjectId: 1, score: 0.8),
          ScoredCandidate(subjectId: 3, score: 0.7),
        ],
      );

      expect(fused.first.subjectId, 1);
      expect(fused.first.foundByBoth, isTrue);
      expect(fused.map((FusedResult f) => f.subjectId), containsAll(<int>[1, 2, 3]));
    });

    test('surfaces a semantic-only match the keyword arm missed', () {
      // The case that justifies shipping the embedding at all: the card shares
      // no wording with the query, so lexical search alone would never find it.
      final List<FusedResult> fused = reciprocalRankFusion(
        lexical: const <ScoredCandidate>[
          ScoredCandidate(subjectId: 1, score: 2),
        ],
        vector: const <ScoredCandidate>[
          ScoredCandidate(subjectId: 99, score: 0.62),
        ],
      );

      final FusedResult semantic =
          fused.firstWhere((FusedResult f) => f.subjectId == 99);
      expect(semantic.semanticOnly, isTrue);
      expect(semantic.lexicalRank, isNull);
      expect(semantic.vectorRank, 1);
    });

    test('is unaffected by the scales of the two arms', () {
      // BM25 is unbounded, cosine sits in [-1, 1]. Fusing ranks rather than
      // scores is what makes them mixable without per-query calibration.
      List<FusedResult> run(double bm25Magnitude) => reciprocalRankFusion(
            lexical: <ScoredCandidate>[
              ScoredCandidate(subjectId: 1, score: bm25Magnitude),
              ScoredCandidate(subjectId: 2, score: bm25Magnitude / 2),
            ],
            vector: const <ScoredCandidate>[
              ScoredCandidate(subjectId: 2, score: 0.9),
            ],
          );

      expect(
        run(5).map((FusedResult f) => f.subjectId),
        run(50000).map((FusedResult f) => f.subjectId),
      );
    });

    test('works when one arm returns nothing', () {
      // Exactly what happens on a query with no lexical overlap, and what would
      // happen if the embedding assets ever failed to load.
      final List<FusedResult> vectorOnly = reciprocalRankFusion(
        lexical: const <ScoredCandidate>[],
        vector: const <ScoredCandidate>[ScoredCandidate(subjectId: 4, score: 0.5)],
      );
      expect(vectorOnly.single.subjectId, 4);

      final List<FusedResult> lexicalOnly = reciprocalRankFusion(
        lexical: const <ScoredCandidate>[ScoredCandidate(subjectId: 7, score: 3)],
        vector: const <ScoredCandidate>[],
      );
      expect(lexicalOnly.single.subjectId, 7);

      expect(
        reciprocalRankFusion(
          lexical: const <ScoredCandidate>[],
          vector: const <ScoredCandidate>[],
        ),
        isEmpty,
      );
    });

    test('respects the limit', () {
      final List<FusedResult> fused = reciprocalRankFusion(
        lexical: <ScoredCandidate>[
          for (int i = 1; i <= 20; i++)
            ScoredCandidate(subjectId: i, score: 20.0 - i),
        ],
        vector: const <ScoredCandidate>[],
        limit: 5,
      );
      expect(fused, hasLength(5));
      expect(fused.first.subjectId, 1);
    });

    test('normalises a both-arms-first result to 1.0', () {
      final List<FusedResult> fused = reciprocalRankFusion(
        lexical: const <ScoredCandidate>[ScoredCandidate(subjectId: 1, score: 9)],
        vector: const <ScoredCandidate>[ScoredCandidate(subjectId: 1, score: 0.9)],
      );
      expect(normalizeFusedScore(fused.single.fusedScore), closeTo(1.0, 1e-9));
    });
  });

  group('computeUtility', () {
    test('a perfect match on every signal scores 1.0', () {
      final UtilityScore score = computeUtility(
        signals: const RankingSignals(
          semantic: 1,
          noteRelevance: 1,
          categoryMatch: 1,
          trust: 1,
          location: 1,
          previousUse: 1,
          verified: 1,
          freshness: 1,
        ),
      );
      expect(score.value, closeTo(1.0, 1e-9));
    });

    test('default weights sum to 1.0', () {
      // Otherwise scores are not comparable across queries and the 0..1 range
      // stops meaning anything.
      expect(const RankingWeightSet().positiveSum, closeTo(1.0, 1e-9));
    });

    test('semantic relevance dominates', () {
      final UtilityScore strong = computeUtility(
        signals: const RankingSignals(semantic: 1),
      );
      final UtilityScore weak = computeUtility(
        signals: const RankingSignals(semantic: 0, categoryMatch: 1),
      );
      expect(strong.value, greaterThan(weak.value));
    });

    test('the note outweighs the category, as designed', () {
      // The user's own recorded experience should count for more than a label
      // the system inferred. That is the whole product thesis in one assertion.
      final UtilityScore note =
          computeUtility(signals: const RankingSignals(semantic: 0, noteRelevance: 1));
      final UtilityScore category =
          computeUtility(signals: const RankingSignals(semantic: 0, categoryMatch: 1));
      expect(note.value, greaterThan(category.value));
    });

    test('expiry is a hard penalty, not a nudge', () {
      final UtilityScore live =
          computeUtility(signals: const RankingSignals(semantic: 1));
      final UtilityScore expired = computeUtility(
        signals: const RankingSignals(semantic: 1, isExpired: true),
      );
      expect(expired.value, lessThan(live.value - 0.4));
      expect(expired.penalties.containsKey('expired'), isTrue);
    });

    test('never leaves the 0..1 range', () {
      final UtilityScore floored = computeUtility(
        signals: const RankingSignals(
          semantic: 0,
          trust: 0,
          freshness: 0,
          isExpired: true,
          isOutdated: true,
        ),
      );
      expect(floored.value, 0.0);

      final UtilityScore capped = computeUtility(
        signals: const RankingSignals(semantic: 5, noteRelevance: 5),
      );
      expect(capped.value, lessThanOrEqualTo(1.0));
    });

    test('explains itself from the arithmetic that ranked it', () {
      final UtilityScore score = computeUtility(
        signals: const RankingSignals(
          semantic: 0.9,
          noteRelevance: 0.8,
          categoryMatch: 0.1,
          trust: 0.5,
        ),
      );
      final List<String> reasons = score.topReasons();
      expect(reasons.first, 'semantic');
      expect(reasons, contains('note_relevance'));
      expect(reasons, isNot(contains('location')));
    });

    test('weights load from the database, falling back per key', () {
      final RankingWeightSet tuned = RankingWeightSet.fromMap(<String, double>{
        'semantic': 0.5,
      });
      expect(tuned.semantic, 0.5);
      expect(tuned.noteRelevance, const RankingWeightSet().noteRelevance);
    });
  });

  group('freshnessFromAge', () {
    test('is 1.0 for something just saved and halves at the half-life', () {
      expect(freshnessFromAge(Duration.zero), closeTo(1.0, 1e-9));
      expect(freshnessFromAge(const Duration(days: 730)), closeTo(0.5, 1e-6));
      expect(freshnessFromAge(const Duration(days: 1460)), closeTo(0.25, 1e-6));
    });

    test('decays without ever reaching zero', () {
      final double ancient = freshnessFromAge(const Duration(days: 3650));
      expect(ancient, greaterThan(0));
      expect(ancient, lessThan(0.1));
    });
  });

  group('trustFromFeedback', () {
    test('starts neutral with no evidence', () {
      expect(trustFromFeedback(useful: 0, notRelevant: 0), 0.5);
    });

    test('moves with evidence but is damped against a single tap', () {
      final double one = trustFromFeedback(useful: 1, notRelevant: 0);
      expect(one, greaterThan(0.5));
      expect(one, lessThan(0.8), reason: 'one tap must not saturate trust');

      expect(
        trustFromFeedback(useful: 20, notRelevant: 0),
        greaterThan(one),
      );
      expect(trustFromFeedback(useful: 0, notRelevant: 5), lessThan(0.3));
    });
  });
}
