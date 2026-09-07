import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database.dart';
import '../../../core/export/vcard.dart';
import '../../capture/data/card_repository.dart';
import '../../contacts/data/contact_export.dart';
import '../../contacts/data/identity_repository.dart';

final walletExportProvider = Provider<WalletExport>(
  // Dependencies resolved here, not held as a `Ref`. The export runs across
  // several awaits, and a provider read after the first one is a read through
  // a `Ref` that may already be dead — the same trap `BackCaptureService` and
  // `RescanService` are built to avoid.
  (Ref ref) => WalletExport(
    db: ref.watch(databaseProvider),
    identity: ref.watch(identityRepositoryProvider),
  ),
);

/// What became of an export, so the row can say something true about it.
enum WalletExportResult {
  /// Handed to the share sheet.
  shared,

  /// There was nothing to export.
  empty,

  /// The archive could not be written.
  failed,
}

/// Writes the whole wallet into one archive and hands it to the share sheet.
///
/// This exists because the wallet cannot otherwise leave the phone. Android
/// backup is off by design (`allowBackup="false"`), there is no server, and
/// the database is encrypted with a key held in the Android Keystore — which
/// is destroyed with the app. So a copied `.sqlite` file restores to nothing:
/// reinstalling, changing the signing key, or losing the phone all cost the
/// user everything, and until now the only way out was one contact at a time.
///
/// The archive holds three kinds of thing, because they answer three different
/// questions:
///
/// - **`contacts.vcf`** — every person and organisation as vCards, the format
///   every address book on earth imports. This is what someone actually wants
///   when they have a new phone. Built through [vCardForPerson], the same
///   function the single-contact share uses, so the two cannot drift apart.
/// - **`wallet.json`** — every row of every table that holds something the
///   user typed, corrected or photographed, including the parts a vCard has no
///   room for: notes, provenance, which side of the card a value was read
///   from, OCR text. Nothing else preserves *why* a card mattered, which is
///   the whole premise of the app.
/// - **`photos/`** — the card photographs, which are not in the database and
///   are not encrypted (they are ordinary JPEGs in the documents directory).
///
/// It is deliberately not an importable backup. Restoring would need a merge
/// policy for a database with an identity graph in it, and inventing one to
/// support a feature nobody has asked for yet is how you get a restore path
/// that silently mangles the thing it was meant to protect. This gets the data
/// *out*, in formats that outlive the app.
class WalletExport {
  WalletExport({required this.db, required this.identity});

  final AppDatabase db;
  final IdentityRepository identity;

  /// Tables whose contents are derived, and would only bloat the archive.
  ///
  /// `embeddings` is the big one — 256 floats per subject, recomputed from
  /// text the export already carries. `ranking_weights` is tuning, not data.
  /// The FTS5 shadow tables are an index over `cards`, and restoring one by
  /// hand is not a thing anybody does.
  static const Set<String> _derived = <String>{
    'embeddings',
    'ranking_weights',
  };

  static bool _isFtsShadow(String name) =>
      name.startsWith('cards_fts') || name.endsWith('_fts');

  /// Builds the archive and opens the share sheet on it.
  Future<WalletExportResult> exportAll() async {
    try {
      final List<int>? bytes = await buildArchive();
      if (bytes == null) return WalletExportResult.empty;

      // The cache, not documents: this file exists to be handed over and has
      // no reason to survive. share_plus exposes it through its own
      // FileProvider, so no storage permission is involved.
      final Directory dir = await getTemporaryDirectory();
      final File out = File(p.join(dir.path, _fileName()));
      await out.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(out.path, mimeType: 'application/zip')],
          subject: 'RecallOS wallet',
        ),
      );
      return WalletExportResult.shared;
    } on Object {
      // An export that half-worked is worse than one that says it failed: the
      // user would file the archive away and find out it was short years
      // later, which is exactly when it matters.
      return WalletExportResult.failed;
    }
  }

  /// The archive's bytes, or null when there is nothing to export.
  ///
  /// Separate from [exportAll] because everything interesting happens here and
  /// none of it needs a platform channel — the share sheet and the temporary
  /// directory do, and they are the two things a test cannot reach. Splitting
  /// them is what lets `test/features/wallet_export_test.dart` open a real
  /// archive and read what is actually in it, rather than asserting that a
  /// method was called.
  Future<List<int>?> buildArchive() async {
    final Map<String, List<Map<String, Object?>>> tables = await _dumpTables();
    final String vcf = await _buildContacts();

    final int subjects =
        (tables['people']?.length ?? 0) +
        (tables['organizations']?.length ?? 0);
    final int cards = tables['cards']?.length ?? 0;
    if (subjects == 0 && cards == 0) return null;

    final Archive archive = Archive()
      ..add(ArchiveFile.string('README.txt', _readme(cards, subjects)))
      ..add(ArchiveFile.string('wallet.json', _json(tables)));

    if (vcf.isNotEmpty) {
      archive.add(ArchiveFile.string('contacts.vcf', vcf));
    }
    for (final File photo in _photos(tables)) {
      archive.add(
        ArchiveFile.bytes(
          'photos/${p.basename(photo.path)}',
          await photo.readAsBytes(),
        ),
      );
    }
    return ZipEncoder().encode(archive);
  }

  /// Every table that holds something the user put there.
  ///
  /// Read from `sqlite_master` rather than a hand-written list, so a table
  /// added in a later migration is exported without anybody remembering to
  /// come back here. A forgotten table is a silently incomplete backup.
  Future<Map<String, List<Map<String, Object?>>>> _dumpTables() async {
    final List<QueryRow> names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();

    final Map<String, List<Map<String, Object?>>> out =
        <String, List<Map<String, Object?>>>{};
    for (final QueryRow row in names) {
      final String table = row.read<String>('name');
      if (_derived.contains(table) || _isFtsShadow(table)) continue;
      final List<QueryRow> rows = await db
          .customSelect('SELECT * FROM "$table"')
          .get();
      out[table] = rows.map((QueryRow r) => r.data).toList();
    }
    return out;
  }

  /// Every person and organisation, as one importable vCard file.
  Future<String> _buildContacts() async {
    final List<VCardData> cards = <VCardData>[];

    for (final PersonSummary person in await identity.watchPeople().first) {
      final PersonDetail? detail = await identity
          .watchPerson(person.id)
          .first;
      if (detail != null) cards.add(vCardForPerson(detail));
    }
    for (final OrgSummary org in await identity.watchOrganizations().first) {
      final OrgDetail? detail = await identity
          .watchOrganization(org.id)
          .first;
      if (detail != null) cards.add(vCardForOrganization(detail));
    }
    return buildVCards(cards);
  }

  /// Every file the database points at.
  ///
  /// Collected by looking for `*_path` columns rather than naming
  /// `image_path`, `back_image_path` and `thumb_path`, for the same reason
  /// [_dumpTables] reads `sqlite_master`: a column added later is picked up
  /// without anybody editing this.
  List<File> _photos(Map<String, List<Map<String, Object?>>> tables) {
    final Set<String> paths = <String>{};
    for (final List<Map<String, Object?>> rows in tables.values) {
      for (final Map<String, Object?> row in rows) {
        row.forEach((String column, Object? value) {
          if (column.endsWith('_path') && value is String && value.isNotEmpty) {
            paths.add(value);
          }
        });
      }
    }

    final List<File> found = <File>[];
    for (final String path in paths) {
      final File file = File(path);
      // A card whose photo went missing still exports its text. Skipping
      // quietly is right here: the alternative is failing the whole archive
      // over one absent thumbnail.
      if (file.existsSync()) found.add(file);
    }
    return found;
  }

  String _json(Map<String, List<Map<String, Object?>>> tables) =>
      const JsonEncoder.withIndent('  ', _encodable).convert(<String, Object?>{
        'app': 'RecallOS',
        'schemaVersion': db.schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'tables': tables,
      });

  /// Drift hands back `DateTime`s and blobs; JSON has neither.
  static Object? _encodable(Object? value) => switch (value) {
    final DateTime d => d.toIso8601String(),
    final List<int> bytes => base64Encode(bytes),
    _ => value.toString(),
  };

  String _fileName() {
    final DateTime now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'recallos-${now.year}-${two(now.month)}-${two(now.day)}.zip';
  }

  String _readme(int cards, int subjects) =>
      '''
RecallOS — wallet export
Taken $_today

$cards card(s), $subjects contact(s).

  contacts.vcf   Every person and company, in the format address books
                 import. Open it on a new phone to get your contacts back.

  wallet.json    Everything else: your notes, which card each fact came
                 from, whether it was printed or you corrected it, and the
                 raw text read off each side. Plain JSON — any text editor
                 will open it.

  photos/        The card photographs themselves.

This archive is not encrypted. The wallet on the phone is; this copy is
yours to look after, so put it somewhere you trust.

There is no import. To read this back, open the files above directly.
''';

  String get _today {
    final DateTime now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }
}
