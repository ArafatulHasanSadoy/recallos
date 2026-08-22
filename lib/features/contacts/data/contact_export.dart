import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database.dart';
import '../../../core/export/vcard.dart';
import 'identity_repository.dart';

final contactExportProvider = Provider<ContactExport>(
  (Ref ref) => ContactExport(ref),
);

/// What became of an export, so the screen can say something true about it.
enum ContactExportResult {
  /// Handed to the contacts app.
  opened,

  /// Handed to the share sheet.
  shared,

  /// Nothing on this phone imports vCards.
  noHandler,

  /// The contact went away between the tap and the write.
  gone,
}

/// Hands a contact to the rest of the phone.
///
/// Deliberately *not* `flutter_contacts`. Writing directly to the address book
/// needs `READ_CONTACTS` and `WRITE_CONTACTS` — two runtime-prompted dangerous
/// permissions — in an app whose manifest is otherwise down to the camera and
/// which makes a point of not even asking for the internet. Reading somebody's
/// entire address book to write one row into it is a bad trade, and a hard one
/// to defend next to the privacy claims.
///
/// So the card goes out as a `.vcf` handed to the OS instead. It needs no
/// permission at all, and the user sees exactly what is being written and
/// where it is going — which for this app is the better interaction, not a
/// consolation prize.
///
/// Two verbs, because they reach different places and only one of them is
/// "save to contacts":
///
/// - **`ACTION_VIEW`** (`OpenFilex`) is what the Contacts app actually listens
///   for. `cmd package query-activities -a android.intent.action.VIEW -t
///   text/x-vcard` returns Google Contacts; the same query for `ACTION_SEND`
///   does not. A share sheet can therefore never offer Contacts as a target,
///   which is a quietly wrong way to ship a feature called "save to contacts".
/// - **`ACTION_SEND`** (`SharePlus`) is for everything else — WhatsApp, email,
///   Drive — which is a genuinely separate thing a person wants to do with a
///   contact.
class ContactExport {
  ContactExport(this._ref);

  final Ref _ref;

  /// Shares one person as a contact file.
  ///
  /// Every role is folded into a single card: a person with a watch shop and a
  /// bank office is still one human, and splitting them into two address-book
  /// entries is precisely the flattening the identity graph exists to avoid.
  /// The organisation and job title come from their current role.
  Future<ContactExportResult> savePerson(int personId,
      {bool share = false}) async {
    final PersonDetail? detail =
        await _ref.read(identityRepositoryProvider).watchPerson(personId).first;
    if (detail == null) return ContactExportResult.gone;

    // Deduplicated across the whole person, not per role. `PersonDetail`
    // collapses endpoints within a role, but the same number usually appears
    // under every role a person has — both of this man's cards carry both of
    // his numbers — and a contacts app given the same number twice stores it
    // twice. The first role to claim an endpoint keeps the label.
    final Map<String, VCardContact> endpoints = <String, VCardContact>{};
    void offer(ContactPoint c, String? label) {
      endpoints.putIfAbsent(
        '${c.kind}|${c.normalizedValue ?? c.value.trim()}',
        () => VCardContact(kind: c.kind, value: c.value, label: label),
      );
    }

    for (final RoleDetail role in detail.roles) {
      for (final ContactPoint c in role.contacts) {
        // The company is the only label that means anything to a contacts app
        // here, and it is what tells two numbers apart.
        offer(c, c.label ?? role.orgName);
      }
    }
    for (final ContactPoint c in detail.looseContacts) {
      offer(c, c.label);
    }

    final RoleDetail? primary =
        detail.roles.isEmpty ? null : detail.roles.first;

    final VCardData card = VCardData(
      displayName: detail.person.displayName,
      organization: primary?.orgName,
      title: primary?.title,
      note: detail.person.relationship,
      contacts: endpoints.values.toList(),
    );
    if (share) {
      await _share(card, fileName: detail.person.displayName);
      return ContactExportResult.shared;
    }
    return _open(card, fileName: detail.person.displayName);
  }

  /// Shares a company as a contact file.
  Future<ContactExportResult> saveOrganization(int orgId,
      {bool share = false}) async {
    final OrgDetail? detail = await _ref
        .read(identityRepositoryProvider)
        .watchOrganization(orgId)
        .first;
    if (detail == null) return ContactExportResult.gone;

    final VCardData card = VCardData(
      // No person on the card, so the company *is* the contact.
      displayName: detail.organization.name,
      organization: detail.organization.name,
      website: detail.organization.website,
      address: detail.branches.isEmpty ? null : detail.branches.first.address,
      contacts: <VCardContact>[
        for (final ContactPoint c in detail.contacts)
          VCardContact(kind: c.kind, value: c.value, label: c.label),
      ],
    );
    if (share) {
      await _share(card, fileName: detail.organization.name);
      return ContactExportResult.shared;
    }
    return _open(card, fileName: detail.organization.name);
  }

  /// Opens the contact in whatever app imports vCards — Contacts, in practice.
  Future<ContactExportResult> _open(
    VCardData data, {
    required String fileName,
  }) async {
    final File file = await _write(data, fileName);
    final OpenResult result =
        await OpenFilex.open(file.path, type: 'text/x-vcard');

    return result.type == ResultType.done
        ? ContactExportResult.opened
        : ContactExportResult.noHandler;
  }

  Future<void> _share(VCardData data, {required String fileName}) async {
    final File file = await _write(data, fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'text/x-vcard')],
        subject: data.displayName,
      ),
    );
  }

  /// Writes the card where another app can be granted a read on it.
  ///
  /// The cache rather than documents: this file exists to be handed over and
  /// has no reason to survive. Both plugins expose it through their own
  /// FileProvider, so no storage permission is involved on either path.
  Future<File> _write(VCardData data, String fileName) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File(p.join(dir.path, '${_safeName(fileName)}.vcf'));
    await file.writeAsString(buildVCard(data));
    return file;
  }

  /// A file name a user will recognise in a share sheet, with nothing in it
  /// that a file system objects to.
  static String _safeName(String raw) {
    final String flat = raw
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return flat.isEmpty ? 'contact' : flat;
  }
}
