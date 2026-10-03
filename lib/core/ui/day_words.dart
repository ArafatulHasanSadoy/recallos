/// Dates in the words a person uses, without a formatting package.
///
/// "Fri, 2 Oct", "Due tomorrow", "Overdue since Tue, 29 Sep". Day-first, the
/// way dates are written in Bangladesh, and English month names because the
/// rest of the interface is English.
library;

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];
const List<String> _weekdays = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

/// Whole calendar days from [now]'s day to [day]'s day; negative in the past.
///
/// Counted on UTC dates built from the local calendar fields, so a
/// daylight-saving day of 23 or 25 hours still counts as one day.
int daysFrom(DateTime now, DateTime day) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

/// "2 Oct", with the year when it is not this year: "2 Oct 2025".
String dayMonth(DateTime d, DateTime now) =>
    '${d.day} ${_months[d.month - 1]}${d.year == now.year ? '' : ' ${d.year}'}';

/// "Fri, 2 Oct".
String weekdayDayMonth(DateTime d, DateTime now) =>
    '${_weekdays[d.weekday - 1]}, ${dayMonth(d, now)}';

/// "9 AM", "9:30 PM".
String clock(DateTime t) {
  final int h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final String m = t.minute == 0
      ? ''
      : ':${t.minute.toString().padLeft(2, '0')}';
  return '$h$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// How a due day reads, and whether it has slipped.
///
/// Overdue is said in words, not only coloured: colour is never the only
/// signal in this app.
({String text, bool overdue}) dueWords(DateTime dueOn, DateTime now) {
  final int days = daysFrom(now, dueOn);
  if (days < 0) {
    return (
      text: days == -1
          ? 'Overdue since yesterday'
          : 'Overdue since ${weekdayDayMonth(dueOn, now)}',
      overdue: true,
    );
  }
  if (days == 0) return (text: 'Due today', overdue: false);
  if (days == 1) return (text: 'Due tomorrow', overdue: false);
  return (text: 'Due ${weekdayDayMonth(dueOn, now)}', overdue: false);
}

/// When to remind about a step due on [dueOn]: 9 AM that day, or — when that
/// has already gone by — an hour from now, on a five-minute mark. A reminder
/// set for a time already past would either fire at once or never.
DateTime reminderTimeFor(DateTime dueOn, DateTime now) {
  final DateTime nine = DateTime(dueOn.year, dueOn.month, dueOn.day, 9);
  if (nine.isAfter(now.add(const Duration(minutes: 5)))) return nine;
  final DateTime inAnHour = now.add(const Duration(hours: 1));
  return DateTime(
    inAnHour.year,
    inAnHour.month,
    inAnHour.day,
    inAnHour.hour,
    (inAnHour.minute ~/ 5) * 5,
  );
}

/// "9 AM on Fri, 2 Oct", "9 AM tomorrow", "4:35 PM today".
String reminderWords(DateTime at, DateTime now) {
  final int days = daysFrom(now, at);
  final String when = switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    _ => 'on ${weekdayDayMonth(at, now)}',
  };
  return '${clock(at)} $when';
}
