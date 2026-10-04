/// Your card as a QR code: which lines go on it, and the vCard it carries.
///
/// The code is the same vCard "Send my card" shares — [vCardForProfile] and
/// [buildVCard], not a second serialiser — with only the lines the user left
/// on. Any phone camera reads a vCard QR and offers to save the contact, so
/// the other person needs no app, and nothing goes through a server.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/export/vcard.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;
import '../../contacts/data/contact_export.dart' show vCardForProfile;
import 'profile_repository.dart';

/// One line the user can take off the code. The name is not one of them:
/// a contact without a name is not a contact.
class QrLine {
  const QrLine({required this.key, required this.label, required this.value});

  /// Stable across edits that leave the value alone. Field ids are not —
  /// saving the card rewrites every row — so the choice is keyed by what the
  /// line says.
  final String key;
  final String label;
  final String value;
}

/// The key of the line under the name, which is not a field.
const String taglineQrKey = 'tagline';

String qrLineKey(ProfileField f) =>
    '${f.fieldKey}:${(f.normalizedValue ?? f.value).trim().toLowerCase()}';

/// Every line that could go on the code, in the card's own order.
List<QrLine> qrLines(ProfileDetail d) => <QrLine>[
  for (final ProfileField f in d.fields)
    if (f.fieldKey != FieldKeys.personName && f.value.trim().isNotEmpty)
      QrLine(key: qrLineKey(f), label: _label(f), value: f.value.trim()),
  if (d.profile.tagline case final String t when t.trim().isNotEmpty)
    QrLine(key: taglineQrKey, label: 'Line under your name', value: t.trim()),
];

/// What is off before the user has chosen anything: the address. A postal
/// address is the one line people tend not to hand to somebody they met
/// ten minutes ago, and it is the longest, so it also makes the code
/// easiest to read when it is left off.
Set<String> defaultQrHidden(ProfileDetail d) => <String>{
  for (final ProfileField f in d.fields)
    if (f.fieldKey == FieldKeys.address) qrLineKey(f),
};

/// The vCard the code carries.
String myCardQrPayload(ProfileDetail d, Set<String> hidden) {
  final ProfileDetail shown = ProfileDetail(
    profile: hidden.contains(taglineQrKey)
        ? d.profile.copyWith(tagline: const Value<String?>(null))
        : d.profile,
    fields: <ProfileField>[
      for (final ProfileField f in d.fields)
        if (f.fieldKey == FieldKeys.personName ||
            !hidden.contains(qrLineKey(f)))
          f,
    ],
  );
  return buildVCard(vCardForProfile(shown));
}

String _label(ProfileField f) {
  final String? custom = f.label?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  return switch (f.fieldKey) {
    FieldKeys.designation => 'Title',
    FieldKeys.company => 'Company',
    FieldKeys.phone => 'Phone',
    FieldKeys.email => 'Email',
    FieldKeys.website => 'Web',
    FieldKeys.address => 'Address',
    _ => f.fieldKey,
  };
}

final myCardQrStoreProvider = Provider<MyCardQrStore>(
  (Ref ref) => MyCardQrStore(ref.watch(databaseProvider)),
);

/// The lines the user took off, or null when they have never chosen.
final myCardQrHiddenProvider = StreamProvider<Set<String>?>(
  (Ref ref) => ref.watch(myCardQrStoreProvider).watchHidden(),
);

/// Remembers the choice, so the code at the next event is the same code.
///
/// In the `settings` table with the app's other preferences: one store, and
/// one backup that carries it.
class MyCardQrStore {
  MyCardQrStore(this._db);

  final AppDatabase _db;

  static const String _key = 'my_card_qr_hidden';

  Stream<Set<String>?> watchHidden() =>
      (_db.select(_db.settings)
            ..where(($SettingsTable s) => s.key.equals(_key)))
          .watchSingleOrNull()
          .map((Setting? row) {
            if (row == null) return null;
            try {
              return <String>{
                for (final Object? k in jsonDecode(row.value) as List<Object?>)
                  if (k is String) k,
              };
            } on Object {
              // A store that cannot be read is treated as never chosen: the
              // default leaves the address off, which is the safe side.
              return null;
            }
          });

  Future<void> setHidden(Set<String> hidden) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: _key,
          value: jsonEncode(hidden.toList()..sort()),
        ),
      );
}
