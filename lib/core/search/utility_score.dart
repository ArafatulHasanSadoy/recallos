import 'dart:math' as math;

/// The signals feeding the utility score for one candidate.
///
/// Every field is already normalised to 0..1 by the caller. Keeping the maths
/// separate from where the numbers come from is what makes this testable
/// without a database.
class RankingSignals {
  const RankingSignals({
    required this.semantic,
    this.noteRelevance = 0,
    this.categoryMatch = 0,
    this.trust = 0.5,
    this.location = 0,
    this.previousUse = 0,
    this.verified = 0,
    this.freshness = 0.5,
    this.isExpired = false,
    this.isOutdated = false,
  });

  /// Fused lexical+vector relevance, normalised. The dominant term.
  final double semantic;

  /// How strongly the user's own note matched. Weighted separately from general
  /// relevance because the note is the thing no competitor has — it is the
  /// user's recorded experience, not the card's marketing copy.
  final double noteRelevance;

  final double categoryMatch;

  /// Private trust, learned from feedback. 0.5 means no signal either way.
  final double trust;

  final double location;

  /// Whether the user has actually transacted with this contact before.
  final double previousUse;

  final double verified;

  /// How recent the information is; decays with age.
  final double freshness;

  /// Hard negatives rather than weighted signals — an expired coupon is not
  /// slightly worse, it is wrong.
  final bool isExpired;
  final bool isOutdated;
}

/// Named weights, matching the `ranking_weights` table seeded in the database.
///
/// Weights live in the database rather than in code so they can be tuned
/// against the labelled query set and nudged per user by search feedback,
/// without shipping a build.
class RankingWeightSet {
  const RankingWeightSet({
    this.semantic = 0.38,
    this.noteRelevance = 0.18,
    this.categoryMatch = 0.12,
    this.trust = 0.10,
    this.location = 0.08,
    this.previousUse = 0.06,
    this.verified = 0.05,
    this.freshness = 0.03,
    this.penaltyExpired = 0.50,
    this.penaltyOutdated = 0.20,
  });

  /// Builds from the rows stored in `ranking_weights`, falling back to the
  /// default for any key the table does not carry.
  factory RankingWeightSet.fromMap(Map<String, double> weights) {
    const RankingWeightSet d = RankingWeightSet();
    return RankingWeightSet(
      semantic: weights['semantic'] ?? d.semantic,
      noteRelevance: weights['note_relevance'] ?? d.noteRelevance,
      categoryMatch: weights['category_match'] ?? d.categoryMatch,
      trust: weights['trust'] ?? d.trust,
      location: weights['location'] ?? d.location,
      previousUse: weights['previous_use'] ?? d.previousUse,
      verified: weights['verified'] ?? d.verified,
      freshness: weights['freshness'] ?? d.freshness,
      penaltyExpired: weights['penalty_expired'] ?? d.penaltyExpired,
      penaltyOutdated: weights['penalty_outdated'] ?? d.penaltyOutdated,
    );
  }

  final double semantic;
  final double noteRelevance;
  final double categoryMatch;
  final double trust;
  final double location;
  final double previousUse;
  final double verified;
  final double freshness;
  final double penaltyExpired;
  final double penaltyOutdated;

  /// The positive weights, which should sum to 1.0 so a perfect match scores
  /// 1.0 and scores stay comparable across queries.
  double get positiveSum =>
      semantic +
      noteRelevance +
      categoryMatch +
      trust +
      location +
      previousUse +
      verified +
      freshness;
}

/// A scored candidate, with the breakdown that produced it.
class UtilityScore {
  const UtilityScore({
    required this.value,
    required this.contributions,
    required this.penalties,
  });

  /// Final score, clamped to 0..1.
  final double value;

  /// Per-signal contribution, largest first. This is what the "why matched"
  /// chip reads — the explanation is derived from the arithmetic that actually
  /// ranked the result, not generated after the fact by a model.
  final Map<String, double> contributions;

  final Map<String, double> penalties;

  /// The signals that did the most work, for explaining the match.
  List<String> topReasons({int count = 3, double threshold = 0.02}) {
    final List<MapEntry<String, double>> sorted =
        contributions.entries
            .where((MapEntry<String, double> e) => e.value >= threshold)
            .toList()
          ..sort(
            (MapEntry<String, double> a, MapEntry<String, double> b) =>
                b.value.compareTo(a.value),
          );

    return sorted
        .take(count)
        .map((MapEntry<String, double> e) => e.key)
        .toList();
  }

  @override
  String toString() =>
      'UtilityScore(${value.toStringAsFixed(4)}, '
      'top=${topReasons().join(", ")})';
}

/// Scores one candidate.
///
/// A pure function so it can be unit-tested and tuned in isolation, and so the
/// same code produces both the ranking and its explanation. This carries the
/// CO2 "algorithms" section.
UtilityScore computeUtility({
  required RankingSignals signals,
  RankingWeightSet weights = const RankingWeightSet(),
}) {
  final Map<String, double> contributions = <String, double>{
    'semantic': weights.semantic * _clamp01(signals.semantic),
    'note_relevance': weights.noteRelevance * _clamp01(signals.noteRelevance),
    'category_match': weights.categoryMatch * _clamp01(signals.categoryMatch),
    'trust': weights.trust * _clamp01(signals.trust),
    'location': weights.location * _clamp01(signals.location),
    'previous_use': weights.previousUse * _clamp01(signals.previousUse),
    'verified': weights.verified * _clamp01(signals.verified),
    'freshness': weights.freshness * _clamp01(signals.freshness),
  };

  final Map<String, double> penalties = <String, double>{
    if (signals.isExpired) 'expired': weights.penaltyExpired,
    if (signals.isOutdated) 'outdated': weights.penaltyOutdated,
  };

  final double positive = contributions.values.fold<double>(
    0,
    (double a, double b) => a + b,
  );
  final double negative = penalties.values.fold<double>(
    0,
    (double a, double b) => a + b,
  );

  return UtilityScore(
    value: _clamp01(positive - negative),
    contributions: contributions,
    penalties: penalties,
  );
}

double _clamp01(double v) => v.isNaN ? 0 : math.min(1.0, math.max(0.0, v));

/// Freshness from age, decaying on a half-life.
///
/// Two years is deliberate: a card that old is plausibly stale — people change
/// jobs and businesses move — but it is still evidence, so the decay is gentle
/// rather than a cliff.
double freshnessFromAge(
  Duration age, {
  Duration halfLife = const Duration(days: 730),
}) {
  if (age.isNegative) return 1;
  final double halfLives = age.inSeconds / halfLife.inSeconds;
  return math.pow(0.5, halfLives).toDouble();
}

/// How specific a query word is, given how many cards contain it.
///
/// BM25's inverse document frequency: a word on every card says nothing
/// about which card is meant, a word on one card says a lot. Never negative,
/// so a word every card carries still counts for a little rather than
/// against.
double inverseDocumentFrequency({
  required int cards,
  required int cardsWithTerm,
}) {
  final int n = math.max(cards, cardsWithTerm);
  return math.log(1 + (n - cardsWithTerm + 0.5) / (cardsWithTerm + 0.5));
}

/// The share of a query's specificity that the user's notes account for.
///
/// [termWeights] gives each query word its weight — its
/// [inverseDocumentFrequency] — and [matchedInNotes] the words found in the
/// notes. A note that matches the rare word of "AC repair" covers more of
/// the question than one that matches the common word, where a yes/no "the
/// note matched" counted them the same.
double noteCoverage({
  required Map<String, double> termWeights,
  required Iterable<String> matchedInNotes,
}) {
  final double total = termWeights.values.fold<double>(
    0,
    (double a, double b) => a + b,
  );
  if (total <= 0) return 0;
  final double matched = matchedInNotes
      .toSet()
      .map((String t) => termWeights[t] ?? 0)
      .fold<double>(0, (double a, double b) => a + b);
  return _clamp01(matched / total);
}

/// Cosine similarity between the query and a note, rescaled to 0..1.
///
/// Below [floor] two texts are unrelated — the same floor the vector arm
/// cuts at — so that maps to 0 rather than to a quarter of a match.
double noteSimilarity(double cosine, {double floor = 0.25}) =>
    _clamp01((cosine - floor) / (1 - floor));

/// How strongly the user's own notes answer the query.
///
/// Wording and meaning both count, because each catches what the other
/// misses: "AC servicing" shares only "AC" with "AC repair", while "laptop
/// repair" shares "repair" — on words alone they tie, and on meaning the
/// first is plainly the answer. Without a note vector (the embedder failed
/// to load) wording carries it alone.
double noteRelevance({required double coverage, double? similarity}) =>
    similarity == null
    ? _clamp01(coverage)
    : _clamp01((coverage + similarity) / 2);

/// Trust from the user's own feedback on past results.
///
/// Starts at 0.5 — no signal — and moves with evidence, damped so that one
/// stray tap cannot bury a contact. Laplace-smoothed, so a single "useful" does
/// not jump straight to 1.0.
double trustFromFeedback({required int useful, required int notRelevant}) {
  final int total = useful + notRelevant;
  if (total == 0) return 0.5;
  return (useful + 1) / (total + 2);
}
