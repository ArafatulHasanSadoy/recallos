import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/enums.dart';
import '../../../../core/extraction/card_extractor.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/primitives.dart';
import '../../../capture/data/card_repository.dart';
import '../../../contacts/data/identity_repository.dart';
import '../../../search/data/search_repository.dart';

/// Human name for a field key.
String fieldLabel(String key) => switch (key) {
  FieldKeys.personName => 'Name',
  FieldKeys.company => 'Company',
  FieldKeys.designation => 'Designation',
  FieldKeys.phone => 'Phone',
  FieldKeys.email => 'Email',
  FieldKeys.website => 'Website',
  FieldKeys.address => 'Address',
  _ => key,
};

/// The fields read off a card, each one repairable in place.
///
/// Extraction gets layout wrong on unusual cards — a brand set over a
/// descriptor, a vertical layout, a shop name that reads like a job title — and
/// a value the app shows as fact but got wrong is worse than one it never
/// found. So every row opens, and the repair is offered cheapest first:
/// re-label it, re-source it from text the card already yielded, and only then
/// type.
///
/// Rows the extractor flagged are pushed forward; the rest stay quiet. That is
/// confidence-based verification rather than a form to fill in — a clean scan
/// should still be two taps.
class EditableFieldList extends ConsumerStatefulWidget {
  const EditableFieldList({
    required this.detail,
    required this.onRegionChanged,
    super.key,
  });

  final CardDetail detail;

  /// Reports the region of the row being edited so the image above can box it.
  final ValueChanged<String?> onRegionChanged;

  @override
  ConsumerState<EditableFieldList> createState() => _EditableFieldListState();
}

class _EditableFieldListState extends ConsumerState<EditableFieldList> {
  /// Runs a correction and puts the result back in front of search.
  ///
  /// The re-index is not optional: a value the user fixed but search cannot
  /// find is not much of a fix.
  Future<void> _apply(Future<void> Function(CardRepository) action) async {
    await action(ref.read(cardRepositoryProvider));
    await ref.read(searchRepositoryProvider).reindexCard(widget.detail.card.id);
    // A corrected phone number is a different person to link against, so the
    // graph is rebuilt from the same edit rather than left pointing at the
    // value that was wrong.
    await ref.read(identityRepositoryProvider).promote(widget.detail.card.id);
  }

  /// Opens one field for repair, and applies whatever comes back.
  Future<void> _edit(CardField field) async {
    // Box the region on the card above before the sheet arrives, so the
    // printing this value was read from is already framed when it opens.
    widget.onRegionChanged(field.regionRect);

    final _EditorOutcome? outcome = await _openEditor(
      title: 'Edit this detail',
      initialKey: field.fieldKey,
      initialValue: field.value,
      initialBlockIds: <int>[
        for (final OcrBlockRow b in widget.detail.blocks)
          if (b.fieldId == field.id) b.id,
      ],
      removable: true,
    );

    if (!mounted) return;
    widget.onRegionChanged(null);
    switch (outcome) {
      case null:
        return;
      case _SaveEdit(
        :final String key,
        :final String? value,
        :final List<int>? blockIds,
      ):
        await _apply(
          (CardRepository repo) => repo.updateField(
            fieldId: field.id,
            fieldKey: key,
            value: value,
            blockIds: blockIds,
          ),
        );
      case _RemoveField():
        await _apply((CardRepository repo) => repo.deleteField(field.id));
    }
  }

  Future<void> _add() async {
    final _EditorOutcome? outcome = await _openEditor(
      title: 'Add a detail',
      // Whatever the card is missing most often; the user re-labels in one tap
      // if it is something else.
      initialKey: FieldKeys.phone,
      initialValue: '',
      initialBlockIds: const <int>[],
      removable: false,
    );

    if (outcome is! _SaveEdit || !mounted) return;
    await _apply(
      (CardRepository repo) => repo.addField(
        cardId: widget.detail.card.id,
        fieldKey: outcome.key,
        value: outcome.value,
        blockIds: outcome.blockIds,
      ),
    );
  }

  /// Puts the editor in a modal sheet rather than in the list.
  ///
  /// It used to expand in place, which put two Save buttons on screen at once
  /// on the capture screen: this one, somewhere in a scrolling list, and the
  /// card's own in the bar pinned along the bottom. The bottom one is larger,
  /// never moves and is where a thumb already rests — so the reliable way to
  /// finish an edit was to hit the wrong one, which saved the card, popped the
  /// screen, and dropped the correction being typed without a word.
  ///
  /// Modal fixes it by construction rather than by labelling: while a field is
  /// open the card's Save cannot be reached at all, and the only Save on
  /// screen is the one for the thing being edited.
  Future<_EditorOutcome?> _openEditor({
    required String title,
    required String initialKey,
    required String initialValue,
    required List<int> initialBlockIds,
    required bool removable,
  }) {
    return showModalBottomSheet<_EditorOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Lighter than the default black54. The whole reason a field opens with
      // its region boxed on the image is so the value can be checked against
      // the printing while it is corrected; a scrim heavy enough to hide that
      // would take the feature away to solve a layout problem.
      barrierColor: Colors.black.withValues(alpha: 0.20),
      // Height is capped inside the sheet rather than here. A route-level
      // `constraints` is measured once, against this context, before the
      // keyboard exists — and then the keyboard's inset is subtracted from
      // that same fixed box, leaving a couple of hundred pixels with the value
      // field clipped through the middle of its own text.
      builder: (BuildContext sheet) => _EditorSheet(
        title: title,
        onRemove: removable
            ? () => Navigator.of(sheet).pop(const _RemoveField())
            : null,
        child: _FieldEditor(
          initialKey: initialKey,
          initialValue: initialValue,
          blocks: widget.detail.blocks,
          initialBlockIds: initialBlockIds,
          // `maybePop`, not `pop`: it goes through the unsaved-changes guard
          // in the editor, so Cancel, the back gesture and a tap outside all
          // behave the same way.
          onCancel: () => Navigator.of(sheet).maybePop(),
          onSave: (String key, String? value, List<int>? blockIds) =>
              Navigator.of(
                sheet,
              ).pop(_SaveEdit(key: key, value: value, blockIds: blockIds)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final CardField field in widget.detail.fields)
          _FieldRow(
            key: ValueKey<int>(field.id),
            field: field,
            onOpen: () => _edit(field),
          ),
        const SizedBox(height: Gap.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextAction(
            label: widget.detail.fields.isEmpty
                ? 'Add a detail'
                : 'Add something it missed',
            icon: Icons.add,
            onTap: _add,
          ),
        ),
      ],
    );
  }
}

/// What the editor sheet came back with, if anything.
///
/// A type rather than a bare value because the sheet has two ways of
/// succeeding — a correction and a removal — and dismissing it is a third
/// outcome that must not be confused with either.
sealed class _EditorOutcome {
  const _EditorOutcome();
}

class _SaveEdit extends _EditorOutcome {
  const _SaveEdit({required this.key, this.value, this.blockIds});

  final String key;

  /// Typed text, or null when the value is the blocks below verbatim.
  final String? value;
  final List<int>? blockIds;
}

class _RemoveField extends _EditorOutcome {
  const _RemoveField();
}

/// The sheet around the editor: a title, a way out, and room for the keyboard.
class _EditorSheet extends StatelessWidget {
  const _EditorSheet({required this.title, required this.child, this.onRemove});

  final String title;
  final Widget child;

  /// Absent when adding, because there is nothing yet to remove.
  ///
  /// In the header rather than beside Save, where it used to sit. The actions
  /// are pinned to the bottom of the sheet now, and a destructive button
  /// pinned a thumb's width from the one people are aiming for is the same
  /// mistake this whole change is about, in miniature.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final VoidCallback? remove = onRemove;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    final Widget body = Padding(
      // The keyboard's height, so the field being typed into is never under
      // it. `isScrollControlled` is what makes this possible at all.
      padding: EdgeInsets.only(bottom: keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(title, style: AppText.rowSerif(c))),
                if (remove != null)
                  TextAction(
                    label: 'Remove',
                    icon: Icons.delete_outline,
                    tint: c.vermilion,
                    onTap: remove,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          Flexible(child: child),
        ],
      ),
    );

    // Two different jobs, so two different limits.
    //
    // With the keyboard down the user is *looking* — at the value, and at the
    // region boxed on the card above it — so the sheet stops short of three
    // fifths of the screen and leaves the photo whole. With the keyboard up
    // they are typing, and there is not room for both; the sheet takes what it
    // needs and the card gives way, because a clipped value field is worse
    // than a covered photo. Closing the keyboard brings the card straight
    // back.
    if (keyboard > 0) return body;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: body,
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field, required this.onOpen, super.key});

  final CardField field;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool flagged = needsALook(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: PressFade(
        onTap: onOpen,
        semanticLabel: '${fieldLabel(field.fieldKey)}: ${field.value}',
        child: Container(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm + 4, Gap.sm, Gap.sm + 4),
          decoration: AppDecoration.card(
            c,
            isDark: isDarkTheme(context),
            lifted: false,
          ).copyWith(
            // Flagged rows are pushed forward rather than merely marked: the
            // ones the extractor is unsure about are the ones worth a glance.
            color: flagged
                ? Color.lerp(c.card, c.vermilion, 0.07)
                : null,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(field.value, style: AppText.rowTitle(c)),
                    const SizedBox(height: Gap.xs),
                    // Wrapped because a long label beside a long provenance
                    // chip runs past the edge of a narrow screen.
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        MicroLabel(fieldLabel(field.fieldKey)),
                        SourceChip(field: field),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(
                flagged ? Icons.flag_outlined : Icons.edit_outlined,
                size: 19,
                color: flagged ? c.vermilion : c.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signature for committing an edit: a key, and either typed text or the
/// blocks to build the value from.
typedef _SaveField =
    void Function(String key, String? value, List<int>? blockIds);

/// Repairs one field, cheapest option first.
class _FieldEditor extends StatefulWidget {
  const _FieldEditor({
    required this.initialKey,
    required this.initialValue,
    required this.blocks,
    required this.initialBlockIds,
    required this.onCancel,
    required this.onSave,
  });

  final String initialKey;
  final String initialValue;
  final List<OcrBlockRow> blocks;
  final List<int> initialBlockIds;
  final VoidCallback onCancel;
  final _SaveField onSave;

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late String _key = widget.initialKey;
  late final Set<int> _selected = widget.initialBlockIds.toSet();
  final FocusNode _focus = FocusNode();

  /// Whether the user has actually been typing in this editor.
  ///
  /// Re-labelling rebuilds the text field, which closes the keyboard, and
  /// whether that should be undone depends on what the user was doing.
  /// Someone mid-edit wants the keyboard straight back; someone who only
  /// opened a row to correct its label does not want one thrown at them.
  ///
  /// Checking `hasFocus` at the moment the chip is tapped does not answer it —
  /// tapping the chip has already taken focus away by then. Adding a field
  /// starts focused, so that counts as typing from the outset.
  late bool _touchedValue = widget.initialValue.isEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The keyboard this kind of value is typed on.
  ///
  /// A number pad for a number, and letters for everything else. Getting this
  /// wrong is not cosmetic: an email cannot be typed at all on a keypad with
  /// no `@`.
  TextInputType get _keyboard => switch (_key) {
    FieldKeys.phone => TextInputType.phone,
    FieldKeys.email => TextInputType.emailAddress,
    FieldKeys.website => TextInputType.url,
    FieldKeys.address => TextInputType.streetAddress,
    _ => TextInputType.text,
  };

  /// Names, companies and job titles are capitalised; addresses too. An email
  /// or a website is not — a leading capital there is a correction to undo.
  TextCapitalization get _capitalization => switch (_key) {
    FieldKeys.personName ||
    FieldKeys.company ||
    FieldKeys.designation ||
    FieldKeys.address => TextCapitalization.words,
    _ => TextCapitalization.none,
  };

  /// Re-labels the field being edited, and gets the right keyboard with it.
  ///
  /// Changing `keyboardType` on a focused `TextField` does not change the
  /// keyboard: the input connection is negotiated when the field attaches and
  /// is not renegotiated on rebuild. Since adding a field starts on Phone —
  /// the commonest thing a card is missing — switching to Email left the user
  /// looking at a number pad with no `@` on it, which is unusable rather than
  /// merely untidy.
  ///
  /// Keying the field on its keyboard type is what fixes it: a different type
  /// is a different widget, so the old connection is torn down and a new one
  /// opened. Focus is restored afterwards, or re-labelling would dismiss the
  /// keyboard the user is in the middle of using.
  void _relabel(String key) {
    if (key == _key) return;
    setState(() => _key = key);
    if (!_touchedValue) return;

    // A round trip through unfocused, not a bare `requestFocus`.
    //
    // Rebuilding the field tears down the platform input connection but
    // leaves the node holding focus, so asking for focus again is a no-op:
    // Flutter opens a keyboard on a focus *transition*, and from its point of
    // view nothing transitioned. The visible result is a text field drawn
    // focused, cursor and all, with no keyboard under it — which is worse
    // than the bug this is fixing, because the field looks ready to type in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    });
  }

  /// Blocks in reading order — the order they were laid out on the card, which
  /// is the order the joined value should read in.
  List<OcrBlockRow> get _selectedBlocks =>
      widget.blocks.where((OcrBlockRow b) => _selected.contains(b.id)).toList();

  String get _joined => _selectedBlocks
      .map((OcrBlockRow b) => b.blockText.trim())
      .where((String t) => t.isNotEmpty)
      .join(' ');

  void _toggleBlock(OcrBlockRow block) {
    setState(() {
      if (!_selected.remove(block.id)) _selected.add(block.id);
      // The value follows the selection, so picking two blocks shows the
      // joined result immediately instead of after saving.
      _controller.text = _joined;
    });
  }

  /// Whether anything here would be lost by closing the sheet now.
  bool get _dirty =>
      _controller.text.trim() != widget.initialValue.trim() ||
      _key != widget.initialKey ||
      !setEquals(_selected, widget.initialBlockIds.toSet());

  /// Asks before throwing away a correction.
  ///
  /// The sheet can be left three ways — Cancel, the back gesture, a tap on the
  /// dimmed card above — and all three used to discard silently. That is the
  /// same way the old inline editor lost work, just with a different finger
  /// slip, so fixing one without the other would only move the problem.
  Future<void> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Discard this change?'),
        content: const Text('What you typed here will not be kept.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    Navigator.of(context).pop();
  }

  void _save() {
    final String text = _controller.text.trim();
    if (text.isEmpty) return;

    // Send the blocks only when the value is still exactly what they say. Once
    // the text has been edited by hand it no longer belongs to any block, and
    // claiming otherwise would box the wrong region on the image.
    final bool fromBlocks = _selected.isNotEmpty && text == _joined;
    widget.onSave(
      _key,
      fromBlocks ? null : text,
      fromBlocks ? _selectedBlocks.map((OcrBlockRow b) => b.id).toList() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final List<OcrBlockRow> offerable = widget.blocks
        .where((OcrBlockRow b) => b.blockText.trim().isNotEmpty)
        .toList();

    return PopScope(
      // Blocks only the *implicit* ways out — back, and a tap on the barrier,
      // which Cancel is routed through as well. An explicit `pop` with a
      // result is untouched, so Save and Remove still close immediately.
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Flexible rather than Expanded, so a short edit makes a short
          // sheet. What it buys is the pinned row below.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Rule 3: a question addressed to the user is the app's own
                  // voice, so it is the serif italic — not micro-caps, which
                  // would shout it, and not a heading, which it is not.
                  Text(
                    'What is this?',
                    style: AppText.displayAsk(c).copyWith(
                      fontSize: 21,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: Gap.sm + 2),
                  // Re-labelling costs no typing at all, which is why it comes first:
                  // most bad extractions read the text correctly and filed it wrong.
                  Wrap(
                    spacing: Gap.xs,
                    runSpacing: Gap.xs,
                    children: <Widget>[
                      for (final String key in FieldKeys.all)
                        SelectChip(
                          label: fieldLabel(key),
                          selected: _key == key,
                          onTap: () => _relabel(key),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  // Rule 1: recessed, never outlined. This was the last
                  // `OutlineInputBorder` in the app.
                  Pocket(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: Gap.sm + 2,
                    ),
                    child: TextField(
                      // See [_relabel]: the key is what makes the keyboard
                      // follow the label instead of being fixed at whatever the
                      // field opened as.
                      key: ValueKey<TextInputType>(_keyboard),
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: widget.initialValue.isEmpty,
                      keyboardType: _keyboard,
                      textCapitalization: _capitalization,
                      autocorrect: _capitalization == TextCapitalization.words,
                      cursorColor: c.ochre,
                      cursorWidth: 2,
                      style: AppText.rowTitle(c).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        fontVariations: AppFonts.weight(400),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Value',
                        hintStyle: AppText.body(c).copyWith(fontSize: 16),
                      ),
                      onTap: () => _touchedValue = true,
                      onChanged: (_) {
                        _touchedValue = true;
                        setState(() {});
                      },
                    ),
                  ),
                  if (offerable.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Gap.md),
                    MicroLabel('Or take it from the card'),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Tap more than one to join them.',
                      style: AppText.small(c),
                    ),
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: Gap.xs,
                      runSpacing: Gap.xs,
                      children: <Widget>[
                        for (final OcrBlockRow b in offerable)
                          SelectChip(
                            // A card line is often wider than the screen;
                            // SelectChip ellipsises rather than clipping
                            // mid-character, which reads as a rendering fault.
                            label: b.blockText.trim(),
                            selected: _selected.contains(b.id),
                            // Blocks already spoken for by another field are
                            // offered anyway — taking one back is a normal
                            // repair — but they read quieter so the free text
                            // stands out.
                            dim: b.fieldId != null && !_selected.contains(b.id),
                            onTap: () => _toggleBlock(b),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Pinned below the scrolling body. On a card with a dozen OCR blocks
          // the chips run past the bottom of the sheet and Save used to go
          // with them, so finishing an edit meant hunting for the button —
          // most of the way back to the problem this change exists to fix.
          // It also keeps Save above the keyboard while typing.
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Gap.xs),
                FilledButton(
                  onPressed: _controller.text.trim().isEmpty ? null : _save,
                  // The theme gives buttons `Size.fromHeight(52)` — an infinite
                  // minimum *width* — which is right for a bottom bar and wrong
                  // here, where Save would swallow the whole line on its own.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 44),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Issues that describe *how* a value was arrived at rather than something
/// still wrong with it. A user confirmation settles these.
const Set<String> _provenanceIssues = <String>{
  'digit_restored',
  'ocr_repaired',
};

/// Whether a field still has an objection nobody has resolved.
bool needsALook(CardField field) =>
    field.validationIssue != null &&
    !_provenanceIssues.contains(field.validationIssue);

/// Where a fact came from, on the fact itself.
///
/// Provenance is what separates this from a card scanner: an OCR guess or a
/// repaired digit never gets to look like something printed on the card.
class SourceChip extends StatelessWidget {
  const SourceChip({required this.field, super.key});

  final CardField field;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final (String text, Color colour) = _describe(c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: AppRadius.chipR,
      ),
      // A tinted wash rather than an outline. Provenance sits next to the
      // field label on every row, and an outlined pill at that size reads as a
      // second, competing border beside the row's own edge.
      child: MetaLabel(text, color: colour),
    );
  }

  (String, Color) _describe(AppColors c) {
    // An unresolved objection outranks even the user's own confirmation. A
    // number too short to dial must not read as settled just because somebody
    // tapped Save on it — silent wrong data is the failure mode that costs
    // trust in everything else the app says.
    if (needsALook(field)) return ('needs a look', c.vermilion);
    if (field.verifiedByUser) return ('you confirmed', c.ochreInk);

    return switch (field.validationIssue) {
      'digit_restored' => ('digit restored', c.olive),
      'ocr_repaired' => ('OCR repaired', c.olive),
      _ => switch (field.source) {
        FactSource.printed => ('on the card', c.inkMuted),
        FactSource.user => ('you typed', c.ochreInk),
        FactSource.aiInferred => ('guess', c.olive),
        FactSource.outdated => ('may be old', c.vermilion),
        FactSource.verified => ('verified', c.ochreInk),
      },
    };
  }
}
