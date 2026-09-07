/// RecallOS design system — "the wallet you can ask questions".
///
/// Replaces the seed-generated Material palette. Nothing here is derived from
/// `ColorScheme.fromSeed`: the palette is a fixed set of warm paper and ink
/// values, and the whole point is that they do not drift when Flutter changes
/// its tonal-palette algorithm.
///
/// Two rules carry the identity, and breaking either one is what makes the app
/// look generic again:
///
///  1. **Inputs are recessed, never outlined.** Use [AppDecoration.pocket],
///     which is an inner shadow via `BlurStyle.inner`. No `OutlineInputBorder`
///     anywhere in the app.
///  2. **Ochre is a marker, not a surface.** In light mode it is a caret, a
///     corner fold, a 4px rail, a confidence dot — never a filled button. In
///     dark mode it becomes the primary button fill, because ink-on-ink has no
///     contrast.
///
/// Fonts are bundled, not fetched. Do **not** add `google_fonts`: it downloads
/// at first run, which breaks the zero-egress guarantee. See the pubspec
/// snippet in `design/DESIGN.md`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

/// The palette, twice. Read these through `AppColors.of(context)`, never as
/// raw constants inside a widget, or dark mode silently stops working.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.card,
    required this.pocket,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.hairline,
    required this.hairlineOnCard,
    required this.ochre,
    required this.ochreInk,
    required this.olive,
    required this.vermilion,
    required this.onInk,
    required this.onOchre,
  });

  /// Screen background. The sand ground everything sits on.
  final Color page;

  /// Raised paper: cards, tiles, grouped-setting containers.
  final Color card;

  /// Sunken paper: every text field, every editable value. In light mode this
  /// is *darker* than [page]; in dark mode it is darker still than [page],
  /// because a pocket is a hole in both.
  final Color pocket;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  /// Hairline on [page].
  final Color hairline;

  /// Hairline on [card] — one step lighter, or rows look ruled.
  final Color hairlineOnCard;

  /// The accent. Folds, carets, rails, low-confidence dots. In dark mode also
  /// the primary button fill.
  final Color ochre;

  /// Ochre pushed dark enough for 4.5:1 body text on [page] / [card].
  /// Use this for links and inline actions — never [ochre] itself.
  final Color ochreInk;

  /// Clean extraction.
  final Color olive;

  /// Failed extraction, destructive copy.
  final Color vermilion;

  /// Foreground on an [ink] fill.
  final Color onInk;

  /// Foreground on an [ochre] fill.
  final Color onOchre;

  static const AppColors light = AppColors(
    page: Color(0xFFE4DAC5),
    card: Color(0xFFFBF7EE),
    pocket: Color(0xFFD6CAB1),
    ink: Color(0xFF1F1B13),
    inkMuted: Color(0xFF6B6047),
    inkFaint: Color(0xFF9C8F73),
    hairline: Color(0xFFC6BAA1),
    hairlineOnCard: Color(0xFFE3D9C4),
    ochre: Color(0xFFC8901A),
    ochreInk: Color(0xFF8A5A12),
    olive: Color(0xFF7A8A5E),
    vermilion: Color(0xFFD9502A),
    onInk: Color(0xFFF5EFE2),
    onOchre: Color(0xFF2A1D0A),
  );

  static const AppColors dark = AppColors(
    page: Color(0xFF15130F),
    card: Color(0xFF1D1A15),
    pocket: Color(0xFF0F0D0A),
    ink: Color(0xFFF0EADC),
    inkMuted: Color(0xFF8A8271),
    inkFaint: Color(0xFF6E6757),
    hairline: Color(0xFF2C2821),
    hairlineOnCard: Color(0xFF332E25),
    ochre: Color(0xFFD8A31A),
    ochreInk: Color(0xFFE8B84B),
    olive: Color(0xFF93A472),
    vermilion: Color(0xFFE0641F),
    onInk: Color(0xFF15130F),
    onOchre: Color(0xFF15130F),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  /// The confidence dot colour for an extraction score. Three states only —
  /// a percentage on a business card field is false precision.
  Color confidence(double score) {
    if (score >= 0.85) return olive;
    if (score >= 0.5) return ochre;
    return vermilion;
  }

  @override
  AppColors copyWith({
    Color? page,
    Color? card,
    Color? pocket,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? hairline,
    Color? hairlineOnCard,
    Color? ochre,
    Color? ochreInk,
    Color? olive,
    Color? vermilion,
    Color? onInk,
    Color? onOchre,
  }) {
    return AppColors(
      page: page ?? this.page,
      card: card ?? this.card,
      pocket: pocket ?? this.pocket,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      hairline: hairline ?? this.hairline,
      hairlineOnCard: hairlineOnCard ?? this.hairlineOnCard,
      ochre: ochre ?? this.ochre,
      ochreInk: ochreInk ?? this.ochreInk,
      olive: olive ?? this.olive,
      vermilion: vermilion ?? this.vermilion,
      onInk: onInk ?? this.onInk,
      onOchre: onOchre ?? this.onOchre,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      pocket: Color.lerp(pocket, other.pocket, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineOnCard: Color.lerp(hairlineOnCard, other.hairlineOnCard, t)!,
      ochre: Color.lerp(ochre, other.ochre, t)!,
      ochreInk: Color.lerp(ochreInk, other.ochreInk, t)!,
      olive: Color.lerp(olive, other.olive, t)!,
      vermilion: Color.lerp(vermilion, other.vermilion, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      onOchre: Color.lerp(onOchre, other.onOchre, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

abstract final class AppFonts {
  /// Pins the weight axis of the variable Archivo file.
  ///
  /// Google publishes Archivo only as a variable font, so every weight comes
  /// out of one file. `fontWeight` alone selects between *declared* pubspec
  /// entries — with a single entry there is nothing to select, and every
  /// weight would render at the 400 default with the heavier ones faked by
  /// synthetic bolding, which on this type reads as a smudge. Setting the
  /// `wght` axis is what actually cuts the weight.
  static List<FontVariation> weight(double w) =>
      <FontVariation>[FontVariation('wght', w)];

  /// Instrument Serif. Display lines, card and person titles, and any standalone
  /// numeral in a section header. Italic is reserved for questions the app asks
  /// the user — "What do you need?", "Why did this one matter?" — and nothing
  /// else, so the italic always reads as the app speaking.
  static const String serif = 'InstrumentSerif';

  /// Archivo. All UI: rows, fields, buttons, labels, body copy.
  static const String sans = 'Archivo';
}

/// The type scale. Six roles, and that is the whole set — a seventh size is
/// almost always a spacing problem in disguise.
///
/// Mapped onto Material's [TextTheme] slots so stock widgets inherit correctly:
/// display→`displaySmall`, title→`headlineSmall`, rowTitle→`titleMedium`,
/// body→`bodyMedium`, small→`bodySmall`, micro→`labelSmall`.
abstract final class AppText {
  static TextStyle display(AppColors c) => TextStyle(
        fontFamily: AppFonts.serif,
        fontSize: 44,
        height: 1.06,
        letterSpacing: -0.2,
        color: c.ink,
      );

  /// The italic variant. Only for a question addressed to the user.
  static TextStyle displayAsk(AppColors c) =>
      display(c).copyWith(fontStyle: FontStyle.italic);

  static TextStyle title(AppColors c) => TextStyle(
        fontFamily: AppFonts.serif,
        fontSize: 28,
        height: 1.1,
        color: c.ink,
      );

  /// Card and person titles inside a row.
  static TextStyle rowSerif(AppColors c) => TextStyle(
        fontFamily: AppFonts.serif,
        fontSize: 22,
        height: 1.1,
        color: c.ink,
      );

  static TextStyle rowTitle(AppColors c) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 17,
        height: 1.28,
        fontWeight: FontWeight.w600,
        fontVariations: AppFonts.weight(600),
        letterSpacing: -0.2,
        color: c.ink,
      );

  static TextStyle body(AppColors c) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        height: 1.45,
        color: c.inkMuted,
      );

  static TextStyle small(AppColors c) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 12.5,
        height: 1.4,
        color: c.inkMuted,
      );

  /// Section headers and field labels. The wide tracking is load-bearing —
  /// at 10.5px without it this is unreadable mud.
  static TextStyle micro(AppColors c) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        fontVariations: AppFonts.weight(700),
        letterSpacing: 2.4,
        color: c.inkMuted,
      );

  /// The metadata line on a wallet tile — "FARMGATE · 3D".
  ///
  /// Smaller and tighter than [micro], which is a section header. Two sizes
  /// rather than one because a header labels a region and this labels a row;
  /// at the same size the row's line competes with its own title.
  static TextStyle meta(AppColors c) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w700,
        fontVariations: AppFonts.weight(700),
        letterSpacing: 1.6,
        color: c.inkFaint,
      );

  static TextStyle button(AppColors c, {required Color on}) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        fontVariations: AppFonts.weight(600),
        letterSpacing: 0.2,
        color: on,
      );
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

/// Spacing scale. Use these instead of raw numbers so screens stay consistent.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal screen gutter. Every screen, no exceptions.
  static const double gutter = 24;

  /// Vertical pitch of the home stack: card height 116 minus 24 of overlap.
  /// The overlap is what makes the library read as a wallet rather than a list.
  static const double stackPitch = 92;
  static const double stackCardHeight = 116;

  /// The card thumbnail. A business card is landscape (3.5×2in) and the
  /// thumbnail keeps that ratio — a portrait crop stops reading as a card.
  static const Size cardFaceThumb = Size(104, 64);
}

abstract final class AppRadius {
  static const double card = 16;
  static const double tile = 13;
  static const double pocket = 14;
  static const double chip = 8;
  static const double cardFace = 9;

  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get tileR => BorderRadius.circular(tile);
  static BorderRadius get pocketR => BorderRadius.circular(pocket);
  static BorderRadius get chipR => BorderRadius.circular(chip);

  /// A pill is always exactly half its height. Never a fixed 999.
  static BorderRadius pill(double height) =>
      BorderRadius.circular(height / 2);
}

/// Minimum tap target. Applies to icon buttons too — a 40px icon button in a
/// 52px world is the thing users blame when they miss.
const double kMinTarget = 52;

// ---------------------------------------------------------------------------
// Decoration
// ---------------------------------------------------------------------------

/// The surfaces, and one rule about how they come across from the frames.
///
/// **Flutter's inner shadows run opposite to CSS's `inset`.** A CSS
/// `inset 0 -2px 0` band lands on the *bottom* inner edge; the same offset
/// given to a `BlurStyle.inner` `BoxShadow` lands on the *top*. So every inset
/// measured off `design/screens.html` has its vertical sign flipped here.
///
/// Getting that backwards is not subtle on a phone. It put a hard white 2px
/// line along the top edge of every card — in an overlapping stack that is
/// exactly where one card meets the next, so the wallet read as a row of
/// scratches. It also lit the top of every input and left the recess shadow
/// along the bottom, so the pockets read as raised rather than sunken, which
/// is rule 1 exactly inverted.
abstract final class AppDecoration {

  /// The recessed input. This is the app's signature surface — use it for
  /// every text field, and for any value the user can edit in place.
  ///
  /// `BlurStyle.inner` is native Flutter and needs no image asset; the second
  /// shadow is the light catch on the bottom lip, which is what stops it
  /// reading as a flat grey box. In dark mode the catch is dropped and the
  /// fill goes below the page colour, so the pocket is a hole either way.
  static BoxDecoration pocket(AppColors c, {bool isDark = false}) {
    // The lit bottom wall of the recess, as a fill rather than a stroke.
    //
    // The frames specify it as `inset 0 -1px 0 rgba(255,255,255,.5)` — a hard
    // 1px line — and transcribing that literally does not survive the trip.
    // CSS builds an inset shadow by translating the *same* rounded rect and
    // filling the difference, so the band stays 1px the whole way round.
    // Flutter's `BlurStyle.inner` builds it by blurring the silhouette and
    // clipping inward, and at `blurRadius: 0` the difference between a corner
    // arc and the same arc moved down is several times wider than the straight
    // edge. The result was a thin line along the bottom that swelled into a
    // bright hook around each corner — an outline where the design wants a lip.
    //
    // A gradient has no such problem: it is a fill, so it follows the rounded
    // rect exactly, and light gathering over the last few points of the bottom
    // wall is closer to what a recess actually does than a drawn line is.
    final Color lip = isDark
        ? Color.lerp(c.pocket, c.ink, 0.07)!
        : Color.lerp(c.pocket, Colors.white, 0.22)!;

    return BoxDecoration(
      borderRadius: AppRadius.pocketR,
      border: isDark ? Border.all(color: c.hairline) : null,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[c.pocket, c.pocket, lip],
        // Flat for most of the drop, then the catch. Spread evenly it would
        // read as a glossy button, which is the opposite of sunken.
        stops: const <double>[0, 0.78, 1],
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.6)
              : const Color(0xFF322816).withValues(alpha: 0.22),
          // Measured off the frames: 0 2px 3px on paper, 0 2px 4px on ink,
          // and no spread in either. Spread on an inner shadow thickens the
          // whole rim rather than deepening the recess.
          //
          // Negative, where the CSS is positive — see the class note. This is
          // the shadow that makes it a hole, and it belongs at the top, away
          // from the light. It keeps `BlurStyle.inner` because it *has* blur,
          // and blur is what hides the corner divergence described above.
          blurRadius: isDark ? 4 : 3,
          offset: const Offset(0, -2),
          blurStyle: BlurStyle.inner,
        ),
      ],
    );
  }

  /// Raised paper. One tile in the home stack, one result, one grouped block.
  static BoxDecoration card(
    AppColors c, {
    bool isDark = false,
    bool lifted = true,
  }) {
    return BoxDecoration(
      color: c.card,
      borderRadius: AppRadius.cardR,
      border: Border.all(color: c.hairlineOnCard),
      // No inner light catch. The frames specify one — `inset 0 -2px 0
      // rgba(255,255,255,.9)` — and it cannot be reproduced here.
      //
      // In CSS it composites as a 2px band over a near-white card, so the step
      // from #FBF7EE to white is almost nothing and it reads as thickness. A
      // Flutter `BlurStyle.inner` shadow paints far more strongly than that,
      // and the result is a near-white stroke. Invisible where it sits on the
      // card, and stark where the card's bottom edge meets the darker page —
      // which is every row on card detail, every block in settings, and every
      // grouped surface in the app.
      //
      // Blur did not fix it and neither did the offset; the mechanism is
      // wrong, not the numbers. Paper here reads as raised through the
      // hairline and, when it is lifted, the drop shadow — which is what was
      // carrying the effect anyway.
      boxShadow: <BoxShadow>[
        if (lifted)
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.75)
                : const Color(0xFF302614).withValues(alpha: 0.45),
            blurRadius: isDark ? 26 : 24,
            spreadRadius: -10,
            offset: Offset(0, isDark ? 14 : 12),
          ),
      ],
    );
  }

  /// A search result: the same paper, sitting flatter.
  ///
  /// Rule 4. Library tiles overlap and cast a deep shadow because they are
  /// things you own; an answer is computed, so it lies nearly flat and stands
  /// alone. Same fill, half the lift — that difference is doing the work.
  static BoxDecoration flatCard(AppColors c, {bool isDark = false}) =>
      BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: c.hairlineOnCard),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFF302614).withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// The ink pill. Primary action in light mode.
  static BoxDecoration inkPill(AppColors c, double height) => BoxDecoration(
        color: c.ink,
        borderRadius: AppRadius.pill(height),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.ink.withValues(alpha: 0.65),
            blurRadius: 26,
            spreadRadius: -10,
            offset: const Offset(0, 14),
          ),
        ],
      );

  /// The ochre pill. Primary action in dark mode. No shadow — a glow around a
  /// bright fill on near-black reads as a bug.
  static BoxDecoration ochrePill(AppColors c, double height) => BoxDecoration(
        color: c.ochre,
        borderRadius: AppRadius.pill(height),
      );

  /// Secondary action: hairline outline, no fill, ink label.
  static BoxDecoration outlinePill(AppColors c, double height) => BoxDecoration(
        borderRadius: AppRadius.pill(height),
        border: Border.all(color: c.hairline, width: 1.5),
      );
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light, AppColors.light);
  static ThemeData dark() => _base(Brightness.dark, AppColors.dark);

  /// Capture is always dark, whatever the app theme. Bright chrome around a
  /// camera preview wrecks the exposure read and makes every card look grey.
  static ThemeData capture() => dark();

  static ThemeData _base(Brightness brightness, AppColors c) {
    final bool isDark = brightness == Brightness.dark;

    // Written out rather than seeded. Stock widgets still need a ColorScheme,
    // and letting `fromSeed` invent one puts Material purple in the ripples.
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.onInk,
      primaryContainer: c.ochre,
      onPrimaryContainer: c.onOchre,
      secondary: c.ochreInk,
      onSecondary: c.onInk,
      secondaryContainer: c.pocket,
      onSecondaryContainer: c.ink,
      tertiary: c.olive,
      onTertiary: c.onInk,
      error: c.vermilion,
      onError: c.onInk,
      errorContainer: isDark ? const Color(0xFF2A1D12) : const Color(0xFFF3DCD2),
      onErrorContainer: isDark ? const Color(0xFFE4C9A8) : const Color(0xFF8E3416),
      surface: c.page,
      onSurface: c.ink,
      surfaceContainerLowest: c.pocket,
      surfaceContainerLow: c.page,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.card,
      surfaceContainerHighest: c.card,
      onSurfaceVariant: c.inkMuted,
      outline: c.hairline,
      outlineVariant: c.hairlineOnCard,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: c.ink,
      onInverseSurface: c.onInk,
      inversePrimary: c.ochre,
    );

    final TextTheme text = TextTheme(
      displayLarge: AppText.display(c),
      displayMedium: AppText.display(c),
      displaySmall: AppText.display(c),
      headlineLarge: AppText.title(c),
      headlineMedium: AppText.title(c),
      headlineSmall: AppText.title(c),
      titleLarge: AppText.rowSerif(c),
      titleMedium: AppText.rowTitle(c),
      titleSmall: AppText.rowTitle(c).copyWith(fontSize: 15),
      bodyLarge: AppText.body(c).copyWith(fontSize: 15.5, color: c.ink),
      bodyMedium: AppText.body(c),
      bodySmall: AppText.small(c),
      labelLarge: AppText.button(c, on: c.ink),
      labelMedium: AppText.micro(c).copyWith(fontSize: 11.5, letterSpacing: 1.8),
      labelSmall: AppText.micro(c),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.page,
      canvasColor: c.page,
      fontFamily: AppFonts.sans,
      textTheme: text,
      visualDensity: VisualDensity.standard,

      // No ripple. A splash on warm paper reads as a smudge; the app uses
      // scale-and-darken press feedback instead (see PressFade in DESIGN.md).
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.micro(c),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // Fields get their look from AppDecoration.pocket, so the InputDecorator
      // itself must contribute nothing — no border, no fill, no default padding
      // fighting the container it sits inside.
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintStyle: AppText.body(c)
            .copyWith(fontSize: 15, color: c.inkMuted.withValues(alpha: 0.85)),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ochre,
        selectionColor: c.ochre.withValues(alpha: 0.28),
        selectionHandleColor: c.ochre,
      ),

      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: 1,
        space: 1,
      ),

      // Retained only for dialogs and anything not yet converted. New UI should
      // use the InkPill / OutlinePill widgets, not FilledButton.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? c.ochre : c.ink,
          foregroundColor: isDark ? c.onOchre : c.onInk,
          minimumSize: const Size(64, kMinTarget),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pill(kMinTarget)),
          textStyle: AppText.button(c, on: isDark ? c.onOchre : c.onInk),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(64, kMinTarget),
          side: BorderSide(color: c.hairline, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pill(kMinTarget)),
          textStyle: AppText.button(c, on: c.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ochreInk,
          textStyle: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: c.ochreInk,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: c.hairlineOnCard),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: AppText.title(c).copyWith(fontSize: 24),
        contentTextStyle: AppText.body(c),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),

      // Floating, and above where the scan pill sits.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: AppText.body(c).copyWith(color: c.onInk, fontSize: 14),
        actionTextColor: c.ochre,
        insetPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, 100),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Present so nothing inherits Material purple; the app should not create
      // one. The scan action is a Positioned pill inside the body.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.ink,
        foregroundColor: c.ochre,
        elevation: 0,
      ),

      // Loading is three ghost cards, not a spinner. This exists only for the
      // pull-to-refresh indicator.
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ochre,
        linearTrackColor: c.hairline,
        circularTrackColor: c.hairline,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.hairlineOnCard),
        ),
        textStyle: AppText.rowTitle(c).copyWith(fontSize: 15),
      ),

      iconTheme: IconThemeData(color: c.ink, size: 20, weight: 500),

      // Rounded and slower than Material's default. The wallet is heavy.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Motion. Three durations and one curve — anything outside this set makes the
/// app feel like two apps.
abstract final class AppMotion {
  /// Press feedback, dot state, switch knob.
  static const Duration quick = Duration(milliseconds: 130);

  /// Card expand, sheet, stack reflow.
  static const Duration normal = Duration(milliseconds: 260);

  /// Hero from the stack into card detail. Long on purpose: it is the moment
  /// the app earns the word "wallet".
  static const Duration hero = Duration(milliseconds: 420);

  static const Curve curve = Curves.easeOutCubic;
}
