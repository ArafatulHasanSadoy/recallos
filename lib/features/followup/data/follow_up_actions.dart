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
      remindAt: a.remind ? reminderTimeFor(a.dueOn, now()) : null,
    );
    return _settle(askedForReminder: a.remind);
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
      remindAt: a.remind ? reminderTimeFor(a.dueOn, now()) : null,
    );
    return _settle(askedForReminder: a.remind);
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

  Future<bool> _settle({required bool askedForReminder}) async {
    final bool allowed = askedForReminder
        ? await engine.ensurePermission()
        : true;
    await engine.reconcile();
    return allowed;
  }
}
