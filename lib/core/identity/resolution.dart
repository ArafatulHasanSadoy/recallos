/// The identity-bearing facts one card asserts, and the rules for deciding
/// whether two cards are talking about the same person or company.
///
/// Kept as pure functions over plain values, with no database in sight, for
/// the same reason `fusion.dart` and `utility_score.dart` are: matching rules
/// are where the judgement calls live, and judgement calls are worth testing
/// without a schema in the way.
///
/// The governing rule is **never merge two people on a name alone**. Two
/// different Md. Rahmans must not collapse into one contact, and un-merging is
/// not something the user can do once the rows are gone. Names that look alike
/// become a duplicate *candidate* the user rules on; only a shared phone or
/// email — something only one person actually holds — links automatically.
library;

import '../db/enums.dart';
import 'similarity.dart';



/// One reachable endpoint read off a card.
class ContactFact {
  const ContactFact({
    required this.kind,
    required this.value,
    required this.source,
    this.normalized,
  });

  final ContactKind kind;
  final String value;

  /// E.164 for phones, lowercased for email. Null when the value could not be
  /// canonicalised, which also means it cannot be matched on.
  final String? normalized;

  final FactSource source;

  /// What resolution blocks on. A fact with no canonical form is still stored
  /// and still shown; it just cannot link two cards together.
  String? get key => normalized;

  @override
  String toString() => '$kind:${normalized ?? value}';
}

/// Everything on one card that belongs in the identity graph.
class CardFacts {
  const CardFacts({
    this.personName,
    this.company,
    this.designation,
    this.website,
    this.websiteDomain,
    this.address,
    this.contacts = const <ContactFact>[],
  });

  final String? personName;
  final String? company;
  final String? designation;

  final String? website;

  /// Registrable domain, the strongest organization signal there is.
  final String? websiteDomain;

  final String? address;
  final List<ContactFact> contacts;

  /// True when there is nothing here worth creating an entity for.
  ///
  /// A card can be perfectly useful and still be empty by this measure — the
  /// note is what makes an unreadable card retrievable, and a note is not an
  /// identity.
  bool get isEmpty =>
      (personName == null || personName!.trim().isEmpty) &&
      (company == null || company!.trim().isEmpty) &&
      contacts.isEmpty;

  /// The endpoints that can actually link this card to an existing person.
  Iterable<String> get matchKeys => contacts
      .where((ContactFact c) =>
          c.kind == ContactKind.phone || c.kind == ContactKind.email)
      .map((ContactFact c) => c.key)
      .whereType<String>();
}

/// Honorifics and qualifications that carry no identity.
///
/// Bangladeshi cards stack these freely — "Md.", "Engr.", "Alhaj" — and the
/// same person appears with and without them across two cards. Stripping them
/// only affects *comparison*; the stored `displayName` keeps whatever was
/// printed.
const Set<String> _honorifics = <String>{
  'md', 'mohammad', 'mohammed', 'mohd', 'muhammad',
  'mr', 'mrs', 'ms', 'miss',
  'dr', 'prof', 'professor',
  'engr', 'engineer', 'adv', 'advocate',
  'alhaj', 'alhajj', 'hajji', 'late',
};

/// Legal-form suffixes that two records of the same company disagree about.
const Set<String> _orgSuffixes = <String>{
  'ltd', 'limited', 'pvt', 'private', 'inc', 'incorporated',
  'co', 'company', 'corp', 'corporation', 'llc', 'plc',
  'enterprise', 'enterprises', 'trading', 'traders',
};

final RegExp _nonWord = RegExp(r'[^a-z0-9\s]');
final RegExp _spaces = RegExp(r'\s+');

/// A person's name reduced to what two cards would have to agree on.
///
/// Only ever used to *propose* a duplicate — never to merge. Returns null when
/// nothing identifying survives, which is the right answer for a card that
/// read "Mr." and nothing else.
String? normalizePersonName(String? raw) => _reduce(raw, drop: _honorifics);

/// Whether a string is plausibly somebody's name.
///
/// Extraction assigns the best candidate it has, and on a card with no legible
/// person that is sometimes a stray line: `OE-mgil: targetbrand2015@gm` is a
/// real read, taken off the email row of a shop card whose text ran together.
/// Promoted, it becomes a contact in the address book named after an email
/// address, which looks exactly like the app inventing people.
///
/// Deliberately a check on *shape*, not a guess at real names. Bangladeshi
/// names on business cards carry honorifics, initials and inconsistent
/// spacing, and anything cleverer would start rejecting the genuine article.
/// It only catches the two things a name never is: an address, and a label
/// that leaked in with its colon attached.
bool looksLikePersonName(String? raw) {
  final String name = (raw ?? '').trim();
  if (name.length < 2) return false;

  // An email or a URL is never a name, however confidently it was assigned.
  if (name.contains('@')) return false;
  if (name.contains('://')) return false;

  // A colon means a field label came along with the value — "E-mail:",
  // "Cell:" — and what follows it is that field, not a person.
  if (name.contains(':')) return false;

  final int letters = name.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
  final int digits = name.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (letters < 2) return false;
  // Names are mostly letters. A string that is mostly digits is a number, a
  // registration, or a house address that landed in the wrong field.
  return letters > digits;
}

/// A company name reduced to what two cards would have to agree on.
///
/// Unlike people, exact agreement here is safe enough to link on. Business
/// names are chosen to be distinctive, and the failure mode — two unrelated
/// shops both called exactly "Aquarius Pet Shop" — is rare and repairable,
/// where a wrongly merged *person* is neither.
String? normalizeOrgName(String? raw) => _reduce(raw, drop: _orgSuffixes);

String? _reduce(String? raw, {required Set<String> drop}) {
  if (raw == null) return null;
  final String flat = raw
      .toLowerCase()
      .replaceAll(_nonWord, ' ')
      .replaceAll(_spaces, ' ')
      .trim();
  if (flat.isEmpty) return null;

  final List<String> kept = flat
      .split(' ')
      .where((String t) => t.isNotEmpty && !drop.contains(t))
      .toList();
  if (kept.isEmpty) return null;
  return kept.join(' ');
}

/// How strongly two records agree, and on what.
class MatchVerdict {
  const MatchVerdict({required this.score, required this.signals});

  const MatchVerdict.none() : score = 0, signals = const <String>[];

  /// 0.0–1.0. At or above [linkThreshold] the link is made without asking.
  final double score;

  /// Which signals fired, so a prompt can explain itself rather than assert.
  final List<String> signals;

  bool get isEmpty => score == 0;

  /// Above this, link automatically. Only a shared endpoint reaches it.
  static const double linkThreshold = 0.9;

  /// Above this but below [linkThreshold], propose it and let the user decide.
  static const double proposeThreshold = 0.5;
}

/// Whether a card's facts describe an existing person.
///
/// [sharedKeys] are the endpoints this card and the candidate both carry.
/// Name agreement alone deliberately lands in propose-only territory.
MatchVerdict scorePerson({
  required Iterable<String> sharedKeys,
  required String? cardName,
  required String? candidateName,
}) {
  final List<String> signals = <String>[];
  double score = 0;

  if (sharedKeys.isNotEmpty) {
    signals.add('shared ${sharedKeys.length == 1 ? "contact" : "contacts"}');
    score = 1.0;
  }

  final double alike =
      nameSimilarity(normalizePersonName(cardName), normalizePersonName(candidateName));
  if (alike >= proposeSimilarity) {
    // "Same name" covers an OCR variant as well as an exact match — the two
    // are indistinguishable to the person looking at the prompt, and both are
    // equally weak evidence on their own.
    signals.add(alike == 1 ? 'same name' : 'a similar name');
    // On its own this stays under the link threshold on purpose.
    score = score > 0 ? score : 0.6;
  }

  return signals.isEmpty
      ? const MatchVerdict.none()
      : MatchVerdict(score: score, signals: signals);
}

/// Whether a card's facts describe an existing organization.
///
/// [cardAddress] and [candidateAddress] are normalised addresses where both
/// are known. A shared address is what turns "these names look alike" into
/// something worth linking without asking: two shops do not share a door.
MatchVerdict scoreOrganization({
  required String? cardDomain,
  required String? candidateDomain,
  required String? cardName,
  required String? candidateName,
  String? cardAddress,
  String? candidateAddress,
}) {
  if (cardDomain != null && cardDomain == candidateDomain) {
    return const MatchVerdict(score: 1.0, signals: <String>['same domain']);
  }

  final String? a = normalizeOrgName(cardName);
  final String? b = normalizeOrgName(candidateName);
  final double alike = nameSimilarity(a, b);

  final bool sameAddress = cardAddress != null &&
      candidateAddress != null &&
      nameSimilarity(cardAddress, candidateAddress) >= proposeSimilarity;

  if (a != null && a == b) {
    return const MatchVerdict(score: 0.92, signals: <String>['same name']);
  }
  // A similar name *and* the same address is two scans of one shop sign. The
  // name alone is not enough: OCR damage and a genuinely different branch of
  // the same chain look identical from here.
  if (alike >= proposeSimilarity && sameAddress) {
    return const MatchVerdict(
      score: 0.95,
      signals: <String>['a similar name', 'the same address'],
    );
  }
  if (alike >= proposeSimilarity) {
    return const MatchVerdict(score: 0.6, signals: <String>['a similar name']);
  }
  if (sameAddress) {
    return const MatchVerdict(
      score: 0.55,
      signals: <String>['the same address'],
    );
  }
  return const MatchVerdict.none();
}
