/// What the saved receipts add up to (B4).
///
/// Pure, so the sum on the screen and the sums B5's "how much…" answers give
/// are worked out by the same code, and so §6 can check them.
///
/// A total here is a claim about money, and it is only as good as the
/// receipts in it. So the rules are strict and visible:
///
/// - a receipt is **counted** only when the user has checked both its total
///   and its date — the two facts B2 asks about before anything counts on
///   them;
/// - anything else is **held back** and listed with what to do about it,
///   never quietly left out and never quietly added;
/// - a receipt that looks like a **second copy** of one already counted is
///   listed with its reasons until the user says which it is;
/// - **one currency at a time**: taka and dollars are never added together,
///   and nothing is converted.
///
/// The wording is "in saved receipts", not "you spent" (PLAN §5): the app
/// knows what was scanned, not everything that was paid.
library;

import '../domain/local_date.dart';
import '../domain/money.dart';
import '../extraction/document_lines.dart' show asciiDigits;
import '../extraction/receipt_extractor.dart' show formatDay;

/// How far one of a receipt's two critical facts — its total, its date —
/// has got.
enum FactState {
  /// Nothing read, nothing typed.
  missing,

  /// Something was read, but not as an amount (or a day).
  unreadable,

  /// Read, and nobody has looked at it yet — or it still has an objection
  /// against it. Either way the receipt shows *check this*.
  unchecked,

  /// The user confirmed it, or typed it.
  checked,
}

/// One saved receipt, as the totals see it.
class ReceiptFacts {
  const ReceiptFacts({
    required this.cardId,
    required this.savedAt,
    this.title,
    this.shop,
    this.category,
    this.categoryGuessed = false,
    this.total,
    this.totalState = FactState.missing,
    this.date,
    this.dateState = FactState.missing,
    this.invoiceNumber,
    this.notCopiesOf = const <int>{},
  });

  final int cardId;

  /// When it was scanned. Orders the receipts saved on one day; never
  /// stands in for a missing purchase date.
  final DateTime savedAt;

  /// What every list calls it.
  final String? title;

  /// The shop, as read or typed.
  final String? shop;

  final String? category;

  /// True while [category] is the app's guess from the shop's name.
  final bool categoryGuessed;

  /// The total as stored, checked or not. Null when there is no amount.
  final Money? total;
  final FactState totalState;

  /// The purchase date as stored, checked or not.
  final LocalDate? date;
  final FactState dateState;

  final String? invoiceNumber;

  /// Receipts the user said are a different purchase from this one, though
  /// they look alike ("Count both").
  final Set<int> notCopiesOf;

  /// Whether its total can be added: both critical facts checked.
  bool get counts =>
      total != null &&
      date != null &&
      totalState == FactState.checked &&
      dateState == FactState.checked;

  /// What to do before it counts, in a few words: "Check the total and the
  /// date", "Add the date". Null when it counts.
  String? get whatToDo {
    if (counts) return null;
    final String? forTotal = _verb(totalState, hasValue: total != null);
    final String? forDate = _verb(dateState, hasValue: date != null);
    if (forTotal != null && forTotal == forDate) {
      return '${_cap(forTotal)} the total and the date';
    }
    final List<String> parts = <String>[
      if (forTotal != null) '$forTotal the total',
      if (forDate != null) '$forDate the date',
    ];
    return parts.isEmpty ? null : _cap(parts.join(' and '));
  }

  static String? _verb(FactState s, {required bool hasValue}) => switch (s) {
    FactState.missing => 'add',
    FactState.unreadable => 'correct',
    FactState.unchecked => 'check',
    // Confirmed, but not as an amount or a day: the field says so itself.
    FactState.checked => hasValue ? null : 'correct',
  };

  static String _cap(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
}

/// A stretch of time the totals cover: a calendar month, or a year.
class SpendingPeriod {
  const SpendingPeriod.month(this.year, int this.month);
  const SpendingPeriod.year(this.year) : month = null;

  /// The month [now] falls in.
  factory SpendingPeriod.monthOf(DateTime now) =>
      SpendingPeriod.month(now.year, now.month);

  final int year;

  /// 1–12, or null for a whole year.
  final int? month;

  bool get isMonth => month != null;

  LocalDate get first => LocalDate(year, month ?? 1, 1);
  LocalDate get last => month == null
      ? LocalDate(year, 12, 31)
      : LocalDate(year, month!, LocalDate.daysInMonth(year, month!));

  bool contains(LocalDate d) =>
      d.year == year && (month == null || d.month == month);

  /// Whether [now] falls in it.
  bool isCurrent(DateTime now) => contains(LocalDate.fromDateTime(now));

  /// Whether it starts after [now] — a period nothing can have been bought
  /// in yet.
  bool isFuture(DateTime now) => first.isAfter(LocalDate.fromDateTime(now));

  SpendingPeriod get previous => month == null
      ? SpendingPeriod.year(year - 1)
      : month == 1
      ? SpendingPeriod.month(year - 1, 12)
      : SpendingPeriod.month(year, month! - 1);

  SpendingPeriod get next => month == null
      ? SpendingPeriod.year(year + 1)
      : month == 12
      ? SpendingPeriod.month(year + 1, 1)
      : SpendingPeriod.month(year, month! + 1);

  /// The year it is in.
  SpendingPeriod get wholeYear => SpendingPeriod.year(year);

  /// "October 2026", "2026".
  String get label =>
      month == null ? '$year' : '${monthNames[month! - 1]} $year';

  /// The days it covers, for an answer's scope: "1–31 Oct 2026",
  /// "1 Jan – 31 Dec 2026".
  String get span {
    final String end = formatDay(last);
    return month == null ? '1 Jan – $end' : '1–$end';
  }

  @override
  bool operator ==(Object other) =>
      other is SpendingPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => label;
}

const List<String> monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// One kind of evidence that two receipts are the same purchase.
enum CopyCue { total, day, shop, invoice }

class CopyReason {
  const CopyReason(this.cue, this.value);

  final CopyCue cue;
  final String value;

  /// "Same total, BDT 432.60".
  String describe() => switch (cue) {
    CopyCue.total => 'Same total, $value',
    CopyCue.day => 'Same day, $value',
    CopyCue.shop => 'Same shop, $value',
    CopyCue.invoice => 'Same invoice no., $value',
  };

  @override
  bool operator ==(Object other) =>
      other is CopyReason && other.cue == cue && other.value == value;

  @override
  int get hashCode => Object.hash(cue, value);

  @override
  String toString() => '${cue.name}($value)';
}

/// A counted-looking receipt that may be a second copy of one already
/// counted: the same paper scanned twice, or the shop's copy and yours.
class PossibleCopy {
  const PossibleCopy({
    required this.receipt,
    required this.original,
    required this.reasons,
  });

  /// The later one, which is held back.
  final ReceiptFacts receipt;

  /// The one counted in its place.
  final ReceiptFacts original;

  final List<CopyReason> reasons;
}

/// Receipts grouped under one shop, one category or one month.
class SpendingGroup {
  const SpendingGroup({
    required this.key,
    required this.label,
    required this.total,
    required this.receipts,
    this.guessed = 0,
  });

  /// What [SpendingFocus] narrows to. Empty for "no shop name" and "no
  /// category"; `YYYY-MM` for a month.
  final String key;
  final String label;
  final Money total;
  final int receipts;

  /// How many of [receipts] carry a category the app guessed.
  final int guessed;
}

/// Narrows a summary to one shop or one category.
class SpendingFocus {
  const SpendingFocus.shop(this.key, this.label) : byShop = true;
  const SpendingFocus.category(this.key, this.label) : byShop = false;

  final bool byShop;
  final String key;
  final String label;

  bool includes(ReceiptFacts r) =>
      byShop ? shopKey(r.shop) == key : categoryKey(r.category) == key;

  @override
  bool operator ==(Object other) =>
      other is SpendingFocus && other.byShop == byShop && other.key == key;

  @override
  int get hashCode => Object.hash(byShop, key);
}

/// Everything the totals say about one period, in one currency.
class SpendingSummary {
  const SpendingSummary._({
    required this.period,
    required this.currencies,
    required this.currency,
    required this.total,
    required this.counted,
    required this.byShop,
    required this.byCategory,
    required this.byMonth,
    required this.notAdded,
    required this.copies,
    required this.undated,
    this.focus,
  });

  /// Works out [period] over [receipts].
  ///
  /// [currency] is the one to sum; when it is null or nothing in the period
  /// is counted in it, the currency with the most counted receipts is used.
  /// [focus] narrows everything — the total and every list — to one shop or
  /// one category.
  factory SpendingSummary.of(
    List<ReceiptFacts> receipts, {
    required SpendingPeriod period,
    String? currency,
    SpendingFocus? focus,
  }) {
    final Map<int, PossibleCopy> copyOf = findCopies(receipts);

    final List<ReceiptFacts> countedInPeriod = <ReceiptFacts>[
      for (final ReceiptFacts r in receipts)
        if (r.counts &&
            !copyOf.containsKey(r.cardId) &&
            period.contains(r.date!))
          r,
    ];

    // Most receipts first; taka before the rest on a tie, then by code, so
    // the choice does not flicker as receipts are added.
    final Map<String, int> perCurrency = <String, int>{};
    for (final ReceiptFacts r in countedInPeriod) {
      perCurrency.update(
        r.total!.currency,
        (int n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    final List<String> currencies = perCurrency.keys.toList()
      ..sort((String a, String b) {
        final int byCount = perCurrency[b]!.compareTo(perCurrency[a]!);
        if (byCount != 0) return byCount;
        if (a == 'BDT') return -1;
        if (b == 'BDT') return 1;
        return a.compareTo(b);
      });
    final String? chosen = currencies.contains(currency)
        ? currency
        : currencies.firstOrNull;

    bool inFocus(ReceiptFacts r) => focus == null || focus.includes(r);

    final List<ReceiptFacts> inCurrency = <ReceiptFacts>[
      for (final ReceiptFacts r in countedInPeriod)
        if (r.total!.currency == chosen) r,
    ]..sort(_newestDateFirst);
    final List<ReceiptFacts> counted = inCurrency.where(inFocus).toList();

    Money? total;
    for (final ReceiptFacts r in counted) {
      total = total == null ? r.total! : total + r.total!;
    }

    return SpendingSummary._(
      period: period,
      currencies: currencies,
      currency: chosen,
      total: total,
      counted: counted,
      byShop: _group(
        inCurrency,
        key: (ReceiptFacts r) => shopKey(r.shop),
        label: (ReceiptFacts r) => r.shop?.trim(),
        none: 'No shop name',
      ),
      byCategory: _group(
        inCurrency,
        key: (ReceiptFacts r) => categoryKey(r.category),
        label: (ReceiptFacts r) => r.category?.trim(),
        none: 'No category',
        guessed: (ReceiptFacts r) => r.category != null && r.categoryGuessed,
      ),
      byMonth: period.isMonth ? const <SpendingGroup>[] : _months(inCurrency),
      notAdded: <ReceiptFacts>[
        for (final ReceiptFacts r in receipts)
          if (!r.counts &&
              r.date != null &&
              period.contains(r.date!) &&
              inFocus(r))
            r,
      ]..sort(_newestDateFirst),
      copies:
          <PossibleCopy>[
            for (final PossibleCopy p in copyOf.values)
              if (period.contains(p.receipt.date!) && inFocus(p.receipt)) p,
          ]..sort(
            (PossibleCopy a, PossibleCopy b) =>
                _newestDateFirst(a.receipt, b.receipt),
          ),
      undated:
          <ReceiptFacts>[
            for (final ReceiptFacts r in receipts)
              if (!r.counts && r.date == null && inFocus(r)) r,
          ]..sort((ReceiptFacts a, ReceiptFacts b) {
            final int bySaved = b.savedAt.compareTo(a.savedAt);
            return bySaved != 0 ? bySaved : b.cardId.compareTo(a.cardId);
          }),
      focus: focus,
    );
  }

  final SpendingPeriod period;

  /// Currencies with something counted in [period], the one with the most
  /// receipts first.
  final List<String> currencies;

  /// The currency [total] is in. Null when nothing in the period counts.
  final String? currency;

  /// The exact sum of [counted]. Null when there is nothing to add.
  final Money? total;

  /// The receipts in [total], newest purchase first.
  final List<ReceiptFacts> counted;

  /// [period]'s counted receipts in [currency], by shop and by category,
  /// largest first, and — for a year — by month, in calendar order. Not
  /// narrowed by [focus], since they are what a focus is picked from.
  final List<SpendingGroup> byShop;
  final List<SpendingGroup> byCategory;
  final List<SpendingGroup> byMonth;

  /// Receipts dated in [period] that do not count yet, in any currency —
  /// each says what to do ([ReceiptFacts.whatToDo]).
  final List<ReceiptFacts> notAdded;

  /// Possible second copies dated in [period].
  final List<PossibleCopy> copies;

  /// Receipts with no date to place them by. Listed whatever the period,
  /// because any period could be theirs.
  final List<ReceiptFacts> undated;

  final SpendingFocus? focus;

  /// Whether nothing at all is listed: no total and nothing held back.
  bool get isEmpty =>
      counted.isEmpty && notAdded.isEmpty && copies.isEmpty && undated.isEmpty;

  /// Held back for any reason.
  int get heldBack => notAdded.length + copies.length + undated.length;

  /// What the total covers, stated with it (PLAN §4, B5): "1–31 Oct 2026 ·
  /// 7 receipts you checked".
  String get scope =>
      '${period.span} · ${counted.length} '
      '${counted.length == 1 ? 'receipt' : 'receipts'} you checked';

  static int _newestDateFirst(ReceiptFacts a, ReceiptFacts b) {
    final int byDate = b.date!.compareTo(a.date!);
    if (byDate != 0) return byDate;
    final int bySaved = b.savedAt.compareTo(a.savedAt);
    return bySaved != 0 ? bySaved : b.cardId.compareTo(a.cardId);
  }

  static List<SpendingGroup> _group(
    List<ReceiptFacts> receipts, {
    required String Function(ReceiptFacts) key,
    required String? Function(ReceiptFacts) label,
    required String none,
    bool Function(ReceiptFacts)? guessed,
  }) {
    final Map<String, List<ReceiptFacts>> by = <String, List<ReceiptFacts>>{};
    for (final ReceiptFacts r in receipts) {
      by.putIfAbsent(key(r), () => <ReceiptFacts>[]).add(r);
    }
    final List<SpendingGroup> out = <SpendingGroup>[
      for (final MapEntry<String, List<ReceiptFacts>> e in by.entries)
        SpendingGroup(
          key: e.key,
          // Named as on the newest receipt, which [receipts] has first.
          label: e.key.isEmpty ? none : (label(e.value.first) ?? none),
          total: e.value.map((ReceiptFacts r) => r.total!).reduce(_add),
          receipts: e.value.length,
          guessed: guessed == null ? 0 : e.value.where(guessed).length,
        ),
    ];
    out.sort((SpendingGroup a, SpendingGroup b) {
      // The unnamed group last, whatever it adds up to: it is a gap in the
      // facts, not a shop.
      if (a.key.isEmpty != b.key.isEmpty) return a.key.isEmpty ? 1 : -1;
      final int byTotal = b.total.compareTo(a.total);
      return byTotal != 0 ? byTotal : a.label.compareTo(b.label);
    });
    return out;
  }

  static List<SpendingGroup> _months(List<ReceiptFacts> receipts) {
    final Map<int, List<ReceiptFacts>> by = <int, List<ReceiptFacts>>{};
    for (final ReceiptFacts r in receipts) {
      by.putIfAbsent(r.date!.month, () => <ReceiptFacts>[]).add(r);
    }
    final List<int> months = by.keys.toList()..sort();
    return <SpendingGroup>[
      for (final int m in months)
        SpendingGroup(
          key: '${by[m]!.first.date!.year}-${m.toString().padLeft(2, '0')}',
          label: monthNames[m - 1],
          total: by[m]!.map((ReceiptFacts r) => r.total!).reduce(_add),
          receipts: by[m]!.length,
        ),
    ];
  }

  static Money _add(Money a, Money b) => a + b;
}

/// Receipts that look like a second copy of one counted before them, by
/// the later receipt's id.
///
/// Only receipts that would otherwise count are compared: one still waiting
/// for a check is already held back, and is compared when it is checked. The
/// first saved of a set is counted; each later one is compared only with
/// receipts being counted, so a copy of a copy points at the original.
Map<int, PossibleCopy> findCopies(List<ReceiptFacts> receipts) {
  final List<ReceiptFacts> countable =
      receipts.where((ReceiptFacts r) => r.counts).toList()
        ..sort((ReceiptFacts a, ReceiptFacts b) {
          final int bySaved = a.savedAt.compareTo(b.savedAt);
          return bySaved != 0 ? bySaved : a.cardId.compareTo(b.cardId);
        });

  final List<ReceiptFacts> originals = <ReceiptFacts>[];
  final Map<int, PossibleCopy> copies = <int, PossibleCopy>{};
  for (final ReceiptFacts r in countable) {
    PossibleCopy? found;
    for (final ReceiptFacts o in originals) {
      final List<CopyReason>? reasons = copyReasons(r, o);
      if (reasons != null) {
        found = PossibleCopy(receipt: r, original: o, reasons: reasons);
        break;
      }
    }
    if (found == null) {
      originals.add(r);
    } else {
      copies[r.cardId] = found;
    }
  }
  return copies;
}

/// Every countable receipt [receipt] looks like a copy of — all of them, so
/// that one "Count both" answers for each, rather than the next look-alike
/// being asked about straight after.
List<int> lookAlikes(ReceiptFacts receipt, List<ReceiptFacts> all) => <int>[
  for (final ReceiptFacts o in all)
    if (o.counts && copyReasons(receipt, o) != null) o.cardId,
];

/// Why [a] and [b] look like one purchase, or null when they do not.
///
/// The same amount in the same currency on the same day, with nothing that
/// tells them apart: shops that differ, or invoice numbers that differ,
/// settle it. A missing shop or invoice number tells nothing apart — so two
/// receipts with no shop read are asked about, because adding a copy twice
/// would be silent and asking costs one tap. Nothing is asked about twice
/// once the user has said they are different purchases.
List<CopyReason>? copyReasons(ReceiptFacts a, ReceiptFacts b) {
  if (a.cardId == b.cardId) return null;
  if (a.notCopiesOf.contains(b.cardId) || b.notCopiesOf.contains(a.cardId)) {
    return null;
  }
  final Money? total = a.total;
  final LocalDate? day = a.date;
  if (total == null || day == null || total != b.total || day != b.date) {
    return null;
  }

  final String shopA = shopKey(a.shop);
  final String shopB = shopKey(b.shop);
  if (shopA.isNotEmpty && shopB.isNotEmpty && shopA != shopB) return null;
  final String invoiceA = _invoiceKey(a.invoiceNumber);
  final String invoiceB = _invoiceKey(b.invoiceNumber);
  if (invoiceA.isNotEmpty && invoiceB.isNotEmpty && invoiceA != invoiceB) {
    return null;
  }

  return <CopyReason>[
    if (invoiceA.isNotEmpty && invoiceA == invoiceB)
      CopyReason(CopyCue.invoice, b.invoiceNumber!.trim()),
    CopyReason(CopyCue.total, total.format()),
    CopyReason(CopyCue.day, formatDay(day)),
    if (shopA.isNotEmpty && shopA == shopB)
      CopyReason(CopyCue.shop, b.shop!.trim()),
  ];
}

/// A shop's name reduced to what tells shops apart: "STAR TECH & ENGINEERING
/// LTD." and "Star Tech & Engineering Ltd" are one shop. Empty when there is
/// no name.
String shopKey(String? shop) {
  if (shop == null) return '';
  final List<String> words = asciiDigits(shop)
      .toLowerCase()
      .split(_notWord)
      .where((String w) => w.isNotEmpty && !_companySuffixes.contains(w))
      .toList();
  return words.join(' ');
}

/// A category as a key: case and spacing do not make two categories.
String categoryKey(String? category) => category == null
    ? ''
    : category.trim().toLowerCase().replaceAll(_spaces, ' ');

String _invoiceKey(String? number) => number == null
    ? ''
    : asciiDigits(number).toUpperCase().replaceAll(_notWord, '');

/// Words a shop's legal name adds that the same shop's receipt may leave
/// off.
const Set<String> _companySuffixes = <String>{
  'ltd',
  'limited',
  'pvt',
  'private',
  'plc',
  'inc',
  'co',
};

final RegExp _notWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final RegExp _spaces = RegExp(r'\s+');
