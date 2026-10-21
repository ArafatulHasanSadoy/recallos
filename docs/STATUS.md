# RecallOS — status and handoff

**Read this first in every new chat. Update it before the chat ends.** (The rule
is in `CLAUDE.md`.) The owner starts fresh chats to save tokens, so anything
decided or built in a chat that is not written here or in `docs/PLAN.md` is
lost.

Last updated: **15 Oct 2026** (M6 / B4 built, steps 1–6).

## Read in this order

1. **This file** — where things stand, **what is being built right now
   (*Now working on*, a checklist to continue from)**, what is next, and the
   session log.
2. **`CLAUDE.md`** — how to work in this repo: rules, design system, the phone.
3. **`docs/PLAN.md`** — the full plan, with the evidence behind each ✅: §4
   scope (Releases A, B, C), §6 evaluation, §7 calendar, §8 owner-only tasks.
4. **`docs/RELEASE.md`** — building, signing, checking and uploading a release.
   **`design/UX-PROTOCOL.md`** — before any UI/UX work: research first
   (Mobbin when connected), every state, design reasoning, phone walk.
5. **`business/STATUS-PRIVATE.md`** (gitignored, local only) — Play Console
   account details, prices, promo codes, the testers list, paths to keys and
   backups. Plus `business/STRATEGY.md`, `DECISION-RECORD.md` and
   `PRICING-OPTIONS-*.md`.

This repo is **public** and `docs/` is served on GitHub Pages. Prices,
strategy, tester emails, promo codes and account IDs go in `business/`, never
in a tracked file.

## Where things stand

**Code** — local `main` at `0940360`. **GitHub's `main` is ahead, at
`01884e6`** (checked 15 Oct): PR #1, merged on GitHub on 7 Oct (reminder
undo, overnight events, contact title corrections, roles kept through
merged-identity backfill), is not in the local tree. Merge it in after the
local work is committed; it overlaps `identity_repository.dart`,
`follow_up_repository.dart` and `card_repository_test.dart`. Target API is
36 (Flutter 3.44's default), which meets Play's current rule. **A6, B1's
schema v11, B2 (receipts and warranties), B3 (linking and calculated
expiry), B4 (spending totals), B5 (Ask) and the M7½ UX pass are in the
working tree, uncommitted — and on the phone since 15 Oct.** Flutter,
Riverpod, Drift + SQLCipher, schema **v11** (B3–B5 needed no schema
change); the phone's real wallet was migrated to v11 in place on 15 Oct.
`flutter analyze` clean, **1,075 tests** pass (2 skipped: the rehearsal,
and the real OCR scoring run).

- **Built and walked on the phone:** F1–F4 (foundation: fixes, encrypted
  backup and restore, photos encrypted at rest), **A1** context and next step,
  **A2** reminders and Today, **A3** Say hello, **A4** My Card QR, **A5** Event
  Mode (built early), **A7** RecallOS Plus (one-time purchase, receipt checked
  on the phone, no `INTERNET`), **A6** people search (7 Oct).
- **Built and walked on the phone (15 Oct):** B1 schema v11 (the real
  wallet migrated, every count the same), B2 receipts and warranties, B3
  linking and calculated expiry, B4 spending totals, **B5 Ask RecallOS**,
  and the **M7½ UX pass**. Walked with two rendered sample papers imported
  through the scanner (since soft-deleted), in light and dark; seven faults
  the walk found are fixed, each with a test. **Still for the owner:** a
  real receipt and warranty through the camera, and the phone at 1.3× text
  (a system setting, so not changed by Claude; renders at 1.3× pass).
- **Not built yet:** the §6 evaluation (M8). It needs the owner's labelled
  cards, receipts and questions.
- **Working tree (uncommitted):**
  - docs edits from the last two chats;
  - a `pubspec.lock` dependency upgrade (drift 2.34 → 2.35 and others). The
    owner decided on 7 Oct to **keep it**: commit it with the docs.

**Google Play** — the app *RecallOS: Business Card Wallet*
(`com.recallos.recallos`):

- App setup complete: store listing, all 10 App content declarations, Business
  category, contact email.
- Version **1 (1.0.0)** — commit `0940360`, signed with the upload key — is on
  **Internal testing** and **Closed testing - Alpha**. Google approved it on
  **6 Oct**.
- **14 testers** (one email list, also licence testers) were emailed the
  closed-test opt-in link on **7 Oct**.
- **15 Oct check: 4 opted in** (Dashboard → *Apply for access to
  production*; *Apply for production* is greyed out, Production
  *Inactive*). 8 more are needed before the 14 days can start.
- **13 Oct check: only 3 of the 14 have opted in** (Dashboard → *Apply for
  access to production*). Statistics → installed audience: 2 devices on 7 and
  8 Oct, 1 on 10 Oct. Google's 14-day clock needs 12 opted in, so it has not
  started; every day under 12 pushes production access back a day.
- The **RecallOS Plus** product (`recallos_plus`) is active. Reviewer promo
  codes are in the Sign-in details declaration.
- The app as Play delivers it has our eight permissions plus `CHECK_LICENSE`
  (added by Google's automatic protection), and **no `INTERNET`**.

**Dates — changed by the owner on 7 Oct, and again on 15 Oct**

- **15 Oct: no target dates at all** — not ~20 Nov, not 10 Nov. Publish as
  soon as Google Play allows, and finish the whole project as fast as
  possible. Google's closed-test rule (12 testers opted in for 14
  continuous days, then a production review) is the only clock; no
  feature may delay a release that is otherwise ready.

- **No milestone deadlines. Build the whole app as fast as possible**, one
  milestone straight after another.
- **Public launch, with every feature (Releases A and B), around 20 Nov.**
  - Google needs the 14-day closed test (12+ testers opted in; the owner
    emailed them all on 7 Oct) and then its production review.
  - The owner may add more features before launch.
- **Apply for production access as soon as the 14 days are up** (~21 Oct at
  the earliest), because the review can take a week. Publish to production
  only when the complete app is ready.
- **10 Nov (university submission):** kept here for reference. The plan no
  longer works backwards from it.

**The phone** (Realme RMX3612, connected over USB):

- Runs a **debug-signed** release build of the current working tree
  (v11, stamped `0940360-wt`, 15 Oct).
- Before it, a raw copy of the v10 wallet was taken (a debuggable build
  with the same key, installed and never opened, then `run-as tar`;
  sha256 checked): `raw-pre-v11-20261015-083756.tar` in the backups
  folder, with the v10 APK to roll back to.
- Its wallet holds the owner's real cards plus demo cards. Backups are in
  `~/Dev/recallos-db-backups/`.
- A build from Play is signed by Google, so it cannot install over this one.
  Switching means uninstalling, which wipes the wallet: make an in-app backup
  file first and restore it after.

## Now working on

**Read this before anything else in a new chat.** Continue from the first
unticked box below.

- Tick a box **in the same turn its sub-step lands**, with the test that
  proves it, not at the end of the chat.
- When every box is ticked and the feature has been walked on the phone:
  - collapse the list into one session-log line;
  - mark the row ✅ in `docs/PLAN.md`;
  - put the next milestone's checklist here.

### M2 — versionCode 2 to testers, and A7 on a Play build (needs the owner)

A6 is done: walked on the phone 7 Oct, ✅ in `docs/PLAN.md`. Every step can
be read in git, in the session log below, and in PLAN's A6 row.

**If the owner is not free for this, start M3 below** and come back to M2.

- [ ] **1. Commit first.** The git chat commits the working tree (A6 + docs +
  `pubspec.lock` + the manifest fix), so the build can be stamped with a real
  commit.
- [ ] **2. Bump** `version:` in `pubspec.yaml` to `1.0.0+2`.
- [ ] **3. Build the AAB with the upload key**, following `docs/RELEASE.md`
  → *Every release*:
  - `flutter build appbundle --release
    --dart-define=RECALLOS_COMMIT=$(git rev-parse --short HEAD)`;
  - `tool/ci/check_permissions.sh`;
  - backup off (`aapt2 … | grep -i backup`);
  - 16 KB alignment;
  - signed with the upload key.
- [ ] **4. The owner drags the AAB** into Internal testing, then promotes it
  to Closed testing - Alpha. **Release notes** (rewritten 15 Oct, because v2
  now carries B1–B5 and the UX pass; 450 characters, under Play's 500):

  ```
  Receipts and warranties: the same Scan saves them. A warranty is matched with its receipt, RecallOS works out when the cover ends, says how, and reminds you a month before. This month's total of the receipts you checked.
  Ask in your own words: "When does my laptop warranty expire?", "Rahim's number".
  People: find them by why you saved them, see their note and next step.
  Today shows warranties ending soon. Phone numbers read as written.
  ```

  Also re-answer **Financial features** in App content
  (`docs/RELEASE.md` → *Financial features*).
- [ ] **5. Re-check the delivered permissions** in App bundle explorer: ours
  plus `CHECK_LICENSE`, no `INTERNET`.
- [ ] **6. A7 on a Play-installed build, with the owner:**
  1. make an in-app encrypted backup, and copy it off the phone;
  2. uninstall, then install v2 from the Internal link;
  3. restore the backup;
  4. a licence-test purchase, a refund, a restore after reinstall, and a
     promo-code redemption.

  Then switch back to a dev build the same way.
- [ ] **7. Record it:** PLAN A7 gets ✅; the details go in STATUS-PRIVATE.

### M3 — B1 Schema v11, in place (can start before M2)

The design is in `docs/PLAN.md` §4, B1 (cut down 7 Oct).

- [x] **1. Freeze the v10 schema** (8 Oct).
  - `test/fixtures/schema_v10.sql` was generated from the v10 code itself,
    before any v11 change (36 statements, FTS shadow tables left out).
  - `test/support/schema_compare.dart` provides `describeSchema`,
    `expectSameSchema` and `frozenDatabase`. They compare columns by name,
    defaults, not-null, primary keys, foreign keys with on-delete, unique
    sets, indexes and the FTS definition.
  - **Tests:** `test/core/migration_v11_test.dart`:
    - a snapshot database opened by this build has the same shape as a
      fresh install (once v11 lands, this is the migration test);
    - the comparison is shown to fail on a dropped index or a stray column.
- [x] **2. Rehearsal harness** (8 Oct): `test/rehearsal/real_wallet_test.dart`.
  - Skipped unless `RECALLOS_REHEARSAL_BACKUP` and
    `RECALLOS_REHEARSAL_PASSPHRASE_FILE` point at a backup and its
    passphrase, both outside the repo.
  - It restores the backup into a temporary folder (photos sealed under a
    throwaway key), opens it with this build, and checks:
    - the version is v11 and the shape matches a fresh install;
    - every table's row count matches the backup's manifest;
    - the foreign-key and integrity checks are clean;
    - review and `verified_by_user` agree on every field.
  - It prints counts only, and deletes its folder.
  - **Proven end to end** on a synthetic v10 backup made through the real
    `writeBackup`: cards 2→2, card_fields 3→3, notes 1→1, 1 confirmed.
- [x] **3. The `from < 11` step** (8 Oct). Schema **v11**.
  - **Columns:**
    - `cards` gains `title`, `capture_source` and
      `classification_confidence`;
    - `card_fields` gains `origin`, `review` and `validity` (defaults
      printed, unreviewed, current), plus `amount_minor`, `currency` and
      `date_value` (`LocalDateConverter`).
  - **`item_links`:** cascades on both cards, a unique (from, to, kind),
    `idx_item_links_to`, `reasons` JSON defaulting to `[]`, and `status`
    defaulting to suggested.
  - **New enums:** `FactOrigin`, `FactReview`, `FactValidity`,
    `CaptureSource`, `LinkKind`, `LinkStatus`.
  - **The step:**
    - runs in a transaction;
    - adds each column and the table only if missing;
    - fills origin, review and validity from `source` and
      `verified_by_user` in one SQL statement. `aiInferred` becomes inferred;
      `outdated` becomes printed and outdated; `verified` was never written,
      so it becomes printed.
  - **`createPending`** writes `visitingCard` and `documentScanner`.
  - **Tests:** `test/core/migration_v11_test.dart`, 6 tests:
    - a migrated v10 has the same shape as a fresh v11;
    - all 5 sources × confirmed map correctly, rows kept, and the
      foreign-key check is clean;
    - a half-migrated database finishes;
    - new rows get the defaults;
    - links cascade and refuse duplicates;
    - the comparison can fail.
  - Also `back_capture_test`: a capture is saved as a business card from the
    scanner.
  - The old v1-rollback test needed no change: the idempotent step skips
    columns that already exist.
  - 834 pass.
- [x] **4. Provenance written in both forms; readers moved** (8 Oct).
  - **`lib/core/db/field_provenance.dart`:** `FieldProvenance.printed` and
    `.userConfirmed` write `source`, `verified_by_user`, `origin`, `review`
    and `validity` together. All three write sites use it: extraction,
    `updateField`, `addField`.
  - **Readers moved to the v11 columns:**
    - re-extraction keeps what the user confirmed (`isConfirmed`);
    - the two launch repairs select printed and unconfirmed;
    - `SourceChip` labels by origin, review and validity, and gains
      *calculated* for derived facts (B3).
  - `contact_points` and `attributes` keep `FactSource`.
  - **Tests:** `test/features/field_provenance_test.dart` covers every write
    path agreeing in both forms, and a confirmed field surviving a fresh
    reading.
  - **Found by the suite:** `card_repository_test` fixtures set only the old
    columns, a state no writer can produce any more. They now write both.
  - 838 pass.
- [x] **5. Money and calendar days** (8 Oct).
  - **`lib/core/domain/money.dart`:** integer minor units plus an ISO code,
    with each currency's own decimals (BDT 2, JPY 0, KWD 3).
    - `parse` reads amounts as printed: "Tk 1,23,456.00", "8.450,50",
      Bangla digits, "(120.00)" as a refund.
    - `+` refuses two currencies.
    - `format` gives "BDT 8,450.50".
  - **`lib/core/domain/local_date.dart`:** `LocalDate` with
    `LocalDateConverter` (stored as `YYYY-MM-DD`). `addMonths` ends the month
    rather than overflowing (31 Jan + 1 is 28 Feb); B3 counts warranties
    with it.
  - **Tests:** `test/core/money_test.dart`.
- [x] **6. Only follow-ups are next steps** (8 Oct).
  - `DateKind.warrantyExpiry` added.
  - Filtered on `kind = followUp`: `watchOpenSteps` (the card), `watchOpen`
    (Today and home's row), `watchFinishedSteps` and the event summary.
  - `activeReminderCount` (the free five) counts only follow-ups.
  - **Changed from the plan:** `pendingReminders` stays kind-agnostic,
    because it is what Android holds, and a warranty reminder must still
    fire. It now carries `kind`.
  - **Tests:** `test/features/date_kinds_test.dart`.
- [x] **7. Only cards about people make contacts** (8 Oct).
  - `IdentityRepository.peopleCardTypes` is visiting card, service-centre
    card and unknown (every card from before types).
    - `promote()` treats any other type as a card with nothing on it, so a
      card re-typed as a receipt leaves the graph.
    - The backfill catch-up query skips other types, so receipts are not
      re-tried on every launch.
  - Moved to step 3: `createPending` writing `visitingCard` and the capture
    source.
  - **Tests:** `test/features/card_type_gate_test.dart`.
  - 827 pass after steps 1, 5, 6 and 7.
- [x] **8. Backup across versions** (8 Oct). In `backup_roundtrip_test`, a
  backup made by a v10 phone (the frozen schema, encrypted with that phone's
  key):
  - restores onto a phone running this build;
  - opens as v11, with provenance mapped;
  - keeps its photograph, at the new phone's own path.

  839 pass, 1 skipped (the rehearsal).
- [x] **9. On the phone** (15 Oct, owner's go-ahead in chat). Done another
  way than (a)–(b): a raw copy instead of the in-app backup (it needs the
  owner's passphrase), and the migration checked on the wallet itself.
  - **Backup:** a debuggable build with the same signing key installed over
    the release one and never opened, the app folder copied with
    `run-as tar`, sha256 matched. The file and the v10 APK are in
    `~/Dev/recallos-db-backups/` (names in "The phone" above).
  - **Install:** `adb install -r` of a `RECALLOS_ALLOW_DEBUG_SIGNING=true`
    release build. The first open migrated v10 → v11: 16 cards, 13 people,
    2 duplicate pairs and 2 overdue steps, as before.
  - **Walked:** scan → review → card (the *On the receipt* chips), Today,
    People, search. Closed with `am stop-app`.

  The original plan, kept for reference: **Do not install a v11
  build on the phone until (a) and (b) are done.** It is the owner's real
  wallet, and a v11 database cannot be opened by the v10 build on Play.
  - **(a) The owner** makes an in-app backup:
    1. Settings → *Back up the wallet*, with a passphrase only they know;
    2. save it to Download;
    3. check its *Restore from a backup* preview, then back out;
    4. put the passphrase in a file outside the repo, e.g.
       `~/Dev/recallos-db-backups/<date>.pass`.

    Then: `adb pull /sdcard/Download/<file>.recallos
    ~/Dev/recallos-db-backups/`.
  - **(b) Rehearse:** `RECALLOS_REHEARSAL_BACKUP=… RECALLOS_REHEARSAL_PASSPHRASE_FILE=…
    flutter test test/rehearsal/real_wallet_test.dart`. Every count must
    match.
  - **(c) Install and walk:**
    - `adb install -r` a `RECALLOS_ALLOW_DEBUG_SIGNING=true` release build;
    - walk scan → review → card (the provenance chips), Today, contacts,
      search;
    - close with `am stop-app`, never `force-stop`.
  - **(d) Close out:** mark PLAN B1 ✅, and give the owner test steps.

### M4 — B2 Receipts and warranties (started 13 Oct)

M3's phone step and M2 wait on the owner, so M4 goes first. It builds on
v11 in the working tree. The phone walk (step 9) needs B1 on the phone first.
The owner's real receipts have not arrived yet, so the readers are built
against invented layouts in common Bangladeshi shapes, then tuned on real
paper when it comes. **Mobbin is not connected**, so the screens follow the
fallback in `design/UX-PROTOCOL.md` §1.

- [x] **1. Vocabulary** (13 Oct). `ReceiptKeys` (merchant, purchase_date,
  total, invoice_number, category; *critical*: total and date) and
  `WarrantyKeys` (product, brand, model, serial, cover_months, start_basis,
  expiry_date, purchase_date; *critical*: cover and expiry), in
  `card_extractor.dart`. `ExtractedField` gains `amountMinor`, `currency`
  and `dateValue`.
- [x] **2. What was scanned** (13 Oct).
  - **`lib/core/extraction/document_lines.dart`:**
    - `rowsOf` puts a split row back together ("Grand Total" | "8,450.00");
    - `findDates` reads day first, month names, ISO and Bangla digits, and
      refuses 31/02;
    - `moneyPattern` and `currencyOf`.
  - **`document_classifier.dart`:** `classifyDocument` gives a kind, a
    confidence (the winner's share of all evidence) and the cues as reasons.
    `isSure` is at 0.6.
  - **Measured on the invented samples:** card 0.86; shop receipt 0.92;
    electronics invoice 0.61 (receipt 10 against warranty 5.5, because it
    prints "2 Years" warranty); restaurant 0.85; warranty card 0.83; an
    ambiguous slip 0.50, so it asks.
  - **Tests:** `test/core/document_classifier_test.dart`, 14 of them.
- [x] **3. Receipt reader** (13 Oct). `lib/core/extraction/receipt_extractor.dart`
  works over `rowsOf` rows.
  - **Total:** "grand total / net payable / amount payable…" first, the
    last one on the paper; then a plain "Total". "Total" and "মোট" count;
    so do "সর্বমোট" and an amount wrapped onto the row below. Subtotal,
    total qty, VAT and change never count. An unlabelled receipt gets **no
    total**, not a guess. The value is `Money` in paisa, with `currency`
    detected (taka by default).
  - **Date:** a "Date" or "তারিখ" row first, day first; a warranty or
    expiry date is never the purchase date.
  - **Merchant:** the largest name-like row among the top six; never an
    address, invoice, phone or priced row.
  - **Also:** the invoice number, and a category guess (`issue: guessed`).
  - The total and the date are always `needsReview`.
  - **Found by the tests:** "SHOPNO" tripped the shop-number rule.
  - **Tests:** `test/core/receipt_extractor_test.dart`, 13 of them (super
    shop, electronics invoice, restaurant, tea stall, wrapped total,
    never-the-total, no total, Bangla, USD, warranty date).
- [x] **4. Warranty reader** (13 Oct). `warranty_extractor.dart` reads:
  - brand, from a label or the logo line;
  - product and model;
  - serial or IMEI, digits required (normalised, the link evidence for B3);
  - cover length in months, flagged `split_cover` for "5 years
    compressor, 1 year parts";
  - start basis;
  - purchase date, and a **printed** expiry only (never calculated here).

  Cover and expiry are `needsReview`. **Tests:**
  `test/core/warranty_extractor_test.dart`, 7 of them. The layout helper
  moved to `test/support/ocr_layout.dart` and is shared with the receipt
  tests.
- [x] **5. Storing it** (13 Oct).
  - **One way in:** `lib/core/extraction/document_reader.dart`.
    - `readDocument(blocks, {as})` classifies, then reads with the right
      reader. It gives a `DocumentReading` with `shouldAsk` (not sure and
      not chosen) and a `title`.
    - `extractAs(type, blocks)` picks the reader for a card's type.
  - **The write:** `attachExtraction` stores `amount_minor`, `currency` and
    `date_value`. A reader's `kGuessedIssue` becomes origin *inferred*
    (`FieldProvenance.inferred`, `provenanceOf`) rather than a "needs a
    look" objection.
  - **"Read enough":** `isUsefulSet` counts a receipt's total (or merchant
    plus date), and a warranty's serial, expiry or product plus cover.
  - **The repository:** `CardRepository.setKind(type, confidence, title)`
    and `typeOf`.
  - **Re-reads:** the back-of-card capture and the re-read use the card's
    own reader, so re-reading a receipt keeps its total.
  - **Found by the tests:** a slogan "Total solutions…" counted as receipt
    evidence. A total now needs an amount after it on the same row.
  - **Tests:** `test/features/receipt_storage_test.dart`:
    - the receipt's typed values, guessed category, type and title;
    - the cashier never becomes a contact;
    - the warranty's serial, cover and title;
    - a business card unchanged;
    - a given type is never asked about;
    - an unclear page asks.
  - 880 pass.
- [x] **6. Capture** (13 Oct). The §18 design reasoning is in PLAN B2.
  Mobbin was not connected, so it says so, and lists the searches to run.
  - **Reading:** capture reads with `readDocument` and records the kind
    with `setKind` (type, confidence, title).
  - **The review screen** shows *Saved as a {kind} · Change*.
  - **When the classifier is not sure**, `showKindSheet` asks *What did you
    save?* (`capture/presentation/kind_sheet.dart`). It is serif italic,
    with three 52px rows; the best guess is marked, and *Keep the best
    guess* leaves it.
  - **Changing the kind** runs `CardRepository.reReadAs`. It re-reads the
    stored OCR blocks with that kind's reader, side by side, and keeps the
    engine. Then capture re-indexes and re-promotes.
  - **The save button and the note question** follow the kind: *Save
    receipt* · "What was this for?"; *Save warranty* · "What does this
    cover?".
  - **"Nothing readable"** copy no longer says "card".
  - **Tests:** `test/features/kind_change_test.dart`:
    - the sheet's question, rows and best guess;
    - one tap answers it; keep-the-guess changes nothing;
    - a receipt misread as a card is re-read, typed and titled, its
      confidence cleared and its contact gone.
  - 884 pass. **Not yet walked:** the capture screen needs the phone (step
    9).
- [x] **7. Reviewing and the card screen** (13 Oct).
  - **Labels** in `fieldLabel`: Shop, Date, Total, Invoice no., Category,
    Product, Brand, Model, Serial or IMEI, Cover, Counts from, Expires.
  - **The editor offers the card kind's own fields**
    (`fieldKeysFor(type)`). *Add something it missed* starts at the total
    on a receipt, or the expiry on a warranty (`defaultMissingKey`).
  - **Typed edits stay in sync.** `validateField` re-reads a total (keeping
    the field's currency), a date or a cover length from the text, and
    `updateField` and `addField` write `amount_minor`, `currency`,
    `date_value` and the cleaned display. Unparseable input gets a plain
    sentence (`not_an_amount`, `not_a_date`, `not_a_period`, `split_cover`).
  - **`needsChecking`:** an unconfirmed total, date, cover or expiry shows
    *check this* in ochre ink, in words as well as colour. Opening and
    saving confirms it.
  - **Tests:** `test/features/receipt_fields_test.dart`, 8 of them:
    - the validator (currency kept, dates, months, plain-language issues);
    - a corrected total stored in paisa and confirmed;
    - the list shows receipt labels and *check this* until confirmed;
    - the editor offers receipt fields, not a card's.
- [x] **8. Library and search** (13 Oct).
  - **One `describeCard(card, fields)`** names every list's tiles (it
    replaced two copies of the business-card-only logic):
    - a receipt shows shop · "BDT 432.60 · 12 Oct 2026";
    - a warranty shows product · "Covered until …" or "5 years of cover";
    - a business card is unchanged.
  - `CardSummary` carries `type`.
  - **Search** finds a receipt by its shop and a warranty by its serial, as
    indexed field text.
  - **Found while doing it:** Event Mode marked every scan as met at the
    event, receipts included.
    - `setKind` now drops Event Mode's encounter for any kind that is not a
      person's card. One the user typed stays.
    - The Plus people filters skip non-people cards.
  - **Tests:** `test/features/library_items_test.dart`, 5 of them.
  - 897 pass.
- [ ] **9. On the phone** (after M3 step 9):
  - scan a real receipt and warranty;
  - check light, dark and 1.3× text;
  - PLAN B2 ✅ and test steps for the owner.

  **Walked 15 Oct** with rendered sample papers (a STAR TECH receipt and
  an HP warranty) imported through the scanner: *What did you save?*,
  the review, *Saved as a receipt*, the note, the card with its chips,
  the total and date checked; light and dark. Release OCR read both (R8
  did not break it). **Left for the owner:** a real paper through the
  camera, and the phone at 1.3× text.

### M5 — B3 Linking and calculated expiry (started 15 Oct)

Started because M2, M3 step 9 and M4 step 9 all wait on the owner (the
commit, then the in-app backup); on 15 Oct there was still no backup in
Download or in `~/Dev/recallos-db-backups/`. Builds on v11 and B2 in the
working tree. The goal is PLAN §3's *Purchase* story: a receipt, then its
warranty; RecallOS suggests they belong together and says why; the user
confirms; the expiry is calculated and labelled so; a reminder is set.

Decisions made at the start (15 Oct):

- **The derived facts are kept in step by the repository**, not by the
  screens. Every `CardRepository` write that can change an input (reading,
  `setKind`, field edits, delete, restore, purge) ends by refreshing the
  card's links, the calculated expiry and the expiry date, so no screen can
  forget to.
- **A suggestion is never used as a fact.** Only a *confirmed* link lends
  the receipt's purchase date to the warranty.
- **A printed or typed expiry wins** over a calculated one; a calculated
  one is recomputed from scratch whenever its inputs change.
- **Expiry reminders do not count against the free five** (the generous
  answer `activeReminderCount` already gave): the user did not ask for them,
  and one should never be refused because of follow-ups. The owner can
  revisit this.
- **Undoing a confirmed link marks it dismissed**, not deleted, so the same
  suggestion does not come straight back.

- [x] **1. The matching rules** (15 Oct). Pure, so §6 can measure the
  false-link rate with the same code: `lib/core/linking/purchase_link_rules.dart`.
  - **Strong:** the warranty's serial printed on the receipt (0.95); the
    receipt's invoice number printed on the warranty (0.9). Found as whole
    words in order ("C02-XL0" in "S/N: C02-XL0", never "A15" inside
    "A150"), or squashed when eight characters or more. Short or digit-only
    numbers under five characters are not evidence.
  - **Weak:** the same purchase day (0.35), the warranty's model on the
    receipt (0.45), its brand (0.15), the receipt's shop on the warranty
    (0.2). Combined as independent evidence; suggested at 0.5, so one weak
    cue never suggests anything. Dates more than 3 days apart silence the
    weak cues and take 15% off the strong ones.
  - **Reasons** are stored as JSON (`{"cue","value"}`) and read as lines:
    "Serial 5CD3281XYZ is on both", "Both dated 12 Oct 2026".
  - **Tests:** `test/core/purchase_link_rules_test.dart`, 18 of them.
- [x] **2. The calculated expiry** (15 Oct). Pure: `warrantyExpiry()` in
  `lib/core/linking/warranty_expiry.dart`.
  - A printed or user-given expiry wins, labelled *Printed on the
    warranty* or *You confirmed it*. A derived one is never read back as an
    input.
  - Otherwise: the warranty's own purchase date, or a **confirmed**
    receipt's, plus the cover. The result is the **last covered day** (two
    years from 12 Oct 2026 holds through 11 Oct 2028), so an error makes the
    reminder early, never late.
  - It explains itself: "Calculated from the receipt's purchase date, 12 Oct
    2026, plus 2 years". A cover counting from installation or delivery
    adds "…so it may end later."
  - **Tests:** `test/core/warranty_expiry_test.dart`, 10 of them (31 Jan +
    1 month, a leap day, across a year end).
- [x] **3. Storing it** (15 Oct). `lib/features/warranty/data/purchase_links.dart`
  (`PurchaseLinks`).
  - **`refresh(cardId)`** works out again the card's suggestions and the
    expiry of every warranty it bears on.
    - `CardRepository` calls it at the end of `attachExtraction`, `setKind`,
      `updateField`, `addField`, `deleteField`, `removeBackImage`,
      `softDelete` and `restore`.
    - `purge` asks `warrantiesLeaningOn` first, because the links cascade
      away with the card.
  - **Suggestions:**
    - only *suggested* rows come and go with the evidence; confirmed and
      dismissed rows are never touched;
    - a matched warranty is offered no other receipt;
    - a card in the bin, or no longer a receipt or warranty, loses its
      suggestions.
  - **Actions:** `confirm`, `dismiss`, `unlink` (marks it dismissed and
    re-suggests), and `link` by hand (reason *You linked these*).
  - **The calculated `expiry_date`** is a field with
    `FieldProvenance.derived` (origin derived). It is never asked about in
    *check this*, because its inputs are. Lists say "Covered until … ·
    calculated".
  - **One `warrantyExpiry` important date per warranty**, on the last
    covered day, whether printed, typed or calculated. Its reminder
    (`expiryReminderTime`) is 9 AM a month before, else a week before, else
    that morning, else none. It is set only when the day is first known or
    moves, so a reminder already shown is never re-timed and shown again.
  - **Watched:** `watchLinks(cardId)` and `watchExpiry(warrantyId)` (the
    working, and when the reminder comes).
  - **Tests:** `test/features/purchase_links_test.dart`, 22 of them, all
    through the real repository:
    - receipt then warranty, and the other way round;
    - confirm, dismiss (survives re-reads), unlink, link by hand;
    - a corrected cover moves the end, the date and the reminder;
    - a corrected receipt date moves the warranty's end;
    - an unrelated edit leaves the reminder alone;
    - a typed expiry wins;
    - the receipt binned, restored, purged;
    - a warranty re-typed as a receipt;
    - a printed expiry; an expired warranty (date, no reminder);
    - it is not one of the free five, nor a next step.
  - 951 pass.
- [x] **4. The reminder itself** (15 Oct).
  - **`ReminderNotice.of`** (`local_notification_port.dart`, pure): a
    warranty's notice reads "Warranty ends in 30 days" / "in a week" /
    "tomorrow" / "today" over "HP Laptop · covered until 11 Oct 2028". It
    uses its own **Warranties** channel and has no Done or Snooze; a tap
    opens the warranty. A next step's notice is unchanged.
  - `PendingReminder` carries `dueOn`.
  - **The same bug fixed in both places that had it:** `_whoIs` (Today rows
    and reminders) and `CardDetail.title` (the card screen's heading) named
    a card from business-card fields only. A warranty's reminder would have
    said "A card", and a receipt's screen "Unread card". Both now use
    `describeCard`; a person is named only on a people card.
  - **Tests:** `test/features/reminder_notice_test.dart` (3), plus the
    reminder's title and due day and the receipt screen's title in
    `purchase_links_test`. 955 pass.
- [x] **5. The card screen** (15 Oct). The §18 design reasoning is in PLAN
  B3; it says Mobbin was not connected and lists the searches to run.
  - **New:** `lib/features/warranty/presentation/purchase_blocks.dart`
    (`PurchaseBlocks`, `CoverBlock`, `LinkBlock`, `PaperRow`) and
    `lib/features/warranty/data/purchase_link_providers.dart`.
  - **Placed** on the card screen (under the note) and on the capture
    review (above the fields).
  - **On a warranty, *Covered until*:**
    - the last day in roman serif, and one line of working;
    - the installation/delivery caveat; *This cover has ended.* in words;
    - *Reminder 9 AM on …*;
    - with notifications off, *Turn on notifications*: it asks, and opens
      settings when refused. Re-checked on resume.
    - With nothing known: a hint pointing at the link and the fields.
  - **On a warranty, *Its receipt*:**
    - a suggestion asks *Is this its receipt?* (serif italic), shows the
      receipt as a row that opens it, and lists its reasons;
    - *Yes, link them* (ink) / *Not this one* (outline, Undo);
    - once linked: the receipt and *Unlink* (Undo).
  - **On a receipt, *Its warranty*** appears only when there is a link or a
    suggestion.
  - **The same "this is a business card" fault, fixed everywhere it showed
    on these screens:**
    - *Where you met* now shows on people's cards only;
    - the headings say *On the receipt* / *Found on the warranty* /
      *Other text on the receipt* (`paperNoun`);
    - every printed field's chip said *ON THE CARD* on a receipt; it now
      names the paper (`SourceChip.paper`).
  - **Tests:** `test/features/purchase_blocks_test.dart`, 9 widget tests
    that tap and then check the wallet: Yes links; Not this one dismisses
    and Undo re-offers; Unlink and Undo; the picker; an empty picker; the
    notifications way out (asked once, then settings); none shown when on;
    a receipt alone (no warranty block, no *Where you met*, no *on the
    card*); a receipt confirming its warranty.
  - **Found by the tests:** a list scrolled down to a button does not build
    the blocks above it. The tests use a tall viewport rather than assert
    on what was never built.
- [x] **6. Linking by hand** (15 Oct). `PurchaseLinks.linkCandidates`
  lists live receipts not already linked, the warranty's own purchase day
  first, then newest. *Link its receipt* opens *Which receipt is it?*
  (`LinkPickerSheet`). With no receipts it says what to do; Cancel changes
  nothing. A hand link is stored as confirmed with *You linked these*.
  Tested in `purchase_blocks_test`. 964 pass.
- [x] **7. On the phone** (15 Oct): the sample receipt and warranty,
  suggested on the serial, confirmed, *Covered until 11 Oct 2028 ·
  calculated*, the reminder in `dumpsys alarm` for 11 Sep 2028 09:00 —
  and cancelled when the warranty was deleted. Light and dark on the
  phone; 1.3× in renders only (see M4 step 9).
  - **Already checked without the phone (15 Oct):** the warranty screen
    was rendered with the bundled fonts in a throwaway test, in six states
    (suggested and linked; light, dark, 1.3×; notifications off). That
    found and fixed: the header said *CARD*; the empty note said "find this
    card when you have forgotten the name"; the delete dialog said "Delete
    this card?"; the field editor said "Or take it from the card"; a date
    broke mid-phrase; the bell sat between two lines at 1.3×. Still for the
    phone: real photographs, a real notification, and the review screen
    right after a scan.
  - **Known, small:** at 1.3× "Reminder 9 AM on Thu, 14 Sep 2028" can put
    the year on its own line (`reminderWords`, shared with next steps).

### M6 — B4 Spending totals (started 15 Oct)

Started because M2, M3 step 9, M4 step 9 and M5 step 7 all still wait on
the owner. Builds on B2's typed receipt facts (`amount_minor`, `currency`,
`date_value`) in the working tree. The goal is PLAN §4 B4: exact sums from
receipts the user has checked, by period, category and shop, one currency
at a time; anything unchecked, and anything that looks like a second copy,
listed apart and never added. Free: this month's total. Plus: other months
and years, shops and categories (`business/STRATEGY.md` §2). **Mobbin is not
connected**, so the screen follows the fallback in `design/UX-PROTOCOL.md` §1.

Decisions made at the start (15 Oct):

- **Counted** means the total *and* the date were confirmed by the user
  (they are B2's two critical receipt fields), the total was read as an
  amount with a currency, and neither has an open objection. Anything else
  is listed under *Not added yet* with what to do ("Check the total"), and
  opens the receipt where *check this* is waiting.
- **No date, no month.** A receipt without a date is listed in every view
  under *No date*; it is never placed by the day it was scanned.
- **A possible second copy** has the same currency and amount, the same
  day, and shops and invoice numbers that do not disagree. The first one
  saved is counted; a later one is listed with its reasons and two answers:
  *Bin this copy* (soft delete, Undo) or *Count both* (kept as a dismissed
  `duplicateOf` row in `item_links`, so it is not asked again).
- **A category stays a guess** until the user confirms it; a category row
  says how many of its receipts are guessed.
- **Free** sees this month with all of its lists: what is not counted, and
  why, is never behind Plus. **Plus** adds other months, years, shops and
  categories.
- **Wording:** "BDT 8,450.00 in saved receipts", never "spent" (PLAN §5).

- [x] **1. The totals, pure** (15 Oct): `lib/core/spending/spending_totals.dart`.
  - `ReceiptFacts` carries each critical fact's `FactState` (missing,
    unreadable, unchecked, checked) and says what to do in words: "Check
    the total and the date", "Add the total and check the date".
  - `SpendingSummary.of(receipts, period, currency, focus)`: the exact sum
    of the counted receipts in one currency (the one with the most receipts
    first; a tie goes to taka); *Not added yet* by the date as read; *No
    date* in every period; possible copies; groups by shop (one shop
    however it is written, "Ltd" dropped), by category (with how many are
    guessed), and by month for a year. A focus narrows the total and every
    list, not the groups it is picked from. `scope` says "1–31 Oct 2026 ·
    7 receipts you checked".
  - `findCopies` / `copyReasons`: same currency, amount and day; a shop or
    an invoice number that differs settles it, a missing one does not; the
    first saved is counted and a copy of a copy points at the original.
  - **Tests:** `test/core/spending_totals_test.dart`, 23 of them (0.10 +
    0.20 is exactly 0.30, a bracketed refund, month edges, a leap February,
    a year by month, currencies kept apart, every copy rule, the focus).
- [x] **2. Reading the wallet** (15 Oct):
  `lib/features/spending/data/spending_repository.dart`.
  - `SpendingRepository.watchReceipts()` (and `receipts()` once): live
    receipts and invoices, not in the bin, read in three queries rather
    than one per card. `receiptFactsProvider` streams them.
  - `receiptFactsOf(card, fields)`: a total or date is *checked* exactly
    when its screen stops saying *check this* (confirmed, current, no
    objection); read but not as an amount or a day is *unreadable*. A
    confirmed field is preferred, then the front's.
  - **The one stored answer:** `LinkKind.duplicateOf`, kept *dismissed*
    in `item_links` by `countBoth(card, others)` ("two purchases");
    `undoCountBoth` removes it. `lookAlikes` answers for every look-alike
    at once. B3's link queries now name `warrantyOf`, so such a row can
    never be read as a warranty link.
  - **Tests:** `test/features/spending_repository_test.dart`, 10 of them,
    through `CardRepository`: held back until both are checked; a
    corrected total; a typed total; the bin and back; re-typed as a
    business card; a receipt scanned twice (Count both, Undo, surviving
    B3's refresh); binning the copy; never a warranty link; the stream
    following a check; a confirmed category. B3's 31 and the backup and
    migration suites still pass.
- [x] **3. Design reasoning** (15 Oct): §18 in PLAN B4. Mobbin was not
  connected (no Mobbin tool in this session); it lists the six searches to
  run.
- [x] **4. The screen** (15 Oct):
  `lib/features/spending/presentation/spending_screen.dart`, route
  `Routes.receiptTotals` (`/receipts`).
  - The figure in roman serif (scaled down, never wrapped), "in saved
    receipts", and the scope. Nothing counted says so in words, and how
    many are waiting.
  - *Possible second copies*: *Is this a second copy?*, the receipt (opens
    it), its reasons, *Yes, bin this copy* / *No, count both*, each with
    Undo. *Not added yet* and *No date*: each row says what it read and
    what to do, in ochre ink, and opens the receipt. *Counted*: date,
    category ("(guess)"), amount; opens the receipt.
  - Currency chips only when a period holds more than one.
  - **Free:** *This month · October 2026*, every list, and one row, *Other
    months, shops and categories*, that opens Plus. **Plus:** arrows (none
    past today), Month / Year, *By month* (a year), *By shop*, *By
    category* (largest five, then *Show all n*); a row narrows the figure
    and the lists, *Show every shop* undoes it. Refunded while elsewhere:
    back to this month. Checking: no upsell is flashed.
  - Loading is a ghost; an empty wallet's action scans one.
  - **Tests:** `test/features/spending_screen_test.dart`, 8 that tap: the
    empty state opens the scanner; free figure, scope and held-back lists,
    with no arrows and a held-back row opening its receipt; the Plus row
    opens Plus; nothing counted; Count both (the figure doubles, a
    dismissed `duplicateOf` row) and Undo; Bin this copy (tombstone) and
    Undo; a currency chip; with Plus, the month before, the year by month,
    a shop focus and back.
- [x] **5. The way in** (15 Oct).
  - **Home:** `_ReceiptsRow`, under the Today row, only while the wallet
    holds a receipt; quiet card chrome, no marker colour.
    `homeReceiptsWords`: "BDT 8,450.00 in receipts this month", "… + 1
    other currency this month", "1 receipt this month to check", else
    "Receipt totals". Opens the totals.
  - **Plus screen:** *Receipt totals for any month* under *Plus adds*
    (opens them), and *Receipts, warranties and this month's total* under
    *Always free* — the exact entitlement, published before purchase.
  - **Tests:** `test/features/spending_home_row_test.dart` (5: the words;
    no row for business cards; the figure, tapped, opens the totals; an
    unchecked receipt waiting) and a sixth in `plus_screen_test` (the row
    opens the totals).
  - **Found by the suite:** the new Plus row pushed the buy button past
    what the Plus list builds, so three of its tests could not find it,
    and the key-less one would have passed without looking. They now
    scroll to it as a person would.
- [x] **6. Rendered check** without the phone (15 Oct): the screen drawn
  with the bundled fonts in a throwaway test (deleted after), free and
  Plus, light, dark and 1.3×, with a copy, an unchecked receipt, an
  undated one, two currencies and a long shop name. Found and fixed:
  - **at 1.3× "STAR TECH & ENGINEERING LTD" broke as "ENGINEE / RING"**
    beside its amount. `_SumRow` measures the longest word and moves the
    amount under the name when it would not fit. Pinned by a test that
    fails on the old layout;
  - **the order:** with Plus, the breakdowns pushed the held-back
    receipts far below the figure. What is not in the figure now comes
    straight after it, then the breakdowns (or the Plus row), then
    *Counted*. PLAN's reasoning says so.
- [ ] **7. On the phone** (after M3 step 9): real receipts checked, counted,
  a copy binned, a currency switched; light, dark, 1.3×. Then PLAN B4 ✅
  and test steps for the owner.

  **Walked 15 Oct:** *Not added yet* with *Check the total and the date*,
  the total and date checked, then counted (*BDT 78,500.00 in receipts
  this month* on Home) and asked. **Left:** a copy binned and a currency
  switched, with the owner's real receipts.

### M7 — B5 Ask RecallOS across people and purchases (started 15 Oct)

Started after M6 because every phone step waits on the owner. On 15 Oct
Claude Code's safety check also refused `adb install` over the phone app (and
refused writing a script for the owner to run it), so the B1–B4 phone walk
needs the owner to allow `adb install` or install it themselves. The APKs and
a copy of the installed 7 Oct app are in `~/Dev/recallos-db-backups/`.

Ask is the home search box: `planQuery` turns a question into a typed plan
and `SearchRepository.ask` carries it out (A6 built the people plans). B5
adds the purchase questions of PLAN §3, typed plans only, never generated
SQL. Each answer states its scope, cites its papers, and says plainly when it
cannot answer.

Decisions made at the start (15 Oct), from `business/STRATEGY.md` (Ask: free
gets lookup and search with sources; Plus gets date and aggregate queries):

- **"When does my laptop warranty expire?"** is a lookup: **free**. It
  answers with the end, how it is known, and both papers (the warranty, and
  its receipt when linked).
- **"What expires in the next 90 days?"** is a date query: **Plus**. Free
  users get the words searched and one line that opens Plus, as A6's people
  filters do.
- **"How much did I spend on electronics this month?"** is an aggregate:
  **Plus**, except this month's plain total, which the free Receipt totals
  screen already shows. Ask never hides what a screen gives free. Worded
  "in saved receipts", never "spent".
- **Cannot answer = says so:** no warranty matches, an end not known yet,
  a period in the future, a week (totals go by month or year).

- [x] **1. The planner** (15 Oct). `WarrantyPlan`, `ExpiringPlan` and
  `SpendingPlan` in `lib/core/search/query_plan.dart`, checked after A6's
  people filters and before lookups.
  - **Warranty:** needs the word *warranty* (or *guarantee*) and names a
    thing: "When does my laptop warranty expire?", "is my fridge still
    under warranty", "AC er warranty kobe shesh". A word like *service*,
    *repair* or *claim* makes it a need, searched as words.
  - **Expiring:** an end word and nothing named. "Next 90 days", "within
    3 months", "this month", "next month", "this year"; with no window,
    the next 90 days. *What has expired* means already over; *my
    warranties* means all of them.
  - **Spending:** *spend*, *spent*, *spending* or Banglish *khoroch*;
    "how much" with *paid*, *cost*, *on*, *at* or *from*; or "receipts
    total". Not *expense*, and not "Total" alone. The period is this
    month, last month, this or last year, a named month (the latest one
    not in the future) or a year, plus Banglish *ei mash* / *gato mash*.
    *This week* and *today* are kept as unsupported, to be said back. The
    focus is what is left; *at* or *from* means a shop.
  - **Tests:** 5 more in `test/core/query_plan_test.dart` (16 in all):
    each kind with its variants, eight needs that stay searches, and A6's
    plans unchanged.
- [x] **2. Answering** (15 Oct). `lib/features/ask/data/purchase_answers.dart`
  (`PurchaseAnswers`). It reads, never writes, and nothing is worked out a
  second way: the answers are the same figures the card screen and the
  Receipt totals screen show.
  - **`warranties(subject)`:** live warranties where every word asked is on
    the warranty (title, product, brand, model, serial, note), with common
    other names ("fridge" finds *Refrigerator*, "AC" finds *air
    conditioner*). Every match is listed, with its end
    (`PurchaseLinks.expiry`, a new one-shot form of `watchExpiry`) and its
    confirmed receipt.
  - **`expiring(plan)`:** what ends in the window, soonest first; already
    over, most recent first; every warranty, with unknown ends last.
  - **`spending(plan)`:** B4's `SpendingSummary` for the period, narrowed to
    a category (with other names: groceries/bazar, health/medicine…) or,
    after *at*, a shop. It says why instead for a week, a period still to
    come, or a shop or category with no receipts.
  - **`SearchAnswer`** gains `warranties`, `expiring`, `spending` and
    `cannot`. In `ask()`: a warranty question is free, and with no match
    says *No saved warranty matches “car”.* above the searched words.
    Expiring is Plus. A total is Plus unless it is this month's plain
    total. Without Plus, the words are searched and `plusNeeded` is set.
  - **Tests:** `test/features/ask_purchases_test.dart`, 15 through the real
    repositories: §3's *Purchase* story (end calculated, both papers cited,
    not listed twice); free lookup; an unknown end; fridge→refrigerator; no
    match; the 90-day window, next month, an empty window that is still an
    answer, already ended, every warranty; Plus offered; §3's *Memory* story
    (electronics this month, exact, "1 receipt you checked"); the free
    month; a shop; an unchecked look-alike held back; and the three
    cannot-answers. 1,033 pass.
- [x] **3. Design reasoning** (15 Oct): §18 in PLAN B5. Mobbin was not
  connected; it lists the five searches to run.
- [x] **4. The answers on home** (15 Oct).
  `lib/features/ask/presentation/ask_answers.dart`, placed by
  `home_screen.dart` in A6's answer slot.
  - **`WarrantyAnswers`:** per warranty, *Covered until*, the day in roman
    serif, how far off ("In about 24 months"), its working, the reminder,
    then *From* with the warranty and its receipt as B3's `PaperRow`s.
  - **`ExpiringAnswers`:** headed *Ends in the next 90 days* (or *Already
    ended* / *Every warranty*) with a count; one row per warranty with its
    day, how it is known and how far off. An empty window is a sentence.
  - **`SpendingAnswerBlock`:** the figure (scaled, never wrapped), *in
    saved receipts*, the scope, up to three receipts as rows, and
    *n not added yet · see Receipt totals*.
  - **`CannotLine`** where a question cannot be answered.
  - `PlusFilterLine` takes its sentence: *Questions about dates come with
    RecallOS Plus*; *Totals by category, shop and other months come with
    RecallOS Plus*.
  - **Tests:** `test/features/ask_home_test.dart`, 8 that type and tap:
    the warranty answer (both papers; the receipt opens); no such
    warranty; the 90-day list with Plus (the iron opens); the Plus line
    for a date question and for a category total (each opens Plus); the
    electronics total with Plus (no "spent" anywhere; its receipt opens);
    the free month (what was not added opens Receipt totals); a week
    cannot be totalled. 1,041 pass.
- [x] **5. Rendered check** (15 Oct), with the bundled fonts in a throwaway
  test (deleted afterwards). Eight states: the warranty answer in light,
  dark and 1.3×; the 90-day list with and without Plus; the electronics
  total; the month's total in dark at 1.3×; the week that cannot be
  totalled. **Found and fixed:**
  - at 1.3× the way to Receipt totals was cut off ("see Rece…"). It is now
    a row that wraps.
  - a free date question listed receipts and business cards that only
    shared a word. Without Plus the words are now searched among
    warranties only (receipts only, for a total).

  **Noticed, not B5's:** A6's *why* block can mark a stop word as the match
  ("From **the** purchase"). For the UX pass (M7½).
- [x] **6. An Ask question set** (15 Oct): `test/eval/ask_question_set_test.dart`.
  20 questions (§3's *Purchase* and *Memory* stories, Banglish, five that
  must decline, A6's people questions) with the plan each should become and
  the papers it must cite, no more and no less. Scored as plan accuracy,
  source correctness and abstention; it prints one line. On the invented
  fixture wallet: plans 20/20, sources 13/13, abstentions 5/5. That is a
  regression check, **not a §6 result**: the report's figures come from the
  same scoring over questions written against the owner's labelled wallet
  (M8). 1,042 pass.
- [x] **7. On the phone** (15 Oct), by typing them:
  - **Person:** Nusrat Jahan's screen shows *Why you saved them* and both
    next steps; "sound system for the fest" finds her first, her note
    highlighted.
  - **Purchase:** "When does my laptop warranty expire?" → *Covered until
    11 Oct 2028*, calculated, both papers cited (light and dark).
  - **Memory:** "how much did I spend this month" → BDT 78,500.00 with its
    receipt.

  Not in airplane mode: Wi-Fi was on, but the build carries no
  `INTERNET` permission (M8–M9 item 7), so it had no way to use it. The
  airplane-mode run stays in M9's final checks.

### M7½ — UX pass over the core flow (started 15 Oct)

Done in the release-first chat at the owner's request. Follows
`design/UX-PROTOCOL.md` §17 and §21. **Mobbin is not connected** (no Mobbin
tool in this session), so no Mobbin screen was inspected; the searches to run
are in PLAN's M7½ reasoning.

**The audit:**
- the installed 7 Oct build walked on the phone by screenshots (home, a
  search, a card, People, a person, Today, the scanner and back);
- B2–B5's screens rendered in tests (B3 and B5 checks);
- a code search for Material left over.

**What already works and stays:**
- everything is on the design system;
- the dialogs, snackbars and sheets that are still Material are themed
  in paper by `app_theme.dart`;
- search answers with their why;
- Today;
- cancelling a scan returns cleanly to home;
- the scanner is Google's own and cannot be restyled.

Checklist, by §21's order (a box is ticked with the test that proves it):

- [x] **1. Onboarding says only what is true.** *(15 Oct; page 2 is now titled "The camera, and little else")* Page 2 claimed the camera
  "and nothing else", but A2 asks to show notifications when a reminder
  is set. Page 1 names receipts and warranties, which the same Scan now
  reads.
- [x] **2. Home gives answers room while you type.** *(15 Oct; `ClipRect` + `AnimatedAlign` as in the profile editor, and hidden from screen readers while folded)* The *What do you need?*
  heading kept a quarter of the screen, so only one answer showed above
  the keyboard. It folds away while there is a question and comes back
  when the field is cleared.
- [x] **3. One Scan button, named for what it does.** *(15 Oct; *Scan*. The empty wallet and Event Mode keep *Scan a card*, where it is a card.)* It said *Scan a card*,
  but since B2 it saves receipts and warranties too.
- [x] **4. The card screen leads with what you came to do.** *(15 Oct; a card with nothing to call, mail or map has no row and no gap)* *Call*, *Say
  hello* and the rest sat under three blocks, at the bottom edge of the
  screen. They move straight under the title.
- [x] **5. A person shows why you kept them.** *(15 Oct; *Why you saved them* with each card's note, then the open next steps, soonest first; every line opens its card; with nothing written, a line that opens the card to write it)* The person screen had the
  business details and the card, but not the note ("AC servicing before
  summer") or the next step, the two things RecallOS is for.
- [x] **6. Numbers read the way they are written.** *(15 Oct; `PhoneExtractor.display`, display only, used by field rows, the person screen, lookup answers, list tiles and My Card's QR lines; the two field-editor tests now tap the number as shown)* A Bangladeshi mobile is
  shown as `01711-223344`, not `01711223344`, everywhere a number is shown.
  Only mobiles are regrouped; other numbers are left exactly as stored.
- [x] **7. Today shows warranties ending soon.** *(15 Oct; `watchWarrantyEnds` / `warrantyEndsProvider`; *Ending soon* lists ends in the next 30 days as "Covered until 20 Oct · ends in 19 days", picked against the clock at build time; later and ended ones are left out; each row opens the warranty)* A warranty's end only
  reached the user as a notification. Today gains *Ending soon* (the next
  30 days), each opening the warranty.
- [x] **8. One name for people.** *(15 Oct; *People* on the list and the home button's tooltip, *Person* on one; "Save to contacts" keeps its name, because it means the phone's own Contacts)* The list's header said *Contacts* under a
  *People* section.
- [x] **9. The *why* never marks a stop word** *(15 Oct; `explainMatch` skips English and Banglish stop words unless the query has nothing else, and with no other word it says *Similar meaning*; A6's ranking is unchanged)* ("From **the** purchase").
- [x] **10. The date picker in paper.** *(15 Oct; `DatePickerThemeData`: a paper card, the serif date, the chosen day filled ink, or ochre in dark (rule 2), today ringed in ochre)* `showDatePicker` fell back to
  Material's defaults: add a `DatePickerThemeData`.
- [x] **11. Rendered check** (15 Oct), with the bundled fonts in a
  throwaway test (deleted afterwards), ten states:
  - home idle and searching;
  - the card in light, and in dark at 1.3×;
  - the person in light, and in dark at 1.3×;
  - Today with *Ending soon*;
  - onboarding page 2;
  - the date picker in light and dark.

  All read as intended. At 1.3× in dark the card's action pills wrap to a
  second line, which is fine.

  **Fixed afterwards (15 Oct):** Material's date picker wrote its header
  US-style ("Fri, Oct 16"). The app now runs in GB English
  (`flutter_localizations`, part of the SDK; `kAppLocale` in `main.dart`),
  so it reads "Fri 16 Oct". Test 10b in `ux_pass_test.dart`. Only that
  entry was added to `pubspec.lock`: a scratch resolve without it matched
  line for line.
- [x] **12. On the phone** (15 Oct), with B1–B5's walks. Seven faults
  found and fixed, each with a test (`ux_pass_test.dart` unless named):
  - **typing in search lost the field** after the first letter: the
    heading fold changed the widget tree, so a new field took focus. A
    fixed-height gap keeps the same `EditableTextState`;
  - **Save was cut to "Sa…"** on the review: *Retake* no longer takes
    half the row;
  - **the note sheet opened light over the dark camera screen**: sheets
    from capture take the capture theme;
  - **the note hint said a card's line** on receipts and warranties
    (`noteHintFor`);
  - **thumbnails showed a blurred stand-in beside the photo**: the stand-in
    now shows only until the first frame (`StandInImage`);
  - **Home's rows cut their text** at one line: two lines, 52 px floor;
  - **the keyboard came back by itself** after the scanner or any screen
    opened from Home: Home drops focus before it navigates.

  Found while closing the walk, also fixed:
  - **Your card showed "01711111111"**, the one place phones were not
    grouped (`typeset_card.dart`; `my_card_test.dart`);
  - **Appearance and Lock after did not mark the choice in use**: both are
    now one `ChoiceSheet` with *In use* on the current row
    (`choice_sheet_test.dart`).

  **Tests:** `test/features/ux_pass_test.dart`, 10 that tap and measure:
  - onboarding;
  - the heading folding and coming back;
  - *Scan*;
  - *Call* above the note;
  - the person's note and next step, each opening its card, and the way to
    write one;
  - `01711-223344` on the card and the person;
  - *Ending soon*, its window and its tap;
  - *People* / *Person*;
  - the date picker's colours against rule 2.

  Also 2 formatter tests in `phone_test.dart` and 3 in
  `match_evidence_test.dart`. 1,057 pass.

### M8–M9, the app side (started 15 Oct)

The owner asked to leave Play and the testers aside and finish the app.
What is left that needs nothing from the owner: say exactly what the app
does wherever it is described, prove the §3 stories end to end, and have
the §6 measurements ready to run the moment labelled data exists.

- [x] **1. Plus names everything it unlocks** (15 Oct). B5's date and total
  questions were Plus but unlisted: the screen gains *Ask about dates and
  totals*. *When a warranty ends, and its reminder* is listed as always
  free. Test in `plus_screen_test.dart`.
- [x] **2. The privacy policy covers Release B** (15 Oct,
  `docs/privacy-policy.html`, "Last updated 15 October 2026"):
  - receipt and warranty data, confirmed links and calculated ends;
  - warranty reminders and their own channel;
  - reading and Ask are done by fixed rules on the phone;
  - still no generative AI, nothing collected, no network.
- [x] **3. The store text covers Release B** (15 Oct, `store/listing.md`,
  3413/4000): *Receipts and warranties*, *Ask in your own words*, and the
  Plus paragraph brought up to date (it still said only "no reminder
  limit"). Marked in the file as checked against the tests, not yet on the
  phone. Walk it before pasting.
- [x] **4. PLAN §3's three stories, end to end** (15 Oct):
  `test/stories/section3_stories_test.dart`.
  - **Person:** scan → note "esports sponsorship" → met at → hello (the
    note stays private) → a reminder Android holds → "Who was interested in
    sponsorship?" finds them first.
  - **Purchase:** receipt and warranty → suggested on the serial →
    confirmed → the end calculated, labelled, and reminded → "When does my
    laptop warranty expire?" cites both.
  - **Memory:** "How much did I spend on electronics this month?" (BDT
    78,500.00, its receipt, its scope) and "What expires in the next 90
    days?".

  1,061 pass. The phone run in airplane mode is still owed (PLAN §9).
- [x] **5. §6 measurement harnesses**, ready for labelled data (15 Oct).
  - **OCR, receipt and warranty fields, classification:**
    - the bench run (`spike_runner.dart`) now reads like capture
      (`readDocument`) and records the kind and its confidence;
    - `lib/core/eval/ocr_scoring.dart` scores a bench export against
      hand-written labels: CER, field F1 by script and by `group`
      ("thermal"), and the classifier's accuracy, per-kind F1, macro-F1
      and confusion (`ClassificationScorer` in `metrics.dart`);
    - labels are written as printed and normalised by the app's own
      `validateField` ("432.60" → 43260);
    - it runs in `test/eval/ocr_score_test.dart`, skipped unless
      `RECALLOS_OCR_RESULTS` and `RECALLOS_OCR_LABELS` name the files.
      `tool/spike/score.dart` still scores cards from plain Dart.
  - **Retrieval, Ask, links, over the real wallet on the phone:** the bench
    screen's *Run a question set* picks a labels file
    (`lib/core/eval/question_set.dart` has the format; papers are named by
    the title the lists show) and runs `EvalRunner`:
    - P@3, MRR, NDCG@3 and latency for lexical, semantic and hybrid;
    - Ask answers citing exactly the right papers
      (`SearchAnswer.citedCardIds`), right abstentions and wrong refusals;
    - link-rule precision, recall and false links
      (`PurchaseLinks.ruleSuggestions`);
    - it reads only, shows the table and shares a JSON report through the
      outbox (removed within a day). Titles not in the wallet are listed,
      not guessed.
  - **Tests:** `test/eval/ocr_score_test.dart` (1 and a skipped real run),
    `test/eval/question_set_test.dart` (3), and 2 in `metrics_test.dart`.
  - **Still needs the owner:** the labelled cards, receipts and questions.
    Then: the bench APK (`--dart-define=RECALLOS_BENCH=true`), *Pick cards
    and run* and *Run a question set* on the phone, and the scoring.
- [x] **7. The release artifact checks, on the laptop** (15 Oct), on a
  bundle built with the upload key from the uncommitted tree (stamped
  `0940360-wt`; a check build, never uploaded):
  - `tool/ci/check_permissions.sh`: the eight allowlisted permissions, and
    **no `INTERNET`**;
  - backup off (`allowBackup=false`, `fullBackupContent=false`);
  - target 36;
  - every native library passes 16 KB alignment;
  - signed by the upload key (`CN=Arafat, OU=RecallOS`).

  **On the phone (15 Oct):** a release APK built the same way read both
  sample papers, so R8 did not break OCR this time. Before any upload, the git
  chat commits, `version:` goes to `1.0.0+2`, and the bundle is rebuilt and
  stamped with the real SHA.
- [x] **6. B8 decided** (15 Oct): keep `tags`, `subject_tags`,
  `search_queries` and `search_feedback`, empty and documented in
  `tables.dart`.
  - Dropping them costs a migration.
  - Writing raw queries would put sensitive text in every backup.
  - §6 no longer needs a query log: the question set replaces it.
  - `tags` is reserved for Release C.

## What's left, in order

### Waiting on others (check at the start of each chat)

1. **Testers opting in.** Play Console → Closed testing - Alpha shows the
   count. 12+ must stay opted in for 14 continuous days. Nudge anyone who
   hasn't joined. More testers would widen a two-person margin.
   **13 Oct: 3 of 14 opted in** — the ~21 Oct date is gone. Earliest now is
   14 days after the 12th tester opts in.
2. **Apply for production access** the day the 14 days are complete (~21 Oct
   at the earliest). Publish v2, which is stable and has no migration.

### Release-first plan (proposed 15 Oct, waiting for the owner's "start")

The publish date is set by Google, not by the code: 12 testers opted in for
14 continuous days, then the production review. On 13 Oct only 3 of 14
had opted in, so the clock has not started. Everything below runs inside
that wait, in this order:

1. **Make the work safe.** Commit the 8 days of uncommitted work (A6,
   B1–B4, docs), merge GitHub's PR #1, CI green, push. Owner: the in-app
   backup.
2. **Start Google's clock (owner, today).** Get 12+ testers actually
   opted in, with a margin of 3–5 extra; re-check daily.
3. **Walk what is built on the phone.** *(Done 15 Oct with sample papers,
   except a real receipt and warranty, 1.3× and B4's copy and currency.)*
   Rehearse v11 on the backup, install,
   walk B1–B4 with real receipts and a warranty, fix what the walk finds.
   Ship versionCode 2 to Internal and Alpha. Run A7's real Play purchase
   test on the Play-installed build (if it fails, hide Plus; it does not
   block the release).
4. **Finish the build.** B5 Ask RecallOS, then the UX pass (M7½). Ship to
   testers each time something lands.
5. **Evaluation in parallel** (§6): harnesses built by Claude; labelled
   cards and receipts, the SUS survey and interviews by the owner.
6. **Apply for production the day the 14 days are complete.** Freeze while
   the review runs: regression, the three §3 stories in airplane mode,
   permissions, listing, screenshots, privacy policy and Data safety for
   receipts. Publish (the owner's click) when approved. Anything not walked
   on the phone by then is hidden, not shipped half-done.

### The order of work (no fixed dates — as fast as possible, 7 Oct)

Each milestone gets its own checklist under *Now working on* when it starts,
and the next one starts as soon as it is done. The design for M1 and M3 is in
`docs/PLAN.md` §4. Target: the complete app, ready well before the ~20 Nov
public launch.

| # | Milestone | To testers / Play |
|---|---|---|
| M1 | ✅ A6 people search (7 Oct) | in the next update |
| M2 | versionCode 2 (A6). **A7 finish** on a Play-installed build, with the owner: licence-test purchase, refund, restore after reinstall, promo code | v2 to Internal and Alpha |
| M3 | B1 schema v11, in place. Rehearse on the phone's **in-app backup** first; the phone's build is not debuggable, so `run-as` cannot copy the database | — |
| — | When the 14 days are up (~21 Oct): **apply for production access**, but don't publish yet | A8 |
| M4 | B2 receipts and warranties (needs the owner's real samples) | update to testers |
| M5 | B3 linking and calculated expiry — **built 15 Oct**, phone walk waits on M3 step 9 | — |
| M6 | B4 spending totals — **built 15 Oct**, phone walk waits on M3 step 9 | update to testers |
| M7 | B5 Ask RecallOS | update to testers |
| M7½ | **UX pass over the core flow** (decided 7 Oct), following `design/UX-PROTOCOL.md` §21: onboarding, home, scanner, OCR review, save, people, person detail, search (A6's UI included), Ask. Release B's new screens follow the protocol as they are built | update to testers |
| M8 | §6 evaluation: OCR (needs the 30+ labelled cards), retrieval P@3 / MRR / NDCG, receipts, SUS survey, Play numbers | — |
| M9 | Freeze: fixes and the three §3 stories, airplane mode | final AAB |
| M10 | **Public launch, as soon as Google allows** (15 Oct: no target date) | production |

Shipping an update, every time:
- bump `version:` in `pubspec.yaml`;
- follow `docs/RELEASE.md`;
- the owner drags the AAB into Play Console, because the extension cannot
  upload more than 10 MB;
- re-check the delivered permissions afterwards.

Cuts if time runs short, in order: generative anything, line items,
multi-page receipts, the Plus people filters. Never cut: security, recovery,
critical-field review, the primary retrieval, billing correctness, or the
evaluation.

### Known defects and clean-ups

- ~~**B8:** unused scaffolding~~ — decided 15 Oct (M8–M9 item 6): kept,
  empty and documented in `tables.dart`.
- A card for a brand named after a place keeps its old company and address
  after the shop-card fix. It is fixed by hand on the card screen.

### Only the owner can do these (`docs/PLAN.md` §8)

- A written agreement with the group partner **before anything is sold**, and
  which parts the partner owns.
- **15% service-fee enrolment** in Play Console (otherwise Google takes 30%),
  and bank details for payouts.
- Back up the upload keystore and its passwords in two places off this laptop.
- Hand-label 30+ cards for the OCR evaluation, as soon as you can.
- Collect 10–20 real receipts and warranties **before M4 starts**, so B2 has
  real documents to build against. Label them before M8.
- Be there with the phone for M2's Play-build purchase test.
- A System Usability Scale survey form for the testers (M8).
- 15–20 interviews with independent professionals and small agencies.
- **At launch:** take the testers off licence testing if any of their Plus
  purchases should count as real sales.

## How we work (rules in `CLAUDE.md`)

- **Chats never run `git commit` or `git push`.** A separate git chat commits.
  End each chat with the changed files and a suggested commit message.
- **After each feature:** mark it done in `docs/PLAN.md`, update this file, and
  give the owner steps to test it on their own phone.
- **UI/UX work** follows `design/UX-PROTOCOL.md`.
  - **Mobbin:** an official connector exists, but is **not connected yet**
    (7 Oct). Until it is, say so, and list the searches to run instead.
  - **The A6 search UI** predates the protocol; review it in the first UX
    pass.
- **Format only the files you changed** (`dart format <paths>`), never
  `lib/` or `test/` whole: HEAD is not formatted with the current SDK, and a
  tree-wide run rewrites dozens of untouched files.
- **Phone:**
  - install with `adb install -r`, never `flutter run`;
  - phone builds use `RECALLOS_ALLOW_DEBUG_SIGNING=true`;
  - back up the database before any migration;
  - close the app with `am stop-app`, not `force-stop`, which cancels the
    reminder alarms.
- **Play Console and Gmail are signed in in Brave** and reached through the
  Claude in Chrome extension.
- **The owner's own clicks:**
  - accepting terms needs an explicit OK;
  - activating a product for sale must be clicked by the owner;
  - so must uploads over 10 MB.
- **Play Console:** keep one tab per release draft — two tabs on the same
  draft make Save spin forever.

## Session log

One short entry per chat, newest last. The details live in `docs/PLAN.md`.

- **28 Sep – 2 Oct** (earlier chats):
  - CSE499B plan written; baseline frozen; F1–F4 built;
  - A1 next steps and where-you-met, and A2 reminders and Today, built on
    schema v10;
  - store listing assets made;
  - two side sessions fixed shop-card taglines and address matching.
- **3 – 7 Oct** (one long chat):
  - A1/A2 walked on the phone (a real reminder, snooze, done, cold-start tap);
    the reminder-time mismatch fixed; *Finished recently* added.
  - A3 Say hello, A4 My Card QR and A7 RecallOS Plus built and walked.
  - The two side-session fixes merged and walked (contact graph rebuilt under
    rules 5).
  - A5 Event Mode built early. A Plus-preview evaluation build was added for
    walking paid features.
  - Play Console:
    - app created; payments profile; licence key; upload key;
    - listing and all App content declarations;
    - first upload to Internal testing; Plus product; reviewer promo codes;
    - closed test set up, approved 6 Oct; testers invited by email 7 Oct.
  - This file was created, and `CLAUDE.md` now requires keeping it current.
- **7 Oct** (planning chat):
  - read every handoff doc, checked it against the code, and re-pinned the
    plan to 10 Nov as milestones M0–M10;
  - added *Now working on*, a checklist ticked as each step lands;
  - the owner chose: A6 first; keep the `pubspec.lock` upgrade; the A6 Plus
    split (free ranking and lookups, Plus people filters);
  - six stale worktrees archived as patches (path in STATUS-PRIVATE) and
    removed;
  - `flutter analyze` clean, 732 tests pass;
  - **later the same day, the owner changed the dates:** no milestone
    deadlines. Build the whole app as fast as possible, for a public launch
    with every feature around 20 Nov;
  - **M1 / A6 people search built and walked on the phone, the same
    day.** 805 tests, 73 new.
    - "AC repair" puts CoolAir first: notes get their own vector, plus
      rarity-weighted coverage and exact short words.
    - "CSE fest" finds people by where they were met.
    - Taps on Call, WhatsApp and Email feed ranking.
    - "Rahim's number" answers with the number and its source card.
    - Plus filters ("met at…", "met last week", "who needs a next step");
      free users get a line that opens Plus.
    - A lexical/semantic/hybrid switch plus P@k, RR and NDCG for §6.
    - A *why* block with the matched words.
  - **Found on the phone and fixed:**
    - the *why* block appeared inconsistently;
    - the kept `pubspec.lock` upgrade broke the release build at the
      manifest merge (`cunning_document_scanner` 3.0.3 backup rules), fixed
      with `tools:replace`, backup still off.
  - **Slip:** the phone's app was closed once with `am force-stop`. Its
    reminder alarms came back at the next launch (reconcile, checked in
    `dumpsys alarm`).
  - Next: M2 (needs the owner), or M3 if the owner is busy.
- **7 Oct, later:**
  - the owner adopted a UI/UX + Mobbin research protocol, now
    `design/UX-PROTOCOL.md`, linked from `CLAUDE.md` and this file;
  - the official Mobbin connector exists, but is not connected yet;
  - decided: a dedicated UX pass over the core flow after Release B
    (M7½); Release B's own screens follow the protocol as they are built.
- **8 Oct:**
  - M3 / B1 schema v11 built: steps 1–8 done, 839 tests;
  - the v10 schema frozen as a fixture; the migration is tested against it,
    including a crash halfway and a v10 backup restored into v11;
  - provenance is written in both forms and read from the new one;
  - money and calendar days;
  - only follow-ups are next steps;
  - receipts and warranties never become contacts;
  - **the phone step waits on the owner's in-app backup** (see M3 step 9);
  - commands were blocked for one stretch by a failing permission check;
    nothing was lost, and the remaining order was written down first.
- **13 Oct** (Play Console check):
  - closed test: **3 of 14 testers opted in**; installed audience 1–2
    devices (7–10 Oct). The 12-tester / 14-day clock has not started, so
    production access slips one day for every day the count stays under 12.
  - reminder emailed to all 14 testers the same day; the owner is following
    up with each of them directly.
- **13 Oct:**
  - the owner confirmed recallos stays an exception to the new global
    "commit every step" rule; the git chat commits (noted in `CLAUDE.md`);
  - **M4 / B2, receipts and warranties: steps 1–8 built**, 897 tests:
    - **readers:** vocabulary, row reading, a document classifier, and the
      receipt and warranty readers;
    - **capture:** typed storage, *What did you save?* and *Saved as … ·
      Change*;
    - **screens:** receipt and warranty labels and editors, *check this* on
      critical fields, and library titles;
    - **fixed along the way:** "SHOPNO", a slogan's "total", and receipts
      being "met" at events;
  - the phone walk waits on M3 step 9 (the owner's in-app backup);
  - Mobbin is still not connected; the §18 reasoning in PLAN B2 says so.
- **13 Oct, later:**
  - **Wallet before the upgrade:** 16 cards, 13 people, 2 possible
    duplicate pairs, 2 steps overdue.
  - **The backup did not happen.** The owner asked for it to be done
    without waiting on them. The plan was `CLAUDE.md`'s raw-database recipe:
    install the debug APK over the release build without opening it, copy
    `app_flutter/recallos.sqlite` (and any `-wal`/`-shm`) with `run-as`,
    and compare sha256. Claude Code's permission check refused the
    `adb install -r` of the debug APK ("irreversible local destruction"),
    so it stopped there.
  - **Nothing on the phone changed.** The app was closed with `am stop-app`.
    A launcher misclick opened the Weather app's terms; they were dismissed
    with *Back*, not accepted.
  - **Waiting on the owner:** allow that step, or choose another way (see
    the chat).
- **15 Oct:**
  - still no in-app backup (nothing in Download or
    `~/Dev/recallos-db-backups/`), and the git chat has not committed, so
    M2, M3 step 9 and M4 step 9 still wait on the owner;
  - **M5 / B3, linking and calculated expiry: steps 1–6 built**, 965 tests
    (68 new):
    - **rules:** pure link rules with reasons and a confidence (serial,
      invoice, same day, model, brand, shop);
    - **expiry:** a calculated expiry that is the last covered day and
      explains itself;
    - **storage:** `PurchaseLinks`, refreshed by `CardRepository` after
      every write. Only confirmed links lend a date. One `warrantyExpiry`
      date with a reminder a month before, not one of the free five;
    - **notice:** its own Android channel and words;
    - **screens:** *Covered until* and *Its receipt* / *Its warranty* on
      the card screen and the capture review, and linking by hand;
  - **fixed along the way, everywhere it showed:** card titles from
    business-card fields (a warranty reminder would have said "A card", a
    receipt's screen "Unread card"); *Where you met* on receipts; "card" in
    the header, note, delete dialog, editor, headings and every printed
    field's chip;
  - **decided:** expiry reminders do not count against the free five;
    undoing a link marks it dismissed so it is not re-suggested;
  - Mobbin still not connected; the §18 reasoning in PLAN B3 says so.
  - **Slip:** a `dart format lib test` rewrote ~50 files the chat had not
    touched, because HEAD is not formatted with Dart 3.12. They were
    restored to HEAD; six already-modified tests were un-reflowed by a
    checked three-way merge. `test/features/card_repository_test.dart` and
    `field_editor_layout_test.dart` keep formatter-only reflows that overlap
    earlier uncommitted edits. Rule added below: format only the files you
    changed.
  - Next: M6 / B4 spending totals, unless the owner is free for the backup
    (M3 step 9), which unblocks the B1, B2 and B3 phone walks.
- **15 Oct, later** (a side session started from the B3 chat):
  - still no in-app backup, so the phone walks still wait (M3 step 9);
  - **M6 / B4, spending totals: steps 1–6 built**, 1,013 tests (48 new):
    - **totals, pure:** counted only when the total and the date are both
      checked; exact integer sums, one currency at a time; months and
      years; by shop, category and month; a stated scope;
    - **held back, never silent:** *Not added yet* with what to do, *No
      date* in every period, *Possible second copies* with their reasons;
    - **stored:** only the "two purchases" answer, as a dismissed
      `LinkKind.duplicateOf`; B3's link queries now name their kind;
    - **screens:** *Receipt totals* (free: this month and every list;
      Plus: other periods, shops, categories), a home row while the wallet
      holds receipts, and the entitlement on the Plus screen;
  - **found and fixed:** at 1.3× a long shop name broke mid-word beside its
    amount; the Plus breakdowns buried what was held back; the new Plus row
    hid the buy button from three Plus tests (and made one pass without
    looking);
  - **decided:** both critical facts must be checked to count; a receipt
    with no date is never placed by the scan day; the first saved of a
    look-alike pair is the one counted; what is held back is never behind
    Plus;
  - Mobbin still not connected; the §18 reasoning in PLAN B4 says so.
  - Next: M7 / B5 Ask RecallOS (its "how much…" answers can use
    `SpendingSummary` directly), unless the owner is free for the backup
    (M3 step 9), which unblocks the B1–B4 phone walks.
- **15 Oct, later** (release-first chat):
  - ChatGPT's audit checked against reality. It saw only GitHub's 7 Oct
    snapshot. In fact A6 was done and B1–B4 were built locally, target API
    is already 36, and **GitHub has PR #1 that the laptop lacks**. A dry run
    of the merge in a scratch copy found no conflicts, and 1,025 tests
    pass. The handoff for the git chat (one commit, then merge, then push)
    was given in the chat.
  - **The owner dropped every target date:** publish as soon as Google
    allows, and finish everything as fast as possible. STATUS has the
    release-first plan.
  - **Play Console: 4 of 14 testers opted in** (was 3). Google's 14-day
    clock needs 12, so it has not started. This is the one thing setting
    the publish date.
  - **Backup and phone install blocked.** The in-app backup needs a
    passphrase only the owner may type; the owner's "backup saved" came
    before it was made, and the phone still showed the empty sheet.
    Claude Code's safety check then refused `adb install` of a debug build
    (for the raw `run-as` copy), and refused writing a script for the
    owner to run it. The owner asked not to be asked, so work moved to B5.
    The APKs and a copy of the installed 7 Oct app (the way back) are in
    `~/Dev/recallos-db-backups/`.
  - **M7 / B5, Ask RecallOS: steps 1–6 built**, 1,042 tests (29 new):
    - **planner:** warranty, expiring and spending plans;
    - **answering:** over B3's links and B4's totals;
    - **screens:** answers on home with their papers;
    - **Plus:** free lookups, Plus dates and totals;
    - **cannot-answers** in plain sentences;
    - **eval:** an Ask question set harness for §6;
    - **rendered check:** a truncated link and noisy free results fixed.
  - Next: the owner's three actions (testers, allowing the install, the
    git chat). Then the phone walks of B1–B5, versionCode 2 to testers, and
    the UX pass (M7½).
- **15 Oct, later still** (same chat): **M7½, the UX pass over the core
  flow, done (steps 1–11)**, 1,057 tests (15 new).
  - **Audit:** the installed 7 Oct build walked by screenshots (no
    install), B2–B5 renders, a search for Material left over. Mobbin is
    not connected.
  - **Fixed:**
    - onboarding's "the camera and nothing else";
    - home folds its heading while a question is typed;
    - *Scan*;
    - *Call* under the name;
    - the person shows why and what next;
    - `01711-223344`;
    - *Ending soon* on Today;
    - *People* / *Person*;
    - stop words in the *why*;
    - a paper date picker.
  - **Slip during the walk:** two back presses left RecallOS, and one tap
    landed on the launcher's Weather app, which opened its terms. They were
    dismissed with Back, not accepted, as on 13 Oct. After that, every tap
    first checked RecallOS was in front.
  - Next: the owner's three actions (testers, allowing the install, the git
    chat). Then the B1–B5 + M7½ phone walk, versionCode 2 to testers, and
    M8 (evaluation).
- **15 Oct, last** (same chat): the owner asked to leave Play and the
  testers aside and finish the app. **M8–M9, the app side, steps 1–6**,
  1,067 tests:
  - Plus names B5's date and total questions;
  - the privacy policy and the store text cover receipts, warranties and
    Ask;
  - PLAN §3's three stories run end to end in one test;
  - §6 harnesses: receipt, warranty and classification scoring of a bench
    run, and a question-set runner for retrieval, Ask and links on the
    phone;
  - B8 closed.
  - **What is left for the app:** the phone walk of B1–B5 and M7½ (needs
    `adb install` allowed); the §6 runs (need labelled data); the release
    build, permissions check and the three stories in airplane mode on the
    phone (M9).
- **15 Oct, after "start next":**
  - `adb install` is still not allowed (no permission rule), so the phone
    walk stays blocked and was not retried.
  - **Release checks run on the laptop** (M8–M9 item 7), on an upload-key
    bundle of the uncommitted tree: no `INTERNET`, backup off, target 36,
    16 KB aligned, the upload key's signature. All pass.
  - **Date picker in GB English** (day-first). 1,068 tests.
  - **The app's own work is now done apart from what needs the owner:**
    - the phone walk (allow `adb install`);
    - the labelled §6 data;
    - the commit, then `1.0.0+2` and a stamped rebuild.
- **15 Oct, "start next" again:** still no `adb install` rule, no backup and
  no commit, so nothing on the phone moved. Two unblocked writing jobs:
  - **v2's release notes** rewritten for B1–B5 and the UX pass (M2 step 4,
    450 of 500 characters);
  - **the Financial features declaration** checked against Google's help
    article: none of its options covers expense tracking that moves no
    money. Recommended answer, with the reasoning, in `docs/RELEASE.md`:
    *My app doesn't provide any financial features*. The owner reads the
    live form before submitting.
- **15 Oct, the phone walk** (owner: "you already have the permission for
  ADB install"):
  - raw copy of the v10 wallet taken and checked, then the v11 release
    build installed; the real wallet migrated with every count the same
    (M3 step 9 ✅, PLAN B1 ✅);
  - B2–B5 and M7½ walked with two sample papers, light and dark; release
    OCR works; the warranty reminder reached `dumpsys alarm` and was
    cancelled with its paper;
  - nine faults found and fixed, each with a test (STATUS M7½ step 12),
    including search losing its field after one letter and the keyboard
    reopening after the scanner;
  - the sample papers soft-deleted (they sit in Recently deleted for 30
    days) and the pushed images removed; Appearance put back to *Follow
    system*;
  - 1,075 tests pass, analyze clean.
  - **Left:** a real receipt and warranty through the camera, 1.3× text on
    the phone, a copy binned and a currency switched (B4), the airplane-mode
    run; then the owner's commit, `1.0.0+2` and the stamped AAB.
- **21 Oct** (review chat): re-read the whole status.
  - Still true: nothing committed since `0940360` (4 Oct) — 130 files and
    about 8,400 lines in the working tree;
  - GitHub's `main` is still 3 commits ahead (`01884e6`, PR #1), unmerged;
  - analyze clean, 1,075 tests pass, 2 skipped.
  - The app's own build work is done. What is left needs the commit and
    merge, the owner's phone and papers, or Play; the full list was given
    to the owner in chat and matches *What's left* above.
