import 'package:flutter/material.dart';

/// Colour seeds and typography for RecallOS.
///
/// The app is used one-handed, often in a hurry, right after someone hands you
/// a card. Type is large, targets are generous, and the palette stays calm so
/// that source chips and confidence warnings are the things that stand out.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF2D6A4F);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      // A 52pt floor on height, and Material's usual 64 on width.
      //
      // Not `Size.fromHeight(52)`, which is `Size(infinity, 52)` — an infinite
      // *minimum* width. Inside anything that measures a child against
      // unbounded width, a Row most of all, that is an unsatisfiable
      // constraint: the button demands infinite width, layout fails, and
      // every sibling in the surrounding list silently fails to paint with
      // it. The screens that use these buttons full-width get their width
      // from an `Expanded` or a stretching `Column`, never from here.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // Floating rather than fixed: a bar welded to the bottom edge covers the
      // scan button and squares off a screen whose every other surface is
      // rounded.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(Gap.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

/// Spacing scale. Use these instead of raw numbers so screens stay consistent.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
