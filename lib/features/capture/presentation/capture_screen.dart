import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/extraction/card_extractor.dart';
import '../../../core/intelligence/engines/mlkit_ocr_engine.dart';
import '../../../core/intelligence/ocr_engine.dart';
import '../../../core/theme/app_theme.dart';
import '../../search/data/search_repository.dart';
import '../data/card_repository.dart';

/// Opens the camera, reads the card, and lets the user keep it.
///
/// The order matters more than it looks. The photo is copied into app storage
/// and a card row is written **before** OCR runs, so a crash, a killed app or a
/// failing engine leaves a recoverable card rather than nothing. Everything
/// after that point — recognition, field assignment, the note — is folded into
/// a row that already exists.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrEngine _engine = MlKitOcrEngine();

  File? _image;
  int? _cardId;
  CardExtraction? _extraction;
  List<OcrBlock> _blocks = const <OcrBlock>[];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Post-frame so the screen (and its back button) is on screen before the
    // OS camera UI takes over — a bare white frame while the camera launches
    // reads as broken.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  @override
  void dispose() {
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _capture() async {
    final CardRepository repo = ref.read(cardRepositoryProvider);

    // Retaking replaces the previous attempt rather than accumulating rows.
    final int? previous = _cardId;
    if (previous != null) {
      unawaited(repo.discard(previous));
      _cardId = null;
    }

    final XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        // Capped rather than full resolution: a 12-megapixel bitmap decodes to
        // ~50 MB, which is what actually kills this app on a 3 GB phone. Card
        // text stays legible well below the sensor's limit.
        maxWidth: 1600,
        imageQuality: 90,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera: $e');
      return;
    }
    if (!mounted) return;

    // User backed out of the camera without taking a shot.
    if (shot == null) {
      if (_image == null && mounted) context.pop();
      return;
    }

    setState(() {
      _image = File(shot!.path);
      _loading = true;
      _extraction = null;
      _blocks = const <OcrBlock>[];
      _error = null;
    });

    try {
      // Save first. From here on the card survives whatever happens next.
      final int cardId = await repo.createPending(File(shot.path));
      if (!mounted) return;
      setState(() => _cardId = cardId);

      final OcrResult result = await _engine.recognize(File(shot.path));
      final CardExtraction extraction =
          CardFieldExtractor.extract(result.blocks);
      await repo.attachExtraction(
        cardId: cardId,
        result: result,
        extraction: extraction,
      );
      // Index straight away so a card is findable even if the user backs out
      // before writing a note.
      await ref.read(searchRepositoryProvider).reindexCard(cardId);

      if (!mounted) return;
      setState(() {
        _blocks = result.blocks;
        _extraction = extraction;
        _loading = false;
        _error = result.isTotalFailure
            ? 'No text found on this card. Save it anyway and tell RecallOS '
                'why it matters — that alone makes it findable.'
            : null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not read the card: $e';
      });
    }
  }

  /// Asks the one question that always works, then commits.
  ///
  /// Every competitor's answer to a bad scan is "type it in yourself". Ours is
  /// the note: a card with zero extracted fields but a note saying "cheap
  /// t-shirt printer from CSE fest" is still fully retrievable by need. So the
  /// prompt is more prominent when extraction went badly, not less.
  Future<void> _save() async {
    final int? cardId = _cardId;
    if (cardId == null) return;

    final bool nothingFound = _extraction?.isUseful != true;
    final String? note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _NotePrompt(emphasised: nothingFound),
    );
    // Dismissed the sheet without deciding — keep them on the review screen.
    if (note == null || !mounted) return;

    setState(() => _saving = true);
    final CardRepository repo = ref.read(cardRepositoryProvider);
    await repo.addNote(cardId: cardId, body: note);
    // Re-index with the note included — it is usually the most valuable text on
    // the record, and the reason need-based search finds anything at all.
    await ref.read(searchRepositoryProvider).reindexCard(cardId);

    if (!mounted) return;
    _cardId = null; // Committed, so leaving must not discard it.
    context.pop();
  }

  Future<void> _discardAndLeave() async {
    final int? cardId = _cardId;
    if (cardId != null) {
      _cardId = null;
      await ref.read(cardRepositoryProvider).discard(cardId);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final CardExtraction? extraction = _extraction;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) unawaited(_discardAndLeave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan'),
          // A back arrow rather than a close cross, so every screen in the app
          // has the same way out. Leaving here still discards the scan — the
          // card is only committed by Save.
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving ? null : _discardAndLeave,
          ),
        ),
        body: SafeArea(
          child: _image == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(Gap.md),
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _image!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // Decode at display size rather than full resolution.
                        cacheHeight: 660,
                      ),
                    ),
                    if (_loading) ...<Widget>[
                      const SizedBox(height: Gap.md),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: Gap.md),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                    if (extraction != null &&
                        extraction.fields.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Gap.lg),
                      Text('Found on the card',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: Gap.sm),
                      for (final ExtractedField f in extraction.fields)
                        _FieldTile(field: f),
                    ],
                    if (extraction != null &&
                        extraction.unassignedBlockIndices.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Gap.lg),
                      Text(
                        'Other text on the card',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: Gap.sm),
                      Text(
                        extraction.unassignedBlockIndices
                            .map((int i) => _blocks[i].text)
                            .join('\n'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: Gap.xl),
                  ],
                ),
        ),
        bottomNavigationBar: _image == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  // Equal halves. Both carry their symbol — a refresh arrow for
                  // retake, a tick for save — so the action reads at a glance
                  // before the label does.
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_loading || _saving) ? null : _capture,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        // Enabled even when nothing was extracted. A saved photo
                        // plus a note beats the paper card the user was about to
                        // lose, so a bad scan must never be a dead end.
                        child: FilledButton.icon(
                          onPressed:
                              (_loading || _saving || _cardId == null)
                                  ? null
                                  : _save,
                          icon: const Icon(Icons.check),
                          label: Text(_saving ? 'Saving…' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// The "why are you saving this?" sheet.
class _NotePrompt extends StatefulWidget {
  const _NotePrompt({required this.emphasised});

  /// Set when extraction found little or nothing, in which case the note is not
  /// a nice-to-have — it is the only thing that will make this card findable.
  final bool emphasised;

  @override
  State<_NotePrompt> createState() => _NotePromptState();
}

class _NotePromptState extends State<_NotePrompt> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.md,
        right: Gap.md,
        top: Gap.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Why are you saving this?',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: Gap.xs),
          Text(
            widget.emphasised
                ? 'Not much was readable on this card, so this note is how '
                    "you'll find it later."
                : "You'll search by this later, so write it how you'd say it.",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. cheap t-shirt printing, did our fest shirts',
            ),
            onSubmitted: (String v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: Gap.md),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Save card'),
          ),
          TextButton(
            // Still saves — the card and its fields are already on disk. This
            // only declines to add a note.
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.field});

  final ExtractedField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? raw = field.rawText;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        title: Text(field.value),
        subtitle: Text(
          // When we corrected what OCR read, say so rather than quietly
          // swapping one for the other.
          raw == null ? _label(field.fieldKey) : '${_label(field.fieldKey)} · card reads "$raw"',
        ),
        trailing: field.needsReview
            ? Icon(
                Icons.flag_outlined,
                color: theme.colorScheme.error,
                size: 20,
              )
            : null,
      ),
    );
  }

  static String _label(String key) => switch (key) {
        FieldKeys.personName => 'Name',
        FieldKeys.company => 'Company',
        FieldKeys.designation => 'Designation',
        FieldKeys.phone => 'Phone',
        FieldKeys.email => 'Email',
        FieldKeys.website => 'Website',
        FieldKeys.address => 'Address',
        _ => key,
      };
}
