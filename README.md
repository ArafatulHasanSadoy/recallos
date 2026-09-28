# RecallOS

An offline-first, zero-egress personal commerce memory system.

Scan a card. Say why it mattered. Find it later by describing the need rather
than the name. Hand over one of your own without printing anything. Everything —
OCR, inference, search — runs on the phone. Nothing is uploaded, because there
is no server to upload to.

> **People remember the *need*, not the *name*.** Existing scanners digitise
> contact details. RecallOS keeps the context: which of his three businesses was
> relevant, whether the price was fair, whether delivery was late.

Full design and phasing: [`docs/PLAN.md`](docs/PLAN.md).
Background research: `ChatGPT-CSE499A Senior Project Guide.md`.

## Status

A working app, not a scaffold. Scan a card, correct what was read, write why it
mattered, find it later by need, hand a contact on to somebody else — that whole
thread runs on a phone today, and so does your own card.

Built and on the device: capture (front *and* back, both read), OCR, field
extraction with validators, human correction, the identity graph, hybrid search,
contacts, duplicate review, a full wallet export, a bespoke design system across
every screen, first-run onboarding, a biometric lock, a SQLCipher-encrypted
database, and the user's own profile and digital card. Both platforms build
release. 474 tests pass.

**The Phase 0 OCR gate has still not been run against real cards.** It is the
one thing that could invalidate work already done, and it stays the next step.

Scope is **Latin script only**. Bangla and Banglish are deferred; see
[Language scope](#language-scope).

## Setup

No model downloads, no API keys, no accounts. The embedding assets are committed.

```bash
flutter pub get
dart run build_runner build          # Drift schema
flutter test
flutter run
```

Regenerating the embedding assets (only needed when changing models):

```bash
python3 -m venv .venv && .venv/bin/pip install model2vec numpy
.venv/bin/python tool/embeddings/export_potion.py
```

## Size

Measured release builds, not estimates:

| | |
|---|---|
| Android arm64 APK | **47.1 MB** |
| Android armeabi-v7a (older 32-bit phones) | **39.7 MB** |
| iOS `Runner.app` | 79.7 MB — measured before encryption landed, not since |

Of the arm64 download: 11.0 MB Flutter engine, 10.6 MB ML Kit OCR model,
7.7 MB app code, 7.3 MB embedding table, 4.8 MB SQLCipher.

That is up about 7 MB from before the database was encrypted, and SQLCipher is
almost all of it: it replaces the plain SQLite build rather than sitting beside
it, and brings its own crypto. The biometric lock and the Keystore binding cost
well under a megabyte between them.

Judge dependency weight on **release** builds. The debug fat APK is 194 MB
because it carries three ABIs unminified, and a package that looks enormous
there can cost well under a megabyte once tree-shaken.

## Language scope

**No mainstream on-device OCR engine reads Bengali.** Not ML Kit (Latin,
Chinese, Devanagari, Japanese, Korean), not Apple Vision, not PaddleOCR PP-OCRv5
across all 106 of its languages. Tesseract is the only one that does, and both
of its Flutter bindings are unmaintained and fail to build on a current
toolchain — one calls `jcenter()`, the other declares its plugin class twice.
Making it work cost a vendored fork, a Gradle 8 downgrade, and a 414 MB binary
framework. It was removed.

Two things soften this. Phone numbers, emails and websites are written in Latin
on essentially every Bangladeshi card, so the highest-value fields still extract
from an otherwise all-Bengali card. And unreadable Bengali regions fall back to
image-crop-as-field-value, so the card still looks right and stays searchable
through its note.

Bengali returns as a second `OcrEngine` registered with `RoutedOcrEngine` — the
routing seam is built and tested for exactly that.

## The Phase 0 gate

Nothing else should be built until this is answered.

1. Collect ~30 real cards — English and mixed-script.
2. Run a **debug** build (`flutter run`) — the spike is developer
   scaffolding and is compiled out of release builds. Settings →
   Development → OCR spike, pick the cards, let it run.
3. Export the results JSON. Pull it off the device.
4. Hand-label ground truth (format documented at the top of `tool/spike/score.dart`).
5. Score it:

```bash
dart run tool/spike/score.dart spike_results.json labels.json
```

The scorer reports per-field precision, recall and F1, character error rate, and
latency. The point of a gate is that scope decisions get made in week one rather
than week four.

## Architecture

```
lib/
  core/
    db/            Drift schema — identity graph, provenance, OCR recovery,
                   and SQLCipher at rest
    intelligence/  OcrEngine + TextIntelligence interfaces, and engines/
    extraction/    Deterministic field extraction, validators, metrics
    identity/      Matching and similarity rules, pure and testable
    imaging/       Card and portrait preparation, Flutter-free so it isolates
    search/        RRF fusion and the utility score
    export/        vCard serialisation
    theme/ ui/     The design system and every primitive built on it
  features/
    capture/ cards/ contacts/ search/ settings/ profile/
docs/              PLAN.md, RELEASE.md, the privacy policy
design/            DESIGN.md, BRAND.md, screens.html (16 frames)
tool/spike/        Offline scorer for the Phase 0 gate
```

### Intelligence

Split deliberately in two, because the two halves have very different hardware
requirements.

**Embeddings — every device.** Model2Vec `potion-base-8M`, implemented in pure
Dart (`lib/core/intelligence/embedding/`). It is a distilled lookup table, not a
network: tokenise, look up each token's row, average, normalise. No forward
pass, no native code, no download.

| | |
|---|---|
| Size | 7.3 MB int8, 29,528 × 256 |
| Latency | **25 µs** per embedding, measured |
| Load | 3 ms — mapped as a typed-data view, never copied |
| Quality | MTEB 51.32, ~92% of all-MiniLM-L6-v2 |
| Quantisation loss | worst-case cosine 0.99994 vs float32 |

So a 3 GB Android 11 phone gets the same retrieval quality as a Pixel 10. That
is the whole point — semantic search is not tiered by hardware.

**No generative model.** An adapter for the phone's own language model
(Gemini Nano on Android, Apple Foundation Models on iOS) was written and never
connected to anything, so it was removed rather than left to be described as a
feature. Availability was narrow in any case — recent flagships only — and
neither platform exposes embeddings, which is why the half above is ours.
Classification rules live in `DeterministicIntelligence`; nothing in the app
generates text. If generation returns, it comes back behind a measured use.

The two compose: `StaticEmbeddingIntelligence(inner: DeterministicIntelligence())`.

### Retrieval

FTS5/BM25 and vector cosine run as two arms, fused by Reciprocal Rank Fusion
(`lib/core/search/fusion.dart`), then scored by a pure-function utility formula
(`utility_score.dart`) whose weights live in the database so they can be tuned
against labelled queries.

Ranks are fused rather than scores because BM25 is unbounded and cosine sits in
[-1, 1] — normalising them against each other would need per-query calibration.
No vector index: a personal corpus is a few thousand 256-dim vectors, and brute
force in Dart is about a millisecond.

Three ideas carry most of the design:

**Save-first.** The card row and image are written to disk *before* OCR runs.
Crash, dead battery, missing model, OCR timeout — the card survives.
Extraction failure must never mean a lost card.

**The note is the real fallback.** Every competitor's answer to failed OCR is
"type it in yourself." Ours is the note: a card with *zero* extracted fields but
a note saying "cheap t-shirt printer from CSE fest" is still fully retrievable
by need. So on total failure the app asks *"Why are you saving this?"* rather
than showing an empty form.

**Provenance on every fact.** `printed | user | ai_inferred | outdated`. An AI
guess never gets displayed as though it were printed on the card.

**Your own card is the one that was never printed.** Every other card in the
wallet is a photograph of a piece of paper. Yours is typeset in the app's own
faces — same warm paper, same ochre corner fold, same proportions — and that
contrast is the point. It carries one line the others do not: *what should they
remember you for?* — the mirror of the note you write about everybody else, and
it travels into their address book as the vCard `NOTE`, so the thing you wanted
remembered is the thing that survives the exchange.

It shares the vCard serialiser with every other export, so the same card reaches
Contacts through `ACTION_VIEW` and WhatsApp through `ACTION_SEND` with no
address-book permission on either path.

## Engine boundaries

`OcrEngine` and `TextIntelligence` (`lib/core/intelligence/`) were defined before
any implementation existed, and the seam has already paid for itself twice.
Dropping Tesseract touched one file and one registration — nothing downstream
knew. Losing embeddings meant `embed()` throwing a typed `IntelligenceUnavailable`
that callers already handled, rather than a redesign.

A Bengali engine, a cloud engine, or an on-device embedding model all drop in
behind the same two interfaces. That also buys a free experiment: run two
implementations over the same dataset and report the difference.

## Deliberate constraints

- **No `INTERNET` permission in the Android release build.** Zero-egress is
  something the OS enforces rather than something a privacy policy claims.
  Check it, do not take it on trust:

  ```bash
  aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
  ```

  Omitting the permission from `AndroidManifest.xml` was not enough on its own,
  and for several months this file claimed something the shipped APK did not
  do. ML Kit pulls in Google's telemetry transport, which declares `INTERNET`
  and merges it in; the permission is now explicitly removed with
  `tools:node="remove"`. **Debug builds keep it** — the Dart VM service needs it
  for hot reload — so the guarantee is a property of release builds, which is
  what ships.

  Two honest limits. The permission constrains *this app's process*: the ML Kit
  document scanner runs inside Google Play Services, so what that component
  does with a card image is governed by Play Services, not by this manifest.
  And it returns in Stage 2, when sync arrives.
- **Deterministic extraction, not an LLM, for phone/email/URL/name.** Small
  on-device models are markedly worse than a regex at this, and far slower.
  Benchmarks put 1B-model structured extraction around 10% flawless.
- **No vector index.** A personal corpus is hundreds to low thousands of rows;
  brute-force cosine in Dart is about a millisecond, and an index would be a
  build step to keep in sync for no gain.
- **Pure Dart embeddings, not the `model2vec` pub package.** The package
  compiles a Rust core through Native Assets, so every build machine would need
  `rustup`. A WordPiece tokeniser and a matrix reader are ~250 lines, and
  correctness is pinned by a parity test against the Python reference.
- **The wallet is encrypted at rest, and the key never leaves the phone.**
  SQLCipher rather than plain SQLite, selected by a `hooks:` block in
  `pubspec.yaml`; the key is 32 random bytes generated on the device and held in
  the Android Keystore. Existing plaintext wallets are converted in place, and
  the migration only swaps the encrypted copy in after verifying it opens and
  holds every row. The card photographs are sealed separately
  (ChaCha20-Poly1305, their own Keystore key — `lib/core/imaging/photo_vault.dart`),
  and photographs from before that change are converted in place at launch.
  OCR reads a short-lived plain copy in the app's private cache, deleted as soon
  as recognition returns.

  On a build without SQLCipher, `PRAGMA key` is silently ignored rather than
  failing — so the app checks `PRAGMA cipher_version` at startup and Settings
  reports what it actually found, not what it intended.
- **Android's own backup is switched off.** It defaults to *on*, which meant the
  whole wallet was being copied to the user's Google Drive by the OS — in an app
  built without permission to reach the network. `allowBackup="false"` plus
  `dataExtractionRules`, because Android 12+ reads the latter. It is also what
  keeps the key and the database together: the Keystore does not travel, so a
  restored ciphertext file would arrive permanently unreadable.
- **A lock in front of the wallet, and a control that never does nothing.** The
  biometric prompt is the OS's; what comes back is a boolean. On a phone with no
  screen lock the row does not render a dead switch — it renders a way to
  Android's security settings, and re-checks when the app comes back.
- **Your own card is authored data, and lives apart from the identity graph.**
  `people`, `organizations` and `roles` are *derived*: rebuilt from scanned cards
  by `promote`, matched on shared endpoints, collected when no card holds them
  up. A self-row inside `people` would have to be excluded from seven of those
  mechanisms, each failing silently — including the sweep that deletes anyone
  whose name does not read like one. Schema v9 gives it `profiles` and
  `profile_fields` of its own.
- **Both sides of a card are read, and a region remembers which side it came
  from.** This was once front-only, because `card_fields` and `ocr_blocks`
  recorded a `region_rect` in one image's pixel space with no column saying
  which side it belonged to — so a value read from the back would have
  highlighted a box on the front, silently, on the one screen whose job is
  letting you check a value against the printing. Schema v8 added
  `card_fields.side` and `ocr_blocks.side`, and extraction is now scoped per
  side: a highlight paints only while its own side is showing, and asking for
  one turns the card over. Where both faces print the same value, the front
  wins.

- **`minSdk 26`** — originally ML Kit GenAI's floor; kept after that package
  was removed, since every device check has run on 26+. Android 8.0 shipped in
  2017, so coverage is effectively total.

## Testing

```bash
flutter test
flutter analyze
```

474 tests. **Run the OCR gate against a release build, not a debug one.**
Minification is not cosmetic here: R8 renamed ML Kit's component registrars,
which are looked up reflectively by name, and OCR returned zero blocks in
release while working perfectly in debug — silently, with no error surfaced to
the app. `proguard-rules.pro` keeps them now. A green debug run says nothing
about the artifact you hand someone.

The valuable ones are in `test/core/`: phone normalisation against
the BTRC numbering plan, Bengali-Latin digit confusables (kept — Bengali
numerals still appear on Latin-script cards), cross-field sanity checks, the
identity-graph case of one person holding three roles with a different number
for each, the no-model intelligence path, and RRF behaviour when one arm returns
nothing.

The most important single test is **embedding parity**: `export_potion.py` emits
20 sample strings with the tokens, ids and vectors Python produced, and
`embedding_test.dart` replays them through the Dart port. A hand-written
tokeniser that diverges from the one that produced the vectors would degrade
rankings silently — this makes it fail loudly instead.

Note that `analysis_options.yaml` excludes `*.g.dart`, so generated-code errors
surface at `flutter test`, not `flutter analyze`. Run both.
