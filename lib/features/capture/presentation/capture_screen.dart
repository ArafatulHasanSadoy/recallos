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
import '../../../core/ui/primitives.dart';
import '../../cards/presentation/widgets/card_sides_view.dart';
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

      // The plugin's cache has served its purpose now that the pixels are
      // ours. Guarded, not fired off bare: unawaited, a throw here is an
      // unhandled async error that no catch can reach, reported long after the
      // capture it belongs to succeeded.
      unawaited(_cleanScannerCache());
      return File(prepared.imagePath);
    } on Object {
      // A card must never be lost to an image step. Fall back to the full-size
      // copy already saved — same pixels, so regions still line up — and carry
      // on to OCR.
      return pending.image;
    }
  }

  /// Drops the scanner's copy. Failing to tidy up is not a failed capture.
  Future<void> _cleanScannerCache() async {
    try {
      await CunningDocumentScanner.cleanCache();
    } on Object {
      // The leftover is the plugin's own cache file; the OS reclaims it.
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
      useSafeArea: true,
      showDragHandle: true,
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
    final int? cardId = _cardId;
    final File? image = _image;

    // Frame 03/04: capture is always dark, whatever the app theme is set to.
    // A bright chrome around a camera preview ruins the exposure read, and the
    // review screen inherits it so the two halves of one task do not flip
    // brightness between them.
    return Theme(
      data: AppTheme.capture(),
      child: Builder(
        builder: (BuildContext context) {
          final AppColors c = AppColors.of(context);

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? _) {
              if (!didPop) unawaited(_discardAndLeave());
            },
            child: Scaffold(
              backgroundColor: c.page,
              body: SafeArea(
                child: image == null
                    ? _Viewfinder(onBack: _saving ? null : _discardAndLeave)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          ScreenHeader(
                            title: 'Step 2 of 2',
                            onBack: _saving ? null : _discardAndLeave,
                            actions: <Widget>[
                              TextAction(
                                label: 'Retake',
                                tint: c.inkMuted,
                                enabled: !(_loading || _saving),
                                onTap: _capture,
                              ),
                            ],
                          ),
                          // Pinned rather than scrolled away: tapping a field
                          // boxes its region on the printing, and that check is
                          // the reason this screen exists.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Gap.lg,
                              0,
                              Gap.lg,
                              Gap.sm,
                            ),
                            child: Consumer(
                              builder:
                                  (BuildContext context, WidgetRef ref, _) =>
                                      CardSidesView(
                                cardId: cardId,
                                front: image,
                                backPath: cardId == null
                                    ? null
                                    : ref
                                        .watch(cardDetailProvider(cardId))
                                        .value
                                        ?.card
                                        .backImagePath,
                                highlight: _highlight,
                              ),
                            ),
                          ),
                          if (_loading)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.lg,
                              ),
                              child: _ReadingRail(colors: c),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Gap.lg,
                                Gap.sm,
                                Gap.lg,
                                0,
                              ),
                              child: Text(
                                _error!,
                                style: AppText.small(c)
                                    .copyWith(color: c.vermilion),
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
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Gap.lg,
                                Gap.sm,
                                Gap.lg,
                                Gap.md,
                              ),
                              // Equal halves, and the right-hand label says
                              // "Save card" — the field editor has a Save of
                              // its own and one bare "Save" is what made people
                              // end the scan while correcting a value.
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: OutlinePill(
                                      label: 'Retake',
                                      icon: Icons.refresh,
                                      height: 58,
                                      onTap: (_loading || _saving)
                                          ? null
                                          : _capture,
                                    ),
                                  ),
                                  const SizedBox(width: Gap.sm + 2),
                                  Expanded(
                                    // Enabled even when nothing was extracted.
                                    // A saved photo plus a note beats the paper
                                    // card the user was about to lose.
                                    child: InkPill(
                                      label: _saving ? 'Saving…' : 'Save card',
                                      icon: Icons.check,
                                      height: 58,
                                      onTap: (_loading ||
                                              _saving ||
                                              cardId == null)
                                          ? null
                                          : _save,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Frame 03. What is on screen while the OS scanner is coming up.
///
/// The brackets and the sweep are the app's own, not the scanner's — the
/// plugin takes over the whole window a moment later, and a blank frame in
/// between reads as the camera having failed.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.onBack});

  final VoidCallback? onBack;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Column(
      children: <Widget>[
        ScreenHeader(title: 'Front of card', onBack: widget.onBack),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: AspectRatio(
                aspectRatio: 1.586,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: AppRadius.cardR,
                        ),
                      ),
                    ),
                    for (final Alignment corner in <Alignment>[
                      Alignment.topLeft,
                      Alignment.topRight,
                      Alignment.bottomLeft,
                      Alignment.bottomRight,
                    ])
                      Align(
                        alignment: corner,
                        child: _Bracket(corner: corner, colors: c),
                      ),
                    // Stops the moment there is something to review, because a
                    // line still sweeping over a finished scan reads as "still
                    // working".
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _sweep,
                        builder: (BuildContext context, _) => Align(
                          alignment: Alignment(0, _sweep.value * 2 - 1),
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(
                              horizontal: Gap.lg,
                            ),
                            decoration: BoxDecoration(
                              color: c.ochre,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: c.ochre.withValues(alpha: 0.55),
                                  blurRadius: 14,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.xl),
          child: Text('Hold steady — finding the edges',
              style: AppText.small(c)),
        ),
      ],
    );
  }
}

/// One corner bracket: two borders on a box, no CustomPaint needed.
class _Bracket extends StatelessWidget {
  const _Bracket({required this.corner, required this.colors});

  final Alignment corner;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final bool top = corner.y < 0;
    final bool left = corner.x < 0;
    final BorderSide side = BorderSide(color: colors.ochre, width: 3);

    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: top ? BorderSide.none : side,
          left: left ? side : BorderSide.none,
          right: left ? BorderSide.none : side,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(8) : Radius.zero,
          topRight: top && !left ? const Radius.circular(8) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(8) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(8) : Radius.zero,
        ),
      ),
    );
  }
}

/// Reading progress, as a rail rather than a bar.
///
/// Rule 5 rules out a spinner; a Material `LinearProgressIndicator` brings its
/// own track colour and rounded caps that belong to a different app.
class _ReadingRail extends StatefulWidget {
  const _ReadingRail({required this.colors});

  final AppColors colors;

  @override
  State<_ReadingRail> createState() => _ReadingRailState();
}

class _ReadingRailState extends State<_ReadingRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 2,
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, _) => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) => Stack(
              children: <Widget>[
                Container(height: 2, color: widget.colors.hairline),
                Positioned(
                  left: (box.maxWidth + 90) * _c.value - 90,
                  child: Container(
                    width: 90,
                    height: 2,
                    color: widget.colors.ochre,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// What the card yielded, and the means to fix it.
class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.cardId, required this.onRegionChanged});

  final int cardId;
  final ValueChanged<String?> onRegionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);

    return ref.watch(cardDetailProvider(cardId)).when(
          loading: () => const SizedBox.shrink(),
          error: (Object e, _) => Center(
            child: Text('Could not read that back.\n$e',
                style: AppText.body(c)),
          ),
          data: (CardDetail? detail) {
            if (detail == null) return const SizedBox.shrink();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              children: <Widget>[
                SectionHeader(
                  detail.fields.isEmpty
                      ? 'Nothing read yet'
                      : 'Found on the card',
                  count: detail.fields.isEmpty ? null : detail.fields.length,
                ),
                const SizedBox(height: Gap.sm),
                EditableFieldList(
                  detail: detail,
                  onRegionChanged: onRegionChanged,
                ),
                if (detail.unassignedText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Gap.lg),
                  const SectionHeader('Other text on the card'),
                  const SizedBox(height: Gap.sm),
                  Text(
                    detail.unassignedText.join(' · '),
                    style: AppText.body(c).copyWith(color: c.inkFaint),
                  ),
                ],
                const SizedBox(height: Gap.xl),
              ],
            );
          },
        );
  }
}

/// The "why are you saving this?" sheet — frame 04b.
///
/// Fired by Save card, not an inline composer on the review screen. The
/// [emphasised] branch is the frame's vermilion pill and harder second
/// sentence, and it appears only when extraction found little or nothing.
class _NotePrompt extends StatefulWidget {
  const _NotePrompt({required this.emphasised});

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
          // Rule 3: the app asking the user, so it is the serif italic.
          Text(
            'Why are you saving this?',
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            widget.emphasised
                ? 'Not much was readable on this card, so this note is how '
                    "you'll find it later."
                : "You'll search by this later, so write it how you'd say it.",
            style: AppText.body(c),
          ),
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
            label: 'Save card',
            height: 58,
            onTap: () => Navigator.of(context).pop(_controller.text),
          ),
          const SizedBox(height: Gap.sm),
          // Still saves — the card and its fields are already on disk. This
          // only declines to add a note.
          PressFade(
            onTap: () => Navigator.of(context).pop(''),
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text(
                  'Skip for now',
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
