import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/imaging/card_geometry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/primitives.dart';

/// Parses a stored `"left,top,right,bottom"` region into a [Rect].
///
/// Coordinates are in the pixel space of the image OCR was run against, which
/// is the file on disk — so they stay valid however the image is displayed.
Rect? parseRegionRect(String? value) {
  if (value == null) return null;

  final List<double> parts = value
      .split(',')
      .map((String s) => double.tryParse(s.trim()))
      .whereType<double>()
      .toList();
  if (parts.length != 4) return null;

  return Rect.fromLTRB(parts[0], parts[1], parts[2], parts[3]);
}

/// The card photo, with the region a field was read from boxed on it.
///
/// This is the cheapest trust mechanism in the app: rather than taking the
/// extractor's word for it, the user glances at the pixels the value came from.
/// It is also what makes a wrong extraction *visible* — wrong data that looks
/// settled is the failure mode that loses people.
///
/// The image is displayed at its natural resolution rather than downscaled,
/// because the region coordinates are in that space and the mapping has to be
/// exact. That is one decode of an image already capped at 1600 px on capture,
/// and only ever one at a time — unlike the list thumbnails, which must stay
/// scaled or a long library exhausts memory on a cheap phone.
class CardImageOverlay extends StatefulWidget {
  const CardImageOverlay({
    required this.image,
    this.preview,
    this.highlight,
    this.maxHeight = 240,
    super.key,
  });

  final File image;

  /// The wallet's thumbnail of [image], drawn underneath until the full
  /// capture decodes.
  ///
  /// [image] is a fresh decode of a file up to 1600px on its long edge, and it
  /// is not ready on the frame a hero flight lands. Without a stand-in the
  /// card arrives, vanishes into an empty rectangle for a frame or two, and
  /// comes back — which is most of what "the animation isn't smooth" was.
  /// This is the entry the wallet tile is already drawing from, so it costs
  /// nothing and it is there immediately.
  final File? preview;

  /// Region to box, as stored in `card_fields.region_rect`. Null boxes nothing.
  final String? highlight;

  final double maxHeight;

  /// Matches WalletCard, so a tile and this header look like one object.
  static const double _radius = 16;

  @override
  State<CardImageOverlay> createState() => _CardImageOverlayState();
}

class _CardImageOverlayState extends State<CardImageOverlay> {
  late FileImage _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  Size? _imageSize;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _provider = FileImage(widget.image);
    _resolve();
  }

  @override
  void didUpdateWidget(CardImageOverlay old) {
    super.didUpdateWidget(old);
    if (old.image.path != widget.image.path) {
      _detach();
      _provider = FileImage(widget.image);
      // The old size is kept rather than cleared. Card detail swaps the
      // wallet's thumbnail for the full capture a frame or two after the
      // screen opens, and both are the same card at the same proportion —
      // dropping back to "unknown" made the box collapse to the default shape
      // and grow again under a hero that had just landed on it.
      _failed = false;
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// Reads the image's true dimensions.
  ///
  /// The same provider instance is handed to the [Image] below, so Flutter's
  /// image cache serves both from one decode rather than two.
  void _resolve() {
    final ImageStream stream = _provider.resolve(ImageConfiguration.empty);
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final ui.Image image = info.image;
        if (!mounted) return;
        setState(
          () => _imageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
        );
      },
      onError: (Object _, StackTrace? _) {
        // A missing or unreadable file is shown as a placeholder rather than
        // taking the screen down — the fields are still worth editing.
        if (mounted) setState(() => _failed = true);
      },
    );

    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _detach() {
    final ImageStreamListener? listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Size? size = _imageSize;

    if (_failed) {
      return Container(
        height: widget.maxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.pocket,
          borderRadius: BorderRadius.circular(CardImageOverlay._radius),
        ),
        child: Icon(Icons.badge_outlined, size: 22, color: c.inkFaint),
      );
    }

    final Rect? region = size == null
        ? null
        : parseRegionRect(widget.highlight);
    final File? thumb = widget.preview;

    // The card's own shape once it has been measured, and the uniform wallet
    // frame until then — so the box is the right size on the first frame
    // instead of appearing at some default and reflowing under a hero that
    // has already landed. A card whose crop is not [cardAspectRatio] eases
    // to its real shape rather than jumping to it.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: size == null ? cardAspectRatio : size.width / size.height,
        end: size == null ? cardAspectRatio : size.width / size.height,
      ),
      duration: AppMotion.quick,
      curve: AppMotion.curve,
      builder: (BuildContext context, double aspect, Widget? child) =>
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: DecoratedBox(
              // The same paper as a wallet tile, so the header reads as the
              // object the user tapped rather than as a picture of it.
              //
              // No border and no fill of its own. The photograph fills this box
              // edge to edge, so a hairline around it is a line drawn on top of
              // a card that already has its own edge — under the old Material
              // colours that was `surfaceContainerHighest`, a near-white, and it
              // showed as a white frame around every scan on capture review and
              // card detail.
              decoration: AppDecoration.card(c, isDark: isDarkTheme(context))
                  .copyWith(
                    border: null,
                    borderRadius: BorderRadius.circular(
                      CardImageOverlay._radius,
                    ),
                  ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CardImageOverlay._radius),
                child: AspectRatio(
                  // The card's own shape, not the uniform tile shape. Tiles
                  // crop to fill a wallet frame; this one is where fields get
                  // checked and corrected, so the whole card has to be visible
                  // and every region reachable. Since the image is now a
                  // cropped card rather than a photograph of one, following its
                  // shape leaves no dead space anyway.
                  aspectRatio: aspect,
                  child: child,
                ),
              ),
            ),
          ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Under everything, for the frames before the full decode lands.
          // `cover` and the wallet's own cache width, because this is the
          // wallet's own decode — see [CardImageOverlay.preview].
          if (thumb != null)
            Image.file(
              thumb,
              fit: BoxFit.cover,
              cacheWidth:
                  (Gap.cardFaceThumb.width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Image(image: _provider, fit: BoxFit.contain, gaplessPlayback: true),
          if (region != null && size != null)
            CustomPaint(
              painter: _RegionPainter(
                region: region,
                imageSize: size,
                // Rule 2: ochre is a marker, and boxing the printing a value
                // was read from is exactly what it marks.
                colour: c.ochre,
              ),
            ),
        ],
      ),
    );
  }
}

/// Dims everything but the region, then outlines it.
///
/// Dimming rather than only outlining, because on a busy card an outline alone
/// is easy to lose among the printing.
class _RegionPainter extends CustomPainter {
  const _RegionPainter({
    required this.region,
    required this.imageSize,
    required this.colour,
  });

  final Rect region;
  final Size imageSize;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    // Mirror `BoxFit.contain` rather than assuming the image fills this box.
    // It usually does, but a portrait photo in a full-width slot is letterboxed
    // — and a highlight drawn as though it were not lands somewhere else on the
    // card, which is worse than drawing nothing at all.
    final double scale = math.min(
      size.width / imageSize.width,
      size.height / imageSize.height,
    );
    final double dx = (size.width - imageSize.width * scale) / 2;
    final double dy = (size.height - imageSize.height * scale) / 2;

    final RRect box = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        region.left * scale + dx,
        region.top * scale + dy,
        region.right * scale + dx,
        region.bottom * scale + dy,
      ).inflate(3),
      const Radius.circular(4),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(box),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    canvas.drawRRect(
      box,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.region != region ||
      old.imageSize != imageSize ||
      old.colour != colour;
}
