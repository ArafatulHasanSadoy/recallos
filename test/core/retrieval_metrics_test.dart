import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/search/retrieval_metrics.dart';

/// Every value here was worked out by hand first, so the numbers the
/// report quotes rest on arithmetic anyone can check.
void main() {
  group('precisionAt', () {
    test('the share of the top k that is relevant', () {
      expect(
        precisionAt(<int>[1, 2, 3], <int>{2, 3}, 3),
        closeTo(2 / 3, 1e-12),
      );
      expect(precisionAt(<int>[1, 2, 3], <int>{2, 3}, 1), 0);
    });

    test('returning fewer results does not score higher', () {
      expect(precisionAt(<int>[2, 3], <int>{2, 3}, 5), closeTo(0.4, 1e-12));
    });
  });

  group('reciprocalRank', () {
    test('one over the first relevant rank', () {
      expect(reciprocalRank(<int>[5, 2, 1], <int>{1}), closeTo(1 / 3, 1e-12));
      expect(reciprocalRank(<int>[1, 2], <int>{1, 2}), 1);
    });

    test('nothing relevant found is 0', () {
      expect(reciprocalRank(<int>[5, 6], <int>{1}), 0);
    });
  });

  group('ndcgAt', () {
    final double log2of3 = math.log(3) / math.ln2;

    test('graded relevance, discounted by rank', () {
      // DCG = 0/1 + 1/log2(3) + 3/log2(4); ideal = 3/1 + 1/log2(3).
      final double dcg = 0 + 1 / log2of3 + 3 / 2;
      final double ideal = 3 + 1 / log2of3;
      expect(
        ndcgAt(<int>[3, 2, 1], <int, int>{1: 2, 2: 1, 3: 0}, 3),
        closeTo(dcg / ideal, 1e-12),
      );
    });

    test('the ideal order scores 1, no relevant ids score 0', () {
      expect(
        ndcgAt(<int>[1, 2, 3], <int, int>{1: 2, 2: 1}, 3),
        closeTo(1, 1e-12),
      );
      expect(ndcgAt(<int>[1, 2], <int, int>{}, 3), 0);
    });
  });

  test('mean', () {
    expect(mean(<double>[]), 0);
    expect(mean(<double>[1, 0, 0.5]), closeTo(0.5, 1e-12));
  });
}
