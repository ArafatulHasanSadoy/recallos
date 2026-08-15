import 'card_extractor.dart';
import 'phone.dart';
import 'web.dart';

/// What checking one field value produced.
class FieldValidation {
  const FieldValidation({this.normalized, this.issue});

  /// Clean, with nothing to canonicalise — a company name, a designation.
  const FieldValidation.ok() : normalized = null, issue = null;

  /// Canonical form for matching: E.164 phones, lowercased emails, bare
  /// domains. Null when the value has no canonical form, or could not be
  /// resolved to one.
  final String? normalized;

  /// Why a validator objected, or null. Names match the ones extraction
  /// produces, so a repaired value looks the same however it got here.
  final String? issue;

  bool get isClean => issue == null;

  @override
  String toString() =>
      'FieldValidation(${normalized ?? "-"}${issue == null ? "" : " [$issue]"})';
}

/// Re-checks one field value on its own.
///
/// Extraction validates as it goes, but a value the user typed or reassigned
/// has never been through those checks — and an edit is exactly when a wrong
/// number gets introduced. Missing data is visible and self-correcting; wrong
/// data is invisible and corrosive, so the cheapest moment to catch it is the
/// moment it is entered.
///
/// Delegates to the same extractors the scan path uses rather than restating
/// their rules, so a number the scanner would reject cannot be accepted just
/// because it arrived by a different route.
FieldValidation validateField(String fieldKey, String value) {
  final String text = value.trim();
  if (text.isEmpty) return const FieldValidation(issue: 'empty');

  return switch (fieldKey) {
    FieldKeys.phone => _phone(text),
    FieldKeys.email => _email(text),
    FieldKeys.website => _website(text),
    FieldKeys.personName => _personName(text),
    // Company, designation and address carry no canonical form and no rule
    // worth enforcing — anything is a plausible business name.
    _ => const FieldValidation.ok(),
  };
}

FieldValidation _phone(String text) {
  final PhoneMatch? match = PhoneExtractor.parse(text);
  if (match == null) {
    return const FieldValidation(issue: 'unrecognizedFormat');
  }
  if (!match.isValid) {
    return FieldValidation(
      issue: match.issue?.name ?? 'unrecognizedFormat',
    );
  }
  return FieldValidation(
    normalized: match.e164,
    // A confusable that had to be undone to reach a dialable number is an
    // inference, so it gets shown as one rather than accepted silently.
    issue: match.repaired ? 'ocr_repaired' : null,
  );
}

FieldValidation _email(String text) {
  final List<EmailMatch> matches = WebExtractor.extractEmails(text);
  if (matches.isEmpty) return const FieldValidation(issue: 'not_an_email');

  final EmailMatch match = matches.first;
  return FieldValidation(
    normalized: match.isValid ? match.normalized : null,
    issue: match.issue ?? (match.repaired ? 'ocr_repaired' : null),
  );
}

FieldValidation _website(String text) {
  final List<WebsiteMatch> matches = WebExtractor.extractWebsites(text);
  if (matches.isEmpty) return const FieldValidation(issue: 'not_a_website');

  return FieldValidation(normalized: matches.first.domain);
}

FieldValidation _personName(String text) {
  // The same check extraction applies after assignment. A person's name that
  // carries road and city words is a misfiled address line, and saying so is
  // more useful than storing it as somebody's name.
  return CardFieldExtractor.looksLikeAddress(text)
      ? const FieldValidation(issue: 'looks_like_address')
      : const FieldValidation.ok();
}
