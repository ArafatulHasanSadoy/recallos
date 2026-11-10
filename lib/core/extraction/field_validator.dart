import '../domain/local_date.dart';
import '../domain/money.dart';
import 'card_extractor.dart';
import 'document_lines.dart';
import 'phone.dart';
import 'receipt_extractor.dart' show formatDay;
import 'web.dart';

/// What checking one field value produced.
class FieldValidation {
  const FieldValidation({
    this.normalized,
    this.issue,
    this.display,
    this.amountMinor,
    this.currency,
    this.dateValue,
  });

  /// Clean, with nothing to canonicalise — a company name, a designation.
  const FieldValidation.ok()
    : normalized = null,
      issue = null,
      display = null,
      amountMinor = null,
      currency = null,
      dateValue = null;

  /// How the value should read once understood — "BDT 8,450.50" for
  /// "8450.5", "12 Oct 2026" for "12/10/26". Null to keep what was typed.
  final String? display;

  /// A total's value in minor units, with its [currency] (receipts).
  final int? amountMinor;
  final String? currency;

  /// A date field's calendar day.
  final LocalDate? dateValue;

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
///
/// [currency] is the currency a total already had, so correcting "12.50" on
/// a dollar receipt does not turn it into taka.
FieldValidation validateField(
  String fieldKey,
  String value, {
  String? currency,
}) {
  final String text = value.trim();
  if (text.isEmpty) return const FieldValidation(issue: 'empty');

  return switch (fieldKey) {
    FieldKeys.phone => _phone(text),
    FieldKeys.email => _email(text),
    FieldKeys.website => _website(text),
    FieldKeys.personName => _personName(text),
    // Receipts and warranties (B2): typed values are re-read from the text,
    // so the stored amount or day can never disagree with what is shown.
    ReceiptKeys.total => _amount(text, currency),
    ReceiptKeys.purchaseDate || WarrantyKeys.expiryDate => _day(text),
    WarrantyKeys.coverMonths => _cover(text),
    WarrantyKeys.serial => FieldValidation(
      normalized: text.toUpperCase().replaceAll(RegExp(r'[\s-]'), ''),
    ),
    WarrantyKeys.model => FieldValidation(normalized: text.toUpperCase()),
    // Company, designation and address carry no canonical form and no rule
    // worth enforcing — anything is a plausible business name.
    _ => const FieldValidation.ok(),
  };
}

/// A run of letters inside an amount, Latin or Bangla.
final RegExp _lettersInAmount = RegExp(r'[A-Za-z\u0985-\u09B9\u09BE-\u09CC]+');

/// The only words an amount may carry: a currency's name, and "only".
const Set<String> _amountWords = <String>{
  'tk',
  'taka',
  'bdt',
  'usd',
  'inr',
  'rs',
  'eur',
  'only',
  'টাকা',
};

FieldValidation _amount(String text, String? currency) {
  // `Money.parse` keeps the digits and drops the rest, which is right for
  // "Tk 1,245/-" and wrong for anything else: a date typed in this box became
  // BDT 92,026.00, marked as confirmed. A wrong amount is worse than none.
  final bool otherWords = _lettersInAmount
      .allMatches(text)
      .any((Match m) => !_amountWords.contains(m[0]!.toLowerCase()));
  if (otherWords || findDates(text).isNotEmpty) {
    return const FieldValidation(issue: 'not_an_amount');
  }
  final Money? money = Money.parse(
    text,
    currency: currencyOf(text) ?? currency ?? 'BDT',
  );
  if (money == null) return const FieldValidation(issue: 'not_an_amount');
  return FieldValidation(
    normalized: '${money.minor}',
    display: money.format(),
    amountMinor: money.minor,
    currency: money.currency,
  );
}

FieldValidation _day(String text) {
  final List<FoundDate> found = findDates(text);
  if (found.isEmpty) return const FieldValidation(issue: 'not_a_date');
  final LocalDate day = found.first.date;
  return FieldValidation(
    normalized: day.toIso(),
    display: formatDay(day),
    dateValue: day,
  );
}

FieldValidation _cover(String text) {
  final RegExpMatch? m = RegExp(
    r'(\d{1,3})\s*(years?|yrs?|months?|mos?|মাস|বছর)?',
    caseSensitive: false,
  ).firstMatch(asciiDigits(text));
  if (m == null) return const FieldValidation(issue: 'not_a_period');
  final int n = int.parse(m[1]!);
  final String unit = (m[2] ?? 'months').toLowerCase();
  final bool years = unit.startsWith('y') || unit == 'বছর';
  final int months = years ? n * 12 : n;
  if (months <= 0 || months > 240) {
    return const FieldValidation(issue: 'not_a_period');
  }
  return FieldValidation(
    normalized: '$months',
    display: years
        ? '$n ${n == 1 ? 'year' : 'years'}'
        : '$n ${n == 1 ? 'month' : 'months'}',
  );
}

/// One validation issue, in words a person can act on.
///
/// The tokens above are deliberately machine names — they are stored in
/// `card_fields.validation_issue`, compared against, and must not change
/// meaning because somebody improved a sentence. This is the other half: the
/// one place they become English, so that no screen invents its own wording
/// and none of them ever shows a user the string `unrecognizedFormat`.
///
/// Returns null for tokens that are not a problem to report — an empty field
/// the user has not filled in yet, and a repair the app made successfully.
String? describeFieldIssue(String? issue) => switch (issue) {
  null || 'empty' || 'ocr_repaired' || 'digit_restored' => null,
  'tooShort' => 'That looks too short to dial.',
  'tooLong' => 'That is longer than a phone number can be.',
  'unknownOperator' => 'No Bangladeshi operator uses that prefix.',
  'unrecognizedFormat' => 'That does not look like a phone number.',
  'not_an_email' => 'That does not look like an email address.',
  'malformed' => 'That does not look like an email address.',
  'malformed_domain' => 'The part after the @ does not look right.',
  'implausible_tld' => 'That domain ending looks unlikely.',
  'not_a_website' => 'That does not look like a web address.',
  'looks_like_address' => 'That reads like an address rather than a name.',
  'not_an_amount' => 'That does not look like an amount.',
  'not_a_date' => 'That does not look like a date. Try 12/10/2026.',
  'not_a_period' => 'Say how long it lasts, like “2 years” or “18 months”.',
  'split_cover' =>
    'The cover is different for different parts. Check this is the one '
        'you want reminded about.',
  // An issue nobody has written a sentence for is worth saying *something*
  // about — but never the token itself.
  _ => 'That does not look right.',
};

FieldValidation _phone(String text) {
  final PhoneMatch? match = PhoneExtractor.parse(text);
  if (match == null) {
    return const FieldValidation(issue: 'unrecognizedFormat');
  }
  if (!match.isValid) {
    return FieldValidation(issue: match.issue?.name ?? 'unrecognizedFormat');
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
