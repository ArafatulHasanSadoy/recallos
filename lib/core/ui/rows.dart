/// Rows and indicators shared by capture review, card detail and person.
///
/// Phase 2 of `design/DESIGN.md` §3.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'primitives.dart';

/// How sure the extractor is, as one dot.
///
/// Three states and never a percentage: "87% confident" about a phone number
/// read off a photograph is false precision, and it invites the user to
/// arithmetic instead of to a glance at the printing.
///
/// The [Semantics] label is not optional. Colour alone is the signal for a
/// sighted user and no signal at all otherwise, and this dot is how the app
/// admits it might be wrong.
class ConfidenceDot extends StatelessWidget {
  const ConfidenceDot({required this.score, this.size = 7, super.key});

  final double score;
  final double size;

  static String describe(double score) {
    if (score >= 0.85) return 'read clearly';
    if (score >= 0.5) return 'uncertain';
    return 'not read';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Semantics(
      label: describe(score),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.confidence(score),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// One labelled fact: micro-caps label, the value, and a trailing slot.
///
/// The label column is a fixed 74px so that every row's value starts on the
/// same vertical line — a ragged left edge is what makes a list of facts read
/// as a form rather than as a card's contents.
class FieldRow extends StatelessWidget {
  const FieldRow({
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
    this.emphasis,
    super.key,
  });

  final String label;
  final String value;

  /// A [ConfidenceDot], a provenance caps line, or an action.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Overrides the value colour — vermilion for something that failed to read.
  final Color? emphasis;

  /// The width of the label column. Exposed so a screen that stacks rows
  /// outside this widget can line up with it.
  static const double labelWidth = 74;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Widget? trail = trailing;

    return PressFade(
      onTap: onTap,
      semanticLabel: '$label: $value',
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        padding: const EdgeInsets.symmetric(vertical: Gap.sm + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: labelWidth,
              child: Padding(
                // Optical alignment: micro caps sit high in their line box, so
                // without this nudge the label floats above its own value.
                padding: const EdgeInsets.only(top: 3),
                child: MicroLabel(label),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                value,
                style: AppText.rowTitle(c).copyWith(color: emphasis),
              ),
            ),
            if (trail != null) ...<Widget>[
              const SizedBox(width: Gap.sm),
              Padding(padding: const EdgeInsets.only(top: 5), child: trail),
            ],
          ],
        ),
      ),
    );
  }
}
