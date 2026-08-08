import 'dart:math' as math;

import '../intelligence/ocr_engine.dart';
import 'phone.dart';
import 'web.dart';

/// Field keys, as a closed vocabulary. Anything not in here cannot be searched
/// or filtered on, so new keys are a deliberate decision rather than a typo.
abstract final class FieldKeys {
  static const String personName = 'person_name';
  static const String company = 'company';
  static const String designation = 'designation';
  static const String phone = 'phone';
  static const String email = 'email';
  static const String website = 'website';
  static const String address = 'address';

  static const List<String> all = <String>[
    personName,
    company,
    designation,
    phone,
    email,
    website,
    address,
  ];
}

/// One field pulled off a card, with everything the review screen needs to show
/// it honestly: how sure we are, where on the image it came from, and whether a
/// validator objected.
class ExtractedField {
  const ExtractedField({
    required this.fieldKey,
    required this.value,
    required this.confidence,
    this.normalizedValue,
    this.rawText,
    this.regionRect,
    this.issue,
    this.needsReview = false,
    this.sourceBlockIndex,
  });

  final String fieldKey;

  /// What to show the user. Usually exactly what OCR read, but for values with
  /// a known canonical form — phone numbers — this is the corrected version,
  /// because a number missing a digit is not something anyone can dial.
  final String value;

  final String? normalizedValue;

  /// Exactly what OCR returned, when [value] differs from it. Kept so the
  /// review screen can show the user what was on the card next to what we
  /// think it means, rather than silently replacing one with the other.
  final String? rawText;

  /// 0.0–1.0, combining OCR confidence with how sure the assignment is.
  final double confidence;

  /// "left,top,right,bottom" — lets the UI highlight the pixels this came from.
  final String? regionRect;

  /// Set when a validator disagreed. Displayed, never silently dropped.
  final String? issue;

  final bool needsReview;

  /// Index into the block list, so the caller can mark that block assigned.
  final int? sourceBlockIndex;

  @override
  String toString() => '$fieldKey="$value" (${confidence.toStringAsFixed(2)})'
      '${issue == null ? "" : " [$issue]"}';
}

/// The result of reading one card.
class CardExtraction {
  const CardExtraction({
    required this.fields,
    required this.unassignedBlockIndices,
  });

  final List<ExtractedField> fields;

  /// Blocks whose text was read but which no field claimed. These are what the
  /// tap-to-assign picker offers: the words are already here, so repairing a
  /// bad layout costs taps rather than typing.
  final List<int> unassignedBlockIndices;

  bool get isEmpty => fields.isEmpty;

  Iterable<ExtractedField> ofKey(String key) =>
      fields.where((ExtractedField f) => f.fieldKey == key);

  ExtractedField? firstOfKey(String key) {
    for (final ExtractedField f in fields) {
      if (f.fieldKey == key) return f;
    }
    return null;
  }

  /// True when enough was found to call the extraction useful. Below this the
  /// card is saved as `partial` and routed to the note prompt instead of a form.
  bool get isUseful =>
      firstOfKey(FieldKeys.phone) != null ||
      firstOfKey(FieldKeys.email) != null ||
      (firstOfKey(FieldKeys.personName) != null &&
          firstOfKey(FieldKeys.company) != null);
}

/// Assigns OCR blocks to card fields using deterministic rules.
///
/// No model is involved. Phones, emails and URLs are found by pattern; names,
/// companies and designations by layout and keyword. This is not a fallback for
/// when the LLM is missing — it is the primary path, because a 1B on-device
/// model is markedly worse at this than a regex, and far slower.
abstract final class CardFieldExtractor {
  /// Job titles seen on Bangladeshi cards. Matched as whole words so that
  /// "Mdina Traders" is not read as "MD".
  static const List<String> designationKeywords = <String>[
    'ceo', 'cto', 'coo', 'cfo', 'md', 'managing director', 'director',
    'chairman', 'president', 'vice president', 'founder', 'co-founder',
    'partner', 'proprietor', 'owner', 'manager', 'senior manager',
    'assistant manager', 'general manager', 'executive', 'sales executive',
    'marketing executive', 'officer', 'engineer', 'consultant', 'advisor',
    'head', 'chief', 'supervisor', 'coordinator', 'analyst', 'accountant',
    'advocate', 'architect', 'designer', 'developer', 'in charge',
    'incharge', 'representative', 'agent', 'assistant', 'associate',
  ];

  /// Tokens that mark a line as a postal address.
  static const List<String> addressKeywords = <String>[
    'road', 'rd.', 'house', 'flat', 'level', 'floor', 'block', 'sector',
    'avenue', 'lane', 'plot', 'suite', 'tower', 'plaza', 'market',
    'dhaka', 'chittagong', 'chattogram', 'sylhet', 'rajshahi', 'khulna',
    'barisal', 'rangpur', 'mymensingh', 'comilla', 'narayanganj',
    'gulshan', 'banani', 'dhanmondi', 'uttara', 'mirpur', 'motijheel',
    'bashundhara', 'mohakhali', 'badda', 'tejgaon', 'farmgate', 'shantinagar',
    'bangladesh',
  ];

  /// Suffixes that mark a line as an organization rather than a person.
  static const List<String> companyKeywords = <String>[
    'ltd', 'limited', 'pvt', 'private', 'inc', 'llc', 'corp', 'corporation',
    'company', 'co.', 'enterprise', 'enterprises', 'trading', 'traders',
    'industries', 'group', 'agency', 'agencies', 'solutions', 'services',
    'systems', 'technologies', 'tech', 'associates', 'international',
    'store', 'shop', 'house', 'centre', 'center', 'mart', 'bazar', 'bazaar',
    'press', 'printers', 'printing', 'studio', 'clinic', 'hospital',
    'pharmacy', 'restaurant', 'hotel', 'books', 'library',
  ];

  /// Reads [blocks] into fields.
  ///
  /// Never throws and never returns null: a card that yields nothing produces an
  /// empty extraction, which the caller turns into a note prompt.
  static CardExtraction extract(List<OcrBlock> blocks) {
    if (blocks.isEmpty) {
      return const CardExtraction(
        fields: <ExtractedField>[],
        unassignedBlockIndices: <int>[],
      );
    }

    final List<ExtractedField> fields = <ExtractedField>[];
    final Set<int> claimed = <int>{};

    _extractPatterns(blocks, fields, claimed);
    _extractAddress(blocks, fields, claimed);
    _extractDesignation(blocks, fields, claimed);
    _extractNameAndCompany(blocks, fields, claimed);
    _applyCrossFieldChecks(fields);

    final List<int> unassigned = <int>[
      for (int i = 0; i < blocks.length; i++)
        if (!claimed.contains(i) && blocks[i].text.trim().isNotEmpty) i,
    ];

    return CardExtraction(
      fields: fields,
      unassignedBlockIndices: unassigned,
    );
  }

  // --- Pattern-based fields: phone, email, website -------------------------

  static void _extractPatterns(
    List<OcrBlock> blocks,
    List<ExtractedField> out,
    Set<int> claimed,
  ) {
    final Set<String> seenPhones = <String>{};
    final Set<String> seenEmails = <String>{};
    final Set<String> seenSites = <String>{};

    for (int i = 0; i < blocks.length; i++) {
      final OcrBlock block = blocks[i];
      final double ocr = _confidenceOf(block);

      for (final PhoneMatch p in PhoneExtractor.extractAll(block.text)) {
        final String key = p.isValid ? p.e164 : p.raw;
        if (!seenPhones.add(key)) continue;

        final String raw = p.raw.trim();
        // Show the dialable form. When OCR lost the leading zero the parser
        // still resolves the number correctly, and the display should reflect
        // what the user needs rather than what the engine misread.
        final String display = p.isValid && p.e164.isNotEmpty
            ? PhoneExtractor.formatNational(p.e164)
            : raw;

        out.add(ExtractedField(
          fieldKey: FieldKeys.phone,
          value: display,
          rawText: display == raw ? null : raw,
          normalizedValue: p.e164.isEmpty ? null : p.e164,
          confidence: p.isValid ? ocr : ocr * 0.5,
          regionRect: _rectOf(block),
          issue: p.issue?.name ??
              (p.repaired
                  ? 'ocr_repaired'
                  : display == raw
                      ? null
                      : 'digit_restored'),
          // Restoring a digit is an inference, so it gets confirmed like any
          // other guess.
          needsReview: p.needsReview || display != raw,
          sourceBlockIndex: i,
        ));
        claimed.add(i);
      }

      for (final EmailMatch e in WebExtractor.extractEmails(block.text)) {
        if (!seenEmails.add(e.normalized)) continue;

        out.add(ExtractedField(
          fieldKey: FieldKeys.email,
          value: e.raw.trim(),
          normalizedValue: e.normalized,
          confidence: e.isValid ? ocr : ocr * 0.5,
          regionRect: _rectOf(block),
          issue: e.issue ?? (e.repaired ? 'ocr_repaired' : null),
          needsReview: e.needsReview,
          sourceBlockIndex: i,
        ));
        claimed.add(i);
      }

      for (final WebsiteMatch w in WebExtractor.extractWebsites(block.text)) {
        if (!seenSites.add(w.domain)) continue;

        out.add(ExtractedField(
          fieldKey: FieldKeys.website,
          value: w.raw.trim(),
          normalizedValue: w.domain,
          confidence: ocr,
          regionRect: _rectOf(block),
          sourceBlockIndex: i,
        ));
        claimed.add(i);
      }
    }
  }

  // --- Keyword-based fields -----------------------------------------------

  /// A numbered unit: `Shop No:278`, `House 42`, `Flat No. 5B`, `Level 3`.
  ///
  /// This pattern rather than a bare `shop` keyword, because the word on its
  /// own is far more often part of a business name — "The Coffee Shop" is not
  /// an address. Requiring the number is what separates the two.
  /// Matches `Shop No:278`, `Shop # 12`, `House 42`, `Flat No. 5B`, `Level 3`.
  ///
  /// The "No" word and the separator are independently optional, because cards
  /// write this every possible way — `No:278`, `No. 5B`, `#12`, or just a bare
  /// number.
  static final RegExp _numberedUnit = RegExp(
    r'\b(shop|house|holding|flat|apartment|suite|room|level|floor|plot|'
    r'block|sector|building|unit)\b\.?\s*(?:no\b\.?)?\s*[:#.\-]?\s*\d',
    caseSensitive: false,
  );

  /// A Bangladeshi postcode as printed: `Dhaka-1205`.
  static final RegExp _postcode = RegExp(r'[A-Za-z]\s*-\s*\d{4}\b');

  static bool _looksLikeAddress(String text) =>
      _containsWord(text, addressKeywords) ||
      _numberedUnit.hasMatch(text) ||
      _postcode.hasMatch(text);

  static void _extractAddress(
    List<OcrBlock> blocks,
    List<ExtractedField> out,
    Set<int> claimed,
  ) {
    final List<int> hits = <int>[];
    for (int i = 0; i < blocks.length; i++) {
      if (claimed.contains(i)) continue;
      if (_looksLikeAddress(blocks[i].text)) hits.add(i);
    }
    if (hits.isEmpty) return;

    // Addresses usually wrap across consecutive lines; join them so the map
    // action gets something complete rather than "House 42".
    final String joined =
        hits.map((int i) => blocks[i].text.trim()).join(', ');

    out.add(ExtractedField(
      fieldKey: FieldKeys.address,
      value: joined,
      confidence: _confidenceOf(blocks[hits.first]) * 0.8,
      regionRect: _rectOf(blocks[hits.first]),
      sourceBlockIndex: hits.first,
    ));
    claimed.addAll(hits);
  }

  static void _extractDesignation(
    List<OcrBlock> blocks,
    List<ExtractedField> out,
    Set<int> claimed,
  ) {
    final double maxSize = _maxTextSize(blocks);

    for (int i = 0; i < blocks.length; i++) {
      if (claimed.contains(i)) continue;

      final String text = blocks[i].text.trim();
      if (text.isEmpty || text.length > 60) continue;
      if (!_containsWord(text, designationKeywords)) continue;

      // A job title is never the biggest thing printed on a card. Without this
      // check, a shop called "President" or "Director" — both real, both common
      // — gets filed as somebody's rank instead of the business name.
      if (_isProminent(blocks[i], maxSize)) continue;

      out.add(ExtractedField(
        fieldKey: FieldKeys.designation,
        value: text,
        confidence: _confidenceOf(blocks[i]) * 0.85,
        regionRect: _rectOf(blocks[i]),
        sourceBlockIndex: i,
      ));
      claimed.add(i);
      return;
    }
  }

  /// Local parts that belong to a business rather than a person.
  static const Set<String> _genericEmailLocals = <String>{
    'info', 'sales', 'contact', 'admin', 'support', 'office', 'hello',
    'enquiry', 'enquiries', 'inquiry', 'mail', 'help', 'service', 'services',
    'marketing', 'accounts', 'booking', 'bookings', 'order', 'orders',
  };

  /// Picks the organization, and a person only when one is actually there.
  ///
  /// The signal is typography: the most prominent leftover line is the business.
  /// Whether a *person* is also on the card is a separate question, and the
  /// answer is frequently no — shop and service cards across Bangladesh carry a
  /// brand, a phone number and an address, and nothing else.
  ///
  /// The previous version always assigned both, so every shop card invented a
  /// contact named after the shop. That is worse than leaving the field empty:
  /// a wrong person is permanent, it pollutes duplicate detection, and the user
  /// has no reason to go looking for it.
  static void _extractNameAndCompany(
    List<OcrBlock> blocks,
    List<ExtractedField> out,
    Set<int> claimed,
  ) {
    final List<int> candidates = <int>[
      for (int i = 0; i < blocks.length; i++)
        if (!claimed.contains(i) &&
            blocks[i].text.trim().isNotEmpty &&
            blocks[i].text.trim().length <= 80)
          i,
    ];
    if (candidates.isEmpty) return;

    // Bigger text first; ties break toward the top of the card. Size is the
    // short side of the box so a card photographed sideways ranks the same as
    // one held straight — see [_textSize].
    candidates.sort((int a, int b) {
      final int bySize = _textSize(blocks[b]).compareTo(_textSize(blocks[a]));
      if (bySize != 0) return bySize;
      return blocks[a].rect.top.compareTo(blocks[b].rect.top);
    });

    final String? knownDomain = out
        .where((ExtractedField f) =>
            f.fieldKey == FieldKeys.website || f.fieldKey == FieldKeys.email)
        .map((ExtractedField f) => f.normalizedValue)
        .whereType<String>()
        .map((String v) => v.contains('@') ? v.split('@').last : v)
        .firstOrNull;

    bool looksLikeCompany(int i) {
      final String text = blocks[i].text.trim();
      return _containsWord(text, companyKeywords) ||
          (knownDomain != null && _matchesDomain(text, knownDomain));
    }

    // The organization is whichever leftover line carries company signals, or
    // failing that simply the most prominent one.
    final int companyIndex =
        candidates.firstWhere(looksLikeCompany, orElse: () => candidates.first);
    final bool companyIsConfident = looksLikeCompany(companyIndex);

    if (!claimed.contains(companyIndex)) {
      out.add(ExtractedField(
        fieldKey: FieldKeys.company,
        value: blocks[companyIndex].text.trim(),
        confidence: _confidenceOf(blocks[companyIndex]) *
            (companyIsConfident ? 0.85 : 0.7),
        regionRect: _rectOf(blocks[companyIndex]),
        needsReview: true,
        sourceBlockIndex: companyIndex,
      ));
      claimed.add(companyIndex);
    }

    final int? nameIndex = _findPerson(
      blocks: blocks,
      candidates: candidates,
      out: out,
      companyIndex: companyIndex,
      companyIsConfident: companyIsConfident,
      looksLikeCompany: looksLikeCompany,
    );
    if (nameIndex == null || claimed.contains(nameIndex)) return;

    out.add(ExtractedField(
      fieldKey: FieldKeys.personName,
      value: blocks[nameIndex].text.trim(),
      confidence: _confidenceOf(blocks[nameIndex]) * 0.7,
      regionRect: _rectOf(blocks[nameIndex]),
      needsReview: true, // Layout is a guess; always worth a glance.
      sourceBlockIndex: nameIndex,
    ));
    claimed.add(nameIndex);
  }

  /// Which leftover line, if any, is a human being.
  ///
  /// Returns null unless something on the card actually indicates a person.
  /// Three things count as evidence, in descending order of reliability:
  ///
  ///  1. **A job title was found.** Titles belong to people.
  ///  2. **A personal email local part** — `kamal@` rather than `info@`.
  ///  3. **A confidently identified company plus a second prominent line with
  ///     no company signals of its own.** If we know which line is the
  ///     business, a different line of similar weight is usually the person.
  ///
  /// Absent all three, the card is treated as a business-only card.
  static int? _findPerson({
    required List<OcrBlock> blocks,
    required List<int> candidates,
    required List<ExtractedField> out,
    required int companyIndex,
    required bool companyIsConfident,
    required bool Function(int) looksLikeCompany,
  }) {
    final List<int> others =
        candidates.where((int i) => i != companyIndex).toList();
    if (others.isEmpty) return null;

    final bool hasDesignation =
        out.any((ExtractedField f) => f.fieldKey == FieldKeys.designation);

    final bool hasPersonalEmail = out
        .where((ExtractedField f) => f.fieldKey == FieldKeys.email)
        .map((ExtractedField f) => f.normalizedValue)
        .whereType<String>()
        .any((String email) {
      final String local = email.split('@').first;
      return local.isNotEmpty &&
          !_genericEmailLocals.contains(local) &&
          !RegExp(r'^\d+$').hasMatch(local);
    });

    if (!hasDesignation && !hasPersonalEmail && !companyIsConfident) {
      return null;
    }

    // Whichever remaining line looks least like a business.
    for (final int i in others) {
      if (looksLikeCompany(i)) continue;
      if (_looksLikeAddress(blocks[i].text)) continue;
      return i;
    }
    return null;
  }

  // --- Cross-field sanity --------------------------------------------------

  /// Catches assignments that are individually plausible but wrong together.
  ///
  /// Missing data is visible and self-correcting; wrong data is invisible and
  /// corrosive. These checks exist to make the second kind visible.
  static void _applyCrossFieldChecks(List<ExtractedField> fields) {
    for (int i = 0; i < fields.length; i++) {
      final ExtractedField f = fields[i];

      if (f.fieldKey == FieldKeys.personName) {
        final ExtractedField? company = fields
            .where((ExtractedField o) => o.fieldKey == FieldKeys.company)
            .firstOrNull;

        if (company != null &&
            company.value.toLowerCase() == f.value.toLowerCase()) {
          fields[i] = _flag(f, 'same_as_company');
          continue;
        }
        // A "name" carrying address words is a misassigned address line.
        if (_containsWord(f.value, addressKeywords)) {
          fields[i] = _flag(f, 'looks_like_address');
        }
      }
    }
  }

  static ExtractedField _flag(ExtractedField f, String issue) =>
      ExtractedField(
        fieldKey: f.fieldKey,
        value: f.value,
        normalizedValue: f.normalizedValue,
        confidence: f.confidence * 0.5,
        regionRect: f.regionRect,
        issue: issue,
        needsReview: true,
        sourceBlockIndex: f.sourceBlockIndex,
      );

  // --- Helpers -------------------------------------------------------------

  /// Whole-word, case-insensitive match, so "MD" hits "MD" but not "Mdina".
  static bool _containsWord(String text, List<String> words) {
    final String lower = text.toLowerCase();
    for (final String w in words) {
      final String pattern = RegExp.escape(w);
      if (RegExp('(?:^|[^a-z0-9])$pattern(?:[^a-z0-9]|\$)').hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  /// Does this line look like the name behind [domain]? `Medica Books` against
  /// `medicabooks.com.bd` should match.
  static bool _matchesDomain(String text, String domain) {
    final String label = domain.split('.').first;
    final String squashed =
        text.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (squashed.isEmpty || label.length < 4) return false;
    return squashed.contains(label) || label.contains(squashed);
  }

  /// Engines that report no confidence are treated as middling rather than
  /// perfect, so unknown never masquerades as certain.
  static double _confidenceOf(OcrBlock b) =>
      b.hasConfidence ? b.confidence : 0.6;

  static String _rectOf(OcrBlock b) =>
      '${b.rect.left.round()},${b.rect.top.round()},'
      '${b.rect.right.round()},${b.rect.bottom.round()}';

  /// How large the text in [b] is drawn, independent of orientation.
  ///
  /// The short side of the box, not its height. ML Kit returns axis-aligned
  /// rectangles, so a card photographed sideways gives tall narrow boxes where
  /// the *width* is the text size. Using height directly ranked a rotated
  /// card's longest line as its biggest, which is how a shop's address came out
  /// more prominent than its name.
  static double _textSize(OcrBlock b) =>
      math.min(b.rect.width, b.rect.height);

  static double _maxTextSize(List<OcrBlock> blocks) => blocks.isEmpty
      ? 0
      : blocks
          .map(_textSize)
          .reduce((double a, double b) => math.max(a, b));

  /// Whether [b] is one of the visually dominant lines on the card.
  ///
  /// The threshold is deliberately generous: on the card that prompted this,
  /// the brand and the shop name were within a few percent of each other, and
  /// only one of them needed to be excluded from the designation pass for the
  /// result to be right.
  static bool _isProminent(OcrBlock b, double maxSize) =>
      maxSize > 0 && _textSize(b) >= maxSize * 0.75;

  /// Largest text size on the card, for callers scoring prominence themselves.
  static double maxTextHeight(List<OcrBlock> blocks) => _maxTextSize(blocks);
}
