/// A labelled question set for PLAN §6: retrieval (P@3, MRR, NDCG@3 for each
/// search mode), Ask RecallOS (does an answer cite exactly the right papers,
/// does it decline when it should), and link suggestions (precision, recall,
/// false links).
///
/// Written by hand against a real wallet, and kept outside the repo — it
/// names real people. Papers are named by their title as the app shows it
/// ("CoolAir Services", "HP Laptop"), so labelling needs no database ids:
///
/// ```json
/// {
///   "questions": [
///     {"q": "AC repair", "relevant": {"CoolAir Services": 2, "TechFix": 1}},
///     {"q": "who prints t-shirts", "relevant": ["Pixel Print House"]},
///     {"q": "When does my laptop warranty expire?",
///      "cites": ["HP Laptop", "STAR TECH & ENGINEERING LTD"]},
///     {"q": "how much did I spend this week", "cannot": true}
///   ],
///   "links": [
///     {"warranty": "HP Laptop", "receipt": "STAR TECH & ENGINEERING LTD"}
///   ]
/// }
/// ```
///
/// `relevant` scores retrieval (a grade of 2 is very relevant, 1 relevant);
/// `cites` and `cannot` score Ask; `plus` (default true) says whether the
/// question is asked as a Plus user. Run on the phone from the bench
/// screen, over the wallet as it is.
library;

import 'dart:convert';

import '../search/retrieval_metrics.dart';

class EvalQuestion {
  const EvalQuestion({
    required this.text,
    this.relevant = const <String, int>{},
    this.cites,
    this.cannot = false,
    this.plus = true,
  });

  final String text;

  /// Retrieval: a paper's title → how relevant it is (1 or 2).
  final Map<String, int> relevant;

  /// Ask: the papers the answer must cite, no more and no less.
  final Set<String>? cites;

  /// Ask: the answer must say it cannot answer.
  final bool cannot;

  final bool plus;

  bool get scoresRetrieval => relevant.isNotEmpty;
  bool get scoresAsk => cites != null || cannot;
}

class EvalLink {
  const EvalLink({required this.warranty, required this.receipt});

  final String warranty;
  final String receipt;
}

class EvalSet {
  const EvalSet({required this.questions, this.links = const <EvalLink>[]});

  /// Reads the format above. Throws a [FormatException] that names what is
  /// wrong, because a labels file is written by hand.
  factory EvalSet.parse(String json) {
    final Object? root = jsonDecode(json);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('The file is not a JSON object.');
    }
    final List<EvalQuestion> questions = <EvalQuestion>[];
    for (final Object? q
        in root['questions'] as List<dynamic>? ?? <dynamic>[]) {
      if (q is! Map<String, dynamic> || q['q'] is! String) {
        throw FormatException('A question has no "q": $q');
      }
      final Object? rel = q['relevant'];
      final Object? cites = q['cites'];
      questions.add(
        EvalQuestion(
          text: q['q'] as String,
          relevant: switch (rel) {
            final Map<String, dynamic> m => <String, int>{
              for (final MapEntry<String, dynamic> e in m.entries)
                e.key: (e.value as num).toInt(),
            },
            final List<dynamic> l => <String, int>{
              for (final Object? name in l) '$name': 1,
            },
            _ => const <String, int>{},
          },
          cites: cites is List<dynamic>
              ? <String>{for (final Object? c in cites) '$c'}
              : null,
          cannot: q['cannot'] == true,
          plus: q['plus'] != false,
        ),
      );
    }
    return EvalSet(
      questions: questions,
      links: <EvalLink>[
        for (final Object? l in root['links'] as List<dynamic>? ?? <dynamic>[])
          if (l is Map<String, dynamic>)
            EvalLink(warranty: '${l['warranty']}', receipt: '${l['receipt']}'),
      ],
    );
  }

  final List<EvalQuestion> questions;
  final List<EvalLink> links;
}

/// One search mode's retrieval scores over the questions that have
/// `relevant` labels.
class RetrievalScore {
  final List<double> _p3 = <double>[];
  final List<double> _rr = <double>[];
  final List<double> _ndcg = <double>[];
  final List<int> _ms = <int>[];

  /// [ranked] is what the search returned, best first; [gains] the labelled
  /// relevance of each relevant paper's id.
  void add(List<int> ranked, Map<int, int> gains, int ms) {
    final Set<int> relevant = gains.keys.toSet();
    _p3.add(precisionAt(ranked, relevant, 3));
    _rr.add(reciprocalRank(ranked, relevant));
    _ndcg.add(ndcgAt(ranked, gains, 3));
    _ms.add(ms);
  }

  int get count => _p3.length;
  double get p3 => mean(_p3);
  double get mrr => mean(_rr);
  double get ndcg3 => mean(_ndcg);
  double get meanMs => mean(_ms.map((int m) => m.toDouble()));

  Map<String, Object> toJson() => <String, Object>{
    'questions': count,
    'p@3': p3,
    'mrr': mrr,
    'ndcg@3': ndcg3,
    'meanMs': meanMs,
  };
}

/// Ask RecallOS: answers that cite exactly the right papers, and questions
/// declined when they should be — and only then.
class AskScore {
  int sourcesRight = 0;
  int sourcesTotal = 0;
  int abstainedRight = 0;
  int abstainTotal = 0;

  /// Questions it should have answered, but declined.
  int declinedWrongly = 0;

  Map<String, Object> toJson() => <String, Object>{
    'sources': '$sourcesRight/$sourcesTotal',
    'abstentions': '$abstainedRight/$abstainTotal',
    'declinedWrongly': declinedWrongly,
  };
}

/// Link suggestions against the labelled true pairs.
class LinkScore {
  const LinkScore({
    required this.suggested,
    required this.right,
    required this.labelled,
  });

  final int suggested;
  final int right;
  final int labelled;

  double get precision => suggested == 0 ? 0 : right / suggested;
  double get recall => labelled == 0 ? 0 : right / labelled;

  /// Suggestions that pair a warranty with the wrong receipt.
  int get falseLinks => suggested - right;

  Map<String, Object> toJson() => <String, Object>{
    'suggested': suggested,
    'right': right,
    'labelled': labelled,
    'precision': precision,
    'recall': recall,
    'falseLinks': falseLinks,
  };
}
