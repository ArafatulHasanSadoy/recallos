import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/phone.dart';
import '../../../core/search/query_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../../cards/presentation/reach_out.dart';
import '../../cards/presentation/widgets/editable_field_list.dart'
    show SourceChip;
import '../data/search_repository.dart';

/// The direct answers to a lookup — "Rahim's number".
///
/// One flat card per person (rule 4: an answer is computed, so it does not
/// stack), each value with where it came from, and a way back to the card
/// it was read off. Every Rahim is listed: picking one would be a guess.
class LookupAnswers extends StatelessWidget {
  const LookupAnswers({required this.plan, required this.answers, super.key});

  final LookupPlan plan;
  final List<LookupAnswer> answers;

  @override
  Widget build(BuildContext context) {
    final bool viaSearch = answers.every((LookupAnswer a) => a.viaSearch);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: SectionHeader(
            viaSearch
                ? '${plan.fieldLabel} · for ${plan.subject}'
                : '${plan.subject}’s ${plan.fieldLabel}',
            count: answers.length > 1 ? answers.length : null,
          ),
        ),
        for (final LookupAnswer a in answers) ...<Widget>[
          LookupAnswerCard(plan: plan, answer: a),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}

class LookupAnswerCard extends ConsumerWidget {
  const LookupAnswerCard({required this.plan, required this.answer, super.key});

  final LookupPlan plan;
  final LookupAnswer answer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final String? also = answer.person != null ? answer.company : null;

    return Container(
      decoration: AppDecoration.flatCard(c, isDark: isDarkTheme(context)),
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(answer.who, style: AppText.rowTitle(c)),
          if (also != null) Text(also, style: AppText.body(c)),
          const SizedBox(height: Gap.xs),
          if (answer.values.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Text(
                'No ${plan.fieldLabel} on this card.',
                style: AppText.body(c),
              ),
            ),
          for (final CardField f in answer.values)
            _ValueRow(field: f, cardId: answer.card.id),
          Container(height: 1, color: c.hairlineOnCard),
          PressFade(
            onTap: () => openCardDetail(
              context,
              cardId: answer.card.id,
              imagePath: answer.card.displayPath,
            ),
            semanticLabel: 'Open the card this came from',
            child: Container(
              constraints: const BoxConstraints(minHeight: kMinTarget),
              alignment: Alignment.centerLeft,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: MetaLabel(
                      answer.viaSearch
                          ? 'Matched what you needed · from this card · '
                                '${compactAge(answer.card.capturedAt)}'
                          : 'From this card · '
                                '${compactAge(answer.card.capturedAt)}',
                      color: c.ochreInk,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One value, and the one thing it can be used for.
///
/// A company or a title opens nothing, so it is drawn as text, not as a
/// control that does nothing when tapped.
class _ValueRow extends ConsumerWidget {
  const _ValueRow({required this.field, required this.cardId});

  final CardField field;
  final int cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final _Action? action = _actionFor(field);

    final Widget row = Container(
      constraints: const BoxConstraints(minHeight: kMinTarget),
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              field.fieldKey == FieldKeys.phone
                  ? PhoneExtractor.display(field.value)
                  : field.value,
              style: AppText.rowSerif(c),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Gap.sm),
          SourceChip(field: field),
          if (action != null) ...<Widget>[
            const SizedBox(width: Gap.sm),
            Icon(action.icon, size: 19, color: c.inkMuted),
          ],
        ],
      ),
    );
    if (action == null) return row;

    return PressFade(
      onTap: () => unawaited(
        reachOut(context, ref, action.uri, cardId: cardId, kind: action.kind),
      ),
      semanticLabel: '${field.value}, ${action.verb}',
      child: row,
    );
  }

  static _Action? _actionFor(CardField f) {
    final String v = f.normalizedValue ?? f.value;
    return switch (f.fieldKey) {
      FieldKeys.phone => _Action(
        Uri(scheme: 'tel', path: v),
        Icons.call_outlined,
        'call',
        InteractionKind.callOpened,
      ),
      FieldKeys.email => _Action(
        Uri(scheme: 'mailto', path: v),
        Icons.mail_outlined,
        'email',
        InteractionKind.emailOpened,
      ),
      FieldKeys.address => _Action(
        Uri.https('www.google.com', '/maps/search/', <String, String>{
          'api': '1',
          'query': f.value,
        }),
        Icons.map_outlined,
        'open in maps',
        null,
      ),
      FieldKeys.website => _Action(
        Uri.parse(v.contains('://') ? v : 'https://$v'),
        Icons.language,
        'open the website',
        null,
      ),
      _ => null,
    };
  }
}

class _Action {
  const _Action(this.uri, this.icon, this.verb, this.kind);

  final Uri uri;
  final IconData icon;
  final String verb;

  /// Recorded as reaching the person; null for a map or a website.
  final InteractionKind? kind;
}
