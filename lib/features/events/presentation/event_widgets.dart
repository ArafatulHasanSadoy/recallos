import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../followup/data/follow_up_actions.dart';
import '../../followup/data/follow_up_repository.dart';

/// On the scan's review: this card was marked as met at the running event,
/// and the one tap that takes it out.
///
/// The way to override Event Mode for a card handed over somewhere else —
/// before the event, by somebody passing on a friend's card. Shown only while
/// the mark is Event Mode's own; once the user has edited where they met, the
/// card says what they said and this has nothing to offer.
class EventMark extends ConsumerWidget {
  const EventMark({required this.cardId, super.key});

  final int cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final Encounter? met = ref.watch(encounterProvider(cardId)).value;
    final String? place = met?.place;
    if (met == null || met.origin != EncounterOrigin.event || place == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Container(
        decoration: AppDecoration.card(
          c,
          isDark: isDarkTheme(context),
          lifted: false,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Rule 2: ochre as a 4px rail, a marker, never a surface.
              Container(width: 4, color: c.ochre),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.sm, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MicroLabel('Event Mode', color: c.ochreInk),
                      const SizedBox(height: Gap.xs),
                      Text('Met at $place, today', style: AppText.rowTitle(c)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextAction(
                          label: 'Not met there',
                          onTap: () => unawaited(
                            ref.read(followUpActionsProvider).setEncounter(
                              cardId,
                              (metOn: null, place: ''),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One person in an event's summary: who, and what is next with them.
///
/// Plain values rather than a [MetCard], so the free version's example can be
/// drawn by the very widget a real summary uses.
class EventPersonRow extends StatelessWidget {
  const EventPersonRow({
    required this.title,
    this.person,
    this.next,
    this.nextIsLate = false,
    this.moreSteps = 0,
    this.onOpen,
    this.onAddStep,
    super.key,
  });

  final String title;
  final String? person;

  /// "Send the proposal · Due tomorrow", or null when nothing is planned.
  final String? next;
  final bool nextIsLate;

  /// Open steps beyond [next].
  final int moreSteps;

  final VoidCallback? onOpen;

  /// Null in the example, where there is nothing to add a step to.
  final VoidCallback? onAddStep;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? who = person == title ? null : person;
    final String? plan = next;
    final VoidCallback? add = onAddStep;

    return Container(
      width: double.infinity,
      decoration: AppDecoration.card(
        c,
        isDark: isDarkTheme(context),
        lifted: false,
      ),
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PressFade(
            onTap: onOpen,
            semanticLabel: onOpen == null
                ? null
                : '${<String?>[title, who].whereType<String>().join(', ')}. '
                      'Open card',
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppText.rowTitle(c)),
                  if (who != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      who,
                      style: AppText.body(c).copyWith(color: c.inkMuted),
                    ),
                  ],
                  if (plan != null) ...<Widget>[
                    const SizedBox(height: Gap.xs),
                    Text(
                      moreSteps > 0 ? '$plan · $moreSteps more' : plan,
                      style: AppText.small(
                        c,
                      ).copyWith(color: nextIsLate ? c.vermilion : c.inkMuted),
                    ),
                  ] else if (add == null) ...<Widget>[
                    const SizedBox(height: Gap.xs),
                    Text('No next step yet', style: AppText.small(c)),
                  ],
                  if (plan != null || add == null)
                    const SizedBox(height: Gap.md),
                ],
              ),
            ),
          ),
          if (plan == null && add != null)
            TextAction(label: 'Add a next step', icon: Icons.add, onTap: add),
        ],
      ),
    );
  }
}
