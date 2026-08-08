import 'digits.dart';

/// Why a candidate phone number was rejected or flagged.
enum PhoneIssue {
  /// Fewer digits than any real number.
  tooShort,

  /// More digits than E.164 permits.
  tooLong,

  /// Right length for a Bangladeshi mobile, but `01X` is not an allocated
  /// operator prefix. Usually a misread digit.
  unknownOperator,

  /// Could not be resolved to a dialable form.
  unrecognizedFormat,
}

/// What kind of line a match resolved to.
///
/// This drives more than labelling. Mobile numbers are validated against the
/// allocated operator prefixes, so a mobile match is *specific*; landlines are
/// accepted on shape alone, so a landline match is *weak*. When one reading of
/// a candidate gives a mobile and another gives a landline, the mobile is
/// almost always the real one.
enum PhoneKind { mobile, landline, international, unknown }

/// A phone number found in card text.
class PhoneMatch {
  const PhoneMatch({
    required this.raw,
    required this.e164,
    required this.isValid,
    this.kind = PhoneKind.unknown,
    this.operator,
    this.issue,
    this.repaired = false,
  });

  /// Exactly as it appeared, kept so the review screen can show the user what
  /// was on the card rather than our cleaned-up version.
  final String raw;

  /// `+8801711223344`. Empty when the number could not be normalised.
  final String e164;

  final bool isValid;

  final PhoneKind kind;

  /// Operator name when it could be identified from the prefix. Not shown to
  /// the user — used as a validation signal.
  final String? operator;

  final PhoneIssue? issue;

  /// True when confusable repair was needed to reach a valid number. These are
  /// surfaced for confirmation rather than accepted silently.
  final bool repaired;

  bool get needsReview => !isValid || repaired;

  @override
  String toString() =>
      'PhoneMatch($raw -> $e164${isValid ? "" : " [${issue?.name}]"}'
      '${repaired ? " repaired" : ""})';

  @override
  bool operator ==(Object other) =>
      other is PhoneMatch && other.e164 == e164 && other.raw == raw;

  @override
  int get hashCode => Object.hash(e164, raw);
}

/// Finds and normalises phone numbers on Bangladeshi cards.
///
/// Phone numbers are the single most valuable thing on a card and — usefully —
/// they are written in Latin digits even on otherwise all-Bengali cards. That
/// makes them reachable by the free, fast, offline Latin OCR path, which is why
/// this runs as deterministic Dart rather than going anywhere near a model.
abstract final class PhoneExtractor {
  /// Allocated mobile prefixes, per the BTRC numbering plan, keyed by the full
  /// national prefix as written on a card. `010`–`012` are spare or retired
  /// (Citycell closed in 2016) and are treated as invalid.
  static const Map<String, String> mobileOperators = <String, String>{
    '013': 'Grameenphone',
    '014': 'Banglalink',
    '015': 'Teletalk',
    '016': 'Airtel',
    '017': 'Grameenphone',
    '018': 'Robi',
    '019': 'Banglalink',
  };

  static const String _countryCode = '880';

  /// Runs of characters that could plausibly be a number. Deliberately loose —
  /// candidates are validated afterwards, and missing a number costs more than
  /// testing a few extra strings.
  static final RegExp _candidate = RegExp(
    r'[+]?[\d০-৯][\d০-৯\s\-.()/]{5,}',
  );

  /// Separates several numbers written into one field: "01711-223344, 01911-556677".
  static final RegExp _splitters = RegExp(r'[,;/]|\s+(?:and|&|or)\s+');

  /// Extracts every distinct phone number in [text].
  ///
  /// Results are de-duplicated by E.164, so the same number written two ways on
  /// one card yields one entry.
  static List<PhoneMatch> extractAll(String text) {
    if (text.trim().isEmpty) return const <PhoneMatch>[];

    final String latin = Digits.toLatin(text);
    final List<PhoneMatch> found = <PhoneMatch>[];
    final Set<String> seen = <String>{};

    for (final RegExpMatch m in _candidate.allMatches(latin)) {
      for (final String piece in m.group(0)!.split(_splitters)) {
        final PhoneMatch? parsed = parse(piece);
        if (parsed == null) continue;

        // Invalid numbers are still surfaced (the user may want to fix one),
        // but we key on the raw text so they do not collapse together.
        final String key = parsed.isValid ? parsed.e164 : parsed.raw.trim();
        if (seen.add(key)) found.add(parsed);
      }
    }
    return found;
  }

  /// Parses a single candidate. Returns null when it is not number-shaped
  /// enough to bother with.
  static PhoneMatch? parse(String candidate) {
    final String raw = candidate.trim();
    if (raw.isEmpty) return null;

    final String latin = Digits.toLatin(raw);

    // Reject anything mostly made of letters before attempting repair —
    // otherwise a word like "Dhanmondi" gets mangled into a number.
    if (Digits.digitRatio(latin) < 0.6) return null;

    // Both readings are computed, then ranked. Taking the first valid reading
    // instead would let a mangled mobile ("Ol711223344", where the O and l are
    // dropped as letters) pass as a shape-valid 9-digit landline — a silently
    // wrong number, which is the worst thing this file could produce.
    final List<PhoneMatch> readings = <PhoneMatch>[];

    final PhoneMatch? plain = _normalize(latin, raw, repaired: false);
    if (plain != null) readings.add(plain);

    final String repairedText = Digits.repairConfusables(latin);
    if (repairedText != latin) {
      final PhoneMatch? fixed = _normalize(repairedText, raw, repaired: true);
      if (fixed != null) readings.add(fixed);
    }

    if (readings.isEmpty) return null;
    readings.sort((PhoneMatch a, PhoneMatch b) {
      final int byQuality = _quality(b).compareTo(_quality(a));
      if (byQuality != 0) return byQuality;
      // Same quality: trust the reading that needed no guessing.
      if (a.repaired != b.repaired) return a.repaired ? 1 : -1;
      return 0;
    });
    return readings.first;
  }

  /// How much a reading should be trusted. A validated mobile beats a
  /// shape-only landline, which beats anything unparseable.
  static int _quality(PhoneMatch m) {
    if (!m.isValid) return 0;
    return switch (m.kind) {
      PhoneKind.mobile => 3,
      PhoneKind.international => 2,
      PhoneKind.landline => 1,
      PhoneKind.unknown => 0,
    };
  }

  static PhoneMatch? _normalize(
    String cleaned,
    String raw, {
    required bool repaired,
  }) {
    final bool hadPlus = cleaned.trimLeft().startsWith('+');
    String digits = Digits.digitsOnly(cleaned);
    if (digits.isEmpty) return null;

    if (digits.length < 6) {
      return PhoneMatch(
        raw: raw,
        e164: '',
        isValid: false,
        issue: PhoneIssue.tooShort,
        repaired: repaired,
      );
    }
    if (digits.length > 15) {
      return PhoneMatch(
        raw: raw,
        e164: '',
        isValid: false,
        issue: PhoneIssue.tooLong,
        repaired: repaired,
      );
    }

    // Peel off however the country code was written: +8801…, 8801…, 008801…
    if (digits.startsWith('00$_countryCode')) {
      digits = digits.substring(2 + _countryCode.length);
    } else if (digits.startsWith(_countryCode) && digits.length > 11) {
      digits = digits.substring(_countryCode.length);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // A local mobile is 10 national digits: `1`, the operator digit, then 8
    // subscriber digits. `digits` has already had its leading 0 removed, so the
    // prefix as printed on the card is that 0 put back on the first two.
    if (digits.startsWith('1') && digits.length == 10) {
      final String printedPrefix = '0${digits.substring(0, 2)}';
      final String? operator = mobileOperators[printedPrefix];
      return PhoneMatch(
        raw: raw,
        e164: '+$_countryCode$digits',
        isValid: operator != null,
        kind: PhoneKind.mobile,
        operator: operator,
        issue: operator == null ? PhoneIssue.unknownOperator : null,
        repaired: repaired,
      );
    }

    // Landlines: an area code (Dhaka is 2) plus subscriber digits. Area codes
    // are not enumerated — there are dozens and they change — so these are
    // accepted on shape alone. That makes a landline match weak evidence, which
    // is exactly why _quality ranks it below a validated mobile.
    if (!digits.startsWith('1') && digits.length >= 7 && digits.length <= 10) {
      return PhoneMatch(
        raw: raw,
        e164: '+$_countryCode$digits',
        isValid: true,
        kind: PhoneKind.landline,
        repaired: repaired,
      );
    }

    // A number that arrived with an explicit + is probably foreign; keep it as
    // dialled rather than forcing it into the Bangladeshi plan.
    if (hadPlus) {
      final String intl = Digits.digitsOnly(cleaned);
      return PhoneMatch(
        raw: raw,
        e164: '+$intl',
        isValid: intl.length >= 8,
        kind: PhoneKind.international,
        issue: intl.length >= 8 ? null : PhoneIssue.tooShort,
        repaired: repaired,
      );
    }

    return PhoneMatch(
      raw: raw,
      e164: '',
      isValid: false,
      issue: PhoneIssue.unrecognizedFormat,
      repaired: repaired,
    );
  }

  /// Renders [e164] the way it is written on cards and dialled locally:
  /// `+8801714066410` becomes `01714066410`.
  ///
  /// This is what the user should *see*. OCR routinely drops the leading zero
  /// on a rotated or tightly-cropped card, and showing them that mistake back
  /// is not faithfulness — the number is unreadable and undialable. The parser
  /// already knows the digit is there, because a 10-digit national number
  /// starting with an allocated operator prefix cannot be anything else.
  ///
  /// Foreign numbers are returned untouched; there is no local convention to
  /// render them in.
  static String formatNational(String e164) {
    if (!e164.startsWith('+$_countryCode')) return e164;

    final String national = e164.substring(1 + _countryCode.length);
    return national.isEmpty ? e164 : '0$national';
  }

  /// True when [e164] is a Bangladeshi mobile — the only numbers WhatsApp
  /// actions should be offered for.
  static bool isMobile(String e164) {
    if (!e164.startsWith('+$_countryCode')) return false;
    final String national = e164.substring(1 + _countryCode.length);
    return national.startsWith('1') &&
        national.length == 10 &&
        mobileOperators.containsKey('0${national.substring(0, 2)}');
  }
}
