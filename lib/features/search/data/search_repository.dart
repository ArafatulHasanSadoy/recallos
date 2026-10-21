import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/intelligence/embedding/static_embedder.dart';
import '../../../core/intelligence/embedding/wordpiece.dart';
import '../../../core/search/fts_query.dart';
import '../../../core/search/fusion.dart';
import '../../../core/search/index_subjects.dart';
import '../../../core/search/match_evidence.dart';
import '../../../core/search/query_plan.dart';
import '../../../core/search/retrieval_metrics.dart';
import '../../../core/search/utility_score.dart';
import '../../../core/spending/spending_totals.dart' show ReceiptFacts;
import '../../ask/data/purchase_answers.dart';
import '../../capture/data/card_repository.dart';
import '../../cards/data/interaction_log.dart';
import '../../contacts/data/identity_repository.dart';
import '../../warranty/data/purchase_links.dart'
    show kReceiptTypes, kWarrantyTypes;

/// The 7.3 MB static embedding table, loaded once.
///
/// Costs about 3 ms — the matrix is mapped as a typed-data view rather than
/// copied — but it does read the asset off disk, so it is held for the life of
/// the app rather than rebuilt per search.
final embedderProvider = FutureProvider<StaticEmbedder>((Ref ref) async {
  final String vocab = await rootBundle.loadString(
    'assets/embedding/vocab.txt',
  );
  final String normalizer = await rootBundle.loadString(
    'assets/embedding/normalizer.json',
  );
  final ByteData matrix = await rootBundle.load('assets/embedding/matrix.bin');

  return StaticEmbedder.fromBytes(
    matrixBytes: matrix.buffer.asUint8List(
      matrix.offsetInBytes,
      matrix.lengthInBytes,
    ),
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
    this.evidence,
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

  /// The words that matched, where they were found.
  final MatchEvidence? evidence;
}

/// One person or business a lookup found, and the field it asked for.
///
/// Every value comes from a stored field, shown with where it came from, on
/// the card it came from — so the answer is checkable, not just asserted.
class LookupAnswer {
  const LookupAnswer({
    required this.card,
    required this.values,
    this.person,
    this.company,
    this.viaSearch = false,
  });

  final CardSummary card;

  /// Every value of the asked-for field on the card — all its numbers, say.
  /// Empty when the card has none, which the answer says rather than hides.
  final List<CardField> values;

  final String? person;
  final String? company;

  /// Found by what the user needed ("AC repair number"), not by a name.
  final bool viaSearch;

  /// Whose card it is, the way a person would say it.
  String get who => person ?? company ?? card.title ?? 'This card';
}

/// One person in a filtered list — "met at CSE fest", "waiting on a next
/// step" — with the facts that put them there.
class PersonMatch {
  const PersonMatch({
    required this.card,
    this.metOn,
    this.place,
    this.nextStep,
    this.nextDue,
  });

  final CardSummary card;

  /// The day they were met, as recorded; null when only the place is known.
  final DateTime? metOn;
  final String? place;

  /// The soonest open next step, if any.
  final String? nextStep;
  final DateTime? nextDue;
}

/// Everything the home screen shows for one query.
class SearchAnswer {
  const SearchAnswer({
    required this.plan,
    this.lookups = const <LookupAnswer>[],
    this.hits = const <SearchHit>[],
    this.people = const <PersonMatch>[],
    this.plusNeeded = false,
    this.warranties = const <WarrantyAnswer>[],
    this.expiring = const <ExpiringAnswer>[],
    this.spending,
    this.cannot,
  });

  static const SearchAnswer empty = SearchAnswer(plan: SearchPlan(''));

  final QueryPlan plan;

  /// Direct answers, for a lookup ("Rahim's number"). Never trimmed to one:
  /// two Rahims are two people, and picking one would be a guess.
  final List<LookupAnswer> lookups;

  /// Ranked cards — for a lookup, the other cards worth a look.
  final List<SearchHit> hits;

  /// The exact list a people filter asked for (RecallOS Plus).
  final List<PersonMatch> people;

  /// The query was a people filter, a date question or a total that comes
  /// with Plus, and Plus is not on: [hits] are the words searched instead,
  /// and the screen says what Plus would have done.
  final bool plusNeeded;

  /// The warranties a warranty question named (B5).
  final List<WarrantyAnswer> warranties;

  /// What ends in the window asked about (B5, Plus).
  final List<ExpiringAnswer> expiring;

  /// A total of saved receipts (B5).
  final SpendingAnswer? spending;

  /// The question was understood but cannot be answered, said plainly:
  /// "No saved warranty matches “laptop”."
  final String? cannot;

  /// Every card the answer names as its source — a lookup's card, the
  /// warranty and its receipt, what ends, a total's receipts. Not the ranked
  /// [hits]: those are offered, not cited. For PLAN §6's grounded-answer
  /// score.
  Set<int> get citedCardIds => <int>{
    for (final LookupAnswer l in lookups) l.card.id,
    for (final WarrantyAnswer w in warranties) ...<int>[
      w.card.id,
      ?w.receipt?.other.id,
    ],
    for (final ExpiringAnswer e in expiring) e.card.id,
    ...?spending?.summary?.counted.map((ReceiptFacts r) => r.cardId),
  };

  /// Whether it said it cannot answer, here or in a total.
  bool get declined => cannot != null || spending?.cannot != null;

  /// True when there is nothing at all to show. A people filter that found
  /// nobody is not empty: "nobody met there" is an answer, and so is
  /// "nothing ends in the next 90 days".
  bool get isEmpty =>
      lookups.isEmpty &&
      hits.isEmpty &&
      people.isEmpty &&
      warranties.isEmpty &&
      spending == null &&
      cannot == null &&
      !plusNeeded &&
      plan is! PeopleFilterPlan &&
      plan is! ExpiringPlan;
}

/// Indexing and retrieval.
///
/// Both retrieval arms run on every device — FTS5 needs no model, and the
/// vector arm is a lookup table — so there is no tier where search silently
/// degrades to something worse.
class SearchRepository {
  SearchRepository(this._db, this._loadEmbedder, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final Future<StaticEmbedder> Function() _loadEmbedder;
  final DateTime Function() _now;

  /// B5's purchase questions, over B3's links and B4's totals.
  late final PurchaseAnswers _purchases = PurchaseAnswers(_db, now: _now);

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
    final CardRow? card = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();
    if (card == null) return;

    final List<CardField> fields = await (_db.select(
      _db.cardFields,
    )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();
    final List<Note> notes =
        await (_db.select(_db.notes)..where(
              ($NotesTable n) =>
                  n.subjectType.equals('card') & n.subjectId.equals(cardId),
            ))
            .get();

    // Field values as well as the raw OCR dump: extraction corrects things the
    // raw text got wrong, most visibly phone numbers with a restored digit.
    //
    // Both sides' dumps. A back often carries the half of a card that never
    // becomes a field — an office address, a list of services, a branch — and
    // that is exactly the text a need-shaped query goes looking for.
    final String cardText = <String>[
      card.rawOcrText ?? '',
      card.backOcrText ?? '',
      for (final CardField f in fields) f.value,
    ].where((String s) => s.trim().isNotEmpty).join('\n');

    final String noteText = notes
        .map(
          (Note n) =>
              <String?>[n.body, n.transcript].whereType<String>().join(' '),
        )
        .where((String s) => s.trim().isNotEmpty)
        .join('\n');

    // Where they were met — an event's name from Event Mode, or a place the
    // user typed. "CSE fest" should find everyone met there.
    final String metText = (await _placesOf(cardId)).join('\n');

    await _deleteIndexRows(cardId);

    await _db.customStatement(
      'INSERT INTO search_index(subject_type, subject_id, card_text, '
      'note_text, canonical_en, tags, met_text) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[kCardSubject, cardId, cardText, noteText, '', '', metText],
    );

    final StaticEmbedder? embedder = await _embedderOrNull();
    if (embedder == null) return;

    final String embedText = <String>[
      cardText,
      noteText,
      metText,
    ].where((String s) => s.trim().isNotEmpty).join('\n');
    if (embedText.trim().isEmpty) return;

    // The note on its own as well (see kCardNoteSubject): in the card's
    // vector it is a few words beside the whole OCR dump. Written first, so
    // the card vector — the write `watchChanges` waits for — still lands
    // last.
    if (noteText.trim().isNotEmpty) {
      await _insertVector(embedder, kCardNoteSubject, cardId, noteText);
    }
    await _insertVector(embedder, kCardSubject, cardId, embedText);
  }

  Future<void> _insertVector(
    StaticEmbedder embedder,
    String subjectType,
    int cardId,
    String text,
  ) async {
    final Float32List vector = embedder.embed(text);
    if (!StaticEmbedder.isUsable(vector)) return;

    await _db
        .into(_db.embeddings)
        .insert(
          EmbeddingsCompanion.insert(
            subjectType: subjectType,
            subjectId: cardId,
            vector: StaticEmbedder.toBlob(vector),
            dim: vector.length,
            model: StaticEmbedder.modelId,
          ),
        );
  }

  /// What the index holds, as a number. Bump it when [reindexCard] starts
  /// writing something new, and [backfill] rebuilds every card's rows once,
  /// on the next launch — otherwise the new kind of row exists only for
  /// cards saved or edited afterwards.
  ///
  /// 2 — notes embedded on their own (`card_note`), 7 Oct 2026.
  /// 3 — where you met (`met_text`), 7 Oct 2026.
  static const int indexVersion = 3;

  /// The places the card's person was met at, as the user or Event Mode
  /// recorded them.
  Future<List<String>> _placesOf(int cardId) async {
    final List<Encounter> met =
        await (_db.select(_db.encounters)..where(
              ($EncountersTable e) =>
                  e.cardId.equals(cardId) &
                  e.deletedAt.isNull() &
                  e.place.isNotNull(),
            ))
            .get();
    return <String>{
      for (final Encounter e in met)
        if (e.place!.trim().isNotEmpty) e.place!.trim(),
    }.toList();
  }

  static const String _indexVersionKey = 'search_index_version';

  /// Indexes anything that has no index rows yet.
  ///
  /// Cards saved before search existed have no entries, and without this they
  /// would stay invisible forever — the failure looks exactly like "search is
  /// broken" from the outside.
  Future<void> backfill() async {
    final Setting? stored =
        await (_db.select(_db.settings)
              ..where(($SettingsTable t) => t.key.equals(_indexVersionKey)))
            .getSingleOrNull();
    if (stored?.value != indexVersion.toString()) {
      // Every card that still exists, the soft-deleted ones included: they
      // keep their rows for thirty days, and one restored from Recently
      // deleted has to be findable by the current rules too.
      final List<QueryRow> all = await _db
          .customSelect('SELECT id FROM cards ORDER BY id')
          .get();
      for (final QueryRow row in all) {
        await reindexCard(row.read<int>('id'));
      }
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: _indexVersionKey,
              value: indexVersion.toString(),
            ),
          );
      return;
    }

    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT c.id AS id FROM cards c '
          'WHERE c.deleted_at IS NULL AND c.id NOT IN '
          '(SELECT subject_id FROM search_index WHERE subject_type = ?)',
          variables: <Variable<Object>>[Variable<String>('card')],
        )
        .get();

    for (final QueryRow row in rows) {
      await reindexCard(row.read<int>('id'));
    }
  }

  Future<void> _deleteIndexRows(int cardId) async {
    await _db.customStatement(
      'DELETE FROM search_index WHERE subject_type = ? AND subject_id = ?',
      <Object?>['card', cardId],
    );
    await (_db.delete(_db.embeddings)..where(
          ($EmbeddingsTable e) =>
              e.subjectType.isIn(kCardVectorSubjects) &
              e.subjectId.equals(cardId),
        ))
        .go();
  }

  /// Removes a card from the index. Called when one is purged.
  Future<void> removeFromIndex(int cardId) => _deleteIndexRows(cardId);

  /// Fires whenever something a result depends on may have changed.
  ///
  /// Results are a snapshot, and a snapshot goes stale: a card deleted from
  /// its own screen, restored from Recently deleted, or given a new note stayed
  /// in the open results — deleted cards still showing — until the next
  /// keystroke. `cards` covers delete and restore, `card_fields`, `notes`
  /// and `encounters` cover edits, and `embeddings` is written last by
  /// [reindexCard], so it
  /// fires once the index has caught up with an edit. (The FTS table is
  /// written with raw SQL, which Drift does not track, hence not listed.)
  Stream<void> watchChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables(
          <ResultSetImplementation<dynamic, dynamic>>[
            _db.cards,
            _db.cardFields,
            _db.notes,
            _db.encounters,
            _db.embeddings,
          ],
        ),
      )
      .map((_) {});

  /// Runs a query.
  ///
  /// Returns an empty list for a query with nothing searchable in it, which the
  /// UI shows differently from "searched and found nothing".
  ///
  /// [mode] runs one arm alone, for the evaluation's keyword-against-meaning
  /// comparison (PLAN §6). The app always runs [SearchMode.hybrid].
  Future<List<SearchHit>> search(
    String rawQuery, {
    int limit = 20,
    SearchMode mode = SearchMode.hybrid,
  }) async {
    final String? match = buildFtsQuery(rawQuery);
    if (match == null) return const <SearchHit>[];

    final List<ScoredCandidate> lexical = mode == SearchMode.semantic
        ? const <ScoredCandidate>[]
        : await _lexicalArm(match);
    final _VectorArm vector = mode == SearchMode.lexical
        ? _VectorArm.none
        : await _vectorArm(rawQuery);

    final List<FusedResult> fused = reciprocalRankFusion(
      lexical: lexical,
      vector: vector.ranked,
      limit: limit,
    );
    if (fused.isEmpty) return const <SearchHit>[];

    final RankingWeightSet weights = await _weights();
    final Map<String, double> termWeights = await _termWeights(rawQuery);
    // Whether the user has reached out to each of these people before — a
    // call, a WhatsApp chat, an email or a hello opened from RecallOS.
    final Map<int, double> use = await InteractionLog(
      _db,
      now: _now,
    ).useSignals(fused.map((FusedResult f) => f.subjectId));
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
      final String places = (await _placesOf(f.subjectId)).join(' · ');
      final bool metMatched = matchedTerms(rawQuery, places).isNotEmpty;
      final String notes = await _notesOf(f.subjectId);
      final List<String> inNotes = matchedTerms(rawQuery, notes);
      final double? noteCosine = vector.noteSimilarity[f.subjectId];

      final UtilityScore score = computeUtility(
        weights: weights,
        signals: RankingSignals(
          semantic: normalizeFusedScore(f.fusedScore),
          noteRelevance: noteRelevance(
            coverage: noteCoverage(
              termWeights: termWeights,
              matchedInNotes: inNotes,
            ),
            similarity: vector.searched
                ? noteSimilarity(noteCosine ?? 0)
                : null,
          ),
          previousUse: use[f.subjectId] ?? 0,
          freshness: freshnessFromAge(_now().difference(summary.capturedAt)),
        ),
      );

      hits.add(
        SearchHit(
          card: summary,
          score: score.value,
          reasons: _explain(f, terms, inNotes.isNotEmpty, metMatched),
          matchedOnMeaningOnly: f.semanticOnly,
          evidence: await _evidence(
            rawQuery,
            f.subjectId,
            notes: notes,
            place: places,
            noteMeaning: f.semanticOnly && vector.viaNote.contains(f.subjectId),
          ),
        ),
      );
    }

    hits.sort((SearchHit a, SearchHit b) => b.score.compareTo(a.score));
    return hits;
  }

  /// Answers a query the way the home screen shows it: a lookup's direct
  /// answers first, when it is one, then the ranked cards.
  ///
  /// [plus] is whether RecallOS Plus is on, which people filters, date
  /// questions and most totals need (`business/STRATEGY.md`: free Ask is
  /// lookup and search with sources; Plus adds date and aggregate queries).
  Future<SearchAnswer> ask(String raw, {bool plus = false}) async {
    final QueryPlan plan = planQuery(raw, now: _now());
    switch (plan) {
      case WarrantyPlan():
        final List<WarrantyAnswer> found = await _purchases.warranties(
          plan.subject,
        );
        if (found.isEmpty) {
          return SearchAnswer(
            plan: plan,
            cannot: 'No saved warranty matches “${plan.subject}”.',
            hits: await search(raw),
          );
        }
        // The papers already cited are not listed again below.
        final Set<int> cited = <int>{
          for (final WarrantyAnswer w in found) ...<int>[
            w.card.id,
            ?w.receipt?.other.id,
          ],
        };
        return SearchAnswer(
          plan: plan,
          warranties: found,
          hits: <SearchHit>[
            for (final SearchHit h in await search(plan.subject))
              if (!cited.contains(h.card.id)) h,
          ],
        );
      // Without Plus the words are still searched, but only among the
      // papers the question is about: warranties for a date question,
      // receipts for a total. A business card that happens to share a word
      // is not an answer to either.
      case ExpiringPlan() when !plus:
        return SearchAnswer(
          plan: plan,
          hits: _onlyOf(await search(raw), kWarrantyTypes),
          plusNeeded: true,
        );
      case ExpiringPlan():
        return SearchAnswer(
          plan: plan,
          expiring: await _purchases.expiring(plan),
        );
      case SpendingPlan() when !plus && !plan.isFreeAt(_now()):
        return SearchAnswer(
          plan: plan,
          hits: _onlyOf(await search(raw), kReceiptTypes),
          plusNeeded: true,
        );
      case SpendingPlan():
        return SearchAnswer(
          plan: plan,
          spending: await _purchases.spending(plan),
        );
      case PeopleFilterPlan() when !plus:
        return SearchAnswer(
          plan: plan,
          hits: await search(raw),
          plusNeeded: true,
        );
      case PeopleFilterPlan():
        return SearchAnswer(plan: plan, people: await people(plan));
      case LookupPlan():
        final List<LookupAnswer> answers = await lookup(plan);
        if (answers.isEmpty) {
          // Nobody by that name — "number plate" is somebody's need, not a
          // person — so this is an ordinary search after all.
          return SearchAnswer(plan: plan, hits: await search(raw));
        }
        final Set<int> shown = <int>{
          for (final LookupAnswer a in answers) a.card.id,
        };
        final List<SearchHit> rest = await search(plan.subject);
        return SearchAnswer(
          plan: plan,
          lookups: answers,
          hits: <SearchHit>[
            for (final SearchHit h in rest)
              if (!shown.contains(h.card.id)) h,
          ],
        );
      case SearchPlan():
        return SearchAnswer(plan: plan, hits: await search(raw));
    }
  }

  static List<SearchHit> _onlyOf(List<SearchHit> hits, Set<CardType> types) =>
      <SearchHit>[
        for (final SearchHit h in hits)
          if (types.contains(h.card.type)) h,
      ];

  /// Everyone who fits a people filter, soonest step first when it asks
  /// about next steps, else most recently met.
  ///
  /// Where they were met is matched on the words typed ("CSE fest" finds
  /// "CSE fest at NSU"); the day is the one recorded, or the day the card
  /// was scanned when none was — the same day the card's *Where you met*
  /// suggests.
  Future<List<PersonMatch>> people(PeopleFilterPlan plan) async {
    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT c.id AS id, c.captured_at AS captured_at, '
          'e.met_on AS met_on, e.place AS place '
          'FROM cards c LEFT JOIN encounters e '
          'ON e.card_id = c.id AND e.deleted_at IS NULL '
          'WHERE c.deleted_at IS NULL '
          // People filters are about people: a receipt is never "met".
          'AND c.type IN (${IdentityRepository.peopleCardTypes.map((CardType t) => "'${t.name}'").join(', ')}) '
          'ORDER BY c.id, e.id',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.cards,
            _db.encounters,
          },
        )
        .get();
    final List<QueryRow> steps = await _db
        .customSelect(
          'SELECT card_id, title, due_on FROM important_dates '
          "WHERE status = 'open' AND deleted_at IS NULL AND kind = ? "
          'ORDER BY due_on, id',
          variables: <Variable<Object>>[
            Variable<String>(DateKind.followUp.name),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.importantDates,
          },
        )
        .get();
    final Map<int, QueryRow> soonest = <int, QueryRow>{};
    for (final QueryRow r in steps) {
      soonest.putIfAbsent(r.read<int>('card_id'), () => r);
    }

    final List<QueryTerm> placeTerms = plan.place == null
        ? const <QueryTerm>[]
        : queryTerms('${plan.place} ');

    // The latest encounter per card wins, as on the card's own screen.
    final Map<int, QueryRow> byCard = <int, QueryRow>{
      for (final QueryRow r in rows) r.read<int>('id'): r,
    };

    final List<PersonMatch> out = <PersonMatch>[];
    for (final QueryRow r in byCard.values) {
      final int id = r.read<int>('id');
      final String? place = r.read<String?>('place');
      final DateTime? metOn = r.read<DateTime?>('met_on');

      if (placeTerms.isNotEmpty) {
        final List<String> words = textWords(place ?? '');
        if (!placeTerms.every((QueryTerm t) => termMatchesAny(t, words))) {
          continue;
        }
      }
      final DateTime? from = plan.from;
      final DateTime? until = plan.until;
      if (from != null && until != null) {
        final DateTime day = metOn ?? r.read<DateTime>('captured_at');
        if (day.isBefore(from) || !day.isBefore(until)) continue;
      }
      final QueryRow? step = soonest[id];
      if (plan.followUp == FollowUpFilter.open && step == null) continue;
      if (plan.followUp == FollowUpFilter.none && step != null) continue;

      final CardSummary? summary = await _summaryOf(id);
      if (summary == null) continue;
      out.add(
        PersonMatch(
          card: summary,
          metOn: metOn,
          place: place,
          nextStep: step?.read<String>('title'),
          nextDue: step?.read<DateTime>('due_on'),
        ),
      );
    }

    out.sort((PersonMatch a, PersonMatch b) {
      if (plan.followUp == FollowUpFilter.open) {
        return a.nextDue!.compareTo(b.nextDue!);
      }
      final DateTime da = a.metOn ?? a.card.capturedAt;
      final DateTime db = b.metOn ?? b.card.capturedAt;
      return db.compareTo(da);
    });
    return out;
  }

  /// The asked-for field on every card whose person or company the subject
  /// names — "Rahim" finds every Rahim.
  ///
  /// When it names nobody, the subject may be a need ("AC repair number"),
  /// so the best few cards for it that carry the field answer instead,
  /// marked as found that way.
  Future<List<LookupAnswer>> lookup(LookupPlan plan) async {
    // A trailing space: the subject is a finished phrase, so a short word in
    // it ("md") matches only itself.
    final List<QueryTerm> terms = queryTerms('${plan.subject} ');
    if (terms.isEmpty) return const <LookupAnswer>[];

    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT f.card_id AS card_id, f.field_key AS field_key, '
          'f.value AS value FROM card_fields f '
          'JOIN cards c ON c.id = f.card_id '
          'WHERE c.deleted_at IS NULL AND f.field_key IN (?, ?)',
          variables: <Variable<Object>>[
            Variable<String>(FieldKeys.personName),
            Variable<String>(FieldKeys.company),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.cards,
            _db.cardFields,
          },
        )
        .get();

    final Map<int, List<String>> nameWords = <int, List<String>>{};
    final Map<int, List<String>> allWords = <int, List<String>>{};
    for (final QueryRow r in rows) {
      final int id = r.read<int>('card_id');
      final List<String> words = textWords(r.read<String>('value'));
      allWords.putIfAbsent(id, () => <String>[]).addAll(words);
      if (r.read<String>('field_key') == FieldKeys.personName) {
        nameWords.putIfAbsent(id, () => <String>[]).addAll(words);
      }
    }

    bool all(List<String>? words) =>
        words != null && terms.every((QueryTerm t) => termMatchesAny(t, words));

    final List<int> byName = <int>[
      for (final MapEntry<int, List<String>> e in allWords.entries)
        if (all(e.value)) e.key,
    ];

    if (byName.isNotEmpty) {
      final Map<int, double> use = await InteractionLog(
        _db,
        now: _now,
      ).useSignals(byName);
      final List<LookupAnswer> answers = <LookupAnswer>[
        for (final int id in byName) ?await _answerFor(id, plan.fieldKey),
      ];
      answers.sort((LookupAnswer a, LookupAnswer b) {
        // The person's own name first, then a company's; then somebody the
        // user has reached out to; then the newest card.
        final int byPerson = (all(nameWords[a.card.id]) ? 0 : 1).compareTo(
          all(nameWords[b.card.id]) ? 0 : 1,
        );
        if (byPerson != 0) return byPerson;
        final int byUse = (use[b.card.id] ?? 0).compareTo(use[a.card.id] ?? 0);
        if (byUse != 0) return byUse;
        return b.card.capturedAt.compareTo(a.card.capturedAt);
      });
      return answers;
    }

    final List<LookupAnswer> viaSearch = <LookupAnswer>[];
    for (final SearchHit h in await search(plan.subject, limit: 5)) {
      final LookupAnswer? a = await _answerFor(
        h.card.id,
        plan.fieldKey,
        viaSearch: true,
      );
      if (a != null && a.values.isNotEmpty) viaSearch.add(a);
      if (viaSearch.length == 3) break;
    }
    return viaSearch;
  }

  Future<LookupAnswer?> _answerFor(
    int cardId,
    String fieldKey, {
    bool viaSearch = false,
  }) async {
    final CardSummary? summary = await _summaryOf(cardId);
    if (summary == null) return null;
    final List<CardField> fields =
        await (_db.select(_db.cardFields)
              ..where(($CardFieldsTable f) => f.cardId.equals(cardId))
              ..orderBy(<OrderClauseGenerator<$CardFieldsTable>>[
                ($CardFieldsTable f) => OrderingTerm.asc(f.id),
              ]))
            .get();
    String? first(String key) =>
        fields.where((CardField f) => f.fieldKey == key).firstOrNull?.value;
    return LookupAnswer(
      card: summary,
      values: <CardField>[
        for (final CardField f in fields)
          if (f.fieldKey == fieldKey) f,
      ],
      person: first(FieldKeys.personName),
      company: first(FieldKeys.company),
      viaSearch: viaSearch,
    );
  }

  /// The words that matched, where they were found — see [explainMatch].
  Future<MatchEvidence?> _evidence(
    String rawQuery,
    int cardId, {
    required String notes,
    required String place,
    required bool noteMeaning,
  }) async {
    final CardRow? card = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();
    final List<CardField> fields =
        await (_db.select(_db.cardFields)
              ..where(($CardFieldsTable f) => f.cardId.equals(cardId))
              ..orderBy(<OrderClauseGenerator<$CardFieldsTable>>[
                ($CardFieldsTable f) => OrderingTerm.asc(f.id),
              ]))
            .get();
    final Map<String, List<String>> byLabel = <String, List<String>>{};
    for (final CardField f in fields) {
      byLabel
          .putIfAbsent(
            _fieldLabels[f.fieldKey] ?? 'On the card',
            () => <String>[],
          )
          .add(f.value);
    }
    return explainMatch(
      rawQuery,
      notes: notes,
      place: place,
      fields: byLabel,
      printed: <String?>[
        card?.rawOcrText,
        card?.backOcrText,
      ].whereType<String>().join('\n'),
      noteMeaning: noteMeaning,
    );
  }

  static const Map<String, String> _fieldLabels = <String, String>{
    FieldKeys.personName: 'Name',
    FieldKeys.company: 'Company',
    FieldKeys.designation: 'Title',
    FieldKeys.phone: 'Phone',
    FieldKeys.email: 'Email',
    FieldKeys.website: 'Website',
    FieldKeys.address: 'Address',
  };

  /// Each query word's specificity across the live cards — see
  /// [inverseDocumentFrequency]. Counted with the same MATCH rule the
  /// lexical arm used, so a finished "ac" is not made to look common by
  /// every "account".
  Future<Map<String, double>> _termWeights(String rawQuery) async {
    const String live =
        'subject_type = ? AND subject_id IN '
        '(SELECT id FROM cards WHERE deleted_at IS NULL)';
    final int cards =
        (await _db
                .customSelect(
                  'SELECT count(*) AS n FROM search_index WHERE $live',
                  variables: <Variable<Object>>[Variable<String>(kCardSubject)],
                )
                .getSingle())
            .read<int>('n');

    final Map<String, double> weights = <String, double>{};
    for (final QueryTerm t in queryTerms(rawQuery)) {
      if (weights.containsKey(t.text)) continue;
      int withTerm = 0;
      try {
        withTerm =
            (await _db
                    .customSelect(
                      'SELECT count(*) AS n FROM search_index '
                      'WHERE search_index MATCH ? AND $live',
                      variables: <Variable<Object>>[
                        Variable<String>(ftsTermExpression(t)),
                        Variable<String>(kCardSubject),
                      ],
                    )
                    .getSingle())
                .read<int>('n');
      } on Object {
        // Same guard as the lexical arm: a term the parser rejects counts as
        // found nowhere, which makes it rare, never a crash.
      }
      weights[t.text] = inverseDocumentFrequency(
        cards: cards,
        cardsWithTerm: withTerm,
      );
    }
    return weights;
  }

  /// All of a card's notes as one text — every note, not only the one the
  /// summary shows, since any of them may be what the user wrote the need
  /// down in.
  Future<String> _notesOf(int cardId) async {
    final List<Note> notes =
        await (_db.select(_db.notes)..where(
              ($NotesTable n) =>
                  n.subjectType.equals(kCardSubject) &
                  n.subjectId.equals(cardId),
            ))
            .get();
    return notes
        .map(
          (Note n) =>
              <String?>[n.body, n.transcript].whereType<String>().join(' '),
        )
        .join('\n');
  }

  /// Both arms exclude deleted cards *before* their limit, not after.
  ///
  /// A soft-deleted card keeps its index rows and its embedding until it is
  /// purged (thirty days later), so filtering only when results were rendered
  /// let recently deleted cards take candidate slots: each arm kept its top
  /// 50, fusion its top 20, and a live card ranked below enough deleted ones
  /// never reached the screen at all.
  Future<List<ScoredCandidate>> _lexicalArm(String match) async {
    try {
      final List<QueryRow> rows = await _db
          .customSelect(
            // One weight per column, the two unindexed ones included. The
            // note counts double: it is what the user wrote down they needed
            // this person for, where the printed text is the card's own
            // advertising. Where they were met is the user's too, and short,
            // so a match there is strong evidence.
            'SELECT subject_id, '
            'bm25(search_index, 0.0, 0.0, 1.0, 2.0, 1.0, 1.0, 1.5) AS score '
            'FROM search_index '
            'WHERE search_index MATCH ? AND subject_type = ? '
            'AND subject_id IN (SELECT id FROM cards WHERE deleted_at IS NULL) '
            'ORDER BY score LIMIT 50',
            variables: <Variable<Object>>[
              Variable<String>(match),
              Variable<String>('card'),
            ],
          )
          .get();

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

  Future<_VectorArm> _vectorArm(String rawQuery) async {
    final StaticEmbedder? embedder = await _embedderOrNull();
    if (embedder == null) return _VectorArm.none;

    final Float32List query = embedder.embed(rawQuery);
    if (!StaticEmbedder.isUsable(query)) return _VectorArm.none;

    final List<Embedding> stored =
        await (_db.select(_db.embeddings)..where(
              ($EmbeddingsTable e) =>
                  e.subjectType.isIn(kCardVectorSubjects) &
                  e.model.equals(StaticEmbedder.modelId) &
                  e.subjectId.isInQuery(
                    _db.selectOnly(_db.cards)
                      ..addColumns(<Expression<Object>>[_db.cards.id])
                      ..where(_db.cards.deletedAt.isNull()),
                  ),
            ))
            .get();

    List<ScoredCandidate> rank(String subjectType, {double minScore = 0}) =>
        rankByCosine(
          queryVector: query,
          candidates: <int, List<double>>{
            for (final Embedding e in stored)
              if (e.subjectType == subjectType)
                e.subjectId: StaticEmbedder.fromBlob(e.vector),
          },
          minScore: minScore,
        );

    // Below this two strings are unrelated, and including them makes every
    // query look like it matched everything.
    const double floor = 0.25;

    // A card is as close as the closer of its two vectors: the whole card,
    // or its notes alone.
    final Map<int, double> best = <int, double>{
      for (final ScoredCandidate c in rank(kCardSubject, minScore: floor))
        c.subjectId: c.score,
    };
    final Map<int, double> notes = <int, double>{};
    final Set<int> viaNote = <int>{};
    for (final ScoredCandidate c in rank(kCardNoteSubject)) {
      notes[c.subjectId] = c.score;
      if (c.score >= floor && c.score > (best[c.subjectId] ?? -1)) {
        best[c.subjectId] = c.score;
        viaNote.add(c.subjectId);
      }
    }

    final List<ScoredCandidate> ranked =
        best.entries
            .map(
              (MapEntry<int, double> e) =>
                  ScoredCandidate(subjectId: e.key, score: e.value),
            )
            .toList()
          ..sort((ScoredCandidate a, ScoredCandidate b) {
            final int byScore = b.score.compareTo(a.score);
            return byScore != 0 ? byScore : a.subjectId.compareTo(b.subjectId);
          });

    return _VectorArm(
      ranked: ranked.length > 50 ? ranked.sublist(0, 50) : ranked,
      noteSimilarity: notes,
      viaNote: viaNote,
      searched: true,
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
    bool metMatched,
  ) {
    final List<String> reasons = <String>[];
    if (noteMatched) reasons.add('your note');
    if (metMatched) reasons.add('where you met');
    if (terms.isNotEmpty) {
      reasons.add(terms.take(3).join(', '));
    }
    if (f.semanticOnly && reasons.isEmpty) {
      reasons.add('similar meaning');
    }
    return reasons;
  }

  Future<CardSummary?> _summaryOf(int cardId) async {
    final CardRow? card =
        await (_db.select(_db.cards)..where(
              ($CardsTable c) => c.id.equals(cardId) & c.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (card == null) return null;

    final List<CardField> fields = await (_db.select(
      _db.cardFields,
    )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();
    final Note? note =
        await (_db.select(_db.notes)
              ..where(
                ($NotesTable n) =>
                    n.subjectType.equals('card') & n.subjectId.equals(cardId),
              )
              ..limit(1))
            .getSingleOrNull();

    final ({String? title, String? subtitle}) named = describeCard(
      card,
      fields,
    );
    return CardSummary(
      id: card.id,
      imagePath: card.imagePath,
      thumbPath: card.thumbPath,
      capturedAt: card.capturedAt,
      status: card.extractionStatus,
      title: named.title,
      subtitle: named.subtitle,
      note: note?.body,
      type: card.type,
    );
  }
}

/// What the vector arm found, and how close each card's notes came on their
/// own — which ranking reads as part of how well the note answers.
class _VectorArm {
  const _VectorArm({
    required this.ranked,
    required this.noteSimilarity,
    required this.searched,
    this.viaNote = const <int>{},
  });

  static const _VectorArm none = _VectorArm(
    ranked: <ScoredCandidate>[],
    noteSimilarity: <int, double>{},
    searched: false,
  );

  /// Cards whose notes vector was closer than the whole card's.
  final Set<int> viaNote;

  final List<ScoredCandidate> ranked;

  /// Cosine between the query and each card's notes vector.
  final Map<int, double> noteSimilarity;

  /// False when there was no embedder or no usable query vector, so a note
  /// with no similarity is "not measured", not "unrelated".
  final bool searched;
}
