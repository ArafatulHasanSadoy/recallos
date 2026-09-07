import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/card_face.dart';
import '../../../../core/ui/primitives.dart';
import '../../../capture/data/back_capture_service.dart';
import '../../../capture/data/card_repository.dart';
import '../../../contacts/data/identity_repository.dart';
import '../../../search/data/search_repository.dart';
import 'card_image_overlay.dart';

/// A region to box, and the photograph it is measured against.
///
/// The pair travels together everywhere because neither half means anything
/// alone: "120,40,300,72" is a different place on each side of the card, and
/// painting it on the wrong one is wrong without throwing.
class FieldHighlight {
  const FieldHighlight({required this.rect, required this.side});

  /// Where a field was read from, or null when it has no region — a value the
  /// user typed rather than sourced from the printing.
  static FieldHighlight? of(CardField field) {
    final String? rect = field.regionRect;
    return rect == null ? null : FieldHighlight(rect: rect, side: field.side);
  }

  /// "left,top,right,bottom" in [side]'s pixel space.
  final String rect;

  final CardSide side;

  @override
  bool operator ==(Object other) =>
      other is FieldHighlight && other.rect == rect && other.side == side;

  @override
  int get hashCode => Object.hash(rect, side);
}

/// The card photo, either side of it, and the controls for the back.
///
/// Wraps [CardImageOverlay] rather than replacing it, because a highlight is
/// only ever correct against one of the two images. Every stored region is a
/// rectangle in one side's pixel space, so this widget owns the rule that keeps
/// them honest: a highlight is painted only while its own side is showing, and
/// asking for one turns the card over to the side it belongs to.
///
/// Used by both the capture review and the card detail screen, which need the
/// same thing: check a value against the printing, keep the other side, get at
/// the full image.
class CardSidesView extends ConsumerStatefulWidget {
  const CardSidesView({
    required this.cardId,
    required this.front,
    this.frontPreview,
    this.backPath,
    this.highlight,
    this.maxHeight = 240,
    this.heroTag,
    this.onOpenFullImage,
    super.key,
  });

  /// The card these sides belong to, or null before the row exists.
  ///
  /// Null only happens for the moment between the shutter and the first write
  /// on the capture screen. There is nothing to attach a back to yet, so the
  /// controls stay hidden rather than appearing and failing.
  final int? cardId;

  /// The side OCR read and every region is measured against.
  final File front;

  /// The wallet's thumbnail of [front]. See [CardImageOverlay.preview] — it is
  /// what stands in for the full capture on the frame a hero flight lands.
  /// The back has no thumbnail, and needs none: nothing flies into it.
  final File? frontPreview;

  /// The other side, when there is one.
  ///
  /// Passed in rather than read from the database here, the same way
  /// `EditableFieldList` takes its fields: the screens above already stream
  /// the card, so a second subscription would be one more thing to keep in
  /// step for no gain. Adding or removing a back writes through the
  /// repository and arrives back down this property.
  final String? backPath;

  /// Region to box, and the side it belongs to.
  final FieldHighlight? highlight;

  final double maxHeight;

  /// Applied to the front only. The library tile it flies from shows the
  /// front, so animating the back into it would be a lie about what was
  /// tapped.
  final Object? heroTag;

  /// Called with whichever side is showing. Null makes the image untappable.
  final ValueChanged<File>? onOpenFullImage;

  @override
  ConsumerState<CardSidesView> createState() => _CardSidesViewState();
}

class _CardSidesViewState extends ConsumerState<CardSidesView> {
  bool _showingBack = false;
  bool _busy = false;

  @override
  void didUpdateWidget(CardSidesView old) {
    super.didUpdateWidget(old);
    // A highlight means the user opened a field to see where it was read from.
    // Turning the card to that side is the only answer that shows them the
    // thing they asked for — and it now goes both ways, because a value read
    // off the back is boxed on the back.
    final FieldHighlight? h = widget.highlight;
    if (h == null || h == old.highlight) return;

    final bool wantBack = h.side == CardSide.back;
    if (wantBack != _showingBack) setState(() => _showingBack = wantBack);
  }

  Future<void> _addBack(int cardId) async {
    // Covers the read as well as the scanner. Recognising the back is the
    // slower half on the hardware this app is aimed at, and it is the half
    // that changes the fields underneath — so the controls stay disabled until
    // it has landed rather than only until the shutter closes.
    setState(() => _busy = true);
    final BackCapture result = await ref
        .read(backCaptureServiceProvider)
        .capture(cardId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Land on the side just photographed, so it is checked rather than
      // taken on trust — the scanner crops, and it sometimes crops wrongly.
      if (result.outcome == BackCaptureOutcome.captured) _showingBack = true;
    });

    final String? message = switch (result.outcome) {
      BackCaptureOutcome.captured => null,
      BackCaptureOutcome.cancelled => null,
      BackCaptureOutcome.permissionDenied =>
        'RecallOS needs camera access to scan the back.',
      BackCaptureOutcome.failed => result.message ?? 'Could not add the back.',
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _removeBack(int cardId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove the back?'),
        // Said plainly because it is the one delete in this app with no undo
        // behind it: there is no tombstone for a side, so the photo and
        // everything read off it go for good. Named in full because values the
        // user themselves confirmed can be among them — they carry a region
        // into an image that is about to stop existing.
        content: const Text(
          'The photo of the back will be deleted, along with '
          'everything read from it. The card and the front stay.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _showingBack = false;
    });
    await ref.read(cardRepositoryProvider).removeBackImage(cardId);
    // The same tail every other change to a card's fields runs. Without it the
    // back's phone number stays on the person it was promoted to, and its text
    // stays findable, after the side it came from is gone.
    await ref.read(searchRepositoryProvider).reindexCard(cardId);
    await ref.read(identityRepositoryProvider).promote(cardId);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final int? cardId = widget.cardId;
    final String? backPath = widget.backPath;

    // Derived rather than stored, so the frames either side of a write — a
    // back just removed, or just captured and not yet streamed back down —
    // cannot show a side that is not there.
    final bool showingBack = _showingBack && backPath != null;
    final File shown = showingBack ? File(backPath) : widget.front;

    final FieldHighlight? h = widget.highlight;
    final CardSide shownSide = showingBack ? CardSide.back : CardSide.front;

    final Widget picture = CardImageOverlay(
      image: shown,
      preview: showingBack ? null : widget.frontPreview,
      // Only on the side it was measured against. See the note on the class.
      highlight: h != null && h.side == shownSide ? h.rect : null,
      maxHeight: widget.maxHeight,
    );

    final Object? heroTag = widget.heroTag;
    // Keep the shared boundary while the back is visible too. On a pop the
    // destination is the wallet's front thumbnail, so the card flies home from
    // wherever it is while showing whichever side is up — the swap to the
    // front happens at thumbnail size, where it is a 104px square changing
    // content rather than a full-width card changing under the user's finger.
    // Removing the Hero here made Back → back button fall back to a page slide.
    final Widget framed = heroTag == null
        ? picture
        : CardHero(
            tag: heroTag,
            frame: const CardFrame.header(),
            imagePath: shown.path,
            child: picture,
          );

    final ValueChanged<File>? onOpen = widget.onOpenFullImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        onOpen == null
            ? framed
            : GestureDetector(onTap: () => onOpen(shown), child: framed),
        if (cardId != null)
          _Controls(
            busy: _busy,
            hasBack: backPath != null,
            showingBack: showingBack,
            onShowSide: (bool back) => setState(() => _showingBack = back),
            onAddBack: () => _addBack(cardId),
            onRemoveBack: () => _removeBack(cardId),
          ),
      ],
    );
  }
}

/// Switch sides, add a back, replace it, remove it.
///
/// One row rather than a menu, because with a back present the thing people
/// want most often — look at the other side — should not be behind anything.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.busy,
    required this.hasBack,
    required this.showingBack,
    required this.onShowSide,
    required this.onAddBack,
    required this.onRemoveBack,
  });

  final bool busy;
  final bool hasBack;
  final bool showingBack;
  final ValueChanged<bool> onShowSide;
  final VoidCallback onAddBack;
  final VoidCallback onRemoveBack;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    if (!hasBack) {
      // Rule 5: no spinner. While the scanner is coming up the label says so,
      // which is more informative than a ring going round anyway.
      return Align(
        alignment: Alignment.centerLeft,
        child: TextAction(
          label: busy ? 'Working…' : 'Add back',
          icon: Icons.add_a_photo_outlined,
          enabled: !busy,
          onTap: onAddBack,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Row(
        children: <Widget>[
          SelectChip(
            label: 'Front',
            selected: !showingBack,
            onTap: busy ? () {} : () => onShowSide(false),
          ),
          const SizedBox(width: Gap.sm),
          SelectChip(
            label: 'Back',
            selected: showingBack,
            onTap: busy ? () {} : () => onShowSide(true),
          ),
          const Spacer(),
          if (busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Text('Working…', style: AppText.small(c)),
            )
          else
            PopupMenuButton<_BackAction>(
              tooltip: 'Back of card',
              icon: Icon(Icons.more_horiz, color: c.inkMuted),
              onSelected: (_BackAction action) => switch (action) {
                _BackAction.replace => onAddBack(),
                _BackAction.remove => onRemoveBack(),
              },
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<_BackAction>>[
                    PopupMenuItem<_BackAction>(
                      value: _BackAction.replace,
                      child: Text('Retake back'),
                    ),
                    PopupMenuItem<_BackAction>(
                      value: _BackAction.remove,
                      child: Text('Remove back'),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

enum _BackAction { replace, remove }
