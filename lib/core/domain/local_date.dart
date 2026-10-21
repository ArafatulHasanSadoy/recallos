/// A calendar day with no time and no time zone: the date on a receipt, the
/// day a warranty runs out.
///
/// Stored as `YYYY-MM-DD` text (`card_fields.date_value`, schema v11). Not a
/// timestamp: "bought on 8 Oct" is the same day wherever the phone is, and a
/// midnight `DateTime` moved across a time zone becomes 7 Oct — exactly the
/// off-by-one that makes a calculated warranty expiry wrong.
library;

import 'package:drift/drift.dart';

class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError('Not a calendar day: $year-$month-$day');
    }
  }

  /// The local calendar day [t] falls on.
  factory LocalDate.fromDateTime(DateTime t) =>
      LocalDate(t.year, t.month, t.day);

  /// Reads `YYYY-MM-DD`; null for anything else, including impossible days.
  static LocalDate? tryParse(String text) {
    final RegExpMatch? m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(text.trim());
    if (m == null) return null;
    try {
      return LocalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    } on ArgumentError {
      return null;
    }
  }

  final int year;
  final int month;
  final int day;

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// [months] later, the day kept where the month has it and moved to the
  /// month's last day where it does not: 31 Jan + 1 month is 28 (or 29)
  /// Feb, never 3 Mar. This is how "24 months from purchase" is counted.
  LocalDate addMonths(int months) {
    final int index = year * 12 + (month - 1) + months;
    final int y = index ~/ 12;
    final int m = index % 12 + 1;
    final int last = daysInMonth(y, m);
    return LocalDate(y, m, day > last ? last : day);
  }

  /// [days] later (or earlier, when negative), across months and years.
  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(DateTime.utc(year, month, day + days));

  /// Midnight at the start of this day, in the phone's time zone — for
  /// scheduling, never for storing.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  /// `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => toIso().compareTo(other.toIso());

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// Stores a [LocalDate] as its `YYYY-MM-DD` text, which also sorts and
/// compares correctly in SQL.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) =>
      LocalDate.tryParse(fromDb) ??
      (throw FormatException('Not a stored day: $fromDb'));

  @override
  String toSql(LocalDate value) => value.toIso();
}
