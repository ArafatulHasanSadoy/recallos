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
String? buildFtsQuery(String raw) {
  final List<String> terms = _terms(raw);
  if (terms.isEmpty) return null;

  // Each term is double-quoted so FTS5 reads it as a literal string rather than
  // as syntax, and any internal quote is escaped by doubling it — the SQLite
  // convention. The `*` sits outside the quotes, where FTS5 expects it.
  return terms.map((String t) => '"${t.replaceAll('"', '""')}"*').join(' OR ');
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

/// Which of [terms] actually appear in [text].
///
/// Used to explain a match in the user's own words — "matched *cheap*,
/// *printing*" — rather than showing them a relevance score they cannot act on.
List<String> matchedTerms(String query, String text) {
  final Set<String> haystack = _terms(text).toSet();
  final List<String> hits = <String>[];

  for (final String term in _terms(query)) {
    if (hits.contains(term)) continue;
    // Prefix match, to mirror the wildcard used in the MATCH expression.
    if (haystack.any((String w) => w.startsWith(term))) hits.add(term);
  }
  return hits;
}
