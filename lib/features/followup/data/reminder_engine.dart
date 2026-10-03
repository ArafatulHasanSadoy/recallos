import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'follow_up_repository.dart';
import 'local_notification_port.dart';

/// What the reminder engine needs from Android, and nothing more.
///
/// An interface so the engine's logic — which reminders Android should hold,
/// and when to ask for permission — is tested against a fake phone rather
/// than trusted to a plugin.
abstract interface class NotificationPort {
  /// Gets ready to schedule: the plugin is initialised and the time zone is
  /// the phone's current one. Called at the start of every reconcile, so a
  /// phone that changed zone is corrected the next time anything runs.
  Future<void> prepare();

  /// Whether RecallOS may post notifications at all.
  Future<bool> enabled();

  /// Asks Android for the notification permission. True when granted.
  Future<bool> requestPermission();

  /// The ids of the notifications Android is holding for later.
  Future<Set<int>> scheduledIds();

  /// Schedules [reminder] under its own id, replacing any earlier one.
  Future<void> schedule(PendingReminder reminder);

  Future<void> cancel(int id);

  /// Opens RecallOS's page in Android's notification settings — the way out
  /// when reminders are off. False when it could not be opened.
  Future<bool> openSettings();
}

final notificationPortProvider = Provider<NotificationPort>(
  (Ref ref) => LocalNotificationPort.instance,
);

final reminderEngineProvider = Provider<ReminderEngine>(
  // Resolved here, not held as a `Ref`: reconcile runs across many awaits, and
  // a provider read after the first one may already be disposed (CLAUDE.md).
  (Ref ref) => ReminderEngine(
    repo: ref.watch(followUpRepositoryProvider),
    port: ref.watch(notificationPortProvider),
  ),
);

/// Whether notifications are allowed. Invalidated on resume and after asking,
/// because the answer changes in Android's settings, outside the app.
final notificationsEnabledProvider = FutureProvider<bool>(
  (Ref ref) => ref.watch(notificationPortProvider).enabled(),
);

/// Keeps Android's scheduled notifications equal to what the database says.
///
/// Reconciling rather than scheduling one change at a time is what makes the
/// hard cases free. A reboot, an app update, a restore from backup, a changed
/// time zone, a card deleted or restored, a step finished from Today: each is
/// just "the database says something else now", and the next reconcile fixes
/// Android to match. Nothing has to remember to cancel anything.
class ReminderEngine {
  ReminderEngine({required this._repo, required this._port});

  final FollowUpRepository _repo;
  final NotificationPort _port;

  /// Makes Android hold exactly the reminders that are still due. Never
  /// throws: a reminder that could not be scheduled is still on Today, and the
  /// next reconcile tries again.
  Future<void> reconcile() async {
    try {
      await _port.prepare();
      final List<PendingReminder> due = await _repo.pendingReminders();
      final Set<int> wanted = <int>{for (final PendingReminder r in due) r.id};

      for (final int id in await _port.scheduledIds()) {
        if (!wanted.contains(id)) await _port.cancel(id);
      }
      // Scheduled again even when already held: the time or the words may
      // have changed, and the same id replaces rather than duplicates.
      for (final PendingReminder r in due) {
        await _port.schedule(r);
      }
    } on Object {
      // Deliberately quiet; see above.
    }
  }

  /// Makes sure notifications may be shown, asking only when they may not.
  ///
  /// Called when the user asks for a reminder — the moment the question makes
  /// sense — and never at onboarding.
  Future<bool> ensurePermission() async {
    try {
      if (await _port.enabled()) return true;
      return await _port.requestPermission();
    } on Object {
      return false;
    }
  }
}
