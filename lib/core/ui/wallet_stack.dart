/// The library, as a wallet you flip through.
///
/// Phase 3 of `design/DESIGN.md` §3, frames 01 and 02. Every number here was
/// measured off `design/screens.html` rather than guessed: the tile is
/// 346×116 at a 92px pitch, so each card covers 24px of the one below, and
/// that overlap is the entire metaphor. Flatten it and the screen becomes a
/// list of search results.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'card_face.dart';
import 'primitives.dart';

/// The stack's geometry at the reader's text size.
///
/// `DESIGN.md` §5 names the pitch as the first thing to break at
/// `textScaleFactor` 1.3 and says to derive it from the resolved row height
/// rather than leave it constant. Both numbers scale together, so the 24dp
/// overlap stays proportional and the design's ratio holds at every size —
/// at 1.0 these are exactly the measured 92 and 116.
@immutable
class StackMetrics {
  const StackMetrics({required this.pitch, required this.height});

  final double pitch;
  final double height;

  factory StackMetrics.of(BuildContext context) {
    // Clamped: past 1.8 the cards stop overlapping usefully and the wallet is
    // better off as a taller list than as a broken stack.
    final double scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.8);
    return StackMetrics(
      pitch: Gap.stackPitch * scale,
      height: Gap.stackCardHeight * scale,
    );
  }

  /// The fraction of a tile that is not covered by the next one.
  static const double visibleFraction = Gap.stackPitch / Gap.stackCardHeight;
}

/// One card in the wallet.
///
/// Anatomy, in tile coordinates: face at (14, 13) sized 106×66 with the fold
/// in its top-right corner; text column starting at x=133 with the serif title
/// on the first line, the note under it, and the metadata caps at the bottom.
class WalletCardTile extends StatelessWidget {
  const WalletCardTile({
    required this.title,
    required this.subtitle,
    this.imagePath,
    this.meta,
    this.hasNote = false,
    this.heroTag,
    this.onTap,
    this.flat = false,
    super.key,
  });

  final String title;

  /// The note where there is one — it is what the user actually recognises the
  /// card by — otherwise the best extracted line.
  final String subtitle;

  final String? imagePath;

  /// The caps line: a place and an age, or why this row was matched.
  final Widget? meta;

  final bool hasNote;
  final Object? heroTag;
  final VoidCallback? onTap;

  /// A search result rather than a library tile. Same paper, half the lift.
  final bool flat;

  /// Tile geometry, from the frames.
  static const EdgeInsets _facePadding = EdgeInsets.only(left: 14, top: 13);
  static const double _textLeft = 133;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool dark = isDarkTheme(context);
    final Widget? metaLine = meta;
    final StackMetrics metrics = StackMetrics.of(context);

    return PressFade(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        height: metrics.height,
        decoration: flat
            ? AppDecoration.flatCard(c, isDark: dark)
            : AppDecoration.card(c, isDark: dark),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: _facePadding,
              child: Align(
                alignment: Alignment.topLeft,
                child: CardFace(
                  imagePath: imagePath,
                  size: Gap.cardFaceThumb,
                  heroTag: heroTag,
                  hasNote: hasNote,
                ),
              ),
            ),
            // No `bottom`, and nothing expands. The tile is 116 tall but only
            // the top 92 is ever visible — the next card in the stack covers
            // the rest — so the content is laid out from the top and has to
            // finish inside that band. An `Expanded` subtitle pushed the meta
            // line to y=89, which is under the card above it: rendered,
            // measurable in a test, and invisible on a phone.
            Positioned(
              left: _textLeft,
              right: 14,
              top: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowSerif(c),
                  ),
                  const SizedBox(height: Gap.xs + 1),
                  Text(
                    subtitle,
                    // One line, as the frames have it. A second line reads
                    // fine on the last card and disappears under every other.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(c).copyWith(fontSize: 13, height: 1.42),
                  ),
                  if (metaLine != null) ...<Widget>[
                    const SizedBox(height: Gap.xs),
                    metaLine,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The overlapping stack.
///
/// A [Stack] of [Positioned] rows rather than a `ListView`, because a list
/// cannot make its children overlap. The scroll extent is computed rather
/// than measured — `pitch × n + (height - pitch)` — so the last card is fully
/// visible with nothing covering it.
///
/// Newest last so it sits on top, which is how a pile of cards actually works.
class CardStack extends StatelessWidget {
  const CardStack({
    required this.count,
    required this.builder,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final int count;
  final Widget Function(BuildContext context, int index) builder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    // The overlap. 116 tall on a 92 pitch leaves 24 of the card beneath
    // showing, which is enough to read as a stack and not enough to lose a
    // line of the note.
    final StackMetrics m = StackMetrics.of(context);
    final double extent = m.pitch * (count - 1) + m.height + padding.vertical;

    return SizedBox(
      height: extent,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Positioned(
              top: padding.top + m.pitch * i,
              left: padding.left,
              right: padding.right,
              height: m.height,
              child: builder(context, i),
            ),
        ],
      ),
    );
  }
}

/// The fade that lets the stack run off the bottom of the screen.
///
/// [IgnorePointer] because it sits over the last card and must not eat the tap
/// that opens it.
class StackFade extends StatelessWidget {
  const StackFade({this.height = 132, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[c.page.withValues(alpha: 0), c.page],
              stops: const <double>[0, 0.72],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three card-shaped skeletons at 40%.
///
/// Rule 5: there is no spinner anywhere in this app. A spinner says "something
/// is happening"; this says "your wallet is about to be here", in the shape it
/// will arrive in, which makes the wait feel like part of the screen rather
/// than an interruption to it.
class GhostStack extends StatelessWidget {
  const GhostStack({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool dark = isDarkTheme(context);

    return Opacity(
      opacity: 0.4,
      child: CardStack(
        count: count,
        builder: (BuildContext context, int i) => Container(
          decoration: AppDecoration.card(c, isDark: dark),
          child: Padding(
            padding: const EdgeInsets.only(left: 14, top: 13),
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: Gap.cardFaceThumb.width,
                    height: Gap.cardFaceThumb.height,
                    decoration: BoxDecoration(
                      color: c.pocket,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Bar(width: 132, height: 13, color: c.pocket),
                      const SizedBox(height: Gap.sm + 2),
                      _Bar(width: 168, height: 8, color: c.pocket),
                      const SizedBox(height: Gap.sm),
                      _Bar(width: 96, height: 8, color: c.pocket),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

/// The one empty state, four times over.
///
/// The glyph is always a card — never a magnifier, never a warning triangle —
/// so the metaphor holds even on a screen that has nothing in it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.label,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// The micro-caps line above the glyph: WALLET EMPTY, NO RESULTS.
  final String label;

  /// One serif line. Short enough to read as a sentence, not a heading.
  final String title;

  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? action = actionLabel;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 55,
              decoration: BoxDecoration(
                color: c.pocket,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.hairline),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: CornerFold(size: 17, colors: c),
              ),
            ),
            const SizedBox(height: Gap.lg),
            MicroLabel(label),
            const SizedBox(height: Gap.sm + 2),
            Text(title, textAlign: TextAlign.center, style: AppText.title(c)),
            const SizedBox(height: Gap.sm + 2),
            Text(body, textAlign: TextAlign.center, style: AppText.body(c)),
            if (action != null) ...<Widget>[
              const SizedBox(height: Gap.lg),
              OutlinePill(label: action, onTap: onAction, height: 52),
            ],
          ],
        ),
      ),
    );
  }
}
