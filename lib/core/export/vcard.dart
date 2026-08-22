/// vCard 3.0 serialisation.
///
/// 3.0 rather than 4.0 deliberately: Android's contacts importer, iOS, Google
/// Contacts and every scanner app in the market read 3.0, while 4.0 support is
/// patchy on exactly the mid-range Android this app targets. Nothing here
/// needs a 4.0 feature.
///
/// Pure and string-in-string-out so it can be tested without a database, a
/// file system or a device — the same reason `fusion.dart` and
/// `resolution.dart` are shaped this way. It is also the piece QR sharing and
/// file export both need, so it is written once and reached from three places.
library;

import '../db/enums.dart';



/// One reachable endpoint, in the shape the serialiser needs.
class VCardContact {
  const VCardContact({
    required this.kind,
    required this.value,
    this.label,
  });

  final ContactKind kind;
  final String value;

  /// "office", "mobile" — becomes the TYPE parameter where it maps cleanly.
  final String? label;
}

/// Everything worth handing to a contacts app.
class VCardData {
  const VCardData({
    required this.displayName,
    this.organization,
    this.title,
    this.address,
    this.website,
    this.note,
    this.contacts = const <VCardContact>[],
  });

  final String displayName;
  final String? organization;
  final String? title;
  final String? address;
  final String? website;

  /// Why this card mattered. Carried across because it is the thing the user
  /// wrote themselves, and the thing a bare contact record always loses.
  final String? note;

  final List<VCardContact> contacts;
}

/// Serialises one contact.
String buildVCard(VCardData data) {
  final StringBuffer out = StringBuffer()
    ..write('BEGIN:VCARD\r\n')
    ..write('VERSION:3.0\r\n');

  final String name = data.displayName.trim().isEmpty
      ? (data.organization?.trim().isNotEmpty ?? false
          ? data.organization!.trim()
          : 'Unnamed contact')
      : data.displayName.trim();

  out.write('FN:${_escape(name)}\r\n');
  out.write('N:${_structuredName(name)}\r\n');

  if (_has(data.organization)) {
    out.write('ORG:${_escape(data.organization!.trim())}\r\n');
  }
  if (_has(data.title)) {
    out.write('TITLE:${_escape(data.title!.trim())}\r\n');
  }

  for (final VCardContact c in data.contacts) {
    if (!_has(c.value)) continue;
    switch (c.kind) {
      case ContactKind.phone:
      case ContactKind.whatsapp:
        out.write('TEL;TYPE=${_telType(c.label)}:${_escape(c.value.trim())}\r\n');
      case ContactKind.email:
        out.write('EMAIL;TYPE=INTERNET:${_escape(c.value.trim())}\r\n');
      case ContactKind.website:
      case ContactKind.social:
        out.write('URL:${_escape(c.value.trim())}\r\n');
      case ContactKind.fax:
        out.write('TEL;TYPE=FAX:${_escape(c.value.trim())}\r\n');
    }
  }

  if (_has(data.website)) {
    out.write('URL:${_escape(data.website!.trim())}\r\n');
  }
  if (_has(data.address)) {
    // ADR is seven semicolon-separated components; everything we have is one
    // unstructured string, so it goes in the street slot with the rest empty.
    out.write('ADR;TYPE=WORK:;;${_escape(data.address!.trim())};;;;\r\n');
  }
  if (_has(data.note)) {
    out.write('NOTE:${_escape(data.note!.trim())}\r\n');
  }

  out.write('END:VCARD\r\n');
  return out.toString();
}

/// Serialises several contacts into one importable file.
String buildVCards(Iterable<VCardData> all) =>
    all.map(buildVCard).join();

bool _has(String? s) => s != null && s.trim().isNotEmpty;

/// vCard has no "mobile"; the TYPE that means it is CELL.
String _telType(String? label) {
  final String l = (label ?? '').toLowerCase();
  if (l.contains('mobile') || l.contains('cell')) return 'CELL';
  if (l.contains('home')) return 'HOME';
  if (l.contains('fax')) return 'FAX';
  return 'WORK';
}

/// `N` wants Family;Given;Middle;Prefix;Suffix.
///
/// Splitting a Bangladeshi name into those five slots is guesswork, and
/// guessing wrong reorders somebody's name in their address book. Last token
/// as family and the rest as given is the least-wrong split, and `FN` above
/// carries the name as printed either way — which is what almost every
/// contacts app actually displays.
String _structuredName(String name) {
  final List<String> parts =
      name.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
  if (parts.length < 2) return '${_escape(name)};;;;';
  final String family = parts.removeLast();
  return '${_escape(family)};${_escape(parts.join(" "))};;;';
}

/// Backslash, semicolon, comma and newline all mean something structural.
String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\n');
