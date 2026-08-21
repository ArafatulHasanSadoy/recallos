import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extraction/card_extractor.dart';
import '../../../core/imaging/card_image_processor.dart';
import '../../../core/intelligence/engines/mlkit_ocr_engine.dart';
import '../../../core/intelligence/ocr_engine.dart';
import '../../../core/theme/app_theme.dart';
import '../../cards/presentation/widgets/card_image_overlay.dart';
import '../../cards/presentation/widgets/editable_field_list.dart';
import '../../contacts/data/identity_repository.dart';
import '../../search/data/search_repository.dart';
import '../data/card_repository.dart';

/// Opens the camera, reads the card, and lets the user correct it.
///
/// The order matters more than it looks. The photo is copied into app storage
/// and a card row is written **before** OCR runs, so a crash, a killed app or a
/// failing engine leaves a recoverable card rather than nothing.
///
/// One consequence shapes this whole screen: by the time there is anything to
/// review, it is already in the database. So the review reads the same stream
/// the detail screen does rather than holding extraction results in memory,
/// and a correction made here is saved the moment it is made — consistent with
/// save-first rather than an exception to it.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final OcrEngine _engine = MlKitOcrEngine();

  File? _image;
  int? _cardId;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  /// Region of the field currently being edited, boxed on the image above.
  String? _highlight;

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

    final List<String>? pages;
    try {
      pages = await CunningDocumentScanner.getPictures(
        // One card at a time. The scanner finds the edges, corrects the
        // perspective and hands back the card alone rather than the desk it
        // was lying on — which is also a large free win for OCR, since the
        // text now fills the frame instead of a third of it.
        noOfPages: 1,
        scannerSource: ScannerSource.cameraAndGallery,
        androidScannerMode: AndroidScannerMode.full,
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.9,
        ),
      );
    } on CunningDocumentScannerException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.code == 'permission_denied'
          ? 'RecallOS needs camera access to scan a card.'
          : 'Could not open the scanner: ${e.message}');
      return;
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the scanner: $e');
      return;
    }
    if (!mounted) return;

    // User backed out of the scanner without keeping a page.
    if (pages == null || pages.isEmpty) {
      if (_image == null && mounted) context.pop();
      return;
    }

    final File scanned = File(pages.first);
    setState(() {
      _image = scanned;
      _loading = true;
      _highlight = null;
      _error = null;
    });

    try {
      // Save first, out of the scanner's cache and into our own storage. From
      // here on the card survives whatever happens next.
      final ({int id, File image}) pending = await repo.createPending(scanned);
      if (!mounted) return;
      setState(() => _cardId = pending.id);

      final File working = await _prepare(repo, pending, scanned);
      if (!mounted) return;
      setState(() => _image = working);

      final OcrResult result = await _engine.recognize(working);
      final CardExtraction extraction =
          CardFieldExtractor.extract(result.blocks);
      await repo.attachExtraction(
        cardId: pending.id,
        result: result,
        extraction: extraction,
      );
      // Index straight away so a card is findable even if the user backs out
      // before writing a note.
      await ref.read(searchRepositoryProvider).reindexCard(pending.id);
      // The fields just written are also what the person and company behind
      // this card are built from.
      await ref.read(identityRepositoryProvider).promote(pending.id);

      if (!mounted) return;
      setState(() {
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

  /// Downscales the capture, writes its thumbnail, and returns the file
  /// everything downstream should use.
  ///
  /// **The returned file is the one OCR must read.** Field regions are recorded
  /// in the pixel space of whatever image the engine was given, and the screens
  /// paint highlights onto the stored image — so resizing after recognition,
  /// or displaying a different file from the one recognised, would put every
  /// highlight somewhere other than the words it came from. Nothing would
  /// throw; it would just be quietly wrong.
  ///
  /// Runs in an isolate because decoding a full-resolution photo on the UI
  /// thread drops frames on exactly the hardware this app is aimed at.
  Future<File> _prepare(
    CardRepository repo,
    ({int id, File image}) pending,
    File scanned,
  ) async {
    try {
      final Directory cards = await repo.cardsDirectory();
      final String targetDir = cards.path;
      final String baseName =
          'card_${pending.id}_${DateTime.now().microsecondsSinceEpoch}';

      final PreparedImage prepared = await Isolate.run(
        () => prepareCardImage(CardImageRequest(
          sourcePath: scanned.path,
          targetDir: targetDir,
          baseName: baseName,
        )),
      );

      await repo.attachImages(
        cardId: pending.id,
        imagePath: prepared.imagePath,
        thumbPath: prepared.thumbPath,
      );

      // The plugin's cache has served its purpose now that the pixels are ours.
      unawaited(CunningDocumentScanner.cleanCache());
      return File(prepared.imagePath);
    } on Object {
      // A card must never be lost to an image step. Fall back to the full-size
      // copy already saved — same pixels, so regions still line up — and carry
      // on to OCR.
      return pending.image;
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

    final CardDetail? detail = ref.read(cardDetailProvider(cardId)).value;
    final bool nothingFound = detail == null || detail.fields.isEmpty;

    final String? note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _NotePrompt(emphasised: nothingFound),
    );
    // Dismissed the sheet without deciding — keep them on the review screen.
    if (note == null || !mounted) return;

    setState(() => _saving = true);
    await ref.read(cardRepositoryProvider).addNote(cardId: cardId, body: note);
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
    final ThemeData theme = Theme.of(context);
    final int? cardId = _cardId;
    final File? image = _image;

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
        body: image == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Pinned rather than scrolled away, because the whole point
                    // of the highlight is being able to check a value against
                    // the printing while editing it.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md,
                        vertical: Gap.sm,
                      ),
                      child: CardImageOverlay(
                        image: image,
                        highlight: _highlight,
                      ),
                    ),
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.md,
                          vertical: Gap.sm,
                        ),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    Expanded(
                      child: cardId == null
                          ? const SizedBox.shrink()
                          : _ReviewBody(
                              cardId: cardId,
                              onRegionChanged: (String? rect) =>
                                  setState(() => _highlight = rect),
                            ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: image == null
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
                          onPressed: (_loading || _saving || cardId == null)
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

/// What the card yielded, and the means to fix it.
class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.cardId, required this.onRegionChanged});

  final int cardId;
  final ValueChanged<String?> onRegionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return ref.watch(cardDetailProvider(cardId)).when(
          loading: () => const SizedBox.shrink(),
          error: (Object e, _) => Center(child: Text('Could not read that back.\n$e')),
          data: (CardDetail? detail) {
            if (detail == null) return const SizedBox.shrink();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              children: <Widget>[
                Text(
                  detail.fields.isEmpty
                      ? 'Nothing read yet'
                      : 'Found on the card',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: Gap.sm),
                EditableFieldList(
                  detail: detail,
                  onRegionChanged: onRegionChanged,
                ),
                if (detail.unassignedText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Gap.lg),
                  Text('Other text on the card',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: Gap.sm),
                  Text(
                    detail.unassignedText.join('\n'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: Gap.xl),
              ],
            );
          },
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
    final ThemeData theme = Theme.of(context);
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
