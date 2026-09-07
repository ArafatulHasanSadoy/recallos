# RecallOS — where the project stands, and what to do next

## Context

The previous plan (`look-at-chatgpt-github-project-shiny-starfish.md`) lives in
`~/.claude/plans/`, not in the repo — which is why it cannot be found from the
project. It is also out of date: everything it listed as "next" is now built,
and the largest body of work in the tree (the whole visual redesign) never
appears in it at all.

This document replaces it. Every claim below was checked against the code on
2026-09-07, not recalled.

**This file is kept up to date as work lands.** Anything marked ✅ DONE below
was built, tested and walked on the device — not planned.

### Done in this session (2026-09-07)

| # | Feature | Verified how |
|---|---|---|
| 8 | **Back-side OCR** | on the RMX3612: back read, 15 blocks, fields land labelled `BACK`, card flips to the side a field was read from |
| 10 | **Biometric lock** | code + 12 widget tests; the *unlock prompt* is unverified — this phone has no screen lock set (see below) |
| 11 | **Database encryption** | on the RMX3612: the live `recallos.sqlite` is ciphertext, all 7 real cards still open |

Plus two things found on the way and fixed: Android was **backing the whole
plaintext wallet up to Google Drive** (`allowBackup` defaults to on), and
`ocrEngineProvider` was being disposed and rebuilt per use despite its own
comment saying it should be held open.

### Interaction polish (2026-09-07)

- ✅ Card detail now uses one 420ms card expansion instead of competing with a
  horizontal page slide. The return animation works from the front or back and
  from wallet, search, contact, repair and duplicate-card entry points.
- ✅ Card detail receives the tapped preview on its first frame, so an uncached
  database read cannot intermittently remove the shared transition.
- ✅ Search is a deeper themed pocket with an ochre index rail and a visible
  lower wall. Opening a card clears search/filter focus so the keyboard does
  not return underneath the shrink-back animation.

**First step of any work here: copy this file into the repo** (`docs/PLAN.md`)
so it is version-controlled and findable. The plans directory is a scratch
space outside the project.

---

## 1. The urgent thing: nothing is committed

Last commit is `c632e66` (22 Aug). **48 files are uncommitted.** That is:

- Tier 3d — front/back capture
- The deletion fixes (both delete paths were destroying data; the detail-screen
  trash icon purged outright)
- The `youtube.com`-as-a-company fix, plus the silent org auto-merge it hid
- The field-editor modality fix
- The entire design system — theme, bundled fonts, ~40 components, 16 frames,
  Settings and Onboarding as new screens

387 tests pass, `flutter analyze` is clean. This should be committed in
reviewable chunks before anything else lands on top of it.

---

## 2. What is actually built

| From the old plan | State |
|---|---|
| Tier 0 — zero egress, release OCR fix | done, committed (`dd15615`) |
| Tier 1 — identity graph | done, committed (`6c2f97e`) |
| Tier 3a — needs-attention queue | done, **uncommitted** |
| Tier 3b — vCard + `share_plus` | done, **uncommitted** |
| Tier 3c — duplicate review + undo-able merge | done, **uncommitted** |
| Tier 3d — front/back capture (cheap version) | done, **uncommitted** |
| The redesign | not in the old plan; **uncommitted** |

The Tier 3b values call held: `flutter_contacts` was declined in favour of a
vCard + share sheet, so the manifest is still only CAMERA + RECORD_AUDIO.

---

## 3. What is missing — the table

Every row checked against the code on 2026-09-07. "Scaffolding" means the
table, enum or function exists but nothing in `lib/` touches it.

| # | Feature | State | Cost | Blocker / note |
|---|---|---|---|---|
| 1 | **OCR gate run** | never run | S | needs your hand-labelled `labels.json` |
| 2 | **Whole-library export** (JSON + VCF) | scaffolding | S | `buildVCards` exists at `vcard.dart:113`, no caller |
| 3 | **Interactions → ranking** | scaffolding | S | table written twice, never read; `previousUse` always 0 |
| 4 | **Tags + library filter** | scaffolding | S | tables dead; FTS `tags` column written as `''` |
| 5 | **Retention sweep** | absent | S | nothing compares `deletedAt` to a date |
| 6 | **My Card / self identity** | absent | M | no `isSelf` anywhere; needs a schema column |
| 7 | **QR sharing** | absent | S | `qr_flutter` not in pubspec; reuses `buildVCard` |
| 8 | **QR scanning** | absent | S | `mobile_scanner` not in pubspec |
| 9 | **Local analytics screen** | absent | S | depends on #3 |
| 10 | **Biometric lock** | ✅ **done** | — | `local_auth ^3.0.2`; `lock_gate.dart`, Settings → Privacy |
| 11 | **Database encryption** | ✅ **done** | — | SQLCipher via `pubspec` hooks; key in the Keystore; `encrypted_database.dart` |
| 12 | **Reminders** | absent | M | `flutter_local_notifications` not in pubspec |
| 13 | **`CardType` ever being set** | scaffolding | S | **blocks 14 and 15** — no card ever gets a type |
| 14 | **Coupon wallet** | absent | M | needs #13 |
| 15 | **Warranty vault** | absent | L | needs #13 |

Three of these are worse than the old plan implied — details below.

### 3b. The product-brief features (`ChatGPT-M CSE499 Project Product HQ`)

That brief lists 16 numbered features. Mapped against the code, most of the
hard half is already done — but the **first five** are the ones the brief's own
demo script (§26) opens with, and four of them collide with the offline
decision.

| Brief # | Feature | State in code | Note |
|---|---|---|---|
| 1 | User accounts | **absent** | needs a server — conflicts with zero-egress |
| 2 | Personal professional profile | **absent** | the local half of this is buildable offline |
| 3 | Digital business card ("My Card") | **absent** | = row 6 of the table above |
| 4 | QR sharing | **absent** | = row 7; `qr_flutter` over the existing `buildVCard` |
| 5 | Link sharing | **absent** | needs a public URL — genuinely online, defer |
| 6 | vCard / contact sharing | **done** | per-person and per-org; `contact_export.dart` |
| 7 | Visiting-card scanner | **done** | permission, preview, capture, review, retake |
| 8 | Front/back scanning | ✅ **done** | both sides read; `card_fields.side` + `ocr_blocks.side` (schema v8); front wins when both faces print the same value |
| 9 | OCR | **done** | on-device ML Kit; release-build bug fixed |
| 10 | Structured extraction | **done** | `card_extractor.dart` + validators |
| 11 | Human verification | **done** | review → correct → confirm, with provenance on every fact |
| 12 | Contact/card management | **done except tags** | notes yes, tags no (row 4 above) |
| 13 | Search and smart retrieval | **done (weakened)** | FTS + embeddings + hybrid rank, but `previousUse` never fires (row 3) and the FTS `tags` column is always empty (row 4) |
| 14 | Networking / contact memory | **partial** | the note carries the context; `people.relationship` and `people.photoPath` are declared and never written |
| 15 | Offers / coupons | **absent** | = row 14; blocked on row 13 (`CardType`) |
| 16 | Privacy and security | **strong, minus accounts** | zero-egress + SQLCipher at rest + a biometric lock + Android backup disabled. No accounts, by choice (see the collision below) |

**The collision worth deciding now.** The brief's §25 core loop begins
"Account/Profile → Digital Card → Share", and its §26 demo script opens with
"Create/login to an account". The old plan explicitly chose to stay offline and
reinterpret CO5 that way — which rules out #1 and #5 outright, and makes #2 a
*local* profile rather than an account.

That is defensible and arguably stronger, but it has to be **said out loud** in
the report rather than left as a gap, or it reads as three missing features.
The honest framing: a local profile plus QR and vCard covers the intent of
#1–#6 without a server, and the zero-egress guarantee is what pays for it.
Deciding this changes what gets built next, so it should be settled with your
supervisor before Step 4.

**Dead data layers.** Tables and enums exist that nothing touches:

- `tags` / `subject_tags` (`lib/core/db/tables.dart:369-382`) — zero reads,
  zero writes. The FTS5 index even has a `tags` column, written as a literal
  empty string on every index (`search_repository.dart:123-127`).
- `CardType` (`lib/core/db/enums.dart:44-53`) — **no value is ever set.** The
  column always holds `unknown`; the sole card insert omits it entirely
  (`card_repository.dart:149-152`). All ten variants, `warrantyCard` and
  `coupon` included, are dead. Tier 5 cannot start without a type-setting path.

**A ranking signal that never fires.** `interactions` is written in only two
places, both in `card_repository.dart` — `scanned` at `:376` (inside `addNote`,
which returns early on an empty note, so a card saved without one logs
*nothing*) and `edited` at `:787`. Nothing ever reads the table. The
`previousUse` term in `utility_score.dart:36` is never supplied, so it silently
defaults to 0 — the ranking advertises a signal it does not use.

**Export is single-subject only.** vCard 3.0, one person or one org at a time
(`contact_export.dart:68,116`). `buildVCards(Iterable)` — the multi-contact
primitive — already exists at `vcard.dart:113` and **has no caller in `lib/`**.
No JSON, no CSV, no whole-library export, no export row in Settings.

**No retention sweep.** Soft-deleted cards and their full-size JPEGs persist
indefinitely. Nothing compares `deletedAt` against a date anywhere. I removed
the "kept for 30 days" copy rather than claim something untrue, so the app is
honest — but this is a debt I introduced by making both delete paths soft.

**Absent entirely:** "My Card" / self identity, QR sharing, QR scanning,
reminders, biometric lock, database encryption. None of `qr_flutter`,
`mobile_scanner`, `flutter_local_notifications`, `local_auth`,
`flutter_secure_storage` are in `pubspec.yaml`. (`sqlcipher_flutter_libs`
appears in `pubspec.lock` only as a transitive dep of `drift_flutter`; the
database is opened unencrypted at `database.dart:54`.)

---

## 4. The OCR gate has never been run

`README.md:20` still admits this, and the old plan called for it "throughout".
It is the gate the entire extraction claim rests on, and there is no evidence
behind it: **no `results.json` or `labels.json` is committed anywhere.**

The machinery is complete and reachable:

- Settings → "OCR spike" → `/spike` (`router.dart:78`)
- `spike_screen.dart:62` picks images with `ImagePicker.pickMultiImage()`
- `_export()` (`:92`) writes `spike_results.json` to the app documents
  directory and copies the path to the clipboard for `adb pull`
- `spike_runner.dart` is complete — no stubs
- `tool/spike/score.dart` grades `<results.json> <labels.json>` and buckets by
  script (`latin` / `bengali` / `mixed`), which is the whole point: an average
  across both hides what the gate needs to show

Three stale details to fix while in there: the screen says "3 engines"
(`spike_screen.dart:70`) but `SpikeRunner.engines` returns 2
(`spike_runner.dart:87`); the availability banner points at
`assets/tessdata/README.md` (`:214`), which does not exist; and
`assets/tessdata_config.json` is a tracked orphan referenced from nowhere.

**This needs you for one step.** I can run the spike on the RMX3612, pull the
results and do the scoring. I cannot write `labels.json` — that is the
hand-labelled ground truth for your cards, and inventing it would defeat the
gate. You have 6 cards in the app already; the plan's target was 5–10.

---

## 5. Recommended order

### Step 1 — Commit, and put this plan in the repo

Yours to do. Suggested split: design system; front/back capture; the three
correctness fixes (deletion, identity/domain, editor modality); then the three
built on 2026-09-07 — back-side OCR (schema v8), the biometric lock, and
SQLCipher encryption.

**One thing to do on the phone first**, before or just after committing: the
lock cannot be armed because this device has **no screen lock set at all**
(`adb shell locksettings get-disabled` → `true`). Set a PIN or fingerprint in
Android Settings, and the "Lock the wallet" switch in RecallOS becomes usable.
Until then the row correctly greys itself out and says why — which is verified,
but the unlock prompt itself has never run on hardware.

### Step 2 — Run the OCR gate

Highest value per hour and the only item with academic weight. It is also the
one thing that could invalidate later work: if extraction scores badly on real
Bangladeshi cards, the priority becomes extraction, not features.

1. Fix the three stale details above.
2. Build **release** (a green debug run says nothing about the artifact — this
   is exactly how the R8 registrar bug hid), install, run the spike over your
   cards, `adb pull` the results.
3. You hand-label `labels.json`; I score it and report `n` honestly.
4. Update `README.md:20` with the real numbers.

### Step 3 — Table rows 2–5, the cheap ones

Each is small, and each fixes something currently broken or dishonest rather
than merely adding surface:

- **#2 Whole-library export** — `buildVCards` already exists and is unused; add
  a JSON sidecar and a Settings row. Covers most of the "cloud backup" intent
  offline.
- **#3 Interactions → ranking** — write `viewed` / `called` / `messaged` on the
  actions that already exist, then feed `previousUse` into `utility_score`.
  Makes the ranking do what it says.
- **#4 Tags + library filter** — the tables exist and the FTS column is already
  reserved, so tagging improves search as well as browsing.
- **#5 Retention sweep** — purge soft-deleted cards older than N days on
  launch, which lets the "kept for N days" copy from frame 10 be true.

**#13 `CardType` belongs here too** if Tier 5 is anywhere on the horizon — it
is a small change now and a blocker later.

### Step 4 — Then choose a direction

Settle the accounts question (§3b) first, because it decides the first option
below.

- **Close the demo script** — brief #2, #3, #4 = rows 6, 7, 8 here: local
  profile → My Card → QR sharing → QR scanning. This is the highest-value
  direction for the supervisor demo, because it is the part of §26 that
  currently has nothing behind it, and all four come off the one vCard
  serialiser already written and tested.
- ~~**Depth on privacy** — brief #16 = rows 10, 11.~~ ✅ **Done 2026-09-07.**
  The lock and SQLCipher both landed, and Android's backup of the plaintext
  wallet was switched off — which was the largest hole in the zero-egress
  claim and nobody had noticed it.
- ~~**Finish #8 properly** — OCR the back.~~ ✅ **Done 2026-09-07.** Schema v8
  added `card_fields.side` and `ocr_blocks.side`; extraction is scoped per
  side; a highlight paints only on the side it was measured against and turns
  the card over to get there.
- **Tier 5** — brief #15 = rows 14, 15: coupon wallet then warranty vault. Both
  blocked on row 13, so budget that first.
- Row 12 (reminders) and row 9 (analytics screen) fit either direction; row 9
  is nearly free once row 3 is done.

Every new package needs `aapt dump permissions` on the release APK and a
re-read of the manifest-merger report afterwards. That is how the ML Kit
`INTERNET` transitive was caught. Done for the three added on 2026-09-07
(`local_auth`, `flutter_secure_storage`, `sqlite3`): the merged manifest gained
`USE_BIOMETRIC` and `USE_FINGERPRINT` and still carries **no `INTERNET`**.

---

## 6. Verification

Unchanged from the old plan, and it has been holding:

- `flutter analyze` clean and `flutter test` green before anything is reported
  done.
- Pure functions unit-tested in `test/core/` style.
- **Every UI change checked on the RMX3612** via `adb exec-out screencap -p`,
  cropped with `tool/devcrop/` where the detail is too small to judge. Four
  bugs this session rendered correctly, passed every test, and were wrong only
  on the phone.
- `aapt dump permissions` after each new package.
- Airplane-mode run of the whole thread — scan → correct → note → search → act
  — as the demo evidence.
- **Back up the phone's database before any migration runs**, with
  `adb exec-out "run-as com.recallos.recallos cat app_flutter/recallos.sqlite"`.
  Done before the encryption migration touched the real wallet on 2026-09-07;
  the copy is what made it safe to let a one-way conversion run over seven real
  cards. Note it only works on a *debug* build — `run-as` refuses a release
  one, so take the copy before installing release.
