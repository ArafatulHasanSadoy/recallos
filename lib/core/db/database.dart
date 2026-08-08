import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Used by the generated part file for the textEnum<...>() columns.
import 'enums.dart';
import 'tables.dart';

part 'database.g.dart';

/// Full-text index over everything a keyword query should reach.
///
/// This is the half of retrieval that always works: no model, no network, no
/// embedding. On a Tier C device — or any device before the models finish
/// downloading — FTS5 alone still finds cards.
const String _createSearchIndex = '''
CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
  subject_type UNINDEXED,
  subject_id   UNINDEXED,
  card_text,
  note_text,
  canonical_en,
  tags,
  tokenize = "unicode61 remove_diacritics 2"
);
''';

@DriftDatabase(
  tables: <Type>[
    People,
    Organizations,
    OrgBranches,
    Roles,
    Cards,
    CardFields,
    ContactPoints,
    OcrBlocks,
    ExtractionAttempts,
    Notes,
    Attributes,
    CapabilityProfiles,
    Embeddings,
    Interactions,
    Tags,
    SubjectTags,
    SearchQueries,
    SearchFeedback,
    RankingWeights,
    DuplicateCandidates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'recallos'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(_createSearchIndex);
          await _seedRankingWeights();
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // FTS5 lives outside Drift's schema tracking, so make sure it exists
          // even for databases created before it was added.
          await customStatement(_createSearchIndex);
        },
      );

  /// Starting weights for the utility score.
  ///
  /// These are a starting point, not a result. They get tuned against the
  /// labelled query set and then nudged per user by search feedback.
  Future<void> _seedRankingWeights() async {
    const Map<String, double> defaults = <String, double>{
      'semantic': 0.38,
      'note_relevance': 0.18,
      'category_match': 0.12,
      'trust': 0.10,
      'location': 0.08,
      'previous_use': 0.06,
      'verified': 0.05,
      'freshness': 0.03,
      'penalty_expired': 0.50,
      'penalty_outdated': 0.20,
    };
    await batch((Batch b) {
      b.insertAll(
        rankingWeights,
        <RankingWeightsCompanion>[
          for (final MapEntry<String, double> e in defaults.entries)
            RankingWeightsCompanion.insert(key: e.key, value: e.value),
        ],
      );
    });
  }
}
