/// Turning what someone typed into something FTS5 will accept.
///
/// SQLite's MATCH operator takes a query *language*, not a string — `-`, `"`,
/// `*`, `(`, `OR` and `NEAR` all mean something. Passing raw user input
/// straight through means a search for "t-shirt" or "01711-223344" throws
/// `fts5: syntax error` and the screen goes blank with no explanation. Cards
/// are full of hyphens and colons, so this is not an edge case.
library;

/// Builds a MATCH expression from free text.
///
/// Returns null when there is nothing searchable left, which the caller should
/// treat as "no query" rather than "no results".
///
/// Terms are OR-ed rather than AND-ed, and each gets a prefix wildcard. Recall
/// matters more than precision here because ranking happens afterwards: RRF
/// fuses this with the vector arm and the utility score sorts what survives, so
/// a term that only half-matches costs a position rather than a result.
///
/// Short terms are the exception (see [QueryTerm.prefix]).
String? buildFtsQuery(String raw) {
  final List<QueryTerm> terms = queryTerms(raw);
  if (terms.isEmpty) return null;

  // Each term is double-quoted so FTS5 reads it as a literal string rather than
  // as syntax, and any internal quote is escaped by doubling it — the SQLite
  // convention. The `*` sits outside the quotes, where FTS5 expects it.
  return terms.map(ftsTermExpression).join(' OR ');
}

/// The MATCH expression for one term on its own — also what counting how
/// many cards contain a term uses, so a term's rarity is measured by the same
/// rule that matched it.
String ftsTermExpression(QueryTerm t) {
  final String quoted = '"${t.text.replaceAll('"', '""')}"';
  if (!t.prefix) return quoted;
  // A short word still being typed matches as a prefix so the results do
  // not blank mid-word, and as itself too, so a card that has the whole
  // word ("AC") outranks one that merely starts with it ("Accounts").
  if (isShortTerm(t.text)) return '$quoted OR $quoted*';
  return '$quoted*';
}

/// Terms this short are matched as whole words, not as prefixes.
///
/// As a prefix, "ac" matched "accounts", "academy" and "accountant", which
/// made a two-letter acronym look as common as "repair" and put a laptop
/// repairer above the person who services ACs (seen on the phone, 4 Oct).
/// Short query words are nearly always whole words — an acronym, a unit
/// number, an initial — so matching them exactly costs almost nothing.
const int kShortTermLength = 2;

bool isShortTerm(String term) => term.length <= kShortTermLength;

/// One word of a query, and whether it may match as a prefix.
class QueryTerm {
  const QueryTerm(this.text, {required this.prefix});

  /// Lowercased, as the index stores it.
  final String text;

  /// Long words always may. A short word may only while it is still being
  /// typed — the last word of the query, with nothing after it — because
  /// search runs on every keystroke and "pr" on the way to "printing" must
  /// not empty the screen. Once another word or a space follows, the user
  /// has finished it and it is matched exactly.
  final bool prefix;

  @override
  String toString() => prefix ? '$text*' : text;
}

/// The words a query is made of, each with how it may match.
List<QueryTerm> queryTerms(String raw) {
  final List<String> words = _terms(raw);
  if (words.isEmpty) return const <QueryTerm>[];

  // A query ending on a letter or digit is mid-word; one ending in a space
  // or punctuation is not.
  final bool lastIsOpen = RegExp(r'[\p{L}\p{N}]$', unicode: true).hasMatch(raw);

  return <QueryTerm>[
    for (int i = 0; i < words.length; i++)
      QueryTerm(
        words[i],
        prefix: !isShortTerm(words[i]) || (i == words.length - 1 && lastIsOpen),
      ),
  ];
}

/// The individual words a query is made of, lowercased.
///
/// Splits on anything that is not a letter or digit, which is what the FTS5
/// `unicode61` tokenizer does to the indexed side. Keeping both sides
/// consistent is the whole point: `01711-223344` indexes as `01711` and
/// `223344`, so the query has to break the same way or it will never match.
List<String> _terms(String raw) {
  return raw
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((String t) => t.isNotEmpty)
      .toList();
}

/// The words of [text] as the index sees them.
List<String> textWords(String text) => _terms(text);

/// Which of the query's terms actually appear in [text].
///
/// Used to explain a match in the user's own words — "matched *cheap*,
/// *printing*" — rather than showing them a relevance score they cannot act on.
/// Follows the same rule as the MATCH expression, so the explanation never
/// claims a word the search itself would not have matched: a finished "ac"
/// does not claim "account".
List<String> matchedTerms(String query, String text) {
  final Set<String> haystack = _terms(text).toSet();
  final List<String> hits = <String>[];

  for (final QueryTerm term in queryTerms(query)) {
    if (hits.contains(term.text)) continue;
    if (termMatchesAny(term, haystack)) hits.add(term.text);
  }
  return hits;
}

/// Whether [term] matches any of [words], by the same rule as the MATCH.
bool termMatchesAny(QueryTerm term, Iterable<String> words) => term.prefix
    ? words.any((String w) => w.startsWith(term.text))
    : words.contains(term.text);
