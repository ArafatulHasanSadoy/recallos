import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/imaging/card_geometry.dart';

/// A saved card, drawn the way a card looks.
///
/// The proportion is ISO/IEC 7810 ID-1 — the credit-card shape both Google
/// Wallet and Apple Wallet use — so a library of these reads as a wallet
/// rather than a camera roll.
class WalletCard extends StatelessWidget {
  const WalletCard({
    required this.imagePath,
    this.needsAttention = false,
    this.heroTag,
    super.key,
  });

  /// The thumbnail where there is one, otherwise the full card image.
  final String imagePath;

  final bool needsAttention;
  final Object? heroTag;

  /// The frame's shape. The card inside keeps its own; see [_Art].
  static const double aspectRatio = cardAspectRatio;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: theme.colorScheme.surfaceContainerHighest,
          // A hairline as well as a shadow: a pale card on this pale
          // background has no edge of its own to show.
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
          borderRadius: BorderRadius.circular(_radius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _Art(imagePath: imagePath, heroTag: heroTag),
              if (needsAttention)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _AttentionBadge(theme: theme),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Below this the image is not a landscape card at all.
///
/// A card is filled edge to edge whatever its proportions, because that is what
/// makes a tile read as a physical card rather than a photo of one. Cropping a
/// *portrait* image to a landscape frame is different in kind though — it shows
/// a patch from the middle of a photograph, unrecognisable as anything — so
/// those are fitted whole instead. In practice that is only cards saved before
/// edge detection existed.
const double _minLandscape = 1.15;

class _Art extends StatefulWidget {
  const _Art({required this.imagePath, required this.heroTag});

  final String imagePath;
  final Object? heroTag;

  @override
  State<_Art> createState() => _ArtState();
}

class _ArtState extends State<_Art> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void didUpdateWidget(_Art old) {
    super.didUpdateWidget(old);
    if (old.imagePath != widget.imagePath) {
      _detach();
      _aspect = null;
      _measure();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// Reads the image's proportions, and nothing else.
  ///
  /// Deliberately decoded at 32 px: the shape is all that is wanted here, and
  /// this must not compete with the full-size decode the [Image] below does at
  /// draw resolution.
  void _measure() {
    final ImageStream stream =
        ResizeImage(FileImage(File(widget.imagePath)), width: 32)
            .resolve(ImageConfiguration.empty);
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!mounted) return;
        setState(() => _aspect = info.image.width / info.image.height);
      },
      onError: (Object _, StackTrace? _) {},
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

  BoxFit get _fit {
    final double? aspect = _aspect;
    // Until the shape is known, fit rather than fill — a wrong `contain` only
    // leaves a little space, while a wrong `cover` hides part of the card.
    if (aspect == null) return BoxFit.contain;

    return aspect >= _minLandscape ? BoxFit.cover : BoxFit.contain;
  }

  @override
  Widget build(BuildContext context) {
    final File file = File(widget.imagePath);
    if (!file.existsSync()) return const _MissingArt();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Decode at the size actually drawn. Full-width card art at native
        // resolution is several megabytes a row, which a long library on a
        // 3 GB phone does not survive.
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final int cacheWidth =
            (width * MediaQuery.devicePixelRatioOf(context)).round();

        final BoxFit fit = _fit;
        final Widget image = Image.file(
          file,
          key: const ValueKey<String>('card-art'),
          fit: fit,
          // Crop from the far edge, never the near one. Whatever a card has by
          // way of identity — logo, business name — is at its top left far
          // more often than not, so that is the corner worth keeping whole.
          alignment: Alignment.topLeft,
          cacheWidth: cacheWidth <= 0 ? null : cacheWidth,
          errorBuilder: (_, _, _) => const _MissingArt(),
        );

        // Only the fallback needs filling behind it. A real card covers the
        // frame on its own, which is the whole point — edge to edge, no border,
        // no seam, indistinguishable from the card in your hand.
        final Widget content = fit == BoxFit.cover
            ? image
            : Stack(
                fit: StackFit.expand,
                children: <Widget>[CardBackdrop(file: file), image],
              );

        final Object? tag = widget.heroTag;
        return tag == null ? content : Hero(tag: tag, child: content);
      },
    );
  }
}

/// Fills a card frame with the card's own colours, softened.
///
/// Deliberately decoded at 40 px and then blurred: upscaling something that
/// small is most of the softening already, so this costs a rounding error of
/// memory per row rather than a second full-size bitmap. The scrim over it
/// keeps a pale card from disappearing into its own pale surround.
class CardBackdrop extends StatelessWidget {
  const CardBackdrop({required this.file, super.key});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
            tileMode: TileMode.clamp,
          ),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 40,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
      ],
    );
  }
}

class _MissingArt extends StatelessWidget {
  const _MissingArt();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.credit_card_outlined,
          size: 40,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

/// Marks a card whose extraction went badly, so the library shows what needs
/// repairing without having to open anything.
class _AttentionBadge extends StatelessWidget {
  const _AttentionBadge({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.flag_outlined,
        size: 16,
        color: theme.colorScheme.onErrorContainer,
      ),
    );
  }
}
