import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/primitives.dart';

/// Opens the "why did you save this?" sheet and returns what the user decided.
///
/// One sheet for both moments the note is written: at save, where it is
/// frame 04b, and afterwards from the card, where a note written in a hurry at
/// an event can be corrected and a skipped one can finally be added. The two
/// differ only in their words and in what the quiet button means, so they are
/// one widget — two copies would drift, and the note is the single most
/// valuable thing the user types into this app.
///
/// Returns the text on the primary button, [secondaryResult] on the secondary
/// one, and null if the sheet was dismissed without deciding.
Future<String?> showNoteSheet(
  BuildContext context, {
  required String question,
  required String explanation,
  required String primaryLabel,
  required String secondaryLabel,
  required String? secondaryResult,
  String initial = '',
  bool emphasised = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => NoteSheet(
      question: question,
      explanation: explanation,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
      secondaryResult: secondaryResult,
      initial: initial,
      emphasised: emphasised,
    ),
  );
}

/// The sheet itself. Public so a widget test can pump it directly.
class NoteSheet extends StatefulWidget {
  const NoteSheet({
    required this.question,
    required this.explanation,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.secondaryResult,
    this.initial = '',
    this.emphasised = false,
    super.key,
  });

  /// Serif italic — the app asking the user (design rule 3).
  final String question;
  final String explanation;
  final String primaryLabel;
  final String secondaryLabel;

  /// What the secondary button returns: `''` at capture ("Skip for now" still
  /// saves the card, just without a note), null when editing ("Cancel" changes
  /// nothing).
  final String? secondaryResult;
  final String initial;

  /// The vermilion "Nothing was readable" pill and the harder wording, shown
  /// only when extraction found little or nothing.
  final bool emphasised;

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: Gap.lg,
        right: Gap.lg,
        top: Gap.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.emphasised) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm + 2,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: c.vermilion.withValues(alpha: 0.14),
                  borderRadius: AppRadius.chipR,
                ),
                child: MicroLabel('Nothing was readable', color: c.vermilion),
              ),
            ),
            const SizedBox(height: Gap.md),
          ],
          Text(
            widget.question,
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.sm),
          Text(widget.explanation, style: AppText.body(c)),
          const SizedBox(height: Gap.md),
          Pocket(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm + 2,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              cursorColor: c.ochre,
              cursorWidth: 2,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.rowTitle(c).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                fontVariations: AppFonts.weight(400),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'cheap t-shirt printing, did our fest shirts',
                hintStyle: AppText.body(c).copyWith(fontSize: 15),
              ),
              onSubmitted: (String v) => Navigator.of(context).pop(v),
            ),
          ),
          const SizedBox(height: Gap.md),
          InkPill(
            label: widget.primaryLabel,
            height: 58,
            onTap: () => Navigator.of(context).pop(_controller.text),
          ),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(widget.secondaryResult),
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text(
                  widget.secondaryLabel,
                  style: AppText.button(c, on: c.inkMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
