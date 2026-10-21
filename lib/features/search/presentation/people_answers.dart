import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/search/query_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/card_face.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../data/search_repository.dart';

/// The exact list a people filter asked for — "met at CSE fest", "waiting
/// on a next step". Everyone who fits, with what put them there; headed by
/// what the list is, so the answer states its own scope.
class PeopleAnswers extends StatelessWidget {
  const PeopleAnswers({
    required this.plan,
    required this.people,
    this.now,
    super.key,
  });

  final PeopleFilterPlan plan;
  final List<PersonMatch> people;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final DateTime today = now ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: SectionHeader(plan.describe, count: people.length),
        ),
        if (people.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.xs,
              vertical: Gap.sm,
            ),
            child: Text('Nobody fits that yet.', style: AppText.body(c)),
          ),
        for (final PersonMatch p in people) ...<Widget>[
          WalletCardTile(
            flat: true,
            title: p.card.title ?? 'Unread card',
            subtitle: p.nextStep != null
                ? 'Next: ${p.nextStep} · ${dayMonth(p.nextDue!, today)}'
                : 'No next step yet',
            imagePath: p.card.displayPath,
            hasNote: p.card.note != null && p.card.note!.trim().isNotEmpty,
            heroTag: cardHeroTag(p.card.id),
            meta: MetaLabel(_metLine(p, today), color: c.ochreInk),
            onTap: () => openCardDetail(
              context,
              cardId: p.card.id,
              imagePath: p.card.displayPath,
            ),
          ),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }

  /// Where and when, as recorded — or the scan day, said as the scan day,
  /// when no meeting day was recorded.
  static String _metLine(PersonMatch p, DateTime today) {
    final String? place = p.place;
    final DateTime? on = p.metOn;
    if (place != null && on != null) {
      return 'Met at $place · ${dayMonth(on, today)}';
    }
    if (place != null) return 'Met at $place';
    if (on != null) return 'Met ${dayMonth(on, today)}';
    return 'Scanned ${dayMonth(p.card.capturedAt, today)}';
  }
}

/// What a free user sees above the results of a question that comes with
/// Plus — a people filter, a date question, a total (B5): the words were
/// searched, and one line that goes to where the answer is.
class PlusFilterLine extends StatelessWidget {
  const PlusFilterLine({
    this.text = 'Filtering by when you met comes with RecallOS Plus',
    super.key,
  });

  /// What Plus would have answered, said for the question asked.
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return PressFade(
      onTap: () => context.push(Routes.plus),
      semanticLabel: text,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text,
                style: AppText.body(c).copyWith(color: c.ochreInk),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.ochreInk),
          ],
        ),
      ),
    );
  }
}
