/// The photograph of a card, in the app's frame.
///
/// Phase 2 of `design/DESIGN.md` §3 — "the card object". Every place a scan is
/// shown goes through [CardFace], so the corner radius, the fallback and the
/// decode budget are described once.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A card's photograph, clipped to the wallet frame.
///
/// **Landscape, because the object is.** `Gap.cardFaceThumb` is 104×64 — a
/// business card is wider than it is tall, and a square thumbnail crops the
/// half of it that carries the printing.
///
/// The decode budget is the reason this is a widget rather than a bare
/// `Image.file`. Without `cacheWidth`, Flutter decodes the full capture — up
/// to 1600px on its long edge — into a 104px box, and a library of them
/// exhausts the heap on exactly the phone this app is for.
class CardFace extends StatelessWidget {
  const CardFace({
    required this.imagePath,
    this.size,
    this.radius = 9,
    this.heroTag,
    this.hasNote = false,
    super.key,
  });

  /// The thumbnail where there is one, the full image otherwise. Null draws
  /// the placeholder — a card saved before its photo could be read.
  final String? imagePath;

  /// Null fills whatever the parent gives it, which is what the detail screen
  /// wants; a thumb passes [Gap.cardFaceThumb].
  final Size? size;

  final double radius;
  final Object? heroTag;

  /// Draws the dog-ear. The fold is the logo's own shape, and on a tile it
  /// means "there is a reason this was saved" — see [CornerFold].
  final bool hasNote;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Size? box = size;

    Widget face = _Photo(imagePath: imagePath, colors: c, radius: radius);

    final Object? tag = heroTag;
    if (tag != null) face = Hero(tag: tag, child: face);

    if (hasNote) {
      face = Stack(
        children: <Widget>[
          face,
          Positioned(
            top: 0,
            right: 0,
            child: CornerFold(size: radius >= 14 ? 38 : 19, colors: c),
          ),
        ],
      );
    }

    if (box == null) return face;
    return SizedBox(width: box.width, height: box.height, child: face);
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.imagePath,
    required this.colors,
    required this.radius,
  });

  final String? imagePath;
  final AppColors colors;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String? path = imagePath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.pocket,
          border: Border.all(color: colors.hairlineOnCard),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: path == null
            ? _Missing(colors: colors)
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  // Decode to the width it will actually be drawn at. Cheap to
                  // get right here, and impossible to notice when it is wrong
                  // until the app is killed for memory on a real phone.
                  final double dpr = MediaQuery.devicePixelRatioOf(context);
                  final int cacheWidth = (box.maxWidth * dpr).round();

                  return Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth:
                        cacheWidth <= 0 || !cacheWidth.isFinite ? null : cacheWidth,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _Missing(colors: colors),
                  );
                },
              ),
      ),
    );
  }
}

/// A card with no readable photograph.
///
/// Tinted paper and the card glyph, never a broken-image icon: the card is
/// still in the wallet and still findable by its note, so the placeholder
/// should not look like an error.
class _Missing extends StatelessWidget {
  const _Missing({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: colors.pocket,
        child: Center(
          child: Icon(
            Icons.badge_outlined,
            size: 18,
            color: colors.inkFaint,
          ),
        ),
      );
}

/// The dog-ear from the logo, drawn into the top-right of a [CardFace].
///
/// The fold is the one ochre shape in the mark, and repeating it here is what
/// ties the icon to the interface. It carries meaning as well as identity: a
/// folded corner is how you mark a card you had a reason to keep.
class CornerFold extends StatelessWidget {
  const CornerFold({required this.size, required this.colors, super.key});

  final double size;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _FoldPainter(colors)),
      );
}

class _FoldPainter extends CustomPainter {
  const _FoldPainter(this.colors);

  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    // The turned-back triangle: page colour underneath, ochre on the fold's
    // own edge, so it reads as paper lifted rather than a coloured sticker.
    final Path fold = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(fold, Paint()..color = colors.ochre);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height),
      Paint()
        ..color = colors.onOchre.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FoldPainter old) => old.colors.ochre != colors.ochre;
}
