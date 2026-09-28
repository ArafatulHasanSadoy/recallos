import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/field_validator.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;

final profileRepositoryProvider = Provider<ProfileRepository>(
  (Ref ref) => ProfileRepository(ref.watch(databaseProvider)),
);

/// The card the user hands out, as a live stream.
///
/// Null when they have not made one. Every screen that shows the card watches
/// this, so an edit lands everywhere at once.
final myProfileProvider = StreamProvider<ProfileDetail?>(
  (Ref ref) => ref.watch(profileRepositoryProvider).watchDefault(),
);

/// One labelled line on the card: "MOBILE  01711 363991".
class ProfileLine {
  const ProfileLine({required this.label, required this.value});

  final String label;
  final String value;
}

/// Everything the typeset card face draws, and nothing else.
///
/// A plain value type with no database in it, which is the whole point. It is
/// what lets the editor's live preview be *the same widget* as the saved card —
/// the preview builds one from a draft that has never been written, the card
/// screen builds one from stored rows, and neither knows the difference. It
/// also makes the face testable with no drift, for the reason
/// `field_editor_layout_test.dart` gives: drift's async does not survive the
/// fake clock `testWidgets` runs under.
class ProfileCard {
  const ProfileCard({
    required this.name,
    this.designation,
    this.company,
    this.tagline,
    this.photoPath,
    this.lines = const <ProfileLine>[],
    this.seed = 1,
  });

  final String name;
  final String? designation;
  final String? company;
  final String? tagline;
  final String? photoPath;

  /// Phones, emails and links, in the order they should be read.
  final List<ProfileLine> lines;

  /// Tints the initials disc. The profile's row id, so the colour is stable
  /// between launches — see [InitialsAvatar].
  final int seed;

  bool get isEmpty => name.trim().isEmpty && lines.isEmpty;
}

/// One row the editor wants written.
class ProfileEntry {
  const ProfileEntry({required this.fieldKey, required this.value, this.label});

  final String fieldKey;
  final String value;
  final String? label;
}

/// The whole card, as the editor hands it over.
///
/// One object rather than a stream of per-field calls, because the editor is a
/// form: it is filled and then committed, and a card that saved its name and
/// not its number is worse than one that saved neither.
class ProfileDraft {
  const ProfileDraft({
    this.id,
    this.label,
    this.tagline,
    this.photoPath,
    this.entries = const <ProfileEntry>[],
  });

  /// Null for a card that does not exist yet.
  final int? id;

  final String? label;
  final String? tagline;
  final String? photoPath;
  final List<ProfileEntry> entries;
}

/// A stored profile and its fields.
class ProfileDetail {
  const ProfileDetail({required this.profile, required this.fields});

  final Profile profile;

  /// In display order rather than insertion order, the same order a scanned
  /// card's fields are read in.
  final List<ProfileField> fields;

  String? valueOf(String key) {
    for (final ProfileField f in fields) {
      if (f.fieldKey == key && f.value.trim().isNotEmpty) return f.value.trim();
    }
    return null;
  }

  List<ProfileField> allOf(String key) =>
      fields.where((ProfileField f) => f.fieldKey == key).toList();

  String get name => valueOf(FieldKeys.personName) ?? '';

  /// True when there is a row but nothing worth handing over on it.
  bool get isEmpty =>
      name.isEmpty && fields.every((ProfileField f) => f.value.trim().isEmpty);

  /// What the card face draws.
  ProfileCard toCard() => ProfileCard(
    name: name,
    designation: valueOf(FieldKeys.designation),
    company: valueOf(FieldKeys.company),
    tagline: profile.tagline,
    photoPath: profile.photoPath,
    seed: profile.id,
    lines: <ProfileLine>[
      for (final ProfileField f in fields)
        if (_lineLabel(f) case final String label)
          ProfileLine(label: label, value: f.value.trim()),
    ],
  );

  /// The caps label a contact line wears, or null for a field that is part of
  /// the heading rather than a way to reach somebody.
  static String? _lineLabel(ProfileField f) {
    if (f.value.trim().isEmpty) return null;
    final String? custom = f.label?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return switch (f.fieldKey) {
      FieldKeys.phone => 'Phone',
      FieldKeys.email => 'Email',
      FieldKeys.website => 'Web',
      FieldKeys.address => 'Address',
      _ => null,
    };
  }
}

/// Storage for the user's own card.
///
/// Authored data throughout: nothing here is promoted, matched, merged or
/// garbage-collected, which is why it lives in its own tables rather than as a
/// row in `people`. See the section comment in `tables.dart`.
class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  /// The order the card and the editor both read in.
  static const List<String> displayOrder = <String>[
    FieldKeys.personName,
    FieldKeys.designation,
    FieldKeys.company,
    FieldKeys.phone,
    FieldKeys.email,
    FieldKeys.website,
    FieldKeys.address,
  ];

  /// Watches the card the user hands out.
  ///
  /// The [readsFrom] set is the load-bearing part, for exactly the reason it is
  /// on [CardRepository.watchCard]. Drift re-runs a stream when the tables its
  /// own query names change — and this query names only `profiles`, while
  /// everything on the screen lives in `profile_fields`. Leave it out and
  /// saving a name writes to the database and never reaches the card above it,
  /// so Save appears to do nothing at all.
  Stream<ProfileDetail?> watchDefault() {
    return _db
        .customSelect(
          'SELECT id FROM profiles WHERE deleted_at IS NULL '
          'ORDER BY is_default DESC, id ASC LIMIT 1',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.profiles,
            _db.profileFields,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          if (rows.isEmpty) return null;
          return _detail(rows.first.read<int>('id'));
        });
  }

  Future<ProfileDetail?> _detail(int id) async {
    final Profile? profile = await (_db.select(
      _db.profiles,
    )..where(($ProfilesTable t) => t.id.equals(id))).getSingleOrNull();
    if (profile == null) return null;

    final List<ProfileField> fields = await (_db.select(
      _db.profileFields,
    )..where(($ProfileFieldsTable f) => f.profileId.equals(id))).get();

    fields.sort((ProfileField a, ProfileField b) {
      final int ai = displayOrder.indexOf(a.fieldKey);
      final int bi = displayOrder.indexOf(b.fieldKey);
      final int byKey = (ai < 0 ? displayOrder.length : ai).compareTo(
        bi < 0 ? displayOrder.length : bi,
      );
      if (byKey != 0) return byKey;
      // Ties broken explicitly: `List.sort` gives no stability guarantee, and
      // two phone numbers must not swap places between builds.
      final int byOrder = a.orderIndex.compareTo(b.orderIndex);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });

    return ProfileDetail(profile: profile, fields: fields);
  }

  /// Writes the whole card at once.
  ///
  /// Every field is deleted and rewritten rather than diffed — the opposite of
  /// [CardRepository.attachExtraction], and for the opposite reason. That
  /// method diffs because it has rows worth protecting: a value the user
  /// confirmed, a region measured against a photograph, a side. Nothing here
  /// has provenance to preserve, because every row is the user's own. A diff
  /// would buy nothing, and a diff is exactly where an editor loses a row.
  ///
  /// One transaction, so a half-saved card cannot exist.
  ///
  /// A portrait the saved card no longer points at — replaced or removed — is
  /// deleted once the transaction has committed, not before: if the write
  /// failed, the row would still point at a file that was already gone.
  Future<int> save(ProfileDraft draft) async {
    String? dropped;
    final int saved = await _db.transaction(() async {
      final int id;
      if (draft.id == null) {
        final int existing = await _db.profiles
            .count(where: ($ProfilesTable t) => t.deletedAt.isNull())
            .getSingle();
        id = await _db
            .into(_db.profiles)
            .insert(
              ProfilesCompanion.insert(
                // The first card is the one you hand over; nothing else can be,
                // and the partial unique index enforces it either way.
                isDefault: Value<bool>(existing == 0),
                label: Value<String?>(draft.label),
                tagline: Value<String?>(draft.tagline),
                photoPath: Value<String?>(draft.photoPath),
              ),
            );
      } else {
        id = draft.id!;
        final Profile? before = await (_db.select(
          _db.profiles,
        )..where(($ProfilesTable t) => t.id.equals(id))).getSingleOrNull();
        final String? previous = before?.photoPath;
        if (previous != null && previous != draft.photoPath) dropped = previous;

        await (_db.update(
          _db.profiles,
        )..where(($ProfilesTable t) => t.id.equals(id))).write(
          ProfilesCompanion(
            label: Value<String?>(draft.label),
            tagline: Value<String?>(draft.tagline),
            photoPath: Value<String?>(draft.photoPath),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
      }

      await (_db.delete(
        _db.profileFields,
      )..where(($ProfileFieldsTable f) => f.profileId.equals(id))).go();

      int order = 0;
      for (final ProfileEntry e in draft.entries) {
        final String text = e.value.trim();
        // An empty slot is not a fact. The editor always offers every field,
        // so most cards commit with several of them blank.
        if (text.isEmpty) continue;

        final FieldValidation check = validateField(e.fieldKey, text);
        await _db
            .into(_db.profileFields)
            .insert(
              ProfileFieldsCompanion.insert(
                profileId: id,
                fieldKey: e.fieldKey,
                value: text,
                normalizedValue: Value<String?>(check.normalized),
                label: Value<String?>(e.label),
                orderIndex: Value<int>(order++),
              ),
            );
      }
      return id;
    });

    final String? toDelete = dropped;
    if (toDelete != null) await _deleteFile(toDelete);
    return saved;
  }

  /// Deletes a portrait the editor made and the user never saved.
  ///
  /// Picking a photo writes a resized copy straight away, because the preview
  /// has to show it; if the user then picks another, removes it, or backs out,
  /// that copy belongs to nothing. Only files inside [profileDirectory] are
  /// touched, so a stray path can never reach anything else on the phone.
  Future<void> discardUnsavedPortrait(String path) async {
    final Directory dir = await profileDirectory();
    if (!p.isWithin(dir.path, path)) return;
    await _deleteFile(path);
  }

  /// Points the card at a portrait, and drops the one it replaces.
  Future<void> attachPhoto(int profileId, String path) async {
    final Profile? existing = await (_db.select(
      _db.profiles,
    )..where(($ProfilesTable t) => t.id.equals(profileId))).getSingleOrNull();
    if (existing == null) return;

    await (_db.update(
      _db.profiles,
    )..where(($ProfilesTable t) => t.id.equals(profileId))).write(
      ProfilesCompanion(
        photoPath: Value<String?>(path),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );

    final String? previous = existing.photoPath;
    if (previous != null && previous != path) await _deleteFile(previous);
  }

  Future<void> removePhoto(int profileId) async {
    final Profile? existing = await (_db.select(
      _db.profiles,
    )..where(($ProfilesTable t) => t.id.equals(profileId))).getSingleOrNull();
    if (existing == null) return;

    await (_db.update(
      _db.profiles,
    )..where(($ProfilesTable t) => t.id.equals(profileId))).write(
      ProfilesCompanion(
        photoPath: const Value<String?>(null),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );

    final String? previous = existing.photoPath;
    if (previous != null) await _deleteFile(previous);
  }

  /// Hides the card without destroying it.
  ///
  /// Soft, like every other delete in this app. The portrait stays on disk: a
  /// tombstone that cannot be restored whole is not much of a tombstone, and
  /// the retention sweep is where orphaned files get answered.
  Future<void> softDelete(int profileId) async {
    await (_db.update(
      _db.profiles,
    )..where(($ProfilesTable t) => t.id.equals(profileId))).write(
      ProfilesCompanion(
        deletedAt: Value<DateTime?>(DateTime.now()),
        // A deleted card cannot go on being the one you hand over, and the
        // partial index would refuse the next default while it held the flag.
        isDefault: const Value<bool>(false),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Where portraits live, created on first use. Mirrors
  /// [CardRepository.cardsDirectory], and is public for the same reason: the
  /// resize runs in an isolate, which cannot call a platform channel itself.
  Future<Directory> profileDirectory() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory profile = Directory(p.join(dir.path, 'profile'));
    if (!profile.existsSync()) await profile.create(recursive: true);
    return profile;
  }

  static Future<void> _deleteFile(String path) async {
    final File file = File(path);
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } on Object {
      // A file that will not go is not worth failing a save over; the row is
      // already pointing somewhere else.
    }
  }
}
