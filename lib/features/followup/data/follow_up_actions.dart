import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/day_words.dart';
import 'follow_up_answers.dart';
import 'follow_up_repository.dart';
import 'reminder_engine.dart';

final followUpActionsProvider = Provider<FollowUpActions>(
  // Resolved here, not through a `Ref` held across awaits (CLAUDE.md).
  (Ref ref) => FollowUpActions(
    repo: ref.watch(followUpRepositoryProvider),
    engine: ref.watch(reminderEngineProvider),
  ),
);

/// What the screens do to next steps, each followed by a reconcile.
///
/// Every write that could change which reminders are due goes through here,
/// so no screen can finish a step and leave its notification behind.
class FollowUpActions {
  FollowUpActions({
    required this.repo,
    required this.engine,
    this.now = DateTime.now,
  });

  final FollowUpRepository repo;
  final ReminderEngine engine;
  final DateTime Function() now;

  Future<void> setEncounter(int cardId, EncounterAnswer a) =>
      repo.setEncounter(cardId: cardId, metOn: a.metOn, place: a.place);

  /// Adds a step. Returns false when a reminder was asked for but Android is
  /// not allowed to show it — the step is saved either way, and the screen
  /// says how to turn notifications on.
  Future<bool> addStep(int cardId, StepAnswer a) async {
    await repo.addStep(
      cardId: cardId,
      title: a.title,
      dueOn: a.dueOn,
      remindAt: _when(a),
    );
    return _settle(askedForReminder: a.remindAt != null);
  }

  /// Saves an edit, or drops the step when the sheet said remove.
  Future<bool> editStep(int stepId, StepAnswer a) async {
    if (a.remove) {
      await repo.dismiss(stepId);
      return _settle(askedForReminder: false);
    }
    await repo.editStep(
      stepId,
      title: a.title,
      dueOn: a.dueOn,
      remindAt: _when(a),
    );
    return _settle(askedForReminder: a.remindAt != null);
  }

  Future<void> complete(int stepId) async {
    await repo.complete(stepId);
    await engine.reconcile();
  }

  Future<void> reopen(int stepId) async {
    await repo.reopen(stepId);
    await engine.reconcile();
  }

  Future<void> snooze(int reminderId, Duration by) async {
    await repo.snooze(reminderId, by);
    await engine.reconcile();
  }

  /// The reminder time to save: the one the sheet showed, so the card never
  /// says a different time from the sheet. Found on the phone: the sheet
  /// worked its time out when it was drawn and this worked it out again on
  /// save, so a save that crossed a five-minute mark promised 10:20 and
  /// scheduled 10:25. Only a time that went by while the sheet stood open is
  /// worked out afresh — a reminder in the past would never fire.
  DateTime? _when(StepAnswer a) {
    final DateTime? shown = a.remindAt;
    if (shown == null) return null;
    final DateTime t = now();
    return shown.isAfter(t) ? shown : reminderTimeFor(a.dueOn, t);
  }

  Future<bool> _settle({required bool askedForReminder}) async {
    final bool allowed = askedForReminder
        ? await engine.ensurePermission()
        : true;
    await engine.reconcile();
    return allowed;
  }
}
