import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/enums.dart';
import '../../../../core/extraction/card_extractor.dart';
import '../../../../core/theme/app_theme.dart';
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
  int? _editingId;
  bool _adding = false;

  void _collapse() {
    setState(() {
      _editingId = null;
      _adding = false;
    });
    widget.onRegionChanged(null);
  }

  void _open(CardField field) {
    setState(() {
      _editingId = field.id;
      _adding = false;
    });
    widget.onRegionChanged(field.regionRect);
  }

  /// Runs a correction and puts the result back in front of search.
  ///
  /// The re-index is not optional: a value the user fixed but search cannot
  /// find is not much of a fix.
  Future<void> _apply(Future<void> Function(CardRepository) action) async {
    await action(ref.read(cardRepositoryProvider));
    await ref
        .read(searchRepositoryProvider)
        .reindexCard(widget.detail.card.id);
    // A corrected phone number is a different person to link against, so the
    // graph is rebuilt from the same edit rather than left pointing at the
    // value that was wrong.
    await ref
        .read(identityRepositoryProvider)
        .promote(widget.detail.card.id);
    if (mounted) _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<OcrBlockRow> blocks = widget.detail.blocks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final CardField field in widget.detail.fields)
          _FieldRow(
            // Keyed by row, because re-labelling a field re-sorts the list —
            // without this the open editor's state could land on its neighbour.
            key: ValueKey<int>(field.id),
            field: field,
            blocks: blocks,
            expanded: _editingId == field.id,
            onOpen: () => _open(field),
            onCancel: _collapse,
            onSave: (String key, String? value, List<int>? blockIds) => _apply(
              (CardRepository repo) => repo.updateField(
                fieldId: field.id,
                fieldKey: key,
                value: value,
                blockIds: blockIds,
              ),
            ),
            onDelete: () => _apply(
              (CardRepository repo) => repo.deleteField(field.id),
            ),
          ),
        const SizedBox(height: Gap.sm),
        if (_adding)
          Card(
            margin: const EdgeInsets.only(bottom: Gap.sm),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: _FieldEditor(
                // Whatever the card is missing most often; the user re-labels
                // in one tap if it is something else.
                initialKey: FieldKeys.phone,
                initialValue: '',
                blocks: blocks,
                initialBlockIds: const <int>[],
                onCancel: _collapse,
                onSave: (String key, String? value, List<int>? blockIds) =>
                    _apply(
                  (CardRepository repo) => repo.addField(
                    cardId: widget.detail.card.id,
                    fieldKey: key,
                    value: value,
                    blockIds: blockIds,
                  ),
                ),
              ),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _adding = true;
                _editingId = null;
              }),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                widget.detail.fields.isEmpty
                    ? 'Add a detail'
                    : 'Add something it missed',
              ),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Signature for committing an edit: a key, and either typed text or the
/// blocks to build the value from.
typedef _SaveField = void Function(
  String key,
  String? value,
  List<int>? blockIds,
);

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.blocks,
    super.key,
    required this.expanded,
    required this.onOpen,
    required this.onCancel,
    required this.onSave,
    required this.onDelete,
  });

  final CardField field;
  final List<OcrBlockRow> blocks;
  final bool expanded;
  final VoidCallback onOpen;
  final VoidCallback onCancel;
  final _SaveField onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool flagged = needsALook(field);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      // Flagged rows are pushed forward rather than merely marked, because the
      // ones the extractor is unsure about are exactly the ones worth a glance.
      color: flagged && !expanded
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
          : null,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: _FieldEditor(
                initialKey: field.fieldKey,
                initialValue: field.value,
                blocks: blocks,
                initialBlockIds: <int>[
                  for (final OcrBlockRow b in blocks)
                    if (b.fieldId == field.id) b.id,
                ],
                onCancel: onCancel,
                onSave: onSave,
                onDelete: onDelete,
              ),
            )
          : ListTile(
              onTap: onOpen,
              title: Text(field.value),
              // Wrapped for the same reason: a long label beside a long
              // provenance chip runs past the edge of a narrow screen.
              subtitle: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(fieldLabel(field.fieldKey)),
                  SourceChip(field: field),
                ],
              ),
              trailing: Icon(
                flagged ? Icons.flag_outlined : Icons.edit_outlined,
                size: 20,
                color: flagged
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline,
              ),
            ),
    );
  }
}

/// Repairs one field, cheapest option first.
class _FieldEditor extends StatefulWidget {
  const _FieldEditor({
    required this.initialKey,
    required this.initialValue,
    required this.blocks,
    required this.initialBlockIds,
    required this.onCancel,
    required this.onSave,
    this.onDelete,
  });

  final String initialKey;
  final String initialValue;
  final List<OcrBlockRow> blocks;
  final List<int> initialBlockIds;
  final VoidCallback onCancel;
  final _SaveField onSave;

  /// Absent when adding, because there is nothing yet to remove.
  final VoidCallback? onDelete;

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  late String _key = widget.initialKey;
  late final Set<int> _selected = widget.initialBlockIds.toSet();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Blocks in reading order — the order they were laid out on the card, which
  /// is the order the joined value should read in.
  List<OcrBlockRow> get _selectedBlocks => widget.blocks
      .where((OcrBlockRow b) => _selected.contains(b.id))
      .toList();

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
    final ThemeData theme = Theme.of(context);
    final List<OcrBlockRow> offerable = widget.blocks
        .where((OcrBlockRow b) => b.blockText.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('What is this?', style: theme.textTheme.labelLarge),
        const SizedBox(height: Gap.xs),
        // Re-labelling costs no typing at all, which is why it comes first:
        // most bad extractions read the text correctly and filed it wrong.
        Wrap(
          spacing: Gap.xs,
          runSpacing: Gap.xs,
          children: <Widget>[
            for (final String key in FieldKeys.all)
              ChoiceChip(
                label: Text(fieldLabel(key)),
                selected: _key == key,
                onSelected: (_) => setState(() => _key = key),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _controller,
          autofocus: widget.initialValue.isEmpty,
          keyboardType: _key == FieldKeys.phone
              ? TextInputType.phone
              : _key == FieldKeys.email
                  ? TextInputType.emailAddress
                  : TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (offerable.isNotEmpty) ...<Widget>[
          const SizedBox(height: Gap.md),
          Text(
            'Or take it from the card',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Tap more than one to join them.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: <Widget>[
              for (final OcrBlockRow b in offerable)
                FilterChip(
                  label: Text(
                    b.blockText.trim(),
                    // A card line is often wider than the screen. Cut it with
                    // an ellipsis rather than letting the chip clip it
                    // mid-character, which reads as a rendering fault.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      // Blocks already spoken for by another field are offered
                      // anyway — taking one back is a normal repair — but they
                      // read quieter so the free text stands out.
                      color: b.fieldId != null && !_selected.contains(b.id)
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  selected: _selected.contains(b.id),
                  onSelected: (_) => _toggleBlock(b),
                ),
            ],
          ),
        ],
        const SizedBox(height: Gap.md),
        // Two lines on purpose. All three actions abreast are wider than a
        // 360 dp phone, and a single Row overflows and paints them over each
        // other. Splitting also puts the destructive action well away from the
        // one the thumb is heading for.
        if (widget.onDelete != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
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
      ],
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
    final ColorScheme colours = Theme.of(context).colorScheme;
    final (String text, Color colour) = _describe(colours);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colour),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colour),
      ),
    );
  }

  (String, Color) _describe(ColorScheme colours) {
    // An unresolved objection outranks even the user's own confirmation. A
    // number too short to dial must not read as settled just because somebody
    // tapped Save on it — silent wrong data is the failure mode that costs
    // trust in everything else the app says.
    if (needsALook(field)) return ('needs a look', colours.error);
    if (field.verifiedByUser) return ('you confirmed', colours.primary);

    return switch (field.validationIssue) {
      'digit_restored' => ('digit restored', colours.tertiary),
      'ocr_repaired' => ('OCR repaired', colours.tertiary),
      _ => switch (field.source) {
          FactSource.printed => ('on the card', colours.outline),
          FactSource.user => ('you typed', colours.primary),
          FactSource.aiInferred => ('guess', colours.tertiary),
          FactSource.outdated => ('may be old', colours.error),
          FactSource.verified => ('verified', colours.primary),
        },
    };
  }
}
