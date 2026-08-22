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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(_createSearchIndex);
          await _createIdentityIndexes();
          await _seedRankingWeights();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v2 — `ocr_blocks.field_id`. Which field owns a block could not be
          // answered from `assigned_field_key` alone once the user could move a
          // block between fields; see the column's own comment.
          if (from < 2) {
            await m.addColumn(ocrBlocks, ocrBlocks.fieldId);
          }
          // v3 — the identity graph started being written. `source_card_id`
          // is what lets one card's contribution be refreshed on its own; the
          // indexes are the blocking keys resolution matches on.
          if (from < 3) {
            await m.addColumn(contactPoints, contactPoints.sourceCardId);
            await _createIdentityIndexes();
          }
          // v4 — duplicate review. Merging is a pointer, so that it can be
          // undone; see the column's own comment.
          if (from < 4) {
            await m.addColumn(people, people.mergedIntoId);
          }
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // FTS5 lives outside Drift's schema tracking, so make sure it exists
          // even for databases created before it was added.
          await customStatement(_createSearchIndex);
        },
      );

  /// Blocking keys for identity resolution.
  ///
  /// Every promotion looks a card's phones and emails up against
  /// `contact_points`, and its domain up against `organizations`. Without
  /// these that is a full scan per field per scan.
  Future<void> _createIdentityIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_contact_points_lookup '
      'ON contact_points(normalized_value, kind)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_contact_points_owner '
      'ON contact_points(owner_type, owner_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_contact_points_card '
      'ON contact_points(source_card_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_organizations_domain '
      'ON organizations(website_domain)',
    );
  }

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
