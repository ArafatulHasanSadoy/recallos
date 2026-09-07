# RecallOS — UI redesign handoff

Everything in this folder is meant to be dropped into the repo. The visual
reference is `design/screens.html` (open in any browser — 16 frames, light and
dark, with a Flutter note under each one).

Every frame was reconciled against the widget it replaces, so the notes name
real types (`CardSidesView`, `_NotePrompt`, `PersonDetail.roles`,
`DuplicateKind`) and the data they actually expose. Where a frame proposes
something the repo does not model yet, the note says so explicitly — see
frames 10 and 12.

**Direction:** a physical wallet you flip through. Warm paper grounds, ink
type, one ochre accent used sparingly. Nothing on screen looks like stock
Material, and nothing requires a shader, a blend mode, a platform view, or an
image asset.

---

## 1. Install

### Files

```
lib/core/theme/app_theme.dart      ← replaces the existing file wholesale
assets/brand/                      ← logo SVG + PNG
assets/fonts/                      ← see below, fonts are NOT committed here
design/screens.html                ← visual reference
design/DESIGN.md                   ← this file
```

`app_theme.dart` keeps the existing `AppTheme.light()`, `AppTheme.dark()` and
`Gap` API, so `main.dart` needs no change. It adds `AppColors`, `AppText`,
`AppRadius`, `AppDecoration` and `AppMotion`.

### Fonts — bundle them, do not fetch them

**Do not add the `google_fonts` package.** It downloads font files on first
run, which breaks the zero-egress guarantee the whole product rests on.

Download the two families from Google Fonts as static TTFs and commit them:

```
assets/fonts/Archivo-Regular.ttf
assets/fonts/Archivo-Medium.ttf
assets/fonts/Archivo-SemiBold.ttf
assets/fonts/Archivo-Bold.ttf
assets/fonts/InstrumentSerif-Regular.ttf
assets/fonts/InstrumentSerif-Italic.ttf
```

Archivo ships as a variable font; export the four static instances or use the
variable file with a single `asset` entry per weight. Total cost is about
600 KB — under 2% of the 39.8 MB release APK.

pubspec additions:

```yaml
flutter:
  assets:
    - assets/embedding/
    - assets/brand/

  fonts:
    - family: Archivo
      fonts:
        - asset: assets/fonts/Archivo-Regular.ttf
          weight: 400
        - asset: assets/fonts/Archivo-Medium.ttf
          weight: 500
        - asset: assets/fonts/Archivo-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Archivo-Bold.ttf
          weight: 700
    - family: InstrumentSerif
      fonts:
        - asset: assets/fonts/InstrumentSerif-Regular.ttf
        - asset: assets/fonts/InstrumentSerif-Italic.ttf
          style: italic
```

If a font file is missing, Flutter silently falls back to Roboto and the whole
design collapses into "another AI app". Add a test that asserts
`Theme.of(context).textTheme.displaySmall!.fontFamily == 'InstrumentSerif'`.

### App icon

The geometry source is `tool/brand/generate.py`. It produces SVG masters,
transparent marks, opaque launcher PNGs, Android adaptive/monochrome vectors,
iOS asset catalogs, and the Flutter paths. No runtime package is needed.

```sh
python3 tool/brand/generate.py  # Python 3 + ImageMagick (`magick`)
dart format lib/core/ui/brand_paths.dart
```

The 1024px export is `assets/brand/png/appicon-1024.png`. The rounded export
is for previews only; the operating system masks the actual launcher icon.
See `design/BRAND.md` for launch-screen behavior and verification steps.

---

## 2. The five rules

Break any of these and the redesign reverts to generic. They matter more than
any individual screen.

**1 · Inputs are recessed, never outlined.** Every text field and every
in-place-editable value uses `AppDecoration.pocket`. There is no
`OutlineInputBorder` in the app. The pocket is an inner shadow via
`BlurStyle.inner`, which Flutter supports natively — no nine-patch, no image.

**2 · Ochre is a marker, not a surface.** In light mode ochre appears only as a
caret, a corner fold, a 4px rail, a confidence dot, or small-caps link text
(use `ochreInk`, which is dark enough for 4.5:1 body contrast). It never fills a
button. In dark mode it takes over the primary button, because ink-on-ink has no
contrast.

A rail has to be *attached* to what it marks and has to carry a state. The
repair queue's cap rail qualifies: it is flush inside the row's own rounded
edge and it says failed-versus-partial. A short bar floating beside the search
pocket did not — it belonged to nothing and meant nothing, and it read as a
stray orange sliver next to the field. It has been removed. A decorative rail
is not covered by this rule; it is the thing this rule exists to prevent.

**3 · Serif italic is the app's own voice.** Instrument Serif italic is used
only for questions addressed to the user — "What do you need?", "Why did this
one matter?". Roman serif for titles and standalone numerals. Everything else
is Archivo.

**4 · The library overlaps; answers do not.** On home, cards sit at a 92px
pitch with a 116px height, so each one covers the one below — that overlap is
the entire "wallet" metaphor. Search results un-stack into separate flat
cards, because a computed answer is not a thing you own.

**5 · No spinners, no ripples.** Loading is three ghost cards in the stack at
40% opacity. Press feedback is a scale-and-darken, not a splash
(`splashFactory: NoSplash.splashFactory` is already set).

---

## 3. Component inventory

Build in this order. Each phase is shippable, and each one leaves the app in a
consistent state rather than half-converted.

### Phase 1 — foundation (no screen changes)

| # | Widget | Notes |
|---|---|---|
| 1 | `app_theme.dart` | Drop in. Verify light and dark boot. |
| 2 | `Pocket` | `Container` + `AppDecoration.pocket`. Takes a child, a height, and optional trailing widget. Every field in the app goes through it. |
| 3 | `PressFade` | `GestureDetector` + `AnimatedScale(0.985)` + `AnimatedOpacity(0.88)` over `AppMotion.quick`. Wraps anything tappable. Replaces every `InkWell`. |
| 4 | `InkPill` / `OchrePill` / `OutlinePill` | 54–58px tall, radius = height/2, icon + label row. Three widgets, not one with a `variant` enum — they have different shadows. |
| 5 | `SectionHeader` | micro-caps label, 1px hairline `Expanded`, optional serif numeral on the right. Used on nine screens. |
| 6 | `MicroLabel` | `AppText.micro` + uppercase. Trivial, but centralises the tracking. |

### Phase 2 — the card object

| # | Widget | Notes |
|---|---|---|
| 7 | `CardFace` | The photograph. `Gap.cardFaceThumb` is 104×64 — landscape, because the object is. `ClipRRect` radius 8 (thumb) / 16 (detail), `Image.file` with `BoxFit.cover`, `cacheWidth` set to the layout width × devicePixelRatio — the current `wallet_card.dart` decodes full-resolution photos into 78px boxes. Falls back to a tinted placeholder when `displayPath` is null. |
| 8 | `CornerFold` | The logo's dog-ear, as a `CustomPaint` triangle in the top-right of a `CardFace`. Shown when the card carries a note. 19px on thumbs, 38px on detail. |
| 9 | `WalletCardTile` | Rewrite of `wallet_card.dart` + `_CardTile`: `CardFace` on the left, serif title, note, micro meta on the right. Keeps the `card-{id}` `Hero` tag. |
| 10 | `ConfidenceDot` | 7px circle, `AppColors.confidence(score)`. Three states, never a percentage. |
| 11 | `FieldRow` | 74px micro-caps label, value, trailing slot (dot / action / provenance caps). Used on capture review, card detail, person. |

### Phase 3 — home

| # | Widget | Notes |
|---|---|---|
| 12 | `CardStack` | `Stack` of `Positioned` tiles at `Gap.stackPitch` (92px) with `Gap.stackCardHeight` (116px), inside a `SingleChildScrollView` with height `pitch × n + cardHeight`. Newest last so it sits on top. Swipe-to-delete stays — keep the existing `_DeleteReveal` trick, it is correct. |
| 13 | `StackFade` | `IgnorePointer` + `LinearGradient` from transparent to `page`, 132px, pinned to the bottom. |
| 14 | `ScanPill` | `Positioned(left: 24, right: 24, bottom: 34)` inside the Scaffold body. **Delete the `floatingActionButton`.** |
| 15 | `HomeHeader` | Logo mark + wordmark + two 36px round icon buttons. Replaces the `AppBar` and the `PopupMenuButton`. |
| 16 | `SearchHitCard` | Flat, separated, with the score bar. Bar width comes from the real rank; the label is `hit.reasons.join(' · ')`. Never write prose reasons. |
| 17 | `AttentionRow` | Tinted row, 7px vermilion dot with a soft ring, count, chevron. Replaces `_AttentionBanner`. |
| 18 | `EmptyState` | Glyph + serif line + one sentence + one action. Four instances (see frame 14). The glyph is always a card — never a magnifier or a warning triangle. |
| 19a | `CardHero` / `CardFrame` | The shared-element boundary every card entry point goes through, and the description of how a card is drawn at each end of the flight — corner radius, its own lift, and which file is behind it. **Never wrap a card photo in a bare `Hero`.** Flutter's default shuttle is the *destination* hero's child, so the detail screen's photograph gets drawn into a 104×64 thumbnail on the flight's first frame: the image re-fits, the corner snaps and a shadow appears before the card has moved. `CardHero` supplies its own shuttle, which interpolates all three. It also pins `createRectTween` to a straight `RectTween` — `MaterialApp` hands every unnamed hero a `MaterialRectArcTween`, which bows the card sideways and changes its proportion on the way, so deleting the arc is not enough to be rid of it. |
| 19 | `GhostStack` | Three `CardFace`-shaped skeletons at 40% opacity. Replaces every `CircularProgressIndicator`. |

### Phase 4 — capture

| # | Widget | Notes |
|---|---|---|
| 20 | `CaptureShell` | Forces `AppTheme.capture()` (always dark) via a nested `Theme`. |
| 21 | `EdgeBrackets` | Four corner brackets, 30px, 3px ochre, rounded outer corner. Two borders per `Container` — no `CustomPaint` needed. |
| 22 | `SweepLine` | `AnimatedPositioned` on a 1.6s loop with an ochre glow. **Stops once edges are detected**, or it reads as "still working". |
| 23 | `ShutterButton` | 78px ring, 62px ochre core, scales to 0.92 on press. |
| 24 | `NoteSheet` | Restyle of the existing `_NotePrompt` `showModalBottomSheet`, fired by **Save card** — not an inline composer. Keep its `emphasised` branch (vermilion pill + harder copy when extraction found little or nothing) and both exits: Save card commits, **Skip for now** pops `''` and the card still saves. Pad by `viewInsets.bottom`. |
| 25 | `SideChips` | `CardSidesView`'s Front/Back `ChoiceChip`s as ink/hairline chips, plus the Add back / Retake back / Remove back affordances. Keep it a two-state choice, **not** a `PageView`: a field highlight must never paint while the back is showing, and `card_fields` has no side column to make that safe. |
| 26 | `RegionHighlight` | The ochre box drawn over `card_fields.region_rect` when a field row is tapped. Wraps the existing `CardImageOverlay`. This is the mechanic that makes an extracted value checkable against the printing — the single most important thing on both capture review and card detail. |

### Phase 5 — detail, identity, maintenance

| # | Widget | Notes |
|---|---|---|
| 27 | `CardDetailScreen` | Pinned `CardSidesView` + scrolling column: title, note block, action pills, "On the card" field list, "Other text". Delete stays in the header and stays **soft** (`softDelete` + `identity.detach`). |
| 28 | `NoteBlock` | Card surface, ochre micro-caps — keep the existing label **"Why you saved this"** — and 15.5px ink body. |
| 29 | `ActionPills` | `_Actions` restyled from `ActionChip`. **Derived, not fixed:** Call needs a phone, WhatsApp needs `PhoneExtractor.isMobile` to pass, Email needs an email, Map needs an address. A landline wa.me link opens to an error, which reads as the app being broken. |
| 30 | `InitialsAvatar` | Radius 13, initials from the existing `contactInitials()` — it strips honorifics, so "Md. Abul Bashar Sarker" is A.S., not M.S. Tint from a **stable hash of the identity id**, never random, or the same person changes colour between builds. |
| 31 | `ContactsScreen` | One `ListView`, two count-labelled sections — people then companies — which is what the screen already builds. **No tabs, no letter grouping, no alphabet rail:** the filter field is the find mechanism and it filters both lists on name and subtitle at once. Companies get their own section because a card with a shop name but no legible person still leaves an organization worth reaching. |
| 31b | `ContactRow` | Restyle of `_PersonRow` / `_OrgRow`. The "N cards" chip renders **only when `person.cardCount > 1`** — on every row it is noise. People get `InitialsAvatar`; organizations get the storefront glyph, which is how the two row types stay distinguishable at a glance. |
| 31c | `DuplicateBanner` | Restyle of `_DuplicateBanner`, conditional on `duplicateCandidatesProvider` being non-empty. Keep the header icon as the permanent way in for the days it is empty — a feature that only appears when it has something to say is indistinguishable from one that is missing. |
| 32 | `RoleBlock` | One block per `RoleDetail`: org name, title, then its own endpoints. **This grouping is the feature** — the motivating case is a man whose watch shop and bank office have different numbers, and "which number do I use for this" is the actual question. Do not flatten it into one contact list. |
| 33 | `EndpointRow` | Restyle of `_EndpointRow`. Trailing actions are conditional the same way the pills are, so the caps read "Call · WhatsApp" only for a mobile. Used by Person, Role and Organization. |
| 34 | `CombinedRow` | Surfaces `mergedFrom` with its `unmerge` path. The merge prompt promises the user can separate them later; without this that sentence is false. |
| 35 | `CardStripRow` | Restyle of `CardStrip` — horizontal `WalletCard.aspectRatio` faces under "From these cards". Every fact above came off one of them, and going back to the paper is what makes an extracted value checkable. |
| 36 | `RepairRow` | Cap rail + face + title + state line + chevron. **Two states only**, off `card.status`: `ExtractionStatus.failed` → vermilion, "Nothing was read from this card"; otherwise ochre, "Only part of this card was read". No per-field guess, no dismiss — the row pushes to card detail, where the field list is the repair tool. |
| 37 | `RetryAllButton` | `_retryAll`, with progress in its own label. Keep it **sequential**: the recogniser is one native resource, and four concurrent full-res decodes is how you get OOM-killed on a 3 GB phone. |
| 38 | `DupeCardPair` | `DuplicateKind.card` — two photographs at the real `1.586` ratio, labelled Kept and Newer. Text cannot settle this one: both sides say the same thing, which is why they were flagged. The **older** scan survives, because it is the one that has been corrected, noted on, or found in a search. |
| 39 | `DupeRecordPair` | The person and organization kinds. **Every button label changes with the kind** — Same person / Different people, Same company / Different companies. Never collapse them into a generic "Merge". The ochre caps line is `'Matched on ' + pair.signals.join(' and ')`: it reports what was noticed, never a verdict, and never an invented reason. |
| 40 | `SettingRow` + `AppSwitch` | 46×28 switch: ink track when on with an ochre knob, pocket track when off with a paper knob. **Do not use `SwitchListTile`** — its Material thumb and ripple are the loudest giveaway in a bespoke app. |
| 41 | `OnboardingScreen` | Three panels. The fanned card stack is the entire illustration budget: three `Transform.rotate`d `Container`s, no assets, no Lottie. Panel two asks for the camera in plain words before the OS dialog fires; panel three scans one real card, so the first thing in the wallet is not a sample. |

---

## 4. Screen-by-screen deltas

Read alongside `design/screens.html`; frame numbers match. Every row below was
checked against the file it names.

| Frame | File | Change |
|---|---|---|
| 01, 02 | `search/presentation/home_screen.dart` | Header replaces `AppBar` + popup menu; `CardStack` replaces `ListView.separated`; scan pill replaces the FAB; results un-stack and gain a score bar. Keep `_delete`, `_restore`, the debounce and the `_DeleteReveal` — that logic is right. |
| 03 | `capture/presentation/capture_screen.dart` | Viewfinder is always dark; brackets + sweep. Sweep **stops** on edge detection. |
| 04 | same | Restyle only. The photo stays pinned and the fields scroll under it, because tapping a field boxes its region on the printing. Bottom bar stays equal halves, Retake and **Save card**. "Found on the card" / "Other text on the card" headings are the existing copy. |
| 04b | same, `_NotePrompt` | The note is a modal sheet fired by Save card — it is *already* structured this way, including the `emphasised` branch. Restyle; do not relocate. |
| 05 | `cards/presentation/card_detail_screen.dart` + `widgets/card_sides_view.dart` | Keep `CardSidesView` (Front/Back `ChoiceChip`s, Add/Retake/Remove back) and the region highlight. Note label stays "Why you saved this". `_Actions` → derived pill row. Delete stays in the header, stays soft. `unassignedText` → "Other text". |
| 06 | `contacts/presentation/contacts_screen.dart` | Restyle only, structure unchanged: filter field, conditional duplicate banner, then one list with "N people" and "N companies" sections. `contactInitials()` avatars for people, storefront glyph for companies, card-count chip only above 1. |
| 07 | `contacts/presentation/person_screen.dart` | One `RoleBlock` per `RoleDetail`; "Other" for `looseContacts`; `CardStrip` for `cardIds`; `CombinedRow` for `mergedFrom`. Header keeps Save to contacts + Share. **No per-field provenance** — the graph does not expose it. |
| 08 | `contacts/presentation/organization_screen.dart` | Website, Address (a *list* — `branches`), Contact (`Endpoints`), People here, From these cards. Each section conditional on its list. **No stat strip, no note aggregation** — the graph does not model org→notes. |
| 09 | `cards/presentation/needs_attention_screen.dart` | `RepairRow` (two states) + `RetryAllButton`. Recently deleted stays a section of this screen unless you take frame 10's proposal. |
| 10 | proposal, not a restyle | Pulling Recently deleted out of Needs attention. `deletedCardsProvider` moves across unchanged; it is a routing change, so keep the section in place until Settings exists to link to it. Restore also calls `identity.promote`; "Delete for good" keeps its confirm dialog — it is the one delete with no undo. **The 30-day line is aspirational**: nothing expires tombstones yet, so implement the sweep or cut the copy. |
| 11 | `contacts/presentation/duplicates_screen.dart` | `DupeCardPair` + `DupeRecordPair`. Three kinds, per-kind labels, signals-derived match line. |
| 12 | new screen | Grouped `SettingRow` blocks. Also the right home for Recently deleted, Duplicates and the OCR spike entry, which are currently in a home-screen popup menu. **Half of these rows are new preferences** — "Ask for a note every time", "Capture the back too", "Photo quality", "Larger type" have no backing store yet. Ship the screen with only the rows that already have state, and add the rest with their features. |
| 13 | (new) onboarding | Three panels, shown once. |
| 14 | everywhere | One `EmptyState` widget, four instances. Delete every `CircularProgressIndicator`. |
| 15 | — | Dark mode. Not an inversion: the pocket goes *darker* than the page, and ochre takes the primary button. Everything else keeps its light-mode geometry, so one widget tree serves both. |

---

## 5. Accessibility floor

- Body text is 14px minimum, at 4.5:1 against the surface behind it. `inkFaint`
  (#9C8F73) is for micro-caps metadata only — never body copy.
- Links and inline actions use `ochreInk` (#8A5A12), not `ochre` (#C8901A),
  which fails contrast on paper.
- Every tap target is 52px minimum, icon buttons included.
- The confidence dot needs a `Semantics(label: 'read clearly' | 'uncertain' |
  'not read')`. Colour alone is not the signal.
- `Larger type` in settings scales `AppText` sizes by 1.15; the serif display
  must be allowed to wrap to three lines when it does.
- Test at `textScaleFactor` 1.3. The stack pitch is the first thing to break —
  make `Gap.stackPitch` responsive to the resolved row height rather than
  constant if it does.

---

## 6. Logo

The mark is a business card with a folded corner and an R cut out of the face.
The R gives RecallOS a recognizable initial; the ochre dog-ear connects it to
saved context and the `CornerFold` used on cards with notes. The cutout is
transparent, so the same geometry works on paper, ink and themed launchers.

| File | Use |
|---|---|
| `recallos-mark.svg` | 32px and above, on paper |
| `recallos-mark-inverse.svg` | on ink |
| `recallos-lockup.svg` | mark + wordmark, splash and about |
| `recallos-appicon.svg` | icon source |
| `png/appicon-*.png` | 1024 / 512 / 192 / 180 / 120 / 48 |
| `png/mark-{light,dark}-*.png` | 512 / 256 / 96, transparent ground |

The wordmark is Archivo Bold, uppercase. Never set it in the
serif, and never sentence-case it in UI chrome — the app header shows
`RECALLOS` at 12px with 2.6 tracking.

Use 32px for in-app chrome so the R remains legible. Launcher exports are
generated individually at the sizes required by each platform.
