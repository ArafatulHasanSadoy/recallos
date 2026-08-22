# RecallOS

An offline-first, zero-egress personal commerce memory system.

Scan a card. Say why it mattered. Find it later by describing the need rather
than the name. Everything — OCR, inference, search — runs on the phone. Nothing
is uploaded, because there is no server to upload to.

> **People remember the *need*, not the *name*.** Existing scanners digitise
> contact details. RecallOS keeps the context: which of his three businesses was
> relevant, whether the price was fair, whether delivery was late.

Full design and phasing: `~/.claude/plans/look-at-the-md-parallel-crab.md`.
Background research: `ChatGPT-CSE499A Senior Project Guide.md`.

## Status

Phase 0 complete, plus the embedding layer and the identity graph. Scaffold,
database, extraction, OCR, embeddings, hybrid ranking and contacts are in
place; both platforms build release. 260 tests pass. **The Phase 0 OCR gate has
not been run against real cards yet** — that is the next step.

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
| Android arm64 APK | **39.8 MB** |
| Android armeabi-v7a (older 32-bit phones) | **32.8 MB** |
| iOS `Runner.app` | 79.7 MB |

Of the Android download: 11.1 MB Flutter engine, 10.6 MB ML Kit OCR model,
7.3 MB embedding table, 4.8 MB app code.

Judge dependency weight on **release** builds. The debug fat APK is 194 MB
because it carries three ABIs unminified — `flutter_local_ai` looks enormous
there and costs 0.7 MB once tree-shaken.

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
2. Open the app, tap the flask icon, pick the cards, let it run.
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
    db/            Drift schema — identity graph, provenance, OCR recovery
    intelligence/  OcrEngine + TextIntelligence interfaces, and engines/
    extraction/    Deterministic field extraction, validators, metrics
    theme/
  features/
    capture/ cards/ contacts/ search/
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

**Generation — flagship only.** Apple Foundation Models on iOS, Gemini Nano via
ML Kit GenAI on Android, through `flutter_local_ai`. Neither platform exposes an
embedding API, which is why the half above is ours. Availability is narrow —
Pixel 9/10, Galaxy S25/S26, iPhones new enough for iOS 26 — so
`DeterministicIntelligence` is not a stub but the path most devices actually
take. Only drafted messages are lost without it.

The two compose: `StaticEmbeddingIntelligence(inner: PlatformIntelligence(...))`.

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
- **`minSdk 26`** — ML Kit GenAI's floor. Android 8.0 shipped in 2017, so
  coverage is effectively total.

## Testing

```bash
flutter test
flutter analyze
```

260 tests. **Run the OCR gate against a release build, not a debug one.**
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
