import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'brand_paths.dart';

/// The folded-card R, shared by the wallet, welcome and launch experience.
/// Geometry is generated alongside the native icons from tool/brand/generate.py.
class RecallMark extends StatelessWidget {
  const RecallMark({
    this.size = 32,
    this.semanticLabel = 'RecallOS',
    super.key,
  });

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _RecallMarkPainter(c.ink, c.ochre)),
      ),
    );
  }
}

class _RecallMarkPainter extends CustomPainter {
  const _RecallMarkPainter(this.ink, this.ochre);

  final Color ink;
  final Color ochre;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    canvas.drawPath(BrandPaths.card(), Paint()..color = ink);
    canvas.drawPath(BrandPaths.fold(), Paint()..color = ochre);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RecallMarkPainter oldDelegate) =>
      ink != oldDelegate.ink || ochre != oldDelegate.ochre;
}

/// A single accessible name, with live bundled typography rather than a bitmap.
class RecallBrand extends StatelessWidget {
  const RecallBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Semantics(
      label: 'RecallOS',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const RecallMark(semanticLabel: null),
          const SizedBox(width: Gap.sm),
          Text(
            'RECALLOS',
            style: AppText.micro(
              c,
            ).copyWith(fontSize: 12, letterSpacing: 2.6, color: c.ink),
          ),
        ],
      ),
    );
  }
}

/// Covers startup while the stored theme and privacy preferences load.
/// No timer: the wallet opens as soon as it is ready.
class RecallLaunchCover extends StatelessWidget {
  const RecallLaunchCover({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.of(context).page,
    child: const Center(child: RecallMark(size: 144)),
  );
}
