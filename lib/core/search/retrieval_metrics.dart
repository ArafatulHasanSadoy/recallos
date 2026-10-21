/// Retrieval quality, for the evaluation (PLAN §6): keyword against meaning
/// against both, on labelled queries.
///
/// Pure functions over ranked ids, so the numbers in the report come from
/// code that is tested against values worked out by hand — never from a
/// spreadsheet nobody can re-run.
library;

import 'dart:math' as math;

/// Which arms a search runs. The switch the evaluation compares.
enum SearchMode {
  /// FTS5 / BM25 only — what "keyword search" means in the report.
  lexical,

  /// The embedding only.
  semantic,

  /// Both, fused — what the app ships.
  hybrid,
}

/// The share of the top [k] that is relevant. Fewer than [k] results count
/// as misses, not as a smaller denominator: returning less is not a way to
/// score higher.
double precisionAt(List<int> ranked, Set<int> relevant, int k) {
  if (k <= 0) return 0;
  final int hits = ranked.take(k).where(relevant.contains).length;
  return hits / k;
}

/// 1 / the rank of the first relevant result, or 0 when there is none.
double reciprocalRank(List<int> ranked, Set<int> relevant) {
  for (int i = 0; i < ranked.length; i++) {
    if (relevant.contains(ranked[i])) return 1 / (i + 1);
  }
  return 0;
}

/// Normalised discounted cumulative gain at [k], with graded relevance:
/// [gains] maps an id to how relevant it is (say 2 = the answer, 1 =
/// useful). Ids not in [gains] are worth 0. 1 is the ideal order.
double ndcgAt(List<int> ranked, Map<int, int> gains, int k) {
  double dcg(Iterable<int> g) {
    double sum = 0;
    int i = 0;
    for (final int gain in g) {
      sum += (math.pow(2, gain) - 1) / (math.log(i + 2) / math.ln2);
      i++;
    }
    return sum;
  }

  final double actual = dcg(ranked.take(k).map((int id) => gains[id] ?? 0));
  final List<int> ideal = gains.values.where((int g) => g > 0).toList()
    ..sort((int a, int b) => b.compareTo(a));
  final double best = dcg(ideal.take(k));
  return best == 0 ? 0 : actual / best;
}

/// The mean of [values], or 0 for none.
double mean(Iterable<double> values) {
  if (values.isEmpty) return 0;
  return values.fold<double>(0, (double a, double b) => a + b) / values.length;
}
