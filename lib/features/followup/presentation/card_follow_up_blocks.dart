import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../../events/data/wallet_events.dart';
import '../../plus/data/plus_controller.dart';
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

/// Whether the free reminders are all in use. A step that already holds one
/// keeps it, so it is never counted against itself.
Future<bool> _remindersFull(
  WidgetRef ref,
  DateTime Function() now, {
  NextStep? editing,
}) async {
  // Both resolved before the first await (CLAUDE.md: no ref across one).
  final PlusController plus = ref.read(plusProvider.notifier);
  final FollowUpRepository repo = ref.read(followUpRepositoryProvider);
  final DateTime? held = editing?.reminder?.remindAt;
  if (held != null && held.isAfter(now())) return false;
  if (await plus.isOwned()) return false;
  return await repo.activeReminderCount() >= kFreeReminders;
}

/// Opens RecallOS Plus, from a sheet that has closed by then.
VoidCallback? _seePlus(BuildContext context) {
  final GoRouter? router = GoRouter.maybeOf(context);
  return router == null ? null : () => unawaited(router.push(Routes.plus));
}

/// Asks for a next step on [cardId] and saves it — the free limit, the
/// notification permission and all — wherever the asking starts: the card
/// itself, or an event's list of everyone met.
Future<void> addNextStep(
  BuildContext context,
  WidgetRef ref,
  int cardId, {
  DateTime Function() now = DateTime.now,
}) async {
  // Resolved before the sheet: the screen may be gone when it closes.
  final FollowUpActions actions = ref.read(followUpActionsProvider);
  final NotificationPort port = ref.read(notificationPortProvider);
  final VoidCallback? seePlus = _seePlus(context);
  final bool full = await _remindersFull(ref, now);
  if (!context.mounted) return;
  final StepAnswer? a = await showNextStepSheet(
    context,
    now: now,
    remindersFull: full,
    onSeePlus: seePlus,
  );
  if (a == null) return;
  final bool shown = await actions.addStep(cardId, a);
  ref.invalidate(notificationsEnabledProvider);
  if (!shown && context.mounted) showNotificationsOffNotice(context, port);
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

  Future<void> _add(BuildContext context, WidgetRef ref) =>
      addNextStep(context, ref, cardId, now: now);

  Future<void> _edit(BuildContext context, WidgetRef ref, NextStep s) async {
    final FollowUpActions actions = ref.read(followUpActionsProvider);
    final NotificationPort port = ref.read(notificationPortProvider);
    final VoidCallback? seePlus = _seePlus(context);
    final bool full = await _remindersFull(ref, now, editing: s);
    if (!context.mounted) return;
    final StepAnswer? a = await showNextStepSheet(
      context,
      title: s.date.title,
      dueOn: s.date.dueOn,
      remind: s.reminder != null,
      remindAt: s.reminder?.remindAt,
      remindersFull: full,
      onSeePlus: seePlus,
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
          _FinishedSteps(cardId: cardId, now: now()),
        ],
      ),
    );
  }
}

/// Steps finished in the last month, folded away under one quiet line.
///
/// Done and Remove keep the step — only its status changes — but past the
/// snackbar's few seconds there was no way to see one again, so a mis-tap
/// on a small circle lost it for good as far as the user could tell. Each
/// row says what happened and when, and brings the step back.
class _FinishedSteps extends ConsumerStatefulWidget {
  const _FinishedSteps({required this.cardId, required this.now});

  final int cardId;
  final DateTime now;

  @override
  ConsumerState<_FinishedSteps> createState() => _FinishedStepsState();
}

class _FinishedStepsState extends ConsumerState<_FinishedSteps> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final List<ImportantDate> finished =
        ref.watch(finishedStepsProvider(widget.cardId)).value ??
        const <ImportantDate>[];
    if (finished.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextAction(
          label: _open
              ? 'Hide finished steps'
              : 'Finished recently (${finished.length})',
          icon: _open ? Icons.expand_less : Icons.expand_more,
          tint: c.inkMuted,
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          for (final ImportantDate d in finished)
            Padding(
              padding: const EdgeInsets.only(left: Gap.sm, bottom: Gap.xs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          d.title,
                          style: AppText.body(c).copyWith(color: c.inkMuted),
                        ),
                        Text(
                          '${d.status == DateStatus.done ? 'Done' : 'Removed'} '
                          '${weekdayDayMonth(d.updatedAt, widget.now)} at '
                          '${clock(d.updatedAt)}',
                          style: AppText.small(c),
                        ),
                      ],
                    ),
                  ),
                  TextAction(
                    label: 'Bring back',
                    onTap: () => unawaited(
                      ref.read(followUpActionsProvider).reopen(d.id),
                    ),
                  ),
                ],
              ),
            ),
      ],
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
    // Provenance, as for every fact: a place Event Mode wrote says so until
    // the user has made it their own by editing it.
    final bool byEventMode = e?.origin == EncounterOrigin.event;
    final WalletEvent? event = eventMetAt(
      ref.watch(walletEventsProvider).value ?? const <WalletEvent>[],
      e,
      now(),
    );

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
              if (byEventMode) ...<Widget>[
                const SizedBox(height: Gap.xs),
                Text('Marked by Event Mode', style: AppText.small(c)),
              ],
              if (event != null)
                TextAction(
                  label: 'Everyone met there',
                  icon: Icons.festival_outlined,
                  onTap: () => unawaited(
                    GoRouter.of(context).push(Routes.eventOf(event.id)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
