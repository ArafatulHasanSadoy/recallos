import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../data/follow_up_actions.dart';
import '../data/follow_up_answers.dart';
import '../data/follow_up_repository.dart';
import '../data/reminder_engine.dart';
import 'follow_up_sheets.dart';

/// Tells the user a reminder was saved but cannot be shown, with the way to
/// turn notifications on. A hint without the button would be a dead end.
void showNotificationsOffNotice(BuildContext context, NotificationPort port) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
        'Saved. Notifications are off for RecallOS, so it will only show on '
        'Today.',
      ),
      action: SnackBarAction(
        label: 'Turn on',
        onPressed: () => unawaited(port.openSettings()),
      ),
    ),
  );
}

/// What happens next with this card: the open steps, each with its day and
/// reminder, and the way to add one.
///
/// Always shown. A card with no plan is exactly the one that needs one, and a
/// block that hid itself when empty would hide the only way to add it — the
/// same reasoning as the note above it.
class NextStepsBlock extends ConsumerWidget {
  const NextStepsBlock({
    required this.cardId,
    this.now = DateTime.now,
    super.key,
  });

  final int cardId;
  final DateTime Function() now;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    // Resolved before the sheet: the screen may be gone when it closes.
    final FollowUpActions actions = ref.read(followUpActionsProvider);
    final NotificationPort port = ref.read(notificationPortProvider);
    final StepAnswer? a = await showNextStepSheet(context, now: now);
    if (a == null) return;
    final bool shown = await actions.addStep(cardId, a);
    ref.invalidate(notificationsEnabledProvider);
    if (!shown && context.mounted) showNotificationsOffNotice(context, port);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, NextStep s) async {
    final FollowUpActions actions = ref.read(followUpActionsProvider);
    final NotificationPort port = ref.read(notificationPortProvider);
    final StepAnswer? a = await showNextStepSheet(
      context,
      title: s.date.title,
      dueOn: s.date.dueOn,
      remind: s.reminder != null,
      editing: true,
      now: now,
    );
    if (a == null) return;
    final bool shown = await actions.editStep(s.date.id, a);
    ref.invalidate(notificationsEnabledProvider);
    if (!shown && context.mounted) showNotificationsOffNotice(context, port);
  }

  Future<void> _done(BuildContext context, WidgetRef ref, NextStep s) async {
    final FollowUpActions actions = ref.read(followUpActionsProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await actions.complete(s.date.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Done: ${s.date.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(actions.reopen(s.date.id)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final List<NextStep> steps =
        ref.watch(openStepsProvider(cardId)).value ?? const <NextStep>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xs),
      decoration: AppDecoration.card(
        c,
        isDark: isDarkTheme(context),
        lifted: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MicroLabel('Next step', color: c.ochreInk),
          if (steps.isEmpty)
            PressFade(
              onTap: () => unawaited(_add(context, ref)),
              semanticLabel: 'Add a next step',
              child: Padding(
                padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        "Nothing planned. Add what you'll do next — it shows "
                        'on Today, and can remind you.',
                        style: AppText.body(c).copyWith(color: c.inkMuted),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Icon(Icons.add, size: 18, color: c.inkMuted),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            for (final NextStep s in steps)
              _StepRow(
                step: s,
                now: now(),
                onEdit: () => unawaited(_edit(context, ref, s)),
                onDone: () => unawaited(_done(context, ref, s)),
              ),
            TextAction(
              label: 'Add another step',
              icon: Icons.add,
              onTap: () => unawaited(_add(context, ref)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.now,
    required this.onEdit,
    required this.onDone,
  });

  final NextStep step;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final ({String text, bool overdue}) due = dueWords(step.date.dueOn, now);
    final DateTime? remindAt = step.reminder?.remindAt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PressFade(
          onTap: onDone,
          scale: 0.9,
          semanticLabel: 'Mark done: ${step.date.title}',
          child: SizedBox(
            width: kMinTarget,
            height: kMinTarget,
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.inkMuted, width: 1.5),
                ),
                child: Icon(Icons.check, size: 15, color: c.inkFaint),
              ),
            ),
          ),
        ),
        Expanded(
          child: PressFade(
            onTap: onEdit,
            semanticLabel: '${step.date.title}. ${due.text}. Edit',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm + 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(step.date.title, style: AppText.rowTitle(c)),
                  const SizedBox(height: 2),
                  Text(
                    due.text,
                    style: AppText.small(
                      c,
                    ).copyWith(color: due.overdue ? c.vermilion : c.inkMuted),
                  ),
                  if (remindAt != null && remindAt.isAfter(now))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.notifications_none,
                            size: 14,
                            color: c.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Reminder ${reminderWords(remindAt, now)}',
                              style: AppText.small(c),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// When and where the user met whoever is behind the card.
///
/// Shows only what the user gave. The scan date is offered inside the sheet as
/// one tap, never filled in here on its own.
class MetBlock extends ConsumerWidget {
  const MetBlock({
    required this.cardId,
    required this.scannedOn,
    this.now = DateTime.now,
    super.key,
  });

  final int cardId;
  final DateTime scannedOn;
  final DateTime Function() now;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Encounter? current,
  ) async {
    final FollowUpActions actions = ref.read(followUpActionsProvider);
    final EncounterAnswer? a = await showEncounterSheet(
      context,
      scannedOn: scannedOn,
      metOn: current?.metOn,
      place: current?.place,
      now: now,
    );
    if (a == null) return;
    await actions.setEncounter(cardId, a);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final Encounter? e = ref.watch(encounterProvider(cardId)).value;
    final String? place = e?.place;
    final DateTime? metOn = e?.metOn;
    final String? day = metOn == null ? null : weekdayDayMonth(metOn, now());

    return PressFade(
      onTap: () => unawaited(_edit(context, ref, e)),
      semanticLabel: e == null
          ? 'Add where you met'
          : 'Where you met: ${<String?>[place, day].whereType<String>().join(', ')}. Edit',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.md),
        decoration: AppDecoration.card(
          c,
          isDark: isDarkTheme(context),
          lifted: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: MicroLabel('Where you met', color: c.ochreInk)),
                Icon(
                  e == null ? Icons.add : Icons.edit_outlined,
                  size: 16,
                  color: c.inkMuted,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            if (e == null)
              Text(
                'Add when and where you met, so you can place them later.',
                style: AppText.body(c).copyWith(color: c.inkMuted),
              )
            else ...<Widget>[
              if (place != null) Text(place, style: AppText.rowTitle(c)),
              if (day != null)
                Text(
                  place == null ? day : 'on $day',
                  style: place == null
                      ? AppText.rowTitle(c)
                      : AppText.body(c).copyWith(color: c.inkMuted),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
