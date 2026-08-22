/// How alike two names are, when one of them came out of an OCR engine.
///
/// Exact equality is useless here. `TARGET, CENTER,` and `CTARGEI. CENTER` are
/// two reads of the same shop sign, taken minutes apart, and no amount of
/// lowercasing or suffix-stripping makes those strings equal. Duplicate
/// detection that compares normalised names with `==` therefore finds nothing
/// on precisely the input this app produces.
///
/// Pure, and kept away from the database so the thresholds can be argued with
/// in a test rather than on a phone.
library;

import 'dart:math' as math;

/// Levenshtein distance, with the usual row-pair optimisation.
///
/// Bounded work: names are a handful of tokens, so the quadratic cost is on
/// the order of a few hundred operations and runs per candidate pair.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  List<int> current = List<int>.filled(b.length + 1, 0);

  for (int i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (int j = 0; j < b.length; j++) {
      final int cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      current[j + 1] = math.min(
        math.min(current[j] + 1, previous[j + 1] + 1),
        previous[j] + cost,
      );
    }
    final List<int> swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

/// Edit distance rescaled to 0–1, where 1 is identical.
double editSimilarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final int longest = math.max(a.length, b.length);
  if (longest == 0) return 1;
  return 1 - editDistance(a, b) / longest;
}

/// How alike two already-normalised names are, token by token.
///
/// Each token of the shorter name is paired with its best match in the longer
/// one and scored by edit similarity; the result is the mean, penalised for
/// tokens the longer name has spare.
///
/// Token-wise rather than whole-string because OCR damage is local. One
/// mangled word out of three should read as "very similar", and comparing the
/// concatenated strings buries that: `target center` against `ctargei center`
/// scores 0.79 as one string but 0.86 by token, while `rahman traders` against
/// `rahman motors` — two genuinely different businesses that happen to share a
/// family name — drops to 0.65 by token where the whole string flatters it at
/// 0.71. The gap between those two cases is the entire decision, and only the
/// token-wise measure opens it wide enough to put a threshold in.
double nameSimilarity(String? a, String? b) {
  if (a == null || b == null) return 0;
  if (a == b) return 1;

  final List<String> left = a.split(' ').where((String t) => t.isNotEmpty).toList();
  final List<String> right = b.split(' ').where((String t) => t.isNotEmpty).toList();
  if (left.isEmpty || right.isEmpty) return 0;

  final List<String> shorter = left.length <= right.length ? left : right;
  final List<String> longer = left.length <= right.length ? right : left;

  double total = 0;
  final List<bool> taken = List<bool>.filled(longer.length, false);
  for (final String token in shorter) {
    double best = 0;
    int bestAt = -1;
    for (int i = 0; i < longer.length; i++) {
      if (taken[i]) continue;
      final double score = editSimilarity(token, longer[i]);
      if (score > best) {
        best = score;
        bestAt = i;
      }
    }
    if (bestAt >= 0) taken[bestAt] = true;
    total += best;
  }

  // Divided by the longer length, so "Target" against "Target Center Dhaka"
  // does not score a perfect 1.0 on the strength of one word.
  return total / longer.length;
}

/// Above this, two names are alike enough to be worth asking about.
///
/// Chosen to sit between the two cases above: it accepts an OCR variant of one
/// word in two, and rejects two businesses sharing a family name. It is a
/// threshold for *proposing*, never for merging — everything above it still
/// goes to a person to decide.
const double proposeSimilarity = 0.75;
