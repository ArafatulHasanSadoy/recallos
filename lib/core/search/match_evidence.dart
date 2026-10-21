/// Why a card is in the results, in its own words.
///
/// The words that matched, shown where they were found — the user's note,
/// where they were met, a field, the printed text — so a result can be
/// checked at a glance rather than trusted. Built from the same matching
/// rule the search used ([termMatchesAny]), so it never claims a word the
/// search did not match.
library;

import 'fts_query.dart';

enum EvidenceSource {
  /// The user's own note.
  note,

  /// Where they were met.
  met,

  /// A field read off the card: name, company, address…
  field,

  /// Printed on the card, but in no field — a back's list of services.
  printed,

  /// No shared word; the note's meaning was closest.
  noteMeaning,

  /// No shared word; the card's meaning was close.
  meaning,
}

class MatchEvidence {
  const MatchEvidence({
    required this.source,
    required this.label,
    this.excerpt,
    this.spans = const <(int, int)>[],
  });

  final EvidenceSource source;

  /// What the excerpt is: "Your note", "Address", "Printed on the card".
  final String label;

  /// About [excerptLength] characters around the first matched word, with
  /// "…" where it was cut. Null when there is no text to show.
  final String? excerpt;

  /// Start and end (exclusive) of each matched word in [excerpt].
  final List<(int, int)> spans;

  @override
  String toString() => '$label: $excerpt';
}

const int excerptLength = 60;

/// Words that join a question together and say nothing about what it is
/// for — English, and the Banglish ones people type with them.
const Set<String> _stopWords = <String>{
  'a', 'an', 'the', 'of', 'in', 'on', 'at', 'to', 'for', 'from', 'and', 'or',
  'is', 'are', 'was', 'be', 'it', 'its', 'by', 'with', 'this', 'that',
  'what', 'whats', 'which', 'who', 'whose', 'when', 'where', 'how', 'my',
  'me', 'i', 'do', 'does', 'did', 'next', //
  'er', 'ki', 'ta', 'e', 'r', 'ar', 'ami', 'amar', 'koto', //
};

/// The best evidence for why [query] found a card, or null for none.
///
/// Tried in the order the user would trust it: their own note, where they
/// met, a field, then the printed text. [fields] maps a field's label to its
/// values; [noteMeaning] is true when no word matched and the note's own
/// vector was the closer one.
MatchEvidence? explainMatch(
  String query, {
  String notes = '',
  String place = '',
  Map<String, List<String>> fields = const <String, List<String>>{},
  String printed = '',
  bool noteMeaning = false,
}) {
  final List<QueryTerm> asked = queryTerms(query);
  if (asked.isEmpty) return null;
  // A stop word is never shown as the reason (M7½): "From **the** purchase"
  // explained nothing about why a card answered "what expires in the next
  // 90 days". Kept only when the query is nothing but stop words. When no
  // other word matched, the card was found by meaning, and says so.
  final List<QueryTerm> meaningful = <QueryTerm>[
    for (final QueryTerm t in asked)
      if (!_stopWords.contains(t.text)) t,
  ];
  final List<QueryTerm> terms = meaningful.isEmpty ? asked : meaningful;

  MatchEvidence? from(String text, EvidenceSource source, String label) {
    final ({String excerpt, List<(int, int)> spans})? e = _excerpt(text, terms);
    if (e == null) return null;
    return MatchEvidence(
      source: source,
      label: label,
      excerpt: e.excerpt,
      spans: e.spans,
    );
  }

  final MatchEvidence? found =
      from(notes, EvidenceSource.note, 'Your note') ??
      from(place, EvidenceSource.met, 'Where you met') ??
      _firstField(fields, from) ??
      from(printed, EvidenceSource.printed, 'Printed on the card');
  if (found != null) return found;

  if (noteMeaning && notes.trim().isNotEmpty) {
    final String flat = _flatten(notes);
    return MatchEvidence(
      source: EvidenceSource.noteMeaning,
      label: 'Close in meaning to your note',
      excerpt: flat.length <= excerptLength
          ? flat
          : '${flat.substring(0, excerptLength).trimRight()}…',
    );
  }
  return const MatchEvidence(
    source: EvidenceSource.meaning,
    label: 'Similar meaning',
  );
}

MatchEvidence? _firstField(
  Map<String, List<String>> fields,
  MatchEvidence? Function(String, EvidenceSource, String) from,
) {
  for (final MapEntry<String, List<String>> f in fields.entries) {
    for (final String value in f.value) {
      final MatchEvidence? e = from(value, EvidenceSource.field, f.key);
      if (e != null) return e;
    }
  }
  return null;
}

String _flatten(String text) => text
    .replaceAll(RegExp(r'\s*\n\s*'), ' · ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final RegExp _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

({String excerpt, List<(int, int)> spans})? _excerpt(
  String text,
  List<QueryTerm> terms,
) {
  final String flat = _flatten(text);
  if (flat.isEmpty) return null;

  final List<(int, int)> all = <(int, int)>[
    for (final RegExpMatch m in _word.allMatches(flat))
      if (terms.any(
        (QueryTerm t) => termMatchesAny(t, <String>[m[0]!.toLowerCase()]),
      ))
        (m.start, m.end),
  ];
  if (all.isEmpty) return null;

  // A window around the first match, starting a little before it so the
  // word lands in context rather than at the very edge.
  int start = 0;
  int end = flat.length;
  if (flat.length > excerptLength) {
    start = (all.first.$1 - excerptLength ~/ 4).clamp(0, flat.length);
    end = (start + excerptLength).clamp(0, flat.length);
    if (end == flat.length) start = (end - excerptLength).clamp(0, end);
    // Never cut a word in half.
    while (start > 0 &&
        _isWordChar(flat, start - 1) &&
        _isWordChar(flat, start)) {
      start--;
    }
    while (end < flat.length &&
        _isWordChar(flat, end - 1) &&
        _isWordChar(flat, end)) {
      end++;
    }
  }

  final String head = start > 0 ? '…' : '';
  final String tail = end < flat.length ? '…' : '';
  final String body = flat.substring(start, end).trim();
  final int offset =
      head.length -
      start -
      (flat.substring(start, end).length -
          flat.substring(start, end).trimLeft().length);
  return (
    excerpt: '$head$body$tail',
    spans: <(int, int)>[
      for (final (int, int) s in all)
        if (s.$1 >= start && s.$2 <= end) (s.$1 + offset, s.$2 + offset),
    ],
  );
}

bool _isWordChar(String s, int i) => _word.hasMatch(s[i]);
