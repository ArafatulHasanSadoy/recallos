import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/imaging/sealed_file_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/primitives.dart';

/// One side of a card at full size, pinch to zoom.
///
/// The stage stays dark in both modes, because a white card reads best
/// against one: `ink` in light mode, `page` in dark, each with the colour
/// the system pairs with it for text on top.
///
/// Not an `AppBar`. This screen used to be a Material one on a hard-coded
/// black, and its back arrow took the theme's ink — near-black on black, a
/// way out nobody could see.
class FullImageView extends StatelessWidget {
  const FullImageView({required this.image, super.key});

  final File image;

  /// The stage and the colour drawn on it, for this brightness.
  static ({Color stage, Color onStage}) colors(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Theme.of(context).brightness == Brightness.dark
        ? (stage: c.page, onStage: c.ink)
        : (stage: c.ink, onStage: c.onInk);
  }

  @override
  Widget build(BuildContext context) {
    final ({Color stage, Color onStage}) look = colors(context);

    // The stage is dark in both modes, so the status bar's icons are light in
    // both — the app's own style would draw them in ink on this screen.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: look.stage,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Center(child: Image(image: SealedFileImage(image))),
                ),
              ),
              Positioned(
                top: Gap.sm,
                left: Gap.sm,
                child: PressFade(
                  onTap: () => Navigator.of(context).maybePop(),
                  scale: 0.9,
                  semanticLabel: 'Back',
                  child: SizedBox(
                    width: kMinTarget,
                    height: kMinTarget,
                    child: Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: look.onStage,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
