import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/primitives.dart';
import '../../../capture/data/back_capture_service.dart';
import '../../../capture/data/card_repository.dart';
import 'card_image_overlay.dart';

/// The card photo, either side of it, and the controls for the back.
///
/// Wraps [CardImageOverlay] rather than replacing it, because the front is
/// still the only side with anything to overlay. Field regions are recorded in
/// the front image's pixel space and `card_fields` carries no side column, so
/// a highlight painted while the back is showing would box a spot on the back
/// that has nothing to do with the value — wrong, and silently so. This widget
/// exists largely to make that impossible: showing a highlight and showing the
/// back are mutually exclusive states, and asking for one turns off the other.
///
/// Used by both the capture review and the card detail screen, which need the
/// same thing: check a value against the printing, keep the other side, get at
/// the full image.
class CardSidesView extends ConsumerStatefulWidget {
  const CardSidesView({
    required this.cardId,
    required this.front,
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

  /// The other side, when there is one.
  ///
  /// Passed in rather than read from the database here, the same way
  /// `EditableFieldList` takes its fields: the screens above already stream
  /// the card, so a second subscription would be one more thing to keep in
  /// step for no gain. Adding or removing a back writes through the
  /// repository and arrives back down this property.
  final String? backPath;

  /// Region to box on the front, as stored in `card_fields.region_rect`.
  final String? highlight;

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
    // A highlight means the user tapped a field to see where it was read
    // from, and that is always somewhere on the front. Turning the card over
    // for them is the only answer that shows the thing they asked for.
    if (_showingBack &&
        widget.highlight != null &&
        widget.highlight != old.highlight) {
      setState(() => _showingBack = false);
    }
  }

  Future<void> _addBack(int cardId) async {
    setState(() => _busy = true);
    final BackCapture result =
        await ref.read(backCaptureServiceProvider).capture(cardId);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _removeBack(int cardId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove the back?'),
        // Said plainly because it is the one delete in this app with no undo
        // behind it. Nothing was read from the back, so there is nothing to
        // restore it from — unlike a card, which keeps its tombstone.
        content: const Text('The photo of the back will be deleted. The card '
            'and everything read from the front stay.'),
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

    final Widget picture = CardImageOverlay(
      image: shown,
      // Never on the back. See the note on the class.
      highlight: showingBack ? null : widget.highlight,
      maxHeight: widget.maxHeight,
    );

    final Object? heroTag = widget.heroTag;
    final Widget framed = (heroTag != null && !showingBack)
        ? Hero(tag: heroTag, child: picture)
        : picture;

    final ValueChanged<File>? onOpen = widget.onOpenFullImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        onOpen == null
            ? framed
            : GestureDetector(
                onTap: () => onOpen(shown),
                child: framed,
              ),
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
          label: busy ? 'Opening…' : 'Add back',
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
