import 'dart:convert';

import '../../../core/db/database.dart';
import '../../../core/eval/question_set.dart';
import '../../../core/linking/purchase_link_rules.dart';
import '../../../core/search/retrieval_metrics.dart';
import '../../search/data/search_repository.dart';
import '../../warranty/data/purchase_links.dart';
import '../data/card_repository.dart' show describeCard;

/// What a question set scored over one wallet.
class EvalReport {
  EvalReport({
    required this.retrieval,
    required this.ask,
    required this.links,
    required this.unresolved,
    required this.rows,
  });

  /// Per search mode.
  final Map<SearchMode, RetrievalScore> retrieval;
  final AskScore ask;
  final LinkScore? links;

  /// Titles in the labels that no card in the wallet is called. Their
  /// questions are skipped rather than scored against a wrong guess.
  final Set<String> unresolved;

  /// One line per question, for checking a score by hand.
  final List<Map<String, Object?>> rows;

  /// The table for the report.
  String format() {
    final StringBuffer b = StringBuffer(
      'Retrieval (P@3 · MRR · NDCG@3 · ms)\n',
    );
    for (final MapEntry<SearchMode, RetrievalScore> e in retrieval.entries) {
      final RetrievalScore s = e.value;
      b.writeln(
        '  ${e.key.name.padRight(8)} ${s.p3.toStringAsFixed(3)} · '
        '${s.mrr.toStringAsFixed(3)} · ${s.ndcg3.toStringAsFixed(3)} · '
        '${s.meanMs.round()}  (${s.count} questions)',
      );
    }
    b.writeln(
      'Ask: sources ${ask.sourcesRight}/${ask.sourcesTotal}, '
      'abstentions ${ask.abstainedRight}/${ask.abstainTotal}, '
      'declined wrongly ${ask.declinedWrongly}',
    );
    final LinkScore? l = links;
    if (l != null) {
      b.writeln(
        'Links: precision ${l.precision.toStringAsFixed(3)}, '
        'recall ${l.recall.toStringAsFixed(3)}, '
        '${l.falseLinks} false of ${l.suggested} suggested',
      );
    }
    if (unresolved.isNotEmpty) {
      b.writeln('Not in this wallet (skipped): ${unresolved.join(', ')}');
    }
    return b.toString();
  }

  String toJson() => const JsonEncoder.withIndent('  ').convert(
    <String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'retrieval': <String, Object>{
        for (final MapEntry<SearchMode, RetrievalScore> e in retrieval.entries)
          e.key.name: e.value.toJson(),
      },
      'ask': ask.toJson(),
      'links': links?.toJson(),
      'unresolved': unresolved.toList(),
      'questions': rows,
    },
  );
}

/// Plays a labelled question set against a wallet, through the same search,
/// Ask and link rules the app runs — PLAN §6's retrieval, Ask and link
/// scores, measured on real papers rather than invented ones.
///
/// It reads and never writes. Papers are found by the title every list
/// shows (`describeCard`), compared without case; a title two papers share
/// names both.
class EvalRunner {
  EvalRunner({required this.db, required this.search, required this.links});

  final AppDatabase db;
  final SearchRepository search;
  final PurchaseLinks links;

  Future<EvalReport> run(EvalSet set) async {
    final Map<String, Set<int>> byTitle = await _titles();
    final Set<String> unresolved = <String>{};
    Set<int>? idsOf(Iterable<String> names) {
      final Set<int> out = <int>{};
      bool missing = false;
      for (final String n in names) {
        final Set<int>? ids = byTitle[_key(n)];
        if (ids == null) {
          unresolved.add(n);
          missing = true;
        } else {
          out.addAll(ids);
        }
      }
      return missing ? null : out;
    }

    final Map<SearchMode, RetrievalScore> retrieval =
        <SearchMode, RetrievalScore>{
          for (final SearchMode m in SearchMode.values) m: RetrievalScore(),
        };
    final AskScore ask = AskScore();
    final List<Map<String, Object?>> rows = <Map<String, Object?>>[];

    for (final EvalQuestion q in set.questions) {
      final Map<String, Object?> row = <String, Object?>{'q': q.text};

      if (q.scoresRetrieval) {
        final Map<int, int> gains = <int, int>{};
        bool known = true;
        for (final MapEntry<String, int> e in q.relevant.entries) {
          final Set<int>? ids = idsOf(<String>[e.key]);
          if (ids == null) {
            known = false;
            continue;
          }
          for (final int id in ids) {
            gains[id] = e.value;
          }
        }
        if (known) {
          for (final SearchMode m in SearchMode.values) {
            final Stopwatch watch = Stopwatch()..start();
            final List<SearchHit> hits = await search.search(q.text, mode: m);
            watch.stop();
            final List<int> ranked = <int>[
              for (final SearchHit h in hits) h.card.id,
            ];
            retrieval[m]!.add(ranked, gains, watch.elapsedMilliseconds);
            row['${m.name}Top3'] = ranked.take(3).toList();
          }
        } else {
          row['skipped'] = 'a relevant paper is not in this wallet';
        }
      }

      if (q.scoresAsk) {
        final SearchAnswer a = await search.ask(q.text, plus: q.plus);
        row['plan'] = a.plan.runtimeType.toString();
        row['declined'] = a.declined;
        row['cited'] = a.citedCardIds.toList();
        if (q.cannot) {
          ask.abstainTotal++;
          if (a.declined) ask.abstainedRight++;
        } else {
          final Set<int>? want = idsOf(q.cites!);
          if (want == null) {
            row['skipped'] = 'a cited paper is not in this wallet';
          } else {
            ask.sourcesTotal++;
            if (a.declined) {
              ask.declinedWrongly++;
            } else if (a.citedCardIds.length == want.length &&
                a.citedCardIds.containsAll(want)) {
              ask.sourcesRight++;
            }
          }
        }
      }
      rows.add(row);
    }

    LinkScore? linkScore;
    if (set.links.isNotEmpty) {
      final Set<(int, int)> truth = <(int, int)>{};
      for (final EvalLink l in set.links) {
        final Set<int>? w = idsOf(<String>[l.warranty]);
        final Set<int>? r = idsOf(<String>[l.receipt]);
        if (w == null || r == null) continue;
        for (final int a in w) {
          for (final int b in r) {
            truth.add((a, b));
          }
        }
      }
      final Set<(int, int)> suggested = <(int, int)>{
        for (final LinkSuggestion s in await links.ruleSuggestions())
          (s.warrantyId, s.receiptId),
      };
      linkScore = LinkScore(
        suggested: suggested.length,
        right: suggested.intersection(truth).length,
        labelled: truth.length,
      );
    }

    return EvalReport(
      retrieval: <SearchMode, RetrievalScore>{
        for (final MapEntry<SearchMode, RetrievalScore> e in retrieval.entries)
          if (e.value.count > 0) e.key: e.value,
      },
      ask: ask,
      links: linkScore,
      unresolved: unresolved,
      rows: rows,
    );
  }

  /// Every live paper's title, as the lists show it.
  Future<Map<String, Set<int>>> _titles() async {
    final Map<String, Set<int>> out = <String, Set<int>>{};
    final List<CardRow> live = await (db.select(
      db.cards,
    )..where(($CardsTable c) => c.deletedAt.isNull())).get();
    for (final CardRow c in live) {
      final List<CardField> fields = await (db.select(
        db.cardFields,
      )..where(($CardFieldsTable f) => f.cardId.equals(c.id))).get();
      final String? title = describeCard(c, fields).title;
      if (title == null) continue;
      out.putIfAbsent(_key(title), () => <int>{}).add(c.id);
    }
    return out;
  }

  static String _key(String title) =>
      title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
