/// Email address and website extraction.
///
/// Like phone numbers, these are written in Latin characters even on all-Bengali
/// cards, so they come through the free offline OCR path. That makes them worth
/// extracting carefully with plain Dart.
library;

/// An email address found in card text.
class EmailMatch {
  const EmailMatch({
    required this.raw,
    required this.normalized,
    required this.isValid,
    this.repaired = false,
    this.issue,
  });

  final String raw;

  /// Lowercased. Used for duplicate detection, so it must be canonical.
  final String normalized;

  final bool isValid;

  /// True when an OCR mangling had to be undone to reach a valid address.
  final bool repaired;

  final String? issue;

  bool get needsReview => !isValid || repaired;

  @override
  String toString() => 'EmailMatch($normalized${repaired ? " repaired" : ""})';
}

/// A website found in card text.
class WebsiteMatch {
  const WebsiteMatch({
    required this.raw,
    required this.url,
    required this.domain,
  });

  final String raw;

  /// Always carries a scheme, so it can be handed straight to url_launcher.
  final String url;

  /// Registrable domain, lowercased, `www.` stripped. A strong duplicate
  /// signal: two cards sharing a domain are very likely the same organization.
  final String domain;

  @override
  String toString() => 'WebsiteMatch($domain)';
}

abstract final class WebExtractor {
  /// Public suffixes seen on Bangladeshi cards, plus the common generics.
  ///
  /// Used to decide whether a bare token like `medicabooks.com.bd` is a domain.
  /// Multi-part suffixes are listed first so the longest match wins.
  static const List<String> knownSuffixes = <String>[
    'com.bd', 'net.bd', 'org.bd', 'edu.bd', 'gov.bd', 'ac.bd', 'mil.bd',
    'co.uk', 'co.in',
    'bd', 'com', 'net', 'org', 'info', 'biz', 'io', 'co', 'xyz', 'app',
    'dev', 'shop', 'store', 'online', 'agency', 'in',
  ];

  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );

  /// An address whose `@` the OCR turned into something else. `(a)`, `[at]`,
  /// and a bare ` at ` are the ones that actually show up.
  static final RegExp _manglendAt = RegExp(
    r'([A-Za-z0-9._%+\-]+)\s*(?:\(a\)|\[at\]|\{at\}|\s+at\s+|©|@)\s*'
    r'([A-Za-z0-9.\-]+\.[A-Za-z]{2,})',
    caseSensitive: false,
  );

  static final RegExp _url = RegExp(
    r'(?:https?://|www\.)[A-Za-z0-9.\-]+\.[A-Za-z]{2,}(?:/[^\s]*)?',
    caseSensitive: false,
  );

  /// A domain written with no scheme and no `www.`, e.g. `medicabooks.com.bd`
  /// or `facebook.com/medicabooks`. Host and path are captured separately so
  /// the public-suffix check runs against the host alone.
  static final RegExp _bareDomain = RegExp(
    r'\b([A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+)(/[^\s]*)?',
  );

  static List<EmailMatch> extractEmails(String text) {
    if (text.trim().isEmpty) return const <EmailMatch>[];

    final List<EmailMatch> found = <EmailMatch>[];
    final Set<String> seen = <String>{};

    for (final RegExpMatch m in _email.allMatches(text)) {
      final String raw = m.group(0)!;
      final EmailMatch parsed = _build(raw, raw, repaired: false);
      if (seen.add(parsed.normalized)) found.add(parsed);
    }

    // Only look for manglings in the parts no clean address already claimed,
    // otherwise every valid address matches twice.
    for (final RegExpMatch m in _manglendAt.allMatches(text)) {
      final String raw = m.group(0)!;
      if (_email.hasMatch(raw)) continue;

      final String rebuilt = '${m.group(1)}@${m.group(2)}';
      final EmailMatch parsed = _build(raw, rebuilt, repaired: true);
      if (seen.add(parsed.normalized)) found.add(parsed);
    }

    return found;
  }

  static EmailMatch _build(
    String raw,
    String candidate, {
    required bool repaired,
  }) {
    final String normalized = candidate.trim().toLowerCase();
    final int at = normalized.indexOf('@');

    if (at <= 0 || at == normalized.length - 1) {
      return EmailMatch(
        raw: raw,
        normalized: normalized,
        isValid: false,
        repaired: repaired,
        issue: 'malformed',
      );
    }

    final String domain = normalized.substring(at + 1);
    if (!domain.contains('.') || domain.startsWith('.') ||
        domain.endsWith('.')) {
      return EmailMatch(
        raw: raw,
        normalized: normalized,
        isValid: false,
        repaired: repaired,
        issue: 'malformed_domain',
      );
    }

    // A plausible public suffix is what separates a real address from OCR noise
    // that happens to contain an @.
    final bool plausible = knownSuffixes.any(
          (String s) => domain.endsWith('.$s'),
        ) ||
        RegExp(r'\.[a-z]{2,}$').hasMatch(domain);

    return EmailMatch(
      raw: raw,
      normalized: normalized,
      isValid: plausible,
      repaired: repaired,
      issue: plausible ? null : 'implausible_tld',
    );
  }

  static List<WebsiteMatch> extractWebsites(String text) {
    if (text.trim().isEmpty) return const <WebsiteMatch>[];

    final List<WebsiteMatch> found = <WebsiteMatch>[];
    final Set<String> seen = <String>{};

    // Email domains are not websites; drop them before looking.
    String remaining = text;
    for (final RegExpMatch m in _email.allMatches(text)) {
      remaining = remaining.replaceFirst(m.group(0)!, ' ');
    }

    for (final RegExpMatch m in _url.allMatches(remaining)) {
      final String raw = m.group(0)!;
      final WebsiteMatch? site = _buildSite(raw);
      if (site != null && seen.add(site.domain)) found.add(site);
      remaining = remaining.replaceFirst(raw, ' ');
    }

    for (final RegExpMatch m in _bareDomain.allMatches(remaining)) {
      final String host = m.group(1)!;
      if (!_hasKnownSuffix(host)) continue;

      final WebsiteMatch? site = _buildSite('$host${m.group(2) ?? ''}');
      if (site != null && seen.add(site.domain)) found.add(site);
    }

    return found;
  }

  static bool _hasKnownSuffix(String candidate) {
    final String lower = candidate.toLowerCase();
    return knownSuffixes.any((String s) => lower.endsWith('.$s'));
  }

  static WebsiteMatch? _buildSite(String raw) {
    String work = raw.trim().toLowerCase();
    if (work.isEmpty) return null;

    if (!work.startsWith('http://') && !work.startsWith('https://')) {
      work = 'https://$work';
    }

    final Uri? uri = Uri.tryParse(work);
    if (uri == null || uri.host.isEmpty) return null;

    String domain = uri.host;
    if (domain.startsWith('www.')) domain = domain.substring(4);
    if (!domain.contains('.')) return null;

    return WebsiteMatch(raw: raw, url: work, domain: domain);
  }

  /// The registrable domain of an email address, for matching a person's email
  /// against their employer's website.
  static String? domainOfEmail(String email) {
    final int at = email.indexOf('@');
    if (at < 0 || at == email.length - 1) return null;

    String domain = email.substring(at + 1).toLowerCase();
    if (domain.startsWith('www.')) domain = domain.substring(4);
    return domain.contains('.') ? domain : null;
  }
}
