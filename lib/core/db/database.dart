import 'package:drift/drift.dart';

// Used by the generated part file for `card_fields.date_value`.
import '../domain/local_date.dart';
import 'encrypted_database.dart';

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
  met_text,
  tokenize = "unicode61 remove_diacritics 2"
);
''';

/// A column only the current [_createSearchIndex] has. FTS5 cannot add a
/// column to an existing table, so a table without it is dropped and made
/// again — it holds nothing but derived rows, which the search backfill
/// writes back on the next launch.
const String _searchIndexNewestColumn = 'met_text';

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
    Settings,
    Profiles,
    ProfileFields,
    Encounters,
    ImportantDates,
    Reminders,
    ItemLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the wallet, encrypted, unless handed something else.
  ///
  /// The parameter is what tests use — an in-memory database with no key and
  /// no keystore behind it. Everything the app itself runs goes through
  /// [openEncryptedDatabase]; see that file for what "encrypted" covers and
  /// what it does not.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openEncryptedDatabase());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement(_createSearchIndex);
      await _createIdentityIndexes();
      await _createProfileIndexes();
      await _createFollowUpIndexes();
      await _createItemLinkIndexes();
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
      // v5 — companies can be duplicates too, and two scans of one shop
      // sign is the commonest way it happens.
      if (from < 5) {
        await m.addColumn(organizations, organizations.mergedIntoId);
      }
      // v6 — the rules for matching companies changed: similar names and
      // shared addresses now count, where before only exact agreement did.
      // Those rules only run during promotion, so without this the new
      // matching would apply to cards scanned afterwards and never to the
      // library that already exists — which is exactly where the
      // duplicates people actually have are sitting.
      //
      // Unhooking the cards is enough. `IdentityRepository.backfill`
      // re-promotes anything carrying a company and no organization, and
      // garbage collection clears what is left behind. People are
      // untouched, so no merge anybody made is disturbed.
      if (from < 6) {
        await customStatement('UPDATE cards SET org_id = NULL, role_id = NULL');
      }
      // v7 — somewhere to record which version of the matching rules
      // produced the graph, so the next change to them rebuilds what is
      // already stored without needing a migration of its own.
      if (from < 7) {
        await m.createTable(settings);
      }
      // v8 — the back of a card became readable. Every stored region is a
      // rectangle in one image's pixel space, so a fact needs to say which
      // image, or a value read off the back boxes a spot on the front.
      //
      // Both columns default to `front`, which is the truth for every row
      // that already exists: until now the front was the only side anything
      // was ever read from.
      if (from < 8) {
        await m.addColumn(cards, cards.backOcrText);
        await m.addColumn(cardFields, cardFields.side);
        await m.addColumn(ocrBlocks, ocrBlocks.side);
      }
      // v9 — the app learned who its own user is.
      //
      // Its own tables rather than a flag on `people`, because a profile is
      // authored and everything in the identity graph is derived. A self row
      // would have to be kept out of the contacts list, endpoint matching,
      // duplicate proposal, the implausible-name sweep, backfill and the
      // wallet export — and out of garbage collection, which would otherwise
      // delete the user's own card for the crime of having no scanned card
      // behind it.
      if (from < 9) {
        await m.createTable(profiles);
        await m.createTable(profileFields);
        await _createProfileIndexes();
      }
      // v10 — context and obligations: when and where the user met someone,
      // what they promised to do next, and when Android should say so. New
      // tables only; nothing already stored changes shape.
      if (from < 10) {
        await m.createTable(encounters);
        await m.createTable(importantDates);
        await m.createTable(reminders);
        await _createFollowUpIndexes();
      }
      // v11 — Release B: things as well as people. Extends the tables in
      // place (PLAN §5) rather than starting parallel ones: a card row is
      // already the general saved item, and a card field already a fact with
      // its provenance.
      //
      // The first step that rewrites existing rows, not only adds to them,
      // so it is built to survive being run twice: in one transaction, and
      // every column and table added only if it is not already there. Drift
      // records the new version only after the migration finishes, so a
      // crash between the work and that write runs it again on the next
      // launch — which must then find nothing left to do rather than fail on
      // a column that already exists.
      if (from < 11) {
        await transaction(() async {
          await _addColumnIfMissing(m, cards, cards.title);
          await _addColumnIfMissing(m, cards, cards.captureSource);
          await _addColumnIfMissing(m, cards, cards.classificationConfidence);
          await _addColumnIfMissing(m, cardFields, cardFields.origin);
          await _addColumnIfMissing(m, cardFields, cardFields.review);
          await _addColumnIfMissing(m, cardFields, cardFields.validity);
          await _addColumnIfMissing(m, cardFields, cardFields.amountMinor);
          await _addColumnIfMissing(m, cardFields, cardFields.currency);
          await _addColumnIfMissing(m, cardFields, cardFields.dateValue);
          if (!await _tableExists('item_links')) {
            await m.createTable(itemLinks);
          }
          await _createItemLinkIndexes();

          // The one old value split three ways. `aiInferred` was the only
          // guess; `outdated` was about validity, not origin; `verified`
          // (the business confirming) was never written by anything. The
          // user's confirmation lived in its own flag and becomes `review`.
          // Plain SQL over every row, so running it again gives the same
          // answer.
          await customStatement(
            'UPDATE card_fields SET '
            'origin = CASE source '
            "  WHEN 'user' THEN 'user' "
            "  WHEN 'aiInferred' THEN 'inferred' "
            "  ELSE 'printed' END, "
            'review = CASE WHEN verified_by_user = 1 '
            "  THEN 'confirmed' ELSE 'unreviewed' END, "
            'validity = CASE source '
            "  WHEN 'outdated' THEN 'outdated' ELSE 'current' END",
          );
        });
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // FTS5 lives outside Drift's schema tracking, so make sure it exists
      // even for databases created before it was added — and has today's
      // columns, which a database (or a restored backup) from an older build
      // would not.
      await _ensureSearchIndexShape();
      await customStatement(_createSearchIndex);
    },
  );

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    final List<QueryRow> columns = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    final bool present = columns.any(
      (QueryRow c) => c.read<String>('name') == column.name,
    );
    if (!present) await m.addColumn(table, column);
  }

  Future<bool> _tableExists(String name) async => (await customSelect(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
    variables: <Variable<Object>>[Variable<String>(name)],
  ).get()).isNotEmpty;

  /// Links are looked up from either end: "what is this warranty for" and
  /// "is there a warranty for this receipt". The unique key covers the first.
  Future<void> _createItemLinkIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_links_to ON item_links(to_card_id)',
    );
  }

  Future<void> _ensureSearchIndexShape() async {
    final QueryRow? row = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' "
      "AND name = 'search_index'",
    ).getSingleOrNull();
    final String? sql = row?.read<String?>('sql');
    if (sql != null && !sql.contains(_searchIndexNewestColumn)) {
      await customStatement('DROP TABLE search_index');
    }
  }

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

  /// Exactly one card is the one you hand over.
  ///
  /// A partial index rather than a rule in the repository, because "at most one
  /// row with is_default = 1" is an invariant, and an invariant every writer
  /// has to remember is one some future writer will not. Rows at 0 are outside
  /// the index entirely, so any number of them is fine.
  Future<void> _createProfileIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_default '
      'ON profiles(is_default) WHERE is_default = 1',
    );
  }

  /// The two lookups Today and the reminder engine make on every refresh:
  /// open obligations by date, and the reminders behind one obligation.
  Future<void> _createFollowUpIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_important_dates_due '
      'ON important_dates(status, due_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_important_dates_card '
      'ON important_dates(card_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_encounters_card ON encounters(card_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reminders_date '
      'ON reminders(important_date_id)',
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
      b.insertAll(rankingWeights, <RankingWeightsCompanion>[
        for (final MapEntry<String, double> e in defaults.entries)
          RankingWeightsCompanion.insert(key: e.key, value: e.value),
      ]);
    });
  }
}
