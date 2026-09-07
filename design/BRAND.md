# RecallOS identity

A folded business card with an R cut into its face. The initial makes the mark
specific to RecallOS; the ochre fold carries forward the wallet's existing
visual language for a card worth remembering.

The mark uses ink `#1F1B13`, paper `#F0EADC` and ochre `#C8901A`. In-app colors
come from `AppColors`, including the brighter ochre in dark mode. The wordmark
uses the already bundled Archivo font, uppercase with 2.6px tracking at 12px.

## Sources and exports

`tool/brand/generate.py` holds the canonical geometry and produces:

- Editable SVG mark, inverse, wordmark lockup and app icon in `assets/brand/`.
- PNG icon exports and transparent marks in `assets/brand/png/`.
- `lib/core/ui/brand_paths.dart`, used by `RecallMark` and `RecallBrand`.
- Android density-specific icons, adaptive foreground and monochrome artwork.
- iPhone/iPad/App Store icons and light/dark launch image catalogs.

Run `python3 tool/brand/generate.py`, then
`dart format lib/core/ui/brand_paths.dart`. ImageMagick (`magick`) is a build-time
requirement only. The generated assets are committed with the app, so normal
Flutter builds do not require it. The SVG wordmark is editable text and requires
Archivo on the machine displaying it; in-app text always uses the bundled font.

This extends the project's native vector identity; no image-generation model
or external image API was used.

## Integration

Home, onboarding and the settings footer use `RecallBrand`. Onboarding's front
card and the closed-wallet screen use `RecallMark`. The startup cover displays
a centered mark while the settings load, with no artificial delay.

Android 8–11 uses a centered vector launch drawable. Android 12+ uses its native
splash API with a padded mark that fits the system mask. Android 8+ launchers
use adaptive icons; Android 13+ also gets monochrome artwork for themed icons.
The iOS storyboard uses a fixed 144pt mark, centered by constraints, and named
light/dark colors. App Store icons are opaque and have no baked-in rounded mask.

Native launch screens follow the device's light/dark mode; Flutter switches to
the saved app appearance once preferences have loaded. A user-selected theme
that differs from the system can therefore cause a brief color transition.

## Check on a phone

1. Find RecallOS in the launcher: paper R-card, ochre fold, dark background.
2. Cold-launch it: centered mark on warm paper or dark ink, then the wallet.
3. Check the home header and Settings footer for the matching mark and wordmark.
4. Change Settings → Appearance to light and dark; check contrast in both.
5. On a fresh install, onboarding shows the wordmark and a branded front card.
   At larger text sizes, its content scrolls while Next and Skip stay reachable.

Do not clear app data to test onboarding on a phone with saved cards. The
compact-screen widget tests exercise all three pages in both themes.
