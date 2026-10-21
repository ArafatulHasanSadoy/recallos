import 'dart:ui' show Rect;

import 'package:recallos/core/intelligence/ocr_engine.dart';

/// A document laid out the way OCR returns it: one block per printed line,
/// or two when a row has a price column — "Grand Total" on the left and
/// "432.60" on the right come back as separate blocks.
///
/// Invented receipts in common Bangladeshi shapes, not copies of real ones.
List<OcrBlock> paper(List<Object> rows, {double headerHeight = 34}) {
  final List<OcrBlock> out = <OcrBlock>[];
  double top = 10;
  for (int i = 0; i < rows.length; i++) {
    final double h = i == 0 ? headerHeight : 18;
    final Object row = rows[i];
    final (String left, String? right) = row is (String, String)
        ? (row.$1, row.$2)
        : (row as String, null);
    out.add(
      OcrBlock(
        text: left,
        rect: Rect.fromLTWH(10, top, 280, h),
        confidence: 0.9,
        script: Script.latin,
      ),
    );
    if (right != null) {
      out.add(
        OcrBlock(
          text: right,
          rect: Rect.fromLTWH(320, top + 1, 120, h),
          confidence: 0.9,
          script: Script.latin,
        ),
      );
    }
    top += h + 12;
  }
  return out;
}
