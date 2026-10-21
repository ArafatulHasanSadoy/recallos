import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/local_notification_port.dart';

/// What Android is asked to show. A next step keeps its words and its
/// buttons; a warranty's end says what ends and when, in its own channel,
/// with nothing to mark done (B3).
void main() {
  PendingReminder warranty(DateTime remindAt) => PendingReminder(
    id: 7,
    stepId: 3,
    cardId: 12,
    remindAt: remindAt,
    stepTitle: 'Warranty ends',
    cardTitle: 'HP Laptop',
    kind: DateKind.warrantyExpiry,
    dueOn: DateTime(2028, 10, 11),
  );

  test('a next step is the user\'s words over the card, with buttons', () {
    final ReminderNotice n = ReminderNotice.of(
      PendingReminder(
        id: 1,
        stepId: 1,
        cardId: 1,
        remindAt: DateTime(2026, 10, 20, 9),
        stepTitle: 'Send the sponsorship deck',
        cardTitle: 'Acme Esports',
      ),
    );
    expect(n.title, 'Send the sponsorship deck');
    expect(n.body, 'Acme Esports');
    expect(n.channelId, 'next_steps');
    expect(n.actionable, isTrue);
  });

  test('a warranty says what ends and when, with nothing to mark done', () {
    final ReminderNotice n = ReminderNotice.of(
      warranty(DateTime(2028, 9, 11, 9)),
    );
    expect(n.title, 'Warranty ends in 30 days');
    expect(n.body, 'HP Laptop · covered until 11 Oct 2028');
    expect(n.channelId, 'warranties');
    expect(n.channelName, 'Warranties');
    expect(n.actionable, isFalse);
  });

  test('a week before, the day before, and the last morning', () {
    expect(
      ReminderNotice.of(warranty(DateTime(2028, 10, 4, 9))).title,
      'Warranty ends in a week',
    );
    expect(
      ReminderNotice.of(warranty(DateTime(2028, 10, 10, 9))).title,
      'Warranty ends tomorrow',
    );
    expect(
      ReminderNotice.of(warranty(DateTime(2028, 10, 11, 9))).title,
      'Warranty ends today',
    );
  });
}
