import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../../cards/presentation/needs_attention_screen.dart';
import '../../contacts/data/identity_repository.dart';
import '../data/follow_up_actions.dart';
import '../data/follow_up_repository.dart';
import '../data/reminder_engine.dart';

/// What needs doing: overdue first, then today, then what is coming, then the
/// review work the wallet is waiting on.
///
/// The split into sections happens here, at build time, against the clock —
/// not in the query — so a screen left open overnight, or reopened the next
/// morning, calls yesterday's step overdue without anything being written.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({this.now = DateTime.now, super.key});

  final DateTime Function() now;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from Android's settings, where notifications may just have been
  /// turned on, and possibly on a new day: ask again, and redraw.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationsEnabledProvider);
      setState(() {});
    }
  }

  Future<void> _done(TodayEntry e) async {
    final FollowUpActions actions = ref.read(followUpActionsProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await actions.complete(e.step.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Done: ${e.step.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(actions.reopen(e.step.id)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final DateTime now = widget.now();
    final List<TodayEntry> open =
        ref.watch(openFollowUpsProvider).value ?? const <TodayEntry>[];
    final TodayView view = TodayView.split(open, now);
    final int pairs = ref.watch(duplicateCandidatesProvider).value?.length ?? 0;
    final int repairs = ref.watch(needsAttentionProvider).value?.length ?? 0;
    final bool anyReminder = open.any((TodayEntry e) => e.remindAt != null);
    final bool notificationsOn =
        ref.watch(notificationsEnabledProvider).value ?? true;

    final bool nothing = view.isEmpty && pairs == 0 && repairs == 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'Today', onBack: () => context.pop()),
            Expanded(
              child: nothing
                  ? const EmptyState(
                      label: 'All clear',
                      title: 'Nothing due',
                      body:
                          'Add a next step on any card and it shows up here, '
                          'with a reminder if you want one.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.lg,
                        0,
                        Gap.lg,
                        Gap.xl,
                      ),
                      children: <Widget>[
                        Text(
                          weekdayDayMonth(now, now),
                          style: AppText.title(c),
                        ),
                        if (anyReminder && !notificationsOn) ...<Widget>[
                          const SizedBox(height: Gap.md),
                          _NotificationsOffRow(
                            onTurnOn: () => unawaited(
                              ref.read(notificationPortProvider).openSettings(),
                            ),
                          ),
                        ],
                        _Section(
                          label: 'Overdue',
                          entries: view.overdue,
                          now: now,
                          onDone: _done,
                        ),
                        _Section(
                          label: 'Today',
                          entries: view.today,
                          now: now,
                          onDone: _done,
                        ),
                        _Section(
                          label: 'Upcoming',
                          entries: view.upcoming,
                          now: now,
                          onDone: _done,
                        ),
                        if (pairs > 0 || repairs > 0) ...<Widget>[
                          const SizedBox(height: Gap.lg),
                          SettingGroup(
                            label: 'Needs review',
                            children: <Widget>[
                              if (pairs > 0)
                                SettingRow(
                                  label: 'Possible duplicates',
                                  description: pairs == 1
                                      ? '1 pair may be the same'
                                      : '$pairs pairs may be the same',
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(Routes.duplicates),
                                ),
                              if (repairs > 0)
                                SettingRow(
                                  label: 'Needs attention',
                                  description: repairs == 1
                                      ? '1 card did not read cleanly'
                                      : '$repairs cards did not read cleanly',
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      context.push(Routes.needsAttention),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.entries,
    required this.now,
    required this.onDone,
  });

  final String label;
  final List<TodayEntry> entries;
  final DateTime now;
  final Future<void> Function(TodayEntry) onDone;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(label, count: entries.length),
          const SizedBox(height: Gap.sm),
          for (final TodayEntry e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: _EntryCard(
                entry: e,
                now: now,
                onDone: () => unawaited(onDone(e)),
                onOpen: () => unawaited(
                  openCardDetail<void>(
                    context,
                    cardId: e.cardId,
                    imagePath: null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.now,
    required this.onDone,
    required this.onOpen,
  });

  final TodayEntry entry;
  final DateTime now;
  final VoidCallback onDone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final ({String text, bool overdue}) due = dueWords(entry.step.dueOn, now);
    final String who = <String?>[
      entry.title,
      if (entry.person != entry.title) entry.person,
    ].whereType<String>().join(' · ');
    final DateTime? remindAt = entry.remindAt;

    return Container(
      decoration: AppDecoration.card(
        c,
        isDark: isDarkTheme(context),
        lifted: false,
      ),
      padding: const EdgeInsets.only(right: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PressFade(
            onTap: onDone,
            scale: 0.9,
            semanticLabel: 'Mark done: ${entry.step.title}',
            child: SizedBox(
              width: kMinTarget + Gap.sm,
              height: kMinTarget + Gap.sm,
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
              onTap: onOpen,
              semanticLabel:
                  '${entry.step.title}, $who. ${due.text}. Open card',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(entry.step.title, style: AppText.rowTitle(c)),
                    const SizedBox(height: 2),
                    Text(
                      who,
                      style: AppText.body(c).copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remindAt != null && remindAt.isAfter(now)
                          ? '${due.text} · reminder ${reminderWords(remindAt, now)}'
                          : due.text,
                      style: AppText.small(
                        c,
                      ).copyWith(color: due.overdue ? c.vermilion : c.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reminders are set but Android will not show them. Not a warning to read
/// and ignore: the row is the way to turn them on.
class _NotificationsOffRow extends StatelessWidget {
  const _NotificationsOffRow({required this.onTurnOn});

  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return PressFade(
      onTap: onTurnOn,
      semanticLabel: 'Notifications are off for RecallOS. Turn on',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + 4,
        ),
        decoration: BoxDecoration(
          color: c.vermilion.withValues(alpha: 0.10),
          borderRadius: AppRadius.pocketR,
          border: Border.all(color: c.vermilion.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Reminders are off',
                    style: AppText.rowTitle(c).copyWith(fontSize: 15),
                  ),
                  Text(
                    'Notifications are turned off for RecallOS.',
                    style: AppText.small(c),
                  ),
                ],
              ),
            ),
            Text('Turn on', style: AppText.button(c, on: c.ochreInk)),
          ],
        ),
      ),
    );
  }
}
