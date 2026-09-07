/// The photograph of a card, in the app's frame.
///
/// Phase 2 of `design/DESIGN.md` §3 — "the card object". Every place a scan is
/// shown goes through [CardFace], so the corner radius, the fallback and the
/// decode budget are described once.
library;

import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'primitives.dart';

/// One stable identity for a physical card everywhere it can be opened.
String cardHeroTag(int cardId) => 'card-$cardId';

/// How a card's photograph is drawn at one end of a hero flight.
///
/// The app has exactly two of these and they disagree about three things: the
/// corner radius, whether the card casts its own shadow, and which file is on
/// disk behind it — the wallet draws the 1000px thumbnail, card detail draws
/// the full capture. All three have to be carried across the flight, or the
/// card changes shape in the first frame and again in the last.
@immutable
class CardFrame {
  /// A card in the wallet: a small radius, flat against the tile it sits on,
  /// drawn from the thumbnail.
  const CardFrame.thumb(this.radius) : lifted = false, full = false;

  /// The pinned photograph on card detail: the tile radius, its own lift, and
  /// the full-size capture.
  const CardFrame.header({this.radius = AppRadius.card})
    : lifted = true,
      full = true;

  final double radius;

  /// Carries [AppDecoration.card]'s drop shadow.
  final bool lifted;

  /// Shows the full capture rather than the wallet's thumbnail.
  final bool full;
}

/// The shared-element boundary used by every card entry point.
///
/// Keeping this wrapper in one place means a card opened from search, a
/// contact, the repair queue or duplicate review moves exactly like one
/// opened from the wallet. `transitionOnUserGestures` also keeps the card
/// attached to an interactive iOS back swipe.
class CardHero extends StatelessWidget {
  const CardHero({
    required this.tag,
    required this.frame,
    required this.child,
    this.imagePath,
    super.key,
  });

  final Object tag;

  /// How this end draws the card. See [CardFrame].
  final CardFrame frame;

  /// The photograph showing at this end, so the flight can draw it itself
  /// rather than borrowing one end's widget and cramming it into the other
  /// end's box.
  final String? imagePath;

  final Widget child;

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    transitionOnUserGestures: true,
    // A straight line, stated rather than left to the default.
    //
    // This used to be a `MaterialRectArcTween`, which arcs the two corners
    // along separate circles: a card travelling from a wallet tile up to the
    // top of the page swooped sideways *and* changed proportion on the way,
    // which is a squash on a photograph, in a design whose whole claim is that
    // these are physical objects. A card lifted out of a wallet goes where it
    // is going.
    //
    // Deleting the line was not enough and the deletion looked correct, which
    // is the trap: `MaterialApp` installs a `HeroController` that supplies
    // `MaterialRectArcTween` to every hero in the app that does not name one,
    // so the arc came back by inheritance. It has to be overridden here.
    createRectTween: (Rect? begin, Rect? end) =>
        RectTween(begin: begin, end: end),
    flightShuttleBuilder: _flight,
    child: child,
  );
}

/// One object for the whole flight, instead of one end's widget stretched into
/// the other end's box.
///
/// Flutter's default shuttle is the *destination* hero's child, which for this
/// app meant the detail screen's photograph — `BoxFit.contain` at radius 16
/// with a drop shadow — being drawn into a 104×64 wallet thumbnail on the
/// flight's first frame, and the reverse on the way home. The photo re-fitted,
/// the corner snapped and a shadow appeared, all before the card had moved.
/// That first frame is what read as "not smooth"; the travel was never the
/// problem.
Widget _flight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final CardHero? from = fromHeroContext
      .findAncestorWidgetOfExactType<CardHero>();
  final CardHero? to = toHeroContext.findAncestorWidgetOfExactType<CardHero>();

  // A card with no photograph on it has nothing of its own to fly. Falling
  // back to Flutter's default shuttle is right there: the placeholder is the
  // same at both ends, so there is nothing to interpolate.
  if (from == null || to == null) return (toHeroContext.widget as Hero).child;

  final CardHero header = from.frame.full ? from : to;
  final CardHero thumb = from.frame.full ? to : from;
  final String? sharp = header.imagePath ?? thumb.imagePath;
  if (sharp == null) return (toHeroContext.widget as Hero).child;

  return CardFlight(
    // The wallet's own decode underneath, the big one over it. See the note in
    // [_CardFlight].
    thumbPath: thumb.imagePath,
    imagePath: sharp,
    animation: animation,
    direction: direction,
    from: from.frame,
    to: to.frame,
  );
}

/// The card, mid-air.
///
/// Radius, lift and photograph all follow the flight rather than snapping at
/// either end.
///
/// Visible to tests because the two ends of a flight are exactly the frames
/// nothing else can see: they render, they lay out, and they are wrong only on
/// a phone. `test/features/card_transition_test.dart` pins them.
@visibleForTesting
class CardFlight extends StatelessWidget {
  const CardFlight({
    required this.thumbPath,
    required this.imagePath,
    required this.animation,
    required this.direction,
    required this.from,
    required this.to,
    super.key,
  });

  /// The wallet's thumbnail, when this flight has one.
  final String? thumbPath;

  /// The photograph the detail screen shows.
  final String imagePath;

  final Animation<double> animation;
  final HeroFlightDirection direction;
  final CardFrame from;
  final CardFrame to;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool dark = isDarkTheme(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final String? thumb = thumbPath;

    // The lift the card arrives with, borrowed from the design system rather
    // than re-typed, and faded in over the flight below.
    final List<BoxShadow> lift =
        AppDecoration.card(c, isDark: dark).boxShadow ?? const <BoxShadow>[];

    return AnimatedBuilder(
      animation: animation,
      // Built once and held across every tick: two `Image`s rebuilt 25 times a
      // second would re-resolve their providers through the whole flight.
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The decode the wallet already holds, so the flight's first frame
          // is never an empty rectangle. It is the same cache entry the tile
          // is drawing from, which is what makes it free.
          if (thumb != null)
            Image.file(
              File(thumb),
              fit: BoxFit.cover,
              cacheWidth: (Gap.cardFaceThumb.width * dpr).round(),
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          // The photograph card detail resolves anyway, through the same bare
          // `FileImage` it uses — so this costs no decode of its own. It paints
          // nothing until it is ready and the thumbnail stands in until then.
          Image(
            image: FileImage(File(imagePath)),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      builder: (BuildContext context, Widget? photo) {
        // `animation` is the route's, so it runs 0→1 on a push and 1→0 on a
        // pop — heroes.dart takes it from `toRoute` in one direction and
        // `fromRoute` in the other. The rect tween is always from→to, so this
        // has to be read the same way round or the radius runs backwards on
        // the way home.
        final double t =
            (direction == HeroFlightDirection.push
                    ? animation.value
                    : 1 - animation.value)
                .clamp(0.0, 1.0);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(from.radius, to.radius, t)!,
        );
        final double raised = lerpDouble(
          from.lifted ? 1 : 0,
          to.lifted ? 1 : 0,
          t,
        )!;

        return DecoratedBox(
          decoration: BoxDecoration(
            // Under the photograph, for the frames before it decodes and for
            // the corners the rounding cuts away.
            color: c.pocket,
            borderRadius: shape,
            boxShadow: <BoxShadow>[
              for (final BoxShadow s in lift)
                BoxShadow(
                  color: s.color.withValues(alpha: s.color.a * raised),
                  blurRadius: s.blurRadius,
                  spreadRadius: s.spreadRadius,
                  offset: s.offset * raised,
                ),
            ],
          ),
          child: ClipRRect(borderRadius: shape, child: photo),
        );
      },
    );
  }
}

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
    if (tag != null) {
      face = CardHero(
        tag: tag,
        frame: CardFrame.thumb(radius),
        imagePath: imagePath,
        child: face,
      );
    }

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
                    cacheWidth: cacheWidth <= 0 || !cacheWidth.isFinite
                        ? null
                        : cacheWidth,
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
      child: Icon(Icons.badge_outlined, size: 18, color: colors.inkFaint),
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
