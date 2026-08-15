import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
    this.highlight,
    this.maxHeight = 240,
    super.key,
  });

  final File image;

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
      _imageSize = null;
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
        setState(() => _imageSize =
            Size(image.width.toDouble(), image.height.toDouble()));
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
    final ThemeData theme = Theme.of(context);
    final Size? size = _imageSize;

    if (_failed) {
      return Container(
        height: widget.maxHeight,
        alignment: Alignment.center,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }
    if (size == null) {
      return SizedBox(
        height: widget.maxHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final Rect? region = parseRegionRect(widget.highlight);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: DecoratedBox(
        // The same radius, hairline and shadow as a list tile's WalletCard, so
        // the header reads as the same object the user tapped.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CardImageOverlay._radius),
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CardImageOverlay._radius),
          child: AspectRatio(
            // The card's own shape, not the uniform tile shape. Tiles crop to
            // fill a wallet frame; this one is where fields get checked and
            // corrected, so the whole card has to be visible and every region
            // reachable. Since the image is now a cropped card rather than a
            // photograph of one, following its shape leaves no dead space
            // anyway.
            aspectRatio: size.width / size.height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image(image: _provider, fit: BoxFit.contain),
                if (region != null)
                  CustomPaint(
                    painter: _RegionPainter(
                      region: region,
                      imageSize: size,
                      colour: theme.colorScheme.primary,
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
      old.region != region || old.imageSize != imageSize || old.colour != colour;
}
