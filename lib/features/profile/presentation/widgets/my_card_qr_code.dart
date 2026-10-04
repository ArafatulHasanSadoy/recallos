import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/primitives.dart';

/// The light palette, in dark mode too.
///
/// A QR code is read as dark squares on a light ground. Camera apps differ on
/// whether they also try the inverse, so a code drawn in the dark theme's
/// light-on-dark would scan on one phone and not the next — and the person
/// holding the other phone is the one who would decide the app is broken.
/// Paper and ink from the light theme keep it the right way round always.
const AppColors _paper = AppColors.light;

/// M rather than the default L: a phone screen under event lighting has
/// glare, and M survives about 15% of the code being unreadable.
const int _correction = QrErrorCorrectLevel.M;

/// The code for [payload], or null when it is too long for one QR code.
QrCode? myCardQrCode(String payload) {
  final QrValidationResult v = QrValidator.validate(
    data: payload,
    errorCorrectionLevel: _correction,
  );
  final QrCode? code = v.qrCode;
  if (v.status != QrValidationStatus.valid || code == null) return null;
  // For data that fits no version the validator still answers "valid", with
  // the largest one; the overflow only surfaces when the squares are laid
  // out, which would be inside the painter, mid-frame.
  try {
    QrImage(code);
  } on InputTooLongException {
    return null;
  }
  return code;
}

/// What draws it. Shared with the test that decodes it, so the test reads
/// exactly the squares the screen paints.
QrPainter myCardQrPainter(QrCode code) => QrPainter.withQr(
  qr: code,
  gapless: true,
  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _paper.ink),
  dataModuleStyle: QrDataModuleStyle(
    dataModuleShape: QrDataModuleShape.square,
    color: _paper.ink,
  ),
);

/// The code on its paper tile, or — when it will not fit — the reason, said
/// where the lines that make it too long can be turned off.
class MyCardQrCode extends StatelessWidget {
  const MyCardQrCode({required this.payload, required this.size, super.key});

  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final QrCode? code = myCardQrCode(payload);

    if (code == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: AppDecoration.card(
          c,
          isDark: isDarkTheme(context),
          lifted: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Too much for one code', style: AppText.rowTitle(c)),
            const SizedBox(height: Gap.xs),
            Text(
              'Turn off a line or two below and it will fit.',
              style: AppText.body(c),
            ),
          ],
        ),
      );
    }

    // Whole device pixels per square. A square that straddles two pixels is
    // drawn with grey edges, and a camera reads grey less surely than black
    // and white — so the code is made a little smaller rather than blurred.
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double perSquare = (size * dpr / code.moduleCount).floorToDouble();
    final double crisp = perSquare * code.moduleCount / dpr;

    return Center(
      child: Semantics(
        image: true,
        label: 'QR code of your card',
        child: Container(
          // The quiet margin a scanner needs is the tile's own padding.
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: _paper.card,
            borderRadius: AppRadius.cardR,
          ),
          child: SizedBox.square(
            dimension: crisp,
            child: CustomPaint(painter: myCardQrPainter(code)),
          ),
        ),
      ),
    );
  }
}
