import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/ui/day_words.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 1, 10, 30); // a Thursday

  test('due days read as a person says them', () {
    expect(dueWords(DateTime(2026, 10, 1), now).text, 'Due today');
    expect(dueWords(DateTime(2026, 10, 2), now).text, 'Due tomorrow');
    expect(dueWords(DateTime(2026, 10, 5), now).text, 'Due Mon, 5 Oct');
    expect(dueWords(DateTime(2027, 1, 4), now).text, 'Due Mon, 4 Jan 2027');
  });

  test('overdue is said in words, not only coloured', () {
    final ({String text, bool overdue}) y = dueWords(
      DateTime(2026, 9, 30),
      now,
    );
    expect(y, (text: 'Overdue since yesterday', overdue: true));
    expect(
      dueWords(DateTime(2026, 9, 28), now).text,
      'Overdue since Mon, 28 Sep',
    );
  });

  test('a reminder is 9 AM on the day, or an hour out once 9 AM has gone', () {
    expect(
      reminderTimeFor(DateTime(2026, 10, 2), now),
      DateTime(2026, 10, 2, 9),
    );
    // Due today, after 9 AM: not a time in the past.
    expect(
      reminderTimeFor(DateTime(2026, 10, 1), now),
      DateTime(2026, 10, 1, 11, 30),
    );
    expect(
      reminderTimeFor(DateTime(2026, 10, 1), DateTime(2026, 10, 1, 10, 33)),
      DateTime(2026, 10, 1, 11, 30),
      reason: 'on a five-minute mark',
    );
  });

  test('reminder times read naturally', () {
    expect(reminderWords(DateTime(2026, 10, 2, 9), now), '9 AM tomorrow');
    expect(reminderWords(DateTime(2026, 10, 1, 16, 35), now), '4:35 PM today');
    expect(reminderWords(DateTime(2026, 10, 6, 9), now), '9 AM on Tue, 6 Oct');
    expect(clock(DateTime(2026, 10, 1, 0, 5)), '12:05 AM');
    expect(clock(DateTime(2026, 10, 1, 12)), '12 PM');
  });

  test('days are counted on the calendar, not in 24-hour blocks', () {
    // 23:00 to 01:00 is two hours and one day; a daylight-saving day of 23
    // hours is still one day, which `inHours ~/ 24` would miss.
    expect(daysFrom(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 29, 1)), 1);
    expect(daysFrom(DateTime(2026, 10, 1, 23, 59), DateTime(2026, 10, 1)), 0);
    expect(daysFrom(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
  });
}
