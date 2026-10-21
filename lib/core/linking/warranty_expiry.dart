/// When a warranty's cover ends, and how that is known (B3).
///
/// Three answers, never blurred: the paper prints it, the user said it, or
/// it was worked out — the purchase date plus the cover — and is labelled
/// *calculated* wherever it appears (PLAN §5, honest wording: "Calculated
/// from purchase date + 24 months", not a bare date).
///
/// Pure, and recomputed from scratch whenever an input changes, so a
/// calculated day can never outlive the facts it came from.
library;

import '../db/enums.dart';
import '../domain/local_date.dart';
import '../extraction/receipt_extractor.dart' show formatDay;

/// How an expiry is known.
enum ExpiryBasis {
  /// Printed on the warranty, not yet looked at.
  printed,

  /// Typed or confirmed by the user.
  confirmed,

  /// The purchase date plus the cover.
  calculated,
}

/// Where a calculated expiry's start date came from.
enum ExpiryStart {
  /// The purchase date printed on the warranty itself.
  warranty,

  /// The purchase date on a receipt the user confirmed is for it.
  receipt,
}

/// A warranty's end, and its working.
class WarrantyExpiry {
  const WarrantyExpiry._({
    required this.day,
    required this.basis,
    this.from,
    this.months,
    this.start,
    this.countsFrom,
  });

  /// The last day the cover holds.
  final LocalDate day;
  final ExpiryBasis basis;

  /// For a calculated expiry: the day it counts from, how many months, and
  /// which paper the day was on.
  final LocalDate? from;
  final int? months;
  final ExpiryStart? start;

  /// What the cover counts from when it is not the purchase — "installation",
  /// "delivery" — said as a caveat, because the calculation used the
  /// purchase date and the real end is then later.
  final String? countsFrom;

  bool get isCalculated => basis == ExpiryBasis.calculated;

  /// How the day is known, in a line.
  ///
  /// The date and the cover are kept whole — "15 Oct 2026", "2 years" — so a
  /// narrow line breaks between the words around them, never inside them.
  String explain() => switch (basis) {
    ExpiryBasis.printed => 'Printed on the warranty',
    ExpiryBasis.confirmed => 'You confirmed it',
    ExpiryBasis.calculated =>
      'Calculated from ${start == ExpiryStart.receipt ? "the receipt's" : 'the'} '
          'purchase date, ${_whole(formatDay(from!))}, plus '
          '${_whole(coverWords(months!))}',
  };

  static String _whole(String s) => s.replaceAll(' ', '\u00A0');

  /// Said under [explain] when the calculation is a lower bound.
  String? get caveat => countsFrom == null
      ? null
      : 'The cover counts from the $countsFrom, so it may end later.';

  @override
  String toString() => '$day (${basis.name})';
}

/// "2 years", "18 months", "1 month".
String coverWords(int months) {
  if (months % 12 == 0) {
    final int years = months ~/ 12;
    return '$years ${years == 1 ? 'year' : 'years'}';
  }
  return '$months ${months == 1 ? 'month' : 'months'}';
}

/// The start bases that are the purchase itself, as the warranty reader
/// stores them (`start_basis`'s normalised value).
const Set<String> _purchaseBases = <String>{'purchase', 'invoice', 'sale'};

/// Works out a warranty's end from what is known about it.
///
/// - [stated] is an `expiry_date` the paper printed or the user gave, with
///   its [statedOrigin] and whether the user has [statedConfirmed] it. A
///   calculated expiry must never be passed back in here: it is an output.
/// - [coverMonths] is the cover; [ownPurchaseDate] the purchase date on the
///   warranty; [receiptPurchaseDate] the date on a receipt the user has
///   *confirmed* is for it — a suggested link lends nothing.
/// - [startBasis] is what the cover counts from, as stored.
///
/// A stated expiry wins. Otherwise the warranty's own purchase date is
/// preferred over the receipt's, because it is the one the cover counts
/// from. The end is the day before the anniversary: two years from 12 Oct
/// 2026 holds through 11 Oct 2028, and a reminder that errs is early.
WarrantyExpiry? warrantyExpiry({
  LocalDate? stated,
  FactOrigin? statedOrigin,
  bool statedConfirmed = false,
  int? coverMonths,
  LocalDate? ownPurchaseDate,
  LocalDate? receiptPurchaseDate,
  String? startBasis,
}) {
  if (stated != null && statedOrigin != FactOrigin.derived) {
    return WarrantyExpiry._(
      day: stated,
      basis: statedConfirmed || statedOrigin == FactOrigin.user
          ? ExpiryBasis.confirmed
          : ExpiryBasis.printed,
    );
  }

  final int? months = coverMonths;
  if (months == null || months <= 0) return null;
  final LocalDate? from = ownPurchaseDate ?? receiptPurchaseDate;
  if (from == null) return null;

  final String? basis = startBasis?.trim().toLowerCase();
  return WarrantyExpiry._(
    day: from.addMonths(months).addDays(-1),
    basis: ExpiryBasis.calculated,
    from: from,
    months: months,
    start: ownPurchaseDate != null ? ExpiryStart.warranty : ExpiryStart.receipt,
    countsFrom: basis == null || basis.isEmpty || _purchaseBases.contains(basis)
        ? null
        : basis,
  );
}

/// When to mention that a warranty is ending: 9 AM a month before its last
/// day; a week before, when it was saved too late for that; the morning of
/// the last day, when it was saved later still. Null once even that has
/// passed — a reminder for a warranty already over helps nobody.
///
/// Worked out once, when the expiry is first known or changes, and then
/// left alone: recomputing it from "now" on every edit would move a
/// reminder that had already been shown back into the future, and show it
/// again.
DateTime? expiryReminderTime(LocalDate lastDay, DateTime now) {
  final DateTime soonest = now.add(const Duration(minutes: 5));
  for (final int before in const <int>[30, 7, 0]) {
    final LocalDate d = lastDay.addDays(-before);
    final DateTime at = DateTime(d.year, d.month, d.day, 9);
    if (at.isAfter(soonest)) return at;
  }
  return null;
}
