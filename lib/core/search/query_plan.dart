/// What a query is asking for, worked out before anything is searched.
///
/// Most queries are a need — "cheap printing", "AC repair" — and are ranked.
/// Some ask for one fact about someone — "Rahim's number" — and the answer
/// to those is the fact itself, with the card it came from, not a list of
/// cards to open and read. Typed plans, never generated SQL: Ask RecallOS
/// (B5) adds more kinds of plan here, each executed by code that can say
/// what it looked at.
library;

import '../domain/local_date.dart';
import '../extraction/card_extractor.dart';
import '../spending/spending_totals.dart' show SpendingPeriod, monthNames;
import 'fts_query.dart';

sealed class QueryPlan {
  const QueryPlan(this.raw);

  /// Exactly what was typed.
  final String raw;
}

/// Rank cards against the query — the default.
final class SearchPlan extends QueryPlan {
  const SearchPlan(super.raw);
}

/// One field about someone: "Rahim's number", "email of Nusrat",
/// "TechFix address", "Rahim er number".
final class LookupPlan extends QueryPlan {
  const LookupPlan(super.raw, {required this.fieldKey, required this.subject});

  /// A [FieldKeys] value.
  final String fieldKey;

  /// Who or what it is about — a name, a company, or a need ("AC repair").
  final String subject;

  /// How the field is said back: "number", "email", "address".
  String get fieldLabel => switch (fieldKey) {
    FieldKeys.phone => 'number',
    FieldKeys.email => 'email',
    FieldKeys.address => 'address',
    FieldKeys.website => 'website',
    FieldKeys.designation => 'title',
    FieldKeys.company => 'company',
    _ => fieldKey,
  };

  @override
  String toString() => 'LookupPlan($fieldKey of "$subject")';
}

/// Which people's follow-up state a filter asks for.
enum FollowUpFilter {
  /// A next step is open: "who do I need to follow up with".
  open,

  /// Nothing planned yet: "no next step", "still need a next step".
  none,
}

/// The people that fit a description — met at an event, met in a stretch of
/// days, waiting on a next step. An exact list, not a ranking: everyone who
/// fits is in it and nobody else. Part of RecallOS Plus; without it the
/// query is searched as words, with a line saying what Plus would do.
final class PeopleFilterPlan extends QueryPlan {
  const PeopleFilterPlan(
    super.raw, {
    this.place,
    this.from,
    this.until,
    this.windowLabel,
    this.followUp,
  });

  /// Where they were met, as typed: "CSE fest".
  final String? place;

  /// Met on a day from [from] up to, not including, [until] — local days.
  final DateTime? from;
  final DateTime? until;

  /// The window in the user's words, for saying back: "last week".
  final String? windowLabel;

  final FollowUpFilter? followUp;

  /// What the list is, said back so the answer states its own scope.
  String get describe => <String>[
    if (place != null) 'Met at $place',
    if (windowLabel != null) 'Met $windowLabel',
    if (followUp == FollowUpFilter.open) 'Waiting on a next step',
    if (followUp == FollowUpFilter.none) 'No next step yet',
  ].join(' · ');

  @override
  String toString() => 'PeopleFilterPlan($describe)';
}

/// One warranty's end, by what it covers: "When does my laptop warranty
/// expire?", "is the fridge still under warranty", "where is my phone
/// warranty" (B5). A lookup, so free: the answer is the end, how it is known,
/// and the papers it came from.
final class WarrantyPlan extends QueryPlan {
  const WarrantyPlan(super.raw, {required this.subject});

  /// What the warranty is for, in the user's words: "laptop".
  final String subject;

  @override
  String toString() => 'WarrantyPlan("$subject")';
}

/// Everything that ends in a stretch of days: "What expires in the next 90
/// days?", "warranties ending this month", "what has expired", "my
/// warranties" (B5). A date query, so part of RecallOS Plus.
final class ExpiringPlan extends QueryPlan {
  const ExpiringPlan(
    super.raw, {
    required this.label,
    this.from,
    this.until,
    this.ended = false,
  });

  /// The first and last day the answer covers, both included. Both null
  /// for "my warranties": every one, soonest end first.
  final LocalDate? from;
  final LocalDate? until;

  /// Asking for the ones already over, most recent first.
  final bool ended;

  /// The window in words, for the answer's scope: "in the next 90 days".
  final String label;

  @override
  String toString() => 'ExpiringPlan($label)';
}

/// A total of saved receipts: "How much did I spend on electronics this
/// month?", "spent at Star Tech last month", "receipts total in
/// September" (B5, over B4's totals). An aggregate, so part of RecallOS
/// Plus — except this month's plain total, which the free Receipt totals
/// screen already shows.
final class SpendingPlan extends QueryPlan {
  const SpendingPlan(
    super.raw, {
    required this.period,
    this.focus,
    this.shopOnly = false,
    this.unsupported,
  });

  final SpendingPeriod period;

  /// A shop or a category, as typed: "electronics", "star tech".
  final String? focus;

  /// Said with "at" or "from", so it can only be a shop.
  final bool shopOnly;

  /// A stretch the totals do not go by — "this week", "today" — said back
  /// in the answer instead of a figure.
  final String? unsupported;

  /// Whether the free Receipt totals screen shows this answer already:
  /// this month, every shop and category.
  bool isFreeAt(DateTime now) =>
      focus == null &&
      unsupported == null &&
      period.isCurrent(now) &&
      period.isMonth;

  @override
  String toString() =>
      'SpendingPlan(${period.label}${focus == null ? '' : ', "$focus"'}'
      '${unsupported == null ? '' : ', unsupported "$unsupported"'})';
}

/// Words that name a field. Several may run together ("phone number").
const Map<String, String> _fieldWords = <String, String>{
  'number': FieldKeys.phone,
  'numbers': FieldKeys.phone,
  'phone': FieldKeys.phone,
  'mobile': FieldKeys.phone,
  'cell': FieldKeys.phone,
  'contact': FieldKeys.phone,
  'nambar': FieldKeys.phone,
  'email': FieldKeys.email,
  'mail': FieldKeys.email,
  'address': FieldKeys.address,
  'office': FieldKeys.address,
  'thikana': FieldKeys.address,
  'website': FieldKeys.website,
  'site': FieldKeys.website,
  'web': FieldKeys.website,
  'designation': FieldKeys.designation,
  'position': FieldKeys.designation,
  'company': FieldKeys.company,
};

/// Words around a lookup that carry no subject: "what is", "give me",
/// "the", and Banglish "ki", "koto", "er" (of).
const Set<String> _filler = <String>{
  'what',
  'whats',
  'is',
  'are',
  'the',
  'a',
  'give',
  'me',
  'show',
  'find',
  'get',
  'tell',
  'please',
  'pls',
  'ki',
  'koto',
  'kon',
  'ta',
  'er',
  'r',
  'e',
};

/// Works out what [raw] asks for.
///
/// A lookup only when the field word sits where a question puts it: last
/// ("Rahim's number", "TechFix address") or first and followed by "of" or
/// "for" ("email of Nusrat"). Elsewhere it is part of a need — "phone
/// repair", "number plate" — and is searched for like any other word.
QueryPlan planQuery(String raw, {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  final PeopleFilterPlan? people = _peopleFilter(raw, today);
  if (people != null) return people;

  // Purchases (B5) before lookups: "how much did the phone cost" is a
  // total, not somebody's number.
  final QueryPlan? purchase =
      _spending(raw, today) ?? _warrantyOrExpiring(raw, today);
  if (purchase != null) return purchase;

  final List<String> words = textWords(
    // "Rahim's" is Rahim; the apostrophe would otherwise leave a stray "s".
    raw.replaceAll(RegExp(r"['’]s\b", caseSensitive: false), ''),
  );
  final List<String> core = _trimFiller(words);
  if (core.length < 2) return SearchPlan(raw);

  // Field words at the end: "Rahim phone number".
  int end = core.length;
  while (end > 0 && _fieldWords.containsKey(core[end - 1])) {
    end--;
  }
  if (end < core.length && end > 0) {
    final String? key = _sameField(core.sublist(end));
    final String subject = _trimFiller(core.sublist(0, end)).join(' ');
    if (key != null && subject.isNotEmpty) {
      return LookupPlan(raw, fieldKey: key, subject: subject);
    }
  }

  // Field words first, then "of" or "for": "phone number of Rahim".
  int start = 0;
  while (start < core.length && _fieldWords.containsKey(core[start])) {
    start++;
  }
  if (start > 0 &&
      start < core.length - 1 &&
      (core[start] == 'of' || core[start] == 'for')) {
    final String? key = _sameField(core.sublist(0, start));
    final String subject = _trimFiller(core.sublist(start + 1)).join(' ');
    if (key != null && subject.isNotEmpty) {
      return LookupPlan(raw, fieldKey: key, subject: subject);
    }
  }

  return SearchPlan(raw);
}

/// The field a run of field words names, or null when they disagree
/// ("email address" is still email; "phone email" is nothing).
String? _sameField(List<String> words) {
  final Set<String> keys = <String>{
    for (final String w in words) _fieldWords[w]!,
  };
  if (keys.length == 1) return keys.single;
  if (keys.containsAll(<String>[FieldKeys.email, FieldKeys.address]) &&
      keys.length == 2) {
    return FieldKeys.email;
  }
  return null;
}

List<String> _trimFiller(List<String> words) {
  int a = 0;
  int b = words.length;
  while (a < b && _filler.contains(words[a])) {
    a++;
  }
  while (b > a && _filler.contains(words[b - 1])) {
    b--;
  }
  return words.sublist(a, b);
}

/// "met at CSE fest", "people I met last week", "who needs a next step",
/// "who do I need to follow up with" — or null when the query is not asking
/// for people by when, where or what is next.
///
/// A time or place counts only beside "met" (or "meet", "scanned"): "last
/// month" alone is a need ("last month's invoices"), not a filter.
PeopleFilterPlan? _peopleFilter(String raw, DateTime now) {
  final String q = ' ${textWords(raw).join(' ')} ';

  FollowUpFilter? followUp;
  if (RegExp(
    r' (no|without|need|needs|still need|still needs) (a )?next step ',
  ).hasMatch(q)) {
    followUp = FollowUpFilter.none;
  } else if (RegExp(
    r' (follow up|followup|follow ups|followups|next steps) ',
  ).hasMatch(q)) {
    followUp = FollowUpFilter.open;
  }

  final bool met = RegExp(r' (met|meet|scanned) ').hasMatch(q);

  ({DateTime from, DateTime until, String label})? window;
  if (met) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) =>
        DateTime(today.year, today.month, today.day + offset);
    for (final (String phrase, DateTime from, DateTime until)
        in <(String, DateTime, DateTime)>[
          ('today', today, day(1)),
          ('yesterday', day(-1), today),
          ('this week', day(-6), day(1)),
          ('last week', day(-13), day(-6)),
          (
            'this month',
            DateTime(today.year, today.month),
            DateTime(today.year, today.month + 1),
          ),
          (
            'last month',
            DateTime(today.year, today.month - 1),
            DateTime(today.year, today.month),
          ),
        ]) {
      if (q.contains(' $phrase ')) {
        window = (from: from, until: until, label: phrase);
        break;
      }
    }
  }

  String? place;
  if (met) {
    final RegExpMatch? at = RegExp(
      r' (?:met|meet|scanned) (?:at|in) (.+?) $',
    ).firstMatch(q);
    String? p = at?.group(1)?.trim();
    if (p != null) {
      // A trailing time or follow-up phrase belongs to those filters.
      p = p
          .replaceAll(
            RegExp(
              r' ?(today|yesterday|this week|last week|this month|last month)'
              r'.*$',
            ),
            '',
          )
          .replaceAll(RegExp(r' ?(with|without|who|that|and) .*$'), '')
          .trim();
      if (p.isNotEmpty &&
          !RegExp(
            r'^(today|yesterday|this week|last week|this month|last month)$',
          ).hasMatch(p)) {
        place = p;
      }
    }
  }

  if (place == null && window == null && followUp == null) return null;
  return PeopleFilterPlan(
    raw,
    place: place,
    from: window?.from,
    until: window?.until,
    windowLabel: window?.label,
    followUp: followUp,
  );
}

// ---------------------------------------------------------------------------
// Purchases (B5)
// ---------------------------------------------------------------------------

/// The words in [raw], lower case, with "Rahim's" as "rahim".
List<String> _words(String raw) =>
    textWords(raw.replaceAll(RegExp(r"['’]s\b", caseSensitive: false), ''));

const Set<String> _warrantyWords = <String>{
  'warranty',
  'warranties',
  'guarantee',
  'guaranty',
  'waranty',
  'warrenty',
};

const Set<String> _endWords = <String>{
  'expire',
  'expires',
  'expiring',
  'expired',
  'expiry',
  'end',
  'ends',
  'ending',
  'ended',
  'over',
  'valid',
  'validity',
  'covered',
  'cover',
  'sesh',
  'shesh',
};

/// Words around a warranty question that are not what it covers.
const Set<String> _warrantyFiller = <String>{
  'when',
  'does',
  'do',
  'did',
  'will',
  'has',
  'have',
  'had',
  'already',
  'my',
  'our',
  'the',
  'a',
  'an',
  'is',
  'are',
  'was',
  'still',
  'under',
  'where',
  'of',
  'for',
  'on',
  'date',
  'until',
  'till',
  'how',
  'long',
  'left',
  'what',
  'whats',
  'which',
  'it',
  'in',
  'kobe',
  'kokhon',
  'koto',
  'din',
  'baki',
  'er',
  'ta',
  'ki',
  'amar',
  'show',
  'find',
  'me',
  'card',
  'paper',
  'run',
  'runs',
  'out',
};

/// Words that make "warranty" part of a need — somebody who does warranty
/// repairs — rather than a question about one of the user's own.
const Set<String> _serviceWords = <String>{
  'service',
  'servicing',
  'centre',
  'center',
  'repair',
  'repairs',
  'claim',
};

/// Subjects that are not a thing: "what expires", "anything ending soon".
const Set<String> _nothingInParticular = <String>{
  'anything',
  'something',
  'things',
  'thing',
  'items',
  'item',
  'everything',
  'stuff',
  'all',
  'soon',
  'next',
  'coming',
  'up',
};

/// "When does my laptop warranty expire?" → [WarrantyPlan]; "what expires in
/// the next 90 days", "my warranties" → [ExpiringPlan]; anything else null.
QueryPlan? _warrantyOrExpiring(String raw, DateTime now) {
  final List<String> words = _words(raw);
  final bool warranty = words.any(_warrantyWords.contains);
  final bool ends =
      words.any(_endWords.contains) ||
      RegExp(r'\bruns? out\b').hasMatch(words.join(' '));
  if (!warranty && !ends) return null;
  if (words.any(_serviceWords.contains)) return null;

  final ({LocalDate from, LocalDate until, String label})? window = _window(
    words,
    now,
  );
  final List<String> rest = <String>[
    for (final String w in _withoutWindow(words))
      if (!_warrantyWords.contains(w) &&
          !_endWords.contains(w) &&
          !_warrantyFiller.contains(w) &&
          !_nothingInParticular.contains(w))
        w,
  ];

  if (rest.isEmpty) {
    final LocalDate today = LocalDate.fromDateTime(now);
    final bool past = words.contains('expired') || words.contains('ended');
    if (past && window == null) {
      return ExpiringPlan(
        raw,
        until: today.addDays(-1),
        ended: true,
        label: 'already ended',
      );
    }
    if (window != null) {
      return ExpiringPlan(
        raw,
        from: window.from,
        until: window.until,
        label: window.label,
      );
    }
    // "What expires soon", "expiring warranties": the next 90 days.
    if (ends) {
      return ExpiringPlan(
        raw,
        from: today,
        until: today.addDays(89),
        label: 'in the next 90 days',
      );
    }
    // "My warranties": every one.
    return ExpiringPlan(raw, label: 'every warranty');
  }

  // A thing named needs the word "warranty": "laptop expiry" alone may be a
  // need ("passport expiry renewal"), and is searched as words.
  if (!warranty) return null;
  return WarrantyPlan(raw, subject: rest.join(' '));
}

/// "next 90 days", "in 3 months", "this month", "next month", "this year".
({LocalDate from, LocalDate until, String label})? _window(
  List<String> words,
  DateTime now,
) {
  final LocalDate today = LocalDate.fromDateTime(now);
  final String q = ' ${words.join(' ')} ';
  final RegExpMatch? n = RegExp(
    r' (?:next|in|within|coming) (\d{1,3}) (day|days|week|weeks|month|months) ',
  ).firstMatch(q);
  if (n != null) {
    final int count = int.parse(n[1]!);
    final String unit = n[2]!;
    final LocalDate end = unit.startsWith('day')
        ? today.addDays(count - 1)
        : unit.startsWith('week')
        ? today.addDays(count * 7 - 1)
        : today.addMonths(count).addDays(-1);
    return (
      from: today,
      until: end,
      label:
          'in the next $count ${count == 1 ? unit.replaceAll('s', '') : unit}',
    );
  }
  if (q.contains(' this month ')) {
    return (
      from: today,
      until: LocalDate(
        today.year,
        today.month,
        LocalDate.daysInMonth(today.year, today.month),
      ),
      label: 'this month',
    );
  }
  if (q.contains(' next month ')) {
    final LocalDate first = LocalDate(today.year, today.month, 1).addMonths(1);
    return (
      from: first,
      until: first.addMonths(1).addDays(-1),
      label: 'next month',
    );
  }
  if (q.contains(' this year ')) {
    return (
      from: today,
      until: LocalDate(today.year, 12, 31),
      label: 'this year',
    );
  }
  return null;
}

/// [words] without the words of a window, so they are not taken for the
/// thing asked about.
List<String> _withoutWindow(List<String> words) {
  final String q = ' ${words.join(' ')} '
      .replaceAll(
        RegExp(
          r' (?:next|in|within|coming) \d{1,3} (?:day|days|week|weeks|month|months) ',
        ),
        ' ',
      )
      .replaceAll(RegExp(r' (?:this|next) (?:month|year) '), ' ');
  return q.trim().isEmpty ? const <String>[] : q.trim().split(' ');
}

/// Words that make a question a total of receipts. Not "expense": an
/// "expense tracker developer" is somebody's line of work.
const Set<String> _spendWords = <String>{
  'spend',
  'spent',
  'spending',
  'khoroch',
  'khorch',
  'khoros',
};

/// Words around a spending question that are not the shop or category.
const Set<String> _spendFiller = <String>{
  'how',
  'much',
  'did',
  'do',
  'does',
  'have',
  'has',
  'i',
  'we',
  'my',
  'our',
  'the',
  'a',
  'in',
  'during',
  'total',
  'money',
  'taka',
  'tk',
  'bdt',
  'koto',
  'ki',
  'ami',
  'amar',
  'holo',
  'was',
  'is',
  'what',
  'whats',
  'receipt',
  'receipts',
  'bill',
  'bills',
  'purchases',
  'so',
  'far',
  'overall',
  'all',
  'together',
  'of',
};

/// "How much did I spend on electronics this month?" — or null.
///
/// A spend word is needed ("spent", "spending", Banglish "khoroch"), or
/// "how much" with a paying word, or "total" beside receipts or bills.
/// "Total" alone is somebody's company ("Total Solutions").
SpendingPlan? _spending(String raw, DateTime now) {
  final List<String> words = _words(raw);
  final String q = ' ${words.join(' ')} ';
  final bool spend =
      words.any(_spendWords.contains) ||
      (q.contains(' how much ') &&
          RegExp(r' (paid|pay|cost|costs|on|at|from) ').hasMatch(q)) ||
      RegExp(
        r' (total|totals) (of )?(my )?(receipts|bills|purchases) ',
      ).hasMatch(q) ||
      RegExp(
        r' (receipts|receipt|bills|purchases) (total|totals) ',
      ).hasMatch(q);
  if (!spend) return null;

  final LocalDate today = LocalDate.fromDateTime(now);
  SpendingPeriod period = SpendingPeriod.monthOf(now);
  String? unsupported;
  final List<String> periodWords = <String>[];

  if (q.contains(' last month ')) {
    period = SpendingPeriod.monthOf(now).previous;
    periodWords.addAll(<String>['last', 'month']);
  } else if (RegExp(r' (gato|agher|ager) (mash|maser) ').hasMatch(q)) {
    // Banglish: "last month".
    period = SpendingPeriod.monthOf(now).previous;
    periodWords.addAll(<String>['gato', 'agher', 'ager', 'mash', 'maser', 'e']);
  } else if (q.contains(' this month ') ||
      RegExp(r' ei (mash|maser) ').hasMatch(q)) {
    periodWords.addAll(<String>['this', 'month', 'ei', 'mash', 'maser', 'e']);
  } else if (q.contains(' last year ')) {
    period = SpendingPeriod.year(today.year - 1);
    periodWords.addAll(<String>['last', 'year']);
  } else if (q.contains(' this year ')) {
    period = SpendingPeriod.year(today.year);
    periodWords.addAll(<String>['this', 'year']);
  } else {
    for (final String phrase in <String>[
      'today',
      'yesterday',
      'this week',
      'last week',
    ]) {
      if (q.contains(' $phrase ')) {
        unsupported = phrase;
        periodWords.addAll(phrase.split(' '));
        break;
      }
    }
    if (unsupported == null) {
      final ({SpendingPeriod period, List<String> words})? named = _namedPeriod(
        words,
        today,
      );
      if (named != null) {
        period = named.period;
        periodWords.addAll(named.words);
      }
    }
  }

  // What is left after the question's own words is the shop or category.
  bool shopOnly = false;
  final List<String> rest = <String>[];
  for (final String w in words) {
    if (_spendWords.contains(w) ||
        _spendFiller.contains(w) ||
        periodWords.contains(w) ||
        RegExp(r'^(paid|pay|cost|costs|did|on|for)$').hasMatch(w)) {
      continue;
    }
    if (w == 'at' || w == 'from') {
      shopOnly = true;
      continue;
    }
    rest.add(w);
  }
  return SpendingPlan(
    raw,
    period: period,
    focus: rest.isEmpty ? null : rest.join(' '),
    shopOnly: shopOnly && rest.isNotEmpty,
    unsupported: unsupported,
  );
}

const List<String> _shortMonths = <String>[
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

/// "September", "sep 2025", "2025": the most recent such month that is not
/// in the future, unless a year is given.
({SpendingPeriod period, List<String> words})? _namedPeriod(
  List<String> words,
  LocalDate today,
) {
  int? month;
  String? monthWord;
  for (final String w in words) {
    final int full = monthNames.indexWhere((String m) => m.toLowerCase() == w);
    final int short = _shortMonths.indexOf(w == 'sept' ? 'sep' : w);
    // "may" is also a verb, so only as a month beside a year or "in".
    if (w == 'may' &&
        !words.any((String x) => RegExp(r'^\d{4}$').hasMatch(x))) {
      continue;
    }
    if (full >= 0 || short >= 0) {
      month = (full >= 0 ? full : short) + 1;
      monthWord = w;
      break;
    }
  }
  final String? yearWord = words
      .where((String w) => RegExp(r'^20\d{2}$').hasMatch(w))
      .firstOrNull;
  final int? year = yearWord == null ? null : int.parse(yearWord);

  if (month != null) {
    final int y = year ?? (month > today.month ? today.year - 1 : today.year);
    return (
      period: SpendingPeriod.month(y, month),
      words: <String>[monthWord!, ?yearWord],
    );
  }
  if (year != null) {
    return (period: SpendingPeriod.year(year), words: <String>[yearWord!]);
  }
  return null;
}
