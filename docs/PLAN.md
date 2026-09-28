# RecallOS — where the project stands, and the CSE499B plan

**This file is the live plan and is kept up to date as work lands.** A row marked
✅ was built, tested and walked on the phone; nothing is marked done because it
was planned. Every claim below was re-checked against the code on 2026-09-28.

**2026-09-29:** reviewed against *RecallOS CSE499B Master Plan v1.0* (a
separate 37-page plan written from the GitHub snapshot). Three decisions came
out of it and are applied below: sell the people workflow first (Release A),
verify the first purchase on the phone so `INTERNET` stays out, and tag
`b48d429` as `cse499b-start`.

Pricing, revenue and competitor strategy are deliberately **not** here: this repo
is public and `docs/` is served on GitHub Pages. They live in the gitignored
`business/` folder.

---

## 1. Where things stand (2026-09-28)

### Repository state

- Last commit: `b48d429` "Prepare the Play Store release surface" (2026-09-08),
  level with `origin/main`.
- **Uncommitted since 2026-09-08:** the profile / My Card feature
  (`lib/features/profile/`, `lib/core/imaging/portrait_image.dart`, schema v9
  with `profiles` + `profile_fields`, `describeFieldIssue`, four new test files).
- `flutter analyze`: clean. `flutter test`: **580 pass** (2026-09-29, after
  F1–F4; 444 at the 499A baseline `b48d429`).
- **Starting point:** `b48d429` (the last pushed commit) is to be tagged
  `cse499b-start`. Everything after it — the profile work included — is 499B
  work, so nothing uncommitted has to be split to draw the line. See §8.
- **CI** exists from 2026-09-28 (`.github/workflows/ci.yml`) but has not run on
  GitHub yet: it runs on the first push.

### What 499A built ✅

| Area | What exists |
|---|---|
| Capture | Camera or gallery through the ML Kit document scanner; save-first (photo + row written before OCR); front **and back** read, `card_fields.side` / `ocr_blocks.side` (schema v8) |
| Understanding | On-device ML Kit OCR (Latin); `card_extractor.dart` with BD phone rules, web/email validators; provenance on every fact (`FactSource`), confidence dot, side-aware highlight of where a field was read |
| Review | Edit, relabel, tap an OCR block to assign it, retry-all queue for cards that need attention |
| People | Identity graph (people, organisations, roles, contact points); platform domains never become a company; duplicate review with pointer-based, undoable merges |
| Search | FTS5 + on-device Model2Vec embeddings + reciprocal-rank fusion + utility scoring, with a "why this matched" label |
| Acting | Call, WhatsApp (mobiles only), email, map; vCard save and share without a contacts permission |
| Privacy | No `INTERNET` in release; SQLCipher database with the key in the Keystore; biometric / device-credential lock; Android backup off |
| Data | "Take a copy" — one zip with `contacts.vcf`, `wallet.json`, `photos/` (plaintext, export only) |
| Profile (uncommitted) | Personal profile, typeset "My Card", handed over as a vCard |
| Look | The wallet design system, bundled fonts, dark mode, onboarding, brand icons |
| Release | Upload-key signing config, `.aab` verified once, privacy policy live at `https://arafatulhasansadoy.github.io/recallos/privacy-policy.html` |

**A decision worth keeping.** The profile got its own tables (schema v9) rather
than an `isSelf` row in `people`. A self-row would have had to be excluded from
seven separate mechanisms, and two of them — `_dropImplausiblePeople` (deletes
names that fail `looksLikePersonName`) and `_syncPersonName` (overwrites a name
from OCR) — are correct for derived data and destructive for authored data.

### Known defects

- [ ] **B1** Profile work uncommitted and `cse499b-start` not tagged — tests are green; the tag and commits are the owner's (§8).
- [x] ✅ **B2** "Take a copy" no longer writes the search index into `wallet.json`. The
  exporter asks `pragma_table_list` which tables are real rather than guessing
  from names (it looked for `*_fts`; the index is `search_index`). The test now
  finds virtual tables by how they were created, not with the exporter's own filter.
- [x] ✅ **B3** Profile portraits no longer leak: Save deletes the one it replaced
  or removed, the editor deletes a pick it never saved, and the retention sweep
  clears older orphans.
- [x] ✅ **B4** Notes can be added, corrected or cleared after saving — tap the
  "Why you saved this" block on a card; the card is re-indexed so search finds
  the new words. Walked on the RMX3612.
- [x] ✅ **B5** `flutter_local_ai` and the unused `PlatformIntelligence` removed
  (25 transitive packages went with it, `audioplayers` and `video_player`
  among them); the AICore permission is gone from the bundle; README and
  privacy policy no longer describe a language model.
- [x] ✅ **B6** Uninstalling no longer has to destroy the wallet: an encrypted
  backup restores it on any phone (F3).
- [x] ✅ **B7** Card photos, thumbnails and the portrait are encrypted at rest (F4).
- [ ] **B8** Scaffolding nothing uses: `CardType` never set; `tags` / `subject_tags` never read or
  written (FTS `tags` column written as `''`); `interactions` read by nothing, so `previousUse` is always 0;
  `search_queries` / `search_feedback` have no writers.
- [ ] **B9** The OCR evaluation has never been run. (The spike's stale "3 engines"
  text, dead `tessdata/README.md` pointer and orphan `tessdata_config.json` are
  fixed; the run itself needs labelled cards.)
- [x] ✅ Capture uses the shared `ocrEngineProvider` instead of building its own recogniser.
- [x] ✅ Retention sweep: Recently deleted keeps a card 30 days, then purges it
  at launch through the same steps as "Delete for good".
- [x] ✅ **A reformatted phone number read as a guess** (found 2026-09-28, fixed
  2026-09-29): `+880 1711-223344` shown as `01711223344` was labelled "digit
  restored" and sent for review. Only a digit the card never printed counts now
  (`PhoneExtractor.restoresDigit`), and labels already stored are re-judged
  once at launch from their OCR text (`repairDigitRestoredLabels`). Written in
  a separate session and ported in; verified in the release build, where both
  new scans show "On the card".
- [x] ✅ **The scan button covered search answers** (found on the phone
  2026-09-29): with the keyboard up, the pinned "Scan a card" pill sat on top
  of the result being typed for. It stands aside while the keyboard is up; a
  widget test fails without the change.
- [x] ✅ **Deleted cards took search slots** (confirmed 2026-09-29, fixed the
  same day): both arms now exclude deleted cards *before* their limits. A test
  with 40 deleted cards outranking one live card returned **nothing** on the
  old code and returns the live card now.
- [x] ✅ **Open search results went stale** (found on the phone 2026-09-29): a
  card deleted from its own screen stayed in the results until the next
  keystroke, and a restore or note edit did not show either. Results now
  re-run when `cards`, `card_fields`, `notes` or `embeddings` change
  (`SearchRepository.watchChanges`). Three widget tests fail with the refresh
  off and pass with it on.
- [x] ✅ **Release builds refuse the debug key** (2026-09-29): without
  `android/key.properties` the signing task fails and says why;
  `RECALLOS_ALLOW_DEBUG_SIGNING=true` opts in for builds that are never
  uploaded (CI sets it). Pinned in `release_surface_test.dart`.

---

## 2. The CSE499B thesis

**Product.** RecallOS is a privacy-first memory for **people** and **important
things**. It captures business cards, receipts and warranties (tickets and IDs
next), turns them into verified, linked facts, reminds you before something
matters, and answers questions with the sources attached — *Ask RecallOS*.

**Direction change from 499A, stated plainly.** 499A was a business-card
wallet. The owner's second prototype, Smart Wallet (`groky-wallet`: receipts,
warranties, coupons, tickets, IDs, reminders), is being folded into RecallOS as
its ideas and rules — not its code; the stacks differ. Only RecallOS will be
published.

**Offline core, optional online.** Everything above works without an account or
a network. Online features (an end-to-end-encrypted cloud backup first) are
opt-in and come after the offline Must list.

**Research question.** Does source-aware hybrid retrieval — keyword + semantic +
structured — answer real personal-memory questions better than keyword search?
Measured, not claimed.

## 3. What "done" means — three stories

499B is done when all three run end to end on a **release** build on the
RMX3612, in airplane mode:

1. **Person.** Scan a card → note "esports sponsorship" → WhatsApp intro the user
   edits and sends → follow-up reminder → later, "Who was interested in
   sponsorship?" returns that person with the source.
2. **Purchase.** Scan a laptop receipt, then its warranty → RecallOS suggests
   they belong together; the user confirms → the expiry is derived and labelled
   *derived* → a reminder is scheduled → "When does my laptop warranty expire?"
   answers with both documents cited.
3. **Memory.** "How much did I spend on electronics this month?" (a database sum,
   receipts cited) and "What expires in the next 90 days?".

## 4. Scope — three releases

The order comes from the Master Plan review: earn on the people workflow, which
sits on code that already works, *before* the riskiest change (the schema
generalisation). Sizes: S ≤ 1 day, M 2–4 days, L 1–2 weeks.

### Foundation

- [x] ✅ **F1. Baseline freeze** (2026-09-28) — B2–B5 and the capture-engine fix;
  30-day retention sweep; Settings → About (version + commit, tap to copy;
  feedback email with the build filled in; privacy policy); CI
  (`.github/workflows/ci.yml` + `tool/ci/check_permissions.sh`, which reads the
  built bundle); the benchmark flag (`lib/core/build_flags.dart`). 25 new tests.
  **Verified on the RMX3612 with the release bundle:** About rows, the commit
  stamp, copy-to-clipboard, OCR under R8 (5 fields read), skip-then-add note,
  search by the new note. Bundle permissions: CAMERA, USE_BIOMETRIC,
  USE_FINGERPRINT, the app's receiver permission — nothing else; every native
  library 16 KB-aligned (zip and ELF).
- [x] ✅ **F2. Search and signing fixes** (2026-09-29) — deleted cards out of
  search candidates; open results refresh when the data changes; release
  builds refuse the debug key unless explicitly allowed. 504 tests pass.
  **Verified on the RMX3612, release bundle:** search finds the live card;
  deleted, it shows "Nothing matched"; restored from Recently deleted, it
  reappears in the open results without retyping; deleted from its own
  screen, it leaves the results at once. A keyless release build fails with
  the message; with the opt-in it builds and carries the same four
  permissions.
- [x] ✅ **F3. Encrypted, versioned backup and restore** (2026-09-29) — its own format,
  separate from the plaintext export: authenticated manifest, stable IDs,
  schema/export versions, encrypted assets with digests; no FTS shadows,
  embeddings or entitlements inside. Restore **replaces** (never merges):
  preview counts, keep a copy of the current vault, validate before touching
  anything, journalled swap that resumes or rolls back. Proven on a clean
  install with synthetic records before it goes near a real wallet.
  **Built:** `lib/core/backup/` — Argon2id (64 MiB, 2 passes) wraps a random
  content key; ChaCha20-Poly1305 seals the manifest, the data and each photo,
  bound to the archive and the header; both primitives pinned to their RFC
  test vectors. The backup carries its own schema, so a newer app restores an
  older backup through the normal migrations and an older app refuses a newer
  one. Restore stages beside the live wallet, the app restarts, and the swap
  happens in `openEncryptedDatabase` before anything opens the file — resumable
  from a crash, rolled back if the restored wallet does not open with this
  phone's key and hold the promised cards. 36 new tests (540 total): a full
  round trip onto a "phone" with another key and folder reproduces every row
  and photo byte for byte; wrong passphrase, edited header, changed or swapped
  photo, truncated file, path-climbing entry, non-backup, newer schema and
  oversized file all leave the current wallet untouched.
  **Verified on the RMX3612, release build:** backup of the test wallet in ~4 s
  (key derivation and read-back check included), saved to Download through the
  share sheet; the phone-made file decrypts and verifies on the laptop; no
  plaintext names or notes in it; restore after editing the note brought the
  original note, photo and search back, the app restarted itself and said
  "Restored 1 card from your backup."; a wrong passphrase re-asks instead of
  failing. No new permissions (still the four); `pointycastle` and
  `file_selector` added. "Take a copy" is now labelled as a readable export
  that cannot be restored.
- [x] **F4. Photos encrypted at rest** (M) ✅ — card photos, thumbnails and the
  portrait; authenticated encryption, versioned header, key in the Keystore.
  - Sealed with ChaCha20-Poly1305 under a second Keystore key (`photo_key_v1`),
    in files that start with `RCPH` + a version byte (`lib/core/imaging/photo_vault.dart`).
  - Photos stored before F4 are sealed in place once, on the first launch.
  - OCR reads a plain temporary copy that is deleted as soon as it's read.
  - Every temporary copy in the cache (the scanner's picture, the pickers'
    copies, exports) now has a set lifetime in `lib/core/storage/hand_offs.dart`.
    Found on the phone: the scanner had kept a plaintext copy of every scan.
  - Verified on the RMX3612 (29 Sep):
    - the existing photos became `RCPH` files;
    - home, card detail and the full-size viewer all display them;
    - a new scan and a back capture were stored sealed, with OCR still working;
    - the scanner folder was empty after capture, with no plain copies left.
  - Also fixed: the full-size viewer's back arrow and status bar were drawn
    dark on dark.
  - Release build walked end to end on the RMX3612 the same day: scan →
    review (6 fields, all "On the card") → note → search by the note →
    contacts → Recently deleted → Settings. 580 tests pass.

### Release A — first sellable workflow (people)

Target: live on Play around weeks 7–8, with a real one-time purchase.

- [ ] **A1. Context and next action** (M) — where and when you met (suggested,
  never fabricated); notes editable any time ✅ (done in F1); a next action with
  purpose, due date and optional reminder.
- [ ] **A2. Reminders and Today** (L) — obligations separate from their
  notification attempts; inexact scheduling; `reconcile()` after reboot,
  update, restore and timezone change; notification permission asked when the
  first reminder is set; generic lock-screen text for sensitive items. Today:
  overdue, due today, upcoming, then review work.
- [ ] **A3. Introduction handoff** (S) — "Say hello": a template from the
  user's own card, shown in full, edited, then handed to WhatsApp / SMS / mail.
  Recorded as *opened*, never as *sent*.
- [ ] **A4. My Card QR** (S) — `qr_flutter` over the existing `buildVCard`;
  only the fields the user chose.
- [ ] **A5. Compact Event Mode** (M) — one active event; captures inherit it;
  the user can override; an end-of-event summary of people and next actions.
- [ ] **A6. People search, grounded** (M) — interactions logged and fed into
  ranking; Ask for people: lookup ("Rahim's number") and need-shaped search,
  every answer citing its card.
- [ ] **A7. Offline Plus — one-time purchase** (L) — Play Billing 8+,
  **verified on the phone** (see §5). Entitlements cached as a signed grant, so
  a bought feature works offline; restore on reinstall; pending / cancelled /
  refunded states; free-tier limits (5 active reminders is a hypothesis). The
  paywall lists only features that are ready, with Play's localised price.
- [ ] **A8. Release A gates** — closed test running since week 2; production
  access applied for; Data safety and privacy policy match the build;
  golden journeys on the phone.

### Release B — people plus purchases (core 499B)

Target: weeks 10–11.

- [ ] **B1. Schema v10, in place** (L) — see §5. Rehearsed on a copy of a real
  database; the encrypted backup (F3) must exist first.
- [ ] **B2. Receipts and warranties** (L) — classification (the capture
  category the user picked is a strong signal; rules next; "What did you
  save?" when unsure). Receipt: merchant, date, final total, currency,
  category. Warranty: product, model, serial, coverage, start basis, duration,
  printed expiry. Critical fields always reviewed.
- [ ] **B3. Linking and derived expiry** (M) — suggested on serial / invoice /
  reference evidence with reasons shown; confirmed, reversible; a derived
  expiry labelled *calculated*, recomputed when its inputs change.
- [ ] **B4. Spending totals** (M) — exact sums from verified receipt facts, by
  period / category / merchant, one currency at a time; duplicates and
  unverified totals listed separately, never silently added.
- [ ] **B5. Ask RecallOS across people and purchases** (L) — typed plans only:
  lookup, search, filter, dates, captured-spending aggregate. Answers state
  their scope ("1–30 Sep, BDT, 12 verified receipts"), cite sources, and say
  "couldn't determine that" when they can't. No model-written SQL.

### Release C — only with spare capacity and passed gates

Tickets · a public self-card link · E2EE cloud snapshots with a subscription
(brings `INTERNET` back — its own disclosure, policy, Data safety and account
deletion work) · IDs, only after F4 and an independent review · several My
Cards · QR/barcode scanning · tags and favourites · Bangla UI (with a bundled
Bengali font) and Banglish query experiments.

**Later, not this semester:** multi-device writable sync, Teams, CRM
integrations, bank connections, ten categories, generative drafting.

**Cuts, if time runs short, in this order:** generative anything, cloud, public
links, tickets, several identities, advanced customisation, line items. Never
cut: security, recovery, honest critical-field review, the primary retrieval,
billing correctness, or the evaluation the report's claims rest on.

## 5. Architecture decisions for 499B

### The first purchase is verified on the phone

Offline Plus is a one-time unlock of features that run offline, so Release A
keeps the strongest thing RecallOS can say about privacy — *Android itself
stops this app from sending anything* — true at launch. The purchase is
checked on the device (Play's signed purchase data, verified against the app's
public key) and acknowledged through the Play Store app. Offline piracy cannot
be driven to zero; a working paid user matters more than always-online DRM.

**To prove before relying on it:** that the Play Billing library adds no
`INTERNET` permission. A one-day spike: add `in_app_purchase`, build the
bundle, run `tool/ci/check_permissions.sh`, and complete a licence-test
purchase from internal testing. If `INTERNET` does come in, this decision
reopens.

A server (a Supabase Edge Function that checks purchases with Google) arrives
with Pro and cloud, when `INTERNET` returns anyway.

### Evolve the schema in place — no parallel tables

The existing tables are already most of a general "memory item" model, so
schema v10 extends them rather than running an old and a new system side by
side:

| Need | Already there | v10 change |
|---|---|---|
| A saved thing of any type | `cards` — `type` enum (already has `receipt`, `warrantyCard`, `coupon`, `eventPass`…), timestamps, soft delete, person/org/role links | add `title`, `sensitivity`, `captureSource`, `classificationConfidence`; add `ticket`, `idDocument` to the enum. "MemoryItem" is the Dart domain name over this table |
| Typed facts | `card_fields` — key, value, normalised value, `FactSource`, confidence, verified, region, side | add `valueType`, `amountMinor` (INTEGER) + `currency`, `dateValue` (a local date, not a timestamp), `status`; a controlled key vocabulary in code |
| Many pages / PDFs | `imagePath`, `backImagePath`, `thumbPath` | new `item_assets`; front and back migrate into it |
| Links between things | `duplicate_candidates` shows the reversible pattern | new `item_links` with a `reasons` JSON column |
| Dates and reminders | — | `important_dates` (obligations) and `reminders`, with a separate `ReminderScheduler` that owns the platform side and can `reconcile()` — needed in Release A, so they land before v10 |

**Money is an integer in minor units plus a currency code** — paisa, cents —
never a floating-point number. BDT and USD are never added together.

**A fact has three separate properties**, not one enum: *origin* (printed,
user, derived, inferred), *review* (unreviewed, confirmed, rejected) and
*validity* (current, superseded, outdated). Today's `FactSource` mixes them
(`verified` and `outdated` sit beside `printed`); v10 separates them.

Deferred until a feature needs them: a fact-dependency table (a derived fact
keeps its inputs as a JSON list), per-page search chunks, a separate
search-document table, per-type summary projections.

The query side adopts interfaces rather than new storage: `HybridSearchQuery`
with lexical / semantic / hybrid modes — the same switch runs the research
comparison — plus `FactQuery`, a money aggregate, and a `RecallQueryPlan` that
Ask RecallOS executes. AI output is always a *candidate* that the user or a
validator promotes; nothing generative writes to the database.

### The benchmark build

`/spike` is compiled out of release builds (`router.dart`), but OCR must be
measured on a release build — R8 once made release OCR return zero blocks while
debug was fine. So the route is also enabled by
`const bool.fromEnvironment('RECALLOS_BENCH')`:

```bash
flutter build apk --release --dart-define=RECALLOS_BENCH=true
```

That APK is never uploaded. The Play bundle is built without the define, and
CI plus `release_surface_test.dart` assert it defaults to off.

### Migration safety

- Back up the phone's database before every migration:
  `adb exec-out "run-as com.recallos.recallos cat app_flutter/recallos.sqlite"` —
  debug builds only, so take it before installing a release build.
- Rehearse each migration on a copied database file first.
- The encrypted backup (F3) exists before schema v10 touches a real wallet.

### No analytics SDK

Installs, retention and purchases come from Play Console's own reports. Paywall
and feature counts are kept on the device and exported only when a tester
chooses to send them from About — never OCR text, names, notes or raw queries.

### Honest wording

"BDT 8,450 in saved receipts", not "you spent". "Message opened", not
"message sent". "Calculated from purchase date + 24 months", not a bare date.
No "100% accurate", "military-grade" or "never miss a deadline" anywhere.

## 6. Evaluation — measured, never invented

- [ ] **OCR on cards** — character error rate and per-field F1, bucketed Latin /
  Bengali / mixed, on the benchmark build. Needs 30+ hand-labelled cards.
- [ ] **Receipt and warranty extraction** — per-field F1 on real documents,
  reported separately for Bangla and thermal-printed receipts.
- [ ] **Classification** — accuracy and macro-F1.
- [ ] **Retrieval** — keyword vs semantic vs hybrid: P@3, MRR, NDCG over a
  labelled set of English and Banglish queries.
- [ ] **Duplicates and link suggestions** — precision, recall, false-link rate.
- [ ] **Ask RecallOS** — answer accuracy and grounded-answer rate (every
  statement traceable to a stored fact) on a fixed question set.
- [ ] **Users** — System Usability Scale with the 20–30 closed-test users, plus a
  willingness-to-pay survey.
- [ ] **Business** — real conversions and revenue from Play Console.

## 7. Calendar

About 14 weeks from 28 Sep 2026; re-pinned once the report and defense dates
are known. Revenue work runs from week 1, not after engineering.

| Week of | Build | Release / evidence |
|---|---|---|
| 28 Sep | ✅ F1 · ✅ F2 | tag `cse499b-start`; Play account; upload key; group agreement |
| 5 Oct | ✅ F3 backup/restore (done early, 29 Sep) | v1.0 (offline, free) → internal → **closed test starts the 14-day clock**; merchant profile; first interviews |
| 12 Oct | F4 photo encryption; billing no-INTERNET spike | backup round-trip on the phone, *then* switch it to the upload key; OCR run |
| 19 Oct | A1 context + next action | apply for production access |
| 26 Oct | A2 reminders + Today | retrieval query set |
| 2 Nov | A3 intro · A4 QR · A5 Event Mode | design-partner sessions |
| 9 Nov | A6 people search · A7 Offline Plus | licence-test purchases |
| 16 Nov | A8 gates | **Release A live — first sale attempt** |
| 23 Nov | B1 schema v10 | evaluation round 1 written up |
| 30 Nov | B2 receipts + warranties | receipt / warranty labels |
| 7 Dec | B3 linking · B4 totals | |
| 14 Dec | B5 Ask across both | **Release B live** |
| 21 Dec | Release C only if spare | usability + willingness-to-pay study; evaluation round 2 |
| 28 Dec | freeze; golden-journey QA | report, defense rehearsal |

**Stop rules** (from the Master Plan): no restore proven by week 4 → no
destructive data change; core people workflow missing by week 6 → no new
features; no payment path by week 8 → Play Console and billing blockers come
before anything else; from week 11 → reliability, evidence and the report only.

## 8. Only the owner can do these

- [ ] Tag `b48d429` as `cse499b-start` (`git tag cse499b-start b48d429`), then commit the current work — this project never commits from an agent. If a separate 499A submission exists, tag that commit too.
- [ ] **A written agreement with the group partner** (and the university, if its rules need it) on ownership, revenue and maintenance **before anything is sold**.
- [ ] Play Console account: 2-Step Verification, ID check, $25.
- [ ] Choose Personal or Organization — a Personal account that sells anything shows its full address publicly.
- [ ] Generate the upload key (`RELEASE.md` §1); back it up in two places off this laptop.
- [ ] Settle the permanent `applicationId` and the store title before the first upload — search Play and trademarks for "RecallOS" first.
- [ ] Merchant payments profile (week 2).
- [ ] Recruit 20–30 closed testers (week 2).
- [ ] Hand-label cards, receipts and warranties for §6 (weeks 1–5).
- [ ] Send the report and defense dates.
- [ ] Agree with the group partner which parts they own (proposed: the evaluation dataset and QA, or the receipt/warranty slice).
- [ ] 15–20 interviews with the first customer segment (independent professionals / small agencies) before Release A ships.

## 9. Verification — how every item above gets its ✅

- `flutter analyze` clean and `flutter test` green before anything is reported done.
- Every UI change checked on the RMX3612 with `adb exec-out screencap -p`.
- `aapt dump permissions` on the release APK after every new package, compared with the CI allowlist.
- `zipalign -c -P 16` on native libraries before each Play upload (required for updates from 1 Feb 2027).
- Backup: create → uninstall → reinstall → restore → identical rows and photos, as a test and once on the phone.
- Each migration rehearsed on a copy of the real database.
- The three stories in §3 on a release build in airplane mode.
- Once online features exist: zero network requests without sign-in (checked through a proxy), row-level-security tests, Play Billing tested with licence testers.

Release procedure and the Play rules that apply to each of these: [`RELEASE.md`](RELEASE.md).
