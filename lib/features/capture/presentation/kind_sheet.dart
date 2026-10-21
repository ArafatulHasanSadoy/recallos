import 'package:flutter/material.dart';

import '../../../core/db/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';

/// The kinds of paper capture can save, in the order the sheet offers them.
const List<CardType> kCapturableKinds = <CardType>[
  CardType.visitingCard,
  CardType.receipt,
  CardType.warrantyCard,
];

/// "business card", "receipt", "warranty" — how a kind is said in a sentence.
String kindNoun(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => 'receipt',
  CardType.warrantyCard => 'warranty',
  _ => 'business card',
};

/// "card", "receipt", "warranty" — the paper, in a heading: *On the
/// receipt*, *Found on the warranty*.
String paperNoun(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => 'receipt',
  CardType.warrantyCard => 'warranty',
  _ => 'card',
};

/// The example in an empty note, for the kind of paper: a business card's
/// is a need, a receipt's what it was for, a warranty's what it covers.
/// Found on the phone: a receipt's note still suggested "cheap t-shirt
/// printing" under a line about office chairs.
String noteHintFor(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => 'new office chair, for home',
  CardType.warrantyCard => 'the kitchen fridge',
  _ => 'cheap t-shirt printing, did our fest shirts',
};

/// "Save card", "Save receipt", "Save warranty".
String saveLabelFor(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => 'Save receipt',
  CardType.warrantyCard => 'Save warranty',
  _ => 'Save card',
};

/// Asks what a scan is, when the words alone did not say (B2).
///
/// One tap answers it. The classifier's best guess is marked, and closing
/// the sheet keeps that guess — it can still be changed from *Saved as a …*
/// on the review. Returns the chosen kind, or null when closed.
Future<CardType?> showKindSheet(
  BuildContext context, {
  required CardType suggested,
}) {
  return showModalBottomSheet<CardType>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => KindSheet(suggested: suggested),
  );
}

/// The sheet. Public so a widget test can pump it directly.
class KindSheet extends StatelessWidget {
  const KindSheet({required this.suggested, super.key});

  final CardType suggested;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Rule 3: the app asking the user something.
          Text(
            'What did you save?',
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'The words on it could be either. Saying which reads it the '
            'right way.',
            style: AppText.body(c),
          ),
          const SizedBox(height: Gap.md),
          SettingGroup(
            label: 'It is a',
            children: <Widget>[
              for (final CardType kind in kCapturableKinds)
                SettingRow(
                  label: _title(kind),
                  description: _hint(kind),
                  trailing: kind == suggested
                      ? MicroLabel('Best guess', color: c.ochreInk)
                      : null,
                  onTap: () => Navigator.of(context).pop(kind),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(),
            semanticLabel: 'Keep the best guess',
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text(
                  'Keep the best guess',
                  style: AppText.button(c, on: c.inkMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _title(CardType kind) => switch (kind) {
    CardType.receipt => 'Receipt or invoice',
    CardType.warrantyCard => 'Warranty',
    _ => 'Business card',
  };

  static String _hint(CardType kind) => switch (kind) {
    CardType.receipt => 'What you bought, where, and for how much.',
    CardType.warrantyCard => 'What is covered, and until when.',
    _ => 'Someone you met, and how to reach them.',
  };
}
