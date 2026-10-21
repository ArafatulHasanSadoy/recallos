import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/domain/money.dart';
import '../../../core/extraction/receipt_extractor.dart' show formatDay;
import '../../../core/linking/warranty_expiry.dart';
import '../../../core/search/query_plan.dart';
import '../../../core/spending/spending_totals.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../../warranty/presentation/purchase_blocks.dart' show PaperRow;
import '../data/purchase_answers.dart';

/// The answers to B5's purchase questions, in the slot on home where A6
/// answers "Rahim's number".
///
/// Each is one flat block (rule 4: a computed answer does not stack),
/// headed by what it is, with the figure first, its scope straight after
/// it, and every paper it came from as a row that opens it.

/// "When does my laptop warranty expire?" — the end of each matching
/// warranty, how it is known, and the warranty and its receipt.
class WarrantyAnswers extends StatelessWidget {
  const WarrantyAnswers({
    required this.plan,
    required this.answers,
    this.now,
    super.key,
  });

  final WarrantyPlan plan;
  final List<WarrantyAnswer> answers;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final DateTime today = now ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: SectionHeader(
            '${plan.subject} warranty',
            count: answers.length > 1 ? answers.length : null,
          ),
        ),
        for (final WarrantyAnswer a in answers) ...<Widget>[
          _WarrantyCard(answer: a, now: today),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({required this.answer, required this.now});

  final WarrantyAnswer answer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final WarrantyExpiry? e = answer.expiry?.expiry;
    final bool ended = e != null && e.day.isBefore(LocalDate.fromDateTime(now));
    final String? caveat = e?.caveat;
    final DateTime? remindAt = ended ? null : answer.expiry?.remindAt;

    return _AnswerCard(
      children: <Widget>[
        MicroLabel('Covered until', color: c.ochreInk),
        const SizedBox(height: Gap.xs),
        if (e == null)
          Text(
            'Not known yet. Link its receipt, or add the purchase date and '
            'the cover, on the warranty.',
            style: AppText.body(c),
          )
        else ...<Widget>[
          Text(formatDay(e.day), style: AppText.rowSerif(c)),
          Text(
            ended ? 'This cover has ended.' : _howFar(e.day, now),
            style: AppText.small(
              c,
            ).copyWith(color: ended ? c.vermilion : c.inkMuted),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            e.explain(),
            style: AppText.small(c).copyWith(color: c.inkMuted),
          ),
          if (caveat != null)
            Text(caveat, style: AppText.small(c).copyWith(color: c.inkMuted)),
          if (remindAt != null)
            Text(
              'Reminder ${reminderWords(remindAt, now)}',
              style: AppText.small(c),
            ),
        ],
        const SizedBox(height: Gap.sm),
        const MicroLabel('From'),
        PaperRow(card: answer.card, fields: answer.fields),
        if (answer.receipt case final receipt?)
          PaperRow(card: receipt.other, fields: receipt.otherFields),
      ],
    );
  }
}

/// "What expires in the next 90 days?" — every warranty that ends in the
/// window, soonest first, each one opening.
class ExpiringAnswers extends StatelessWidget {
  const ExpiringAnswers({
    required this.plan,
    required this.answers,
    this.now,
    super.key,
  });

  final ExpiringPlan plan;
  final List<ExpiringAnswer> answers;
  final DateTime? now;

  String get _heading => switch (plan) {
    ExpiringPlan(ended: true) => 'Already ended',
    ExpiringPlan(from: null, until: null) => 'Every warranty',
    _ => 'Ends ${plan.label}',
  };

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final DateTime today = now ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: SectionHeader(_heading, count: answers.length),
        ),
        if (answers.isEmpty)
          // "Nothing ends then" is an answer, said as one.
          _AnswerCard(
            children: <Widget>[
              Text(
                plan.ended
                    ? 'No warranty you saved has ended.'
                    : plan.from == null && plan.until == null
                    ? 'No warranties saved yet.'
                    : 'Nothing you saved ends ${plan.label}.',
                style: AppText.body(c),
              ),
            ],
          )
        else
          _AnswerCard(
            children: <Widget>[
              for (final ExpiringAnswer a in answers)
                _ExpiringRow(answer: a, now: today),
            ],
          ),
      ],
    );
  }
}

class _ExpiringRow extends StatelessWidget {
  const _ExpiringRow({required this.answer, required this.now});

  final ExpiringAnswer answer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final WarrantyExpiry? e = answer.expiry;
    final String title = answer.card.title ?? 'Warranty';
    final bool ended = e != null && e.day.isBefore(LocalDate.fromDateTime(now));
    final String line = e == null
        ? 'End not known yet'
        : '${formatDay(e.day)} · ${_basisWord(e.basis)}';
    final String far = e == null ? '' : _howFar(e.day, now);

    return PressFade(
      onTap: () => unawaited(context.push<void>(Routes.card(answer.card.id))),
      semanticLabel:
          'Open the warranty: $title, $line${far.isEmpty ? '' : ', $far'}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Row(
            children: <Widget>[
              Icon(Icons.verified_user_outlined, size: 20, color: c.inkMuted),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppText.rowTitle(c)),
                    Text(line, style: AppText.small(c)),
                    if (far.isNotEmpty)
                      Text(
                        far,
                        style: AppText.small(
                          c,
                        ).copyWith(color: ended ? c.vermilion : c.inkMuted),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// "How much did I spend on electronics this month?" — the figure in saved
/// receipts, what it covers, the receipts it is made of, and the way to
/// what was not added. Or, when there is no figure, why.
class SpendingAnswerBlock extends StatelessWidget {
  const SpendingAnswerBlock({
    required this.plan,
    required this.answer,
    super.key,
  });

  final SpendingPlan plan;
  final SpendingAnswer answer;

  /// The counted receipts shown under the figure; the rest are one tap
  /// away on Receipt totals.
  static const int _shown = 3;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final SpendingSummary? s = answer.summary;
    final String? cannot = answer.cannot;
    final String heading = answer.focusLabel == null
        ? 'In saved receipts'
        : '${answer.focusLabel} · in saved receipts';

    if (cannot != null || s == null) {
      return CannotLine(cannot ?? 'There is no total for that.');
    }

    final Money? total = s.total;
    final List<String> others = <String>[
      for (final String code in s.currencies)
        if (code != s.currency) code,
    ];
    final int held = s.heldBack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: SectionHeader(heading),
        ),
        _AnswerCard(
          children: <Widget>[
            if (total == null)
              Text(
                'Nothing checked in ${s.period.label} yet, so nothing is '
                'added.',
                style: AppText.body(c),
              )
            else ...<Widget>[
              // Scaled down rather than wrapped: a figure broken across
              // lines misreads (as on Receipt totals).
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(total.format(), style: AppText.title(c)),
              ),
              Text('in saved receipts', style: AppText.body(c)),
              const SizedBox(height: 2),
              Text(
                s.scope,
                style: AppText.small(c).copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Gap.sm),
              const MicroLabel('From'),
              for (final ReceiptFacts r in s.counted.take(_shown))
                _ReceiptRow(receipt: r),
              if (s.counted.length > _shown)
                Text(
                  'and ${s.counted.length - _shown} more',
                  style: AppText.small(c),
                ),
            ],
            // A row that wraps, not a one-line action: at large text the
            // place it leads to must not be the part cut off.
            if (held > 0 || others.isNotEmpty)
              _GoRow(
                text: <String>[
                  if (held > 0)
                    '$held not added yet'
                  else
                    'Also in ${others.join(', ')}',
                  'see Receipt totals',
                ].join(' · '),
                onTap: () =>
                    unawaited(context.push<void>(Routes.receiptTotals)),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt});

  final ReceiptFacts receipt;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String title = receipt.shop ?? receipt.title ?? 'Receipt';
    final String line = <String>[
      if (receipt.date case final LocalDate d) formatDay(d),
      if (receipt.total case final Money m) m.format(),
    ].join(' · ');

    return PressFade(
      onTap: () => unawaited(context.push<void>(Routes.card(receipt.cardId))),
      semanticLabel: 'Open the receipt: $title, $line',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Row(
            children: <Widget>[
              Icon(Icons.receipt_long, size: 20, color: c.inkMuted),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppText.rowTitle(c)),
                    Text(line, style: AppText.small(c)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// A way on from an answer, in ochre ink, wrapping rather than cut off.
class _GoRow extends StatelessWidget {
  const _GoRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return PressFade(
      onTap: onTap,
      semanticLabel: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTarget),
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

/// A question understood but not answerable, said in a sentence where the
/// answer would be — never an empty state.
class CannotLine extends StatelessWidget {
  const CannotLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return _AnswerCard(children: <Widget>[Text(text, style: AppText.body(c))]);
  }
}

/// A flat answer card.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Container(
      decoration: AppDecoration.flatCard(c, isDark: isDarkTheme(context)),
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// "printed", "you confirmed", "calculated" — how an end is known, in a row
/// with no room for its working.
String _basisWord(ExpiryBasis b) => switch (b) {
  ExpiryBasis.printed => 'printed',
  ExpiryBasis.confirmed => 'you confirmed',
  ExpiryBasis.calculated => 'calculated',
};

/// "in 46 days", "in about 23 months", "ends today", "ended 3 days ago".
String _howFar(LocalDate day, DateTime now) {
  final int days = daysFrom(now, day.toLocalDateTime());
  if (days < 0) {
    final int ago = -days;
    if (ago == 1) return 'Ended yesterday';
    return ago > 60
        ? 'Ended about ${(ago / 30).round()} months ago'
        : 'Ended $ago days ago';
  }
  return switch (days) {
    0 => 'Ends today',
    1 => 'Ends tomorrow',
    <= 60 => 'In $days days',
    _ => 'In about ${(days / 30).round()} months',
  };
}
