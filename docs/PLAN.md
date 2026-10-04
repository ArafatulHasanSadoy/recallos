# RecallOS — where the project stands, and the CSE499B plan

**This file is the live plan and is kept up to date as work lands.** A row marked
✅ was built, tested and walked on the phone; nothing is marked done because it
was planned. Every claim below was re-checked against the code on 2026-09-28.

**2026-09-29:** reviewed against *RecallOS CSE499B Master Plan v1.0* (a
separate 37-page plan written from the GitHub snapshot). Three decisions came
out of it and are applied below: sell the people workflow first (Release A),
verify the first purchase on the phone so `INTERNET` stays out, and tag
`b48d429` as `cse499b-start`.

**2026-09-29, later — the dates are fixed.** The **first release is live on
Google Play on 20 Oct 2026**. The **final code and the final Play release are
submitted to the university on 10 Nov 2026**, and the project is judged on that
submission. The owner chose the **complete app** for it: Releases A and B.
§4 targets and the §7 calendar are re-pinned to these dates; Release C moves
after the judging.

**2026-09-30 — build order and schema numbers.** Release A is built in this
order: **A1 + A2 → A3 + A4 → A7 purchase → A5 → A6 → A8**, so the purchase
follows the first release by about a week instead of trailing to the end of
October. Schema **v10** is the one that shipped with A1/A2 — `encounters`,
`important_dates` and `reminders`, new tables only. The larger generalisation
this plan used to call v10 (typed facts, item assets, item links) is now
**v11**. Schema numbers describe what happened, not the order they were once
planned in.

**2026-10-04 — what ships on 20 Oct.** Release A is split: **A1–A4, A7 and A8
are the first release**; A5 and A6 follow as its first update around 26 Oct.
The build order is now **A7 → A8 → (release) → A5 → A6**, A1–A4 being done.
The billing spike's first half is answered: Play Billing adds no `INTERNET`.

Pricing, revenue and competitor strategy are deliberately **not** here: this repo
is public and `docs/` is served on GitHub Pages. They live in the gitignored
`business/` folder.

---

## 1. Where things stand (2026-09-28)

### Repository state

- 499A ends at `b48d429` "Prepare the Play Store release surface"
  (2026-09-08), tagged `cse499b-start`.
- 499B so far is seven commits on `main`, pushed 2026-09-29: My Card, F1–F4,
  and the phone-number label fix.
- `flutter analyze`: clean. `flutter test`: **667 pass** (2026-10-04, after
  A7's build; 641 after A1–A4; 580 after F1–F4; 444 at the 499A baseline
  `b48d429`).
- **Starting point:** everything after `cse499b-start` is 499B work
  (`git log cse499b-start..main`).
- **CI** (`.github/workflows/ci.yml`) runs on every push to `main`; its first
  run was the 2026-09-29 push. Pinned to `ubuntu-24.04` on 2026-10-04, because
  `ubuntu-latest` moves to Ubuntu 26 from 19 Oct, the day before the first
  release; checkout and setup-java moved to their Node 24 majors.

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

- [x] ✅ **B1** Profile work committed and `cse499b-start` tagged (2026-09-29).
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
- [x] ✅ **A finished step could not be found again** (found on the phone
  2026-10-04, fixed the same day): two of Nusrat's demo steps vanished
  overnight. Done and Remove only change a step's status, so nothing was
  lost — but past the snackbar's few seconds there was no way to see that,
  or undo it. Each card now has *Finished recently (n)* under its next steps:
  what was done or removed in the last 30 days, when, and *Bring back*. It
  answered the question at once: both were *Done Sun 4 Oct at 6:09 / 6:10
  AM*, matching touches on the app in the phone's input log — taps on their
  circles, not a fault. Both brought back. Two widget tests tap through it.
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

### Release A core — the first Play release, 20 Oct (people)

Target: the **first Play release, 20 Oct 2026**: A1–A4, A7 and A8, with a real
one-time purchase. **Decided 2026-10-04:** Event Mode and people search (A5,
A6) follow as the first update, around 26 Oct — billing, Play testing and a
stable first release matter more than holding the launch for them.

- [x] ✅ **A1. Context and next action** (M) — where and when you met (suggested,
  never fabricated); notes editable any time ✅ (done in F1); a next action with
  purpose, due date and optional reminder.
  **Built 2026-09-30; walked on the RMX3612, release build, 2026-10-03.** The
  phone's database was backed up first (`pre-v10-20261003-…`), the v9 → v10
  upgrade kept all 15 cards, and every step below was done by tapping:
  a step added with its day and reminder, edited from its row, marked done and
  undone (Android's alarm went and came back with it); *Where you met* saved
  with the scan day taken from the one-tap suggestion ("Not sure" is the
  default, so nothing is assumed); both blocks checked in light and dark.
  On a card, under the note: *Next
  step* (add, edit, remove, mark done with Undo; due day in words, overdue
  said as well as coloured) and *Where you met* (a place and a day; the scan
  day is a one-tap suggestion inside the sheet and is never stored unless
  saved). `lib/features/followup/`, schema v10.
- [x] ✅ **A2. Reminders and Today** (L) — obligations separate from their
  notification attempts; inexact scheduling; `reconcile()` after reboot,
  update, restore and timezone change; notification permission asked when the
  first reminder is set; generic lock-screen text for sensitive items. Today:
  overdue, due today, upcoming, then review work.
  **Built 2026-09-30; walked on the RMX3612, release build, 2026-10-03.**
  `ReminderEngine.reconcile()` makes
  Android hold exactly the reminders the database says are due; it runs after
  every change, at launch and on every return to the app. Reminders are 9 AM
  on the due day (an hour out once that has passed), inexact, private on the
  lock screen, with *Done* and *Snooze 1 hour*. The permission is asked at the
  first reminder; when it is refused, Today and the card say so with a button
  that opens Android's notification settings. Home shows the next thing due
  and opens Today. New permissions, all on the CI allowlist:
  `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` — no exact alarms.
  619 tests pass (39 new).
  **On the phone, 2026-10-03:** the permission prompt appeared at the first
  reminder and not before; Android held the alarm at exactly the time shown
  (`dumpsys alarm`: 09:00 next day, inexact window); an app update kept the
  alarms (`MY_PACKAGE_REPLACED`), and the next launch's reconcile dropped the
  ones whose card had been deleted. Today and the home row are right in light
  and dark. **Found and fixed:** deleting a card from its own screen left its
  reminders scheduled, because card deletes never called the engine; the app
  root now reconciles on any change to `cards`, `important_dates` or
  `reminders`, which covers all five delete/restore/purge paths. Verified:
  delete → alarms gone, restore → back. **A real reminder arrived** (set for
  21:20, shown 21:21): the step as its title, the company under it, private on
  the lock screen, *Done* and *Snooze 1 hour* under it. *Snooze 1 hour* took
  it out of the shade, moved Android's alarm to 22:22 and the card's line to
  "Reminder 10:22 PM today". **Found and fixed:** the sheet said "A
  notification at 10:20 PM today" and Android was given 10:25 — the sheet
  worked the time out when it was drawn and the save worked it out again a
  minute later, across a five-minute mark. The sheet's time is now the one
  saved, and editing a step keeps its reminder (a snoozed one included)
  unless its day changes; on the phone, the snoozed step's edit sheet showed
  10:22 and saving left the alarm at 22:22. 622 tests pass; both new widget
  tests fail on the old behaviour. **Done from the notification** (22:30, app
  in the background): the notification went, the app came forward, the home
  row fell from "2 steps due today" to "1", and Android held only the next
  day's 9 AM alarm. **A tap with the app closed** (`am stop-app`, which keeps
  notifications and alarms, unlike force-stop) started RecallOS straight onto
  Nusrat's card, through `getNotificationAppLaunchDetails`; the step stayed
  open, as a tap only opens it. Not walked: a phone restart, which would mean
  restarting the owner's phone — the boot receiver is in the bundle and the
  restart path is the same reconcile the update path proved.
- [x] ✅ **A3. Introduction handoff** (S) — "Say hello": a template from the
  user's own card, shown in full, edited, then handed to WhatsApp / SMS / mail.
  Recorded as *written*, never as *sent*.
  **Built and walked on the RMX3612, release build, 2026-10-03.** *Say hello*
  sits beside *Call* on a card that has a mobile number or an email, and
  nowhere else (a landline-only card gets no button). The draft is a fixed
  sentence with the facts slotted in — "Hi Nusrat, great meeting you at CSE
  fest at NSU on Tuesday. This is Arafat from EnationX. Looking forward to
  staying in touch." — and leaves out, never guesses, what is missing; the
  private note is never used. "Md." and "Mohammad" are passed over in the
  greeting and a name printed in capitals is not shouted back. Without a card
  of your own the hello is unsigned and offers *Sign it — make your card*.
  The record goes in `interactions` (`helloOpened`, the channel in `detail`),
  its first real writer, for A6 to rank by. **On the phone:** the sheet in
  dark mode; *Open as a text message* put up Android's "Open with" chooser
  (Messages and WhatsApp both take SMS links), and Messages opened addressed
  to 01812-445566 with the whole message intact. Nothing was sent; the text
  was cleared. **Found and fixed on the phone:** the card first said "Hello
  opened…", untrue for anyone who backs out of that chooser; it now says
  "Hello written as a text message today", which is true either way.
  WhatsApp and email were not opened on the phone, because the demo numbers
  are made up; their links are pinned by tests. `lib/features/introduction/`.
- [x] ✅ **A4. My Card QR** (S) — `qr_flutter` over the existing `buildVCard`;
  only the fields the user chose.
  **Built and walked on the RMX3612, release build, 2026-10-03.** *Your card
  → Show as a QR code*: the same vCard *Send my card* shares, with a switch
  per line (title, company, each number and email, website, address, the line
  under the name); the address starts off, the name is always on, and the
  choice is remembered (`settings` table). Drawn dark-on-light in both themes
  — some camera apps do not read an inverted code — at M error correction,
  with every square on whole device pixels. A card too long for one code says
  so above the switches instead of drawing nothing. **On the phone:**
  screenshots of the screen were read by macOS's own QR detector (the iPhone
  camera's): exactly `FN:Arafat / ORG:EnationX / TITLE:Founder /
  TEL:01711111111`; switching *Phone* off took the TEL line out of the code
  and back on put it back; dark mode decoded the same. A Bangla card decodes
  correctly with the same detector. zxing2 (the pure-Dart reader in the
  tests) cannot read some codes its own encoder makes from Bangla bytes, so
  the automated round trip uses Latin names. No new permissions.
- [ ] **A7. RecallOS Plus — one-time purchase** (L) — Play Billing 8+,
  **verified on the phone** (see §5). Entitlements cached as a signed grant, so
  a bought feature works offline; restore on reinstall; pending / cancelled /
  refunded states; free-tier limits (5 active reminders is a hypothesis). The
  paywall lists only features that are ready, with Play's localised price.
  **Billing spike, first half done 2026-10-04:** `in_app_purchase` 3.3.1 →
  `in_app_purchase_android` 0.5.3 → Play Billing Library 8.0.0. Built into the
  release bundle (in a throwaway worktree), it adds
  `com.android.vending.BILLING` and a `<queries>` entry for the Play Store's
  billing service — **no `INTERNET`**, and nothing else. Billing talks to the
  Play Store app on the phone, which does the networking. When A7 lands,
  `BILLING` goes on the CI allowlist with its reason. Second half, a
  licence-test purchase, waits on the Play Console account, the app on a test
  track, a merchant profile and a product.
  **Decided 2026-10-04:** it is called **RecallOS Plus** (product ID
  `recallos_plus`, permanent in Play Console); the purchase is on from the
  first release; Plus at launch is **no limit on reminders**, the free version
  keeping **5 waiting at a time**; buyers get Event Mode and people search in
  the ~26 Oct update; scanning, search, notes, Say hello, the QR code,
  backup, restore and the lock are always free.
  **Built 2026-10-04** (`lib/features/plus/`): the receipt Play signs is
  checked on the phone (SHA1withRSA against the app's licence key, and it
  must be a paid purchase of `recallos_plus`) and kept in the Keystore — not
  the database, so never in a backup or export — and re-checked every launch.
  Play is asked again at launch, on every return to the app and on
  *Restore*: that brings Plus back after a reinstall and takes it away after a
  refund, while *not reaching* Play (offline) changes nothing. Pending
  payments say so and turn Plus on when confirmed; cancelled says nothing was
  charged; a receipt that does not check out is not acknowledged, so Play
  refunds it. Without the licence key the app offers no purchase at all. At
  the free limit the step sheet shows no Remind me switch but says why, with
  *No limit with RecallOS Plus*; a step already holding a reminder keeps it.
  Settings → You → *RecallOS Plus*. 665 tests pass (25 new, against real RSA
  signatures made with openssl); `BILLING` is on the CI allowlist.
  **Walked on the RMX3612, release build, 2026-10-04:** eight permissions,
  `BILLING` new, still no `INTERNET`; Settings shows *RecallOS Plus · Free —
  5 reminders at a time*; the Plus screen, with no licence key in this build,
  offers no Buy button and says why, with *Try again*; with five reminders
  waiting, the sixth step's sheet showed no switch, the limit sentence and
  *No limit with RecallOS Plus*, which opened the Plus screen. The five test
  steps were then removed and Android held no RecallOS alarms again.
  **Still to do, needing Play Console** — the product, the licence key pasted
  into `play_key.dart`, licence testers: a real test purchase, a refund and a
  restore.
- [ ] **A8. Release A gates** — **store listing ready 2026-10-04 and saved in Play Console** the same day (title *RecallOS: Business Card Wallet*; `store/`: text within Play's limits, six captioned 1080×1920 screenshots of real screens with demo cards, the 1024×500 feature graphic, the 512 icon — saved, not yet sent for review); **App content, 7 of 10 saved 2026-10-04:** privacy policy URL, no ads, content rating (IARC: utility, digital purchases — Everyone / PEGI 3 / USK 0 / 3+, Brazil 14+ for in-app purchases), no advertising ID, not a government app, no financial features, no health features; Data safety drafted as *collects and shares nothing* (Play Billing and user-started sharing are exempt), submittable once Target audience (18+) is in, which waits on Sign-in details — Plus is paid content, so the answer is *Yes — no account; Plus unlocked with a reviewer promo code for `recallos_plus`*, entered once the product exists after the first upload (a redeemed code turns Plus on when the app returns to the foreground); closed test running since ~3 Oct; production
  access applied for the day its 14 days are up (~17 Oct); Data safety and privacy policy match the build;
  golden journeys on the phone.

### Release A, first update — ~26 Oct

- [ ] **A5. Compact Event Mode** (M) — one active event; captures inherit it;
  the user can override; an end-of-event summary of people and next actions.
- [ ] **A6. People search, grounded** (M) — interactions logged and fed into
  ranking; Ask for people: lookup ("Rahim's number") and need-shaped search,
  every answer citing its card. A3's hellos are the first interactions it has
  to rank by. **Seen on the phone 2026-10-04:** "AC repair" ranked TechFix
  (note: *laptop repair*) above CoolAir (note: *AC servicing*) — one shared
  word each, and "repair" won. The person who services ACs is the answer;
  term specificity (an acronym like "AC" is rarer than "repair") or the
  semantic arm should carry it.

### Release B — people plus purchases (core 499B)

Target: shipped as updates between 20 Oct and 7 Nov; all in the final release on 10 Nov.

- [ ] **B1. Schema v11, in place** (L) — see §5. Rehearsed on a copy of a real
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

### Release C — after the judging

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
reopens. **Half proven, 2026-10-04:** Play Billing Library 8.0.0 adds only
`com.android.vending.BILLING` and a `<queries>` entry — no `INTERNET` (A7).
The licence-test purchase waits on Play Console.

A server (a Supabase Edge Function that checks purchases with Google) arrives
with Pro and cloud, when `INTERNET` returns anyway.

### Evolve the schema in place — no parallel tables

The existing tables are already most of a general "memory item" model, so
schema v11 extends them rather than running an old and a new system side by
side:

| Need | Already there | v11 change |
|---|---|---|
| A saved thing of any type | `cards` — `type` enum (already has `receipt`, `warrantyCard`, `coupon`, `eventPass`…), timestamps, soft delete, person/org/role links | add `title`, `sensitivity`, `captureSource`, `classificationConfidence`; add `ticket`, `idDocument` to the enum. "MemoryItem" is the Dart domain name over this table |
| Typed facts | `card_fields` — key, value, normalised value, `FactSource`, confidence, verified, region, side | add `valueType`, `amountMinor` (INTEGER) + `currency`, `dateValue` (a local date, not a timestamp), `status`; a controlled key vocabulary in code |
| Many pages / PDFs | `imagePath`, `backImagePath`, `thumbPath` | new `item_assets`; front and back migrate into it |
| Links between things | `duplicate_candidates` shows the reversible pattern | new `item_links` with a `reasons` JSON column |
| Dates and reminders | built in **v10** (A1/A2, walked on the phone 2026-10-03): `encounters`, `important_dates` (obligations) and `reminders`, with `ReminderEngine` owning the platform side through `reconcile()` | warranty expiry, ticket and ID dates become more `DateKind` values, not new tables |

**Money is an integer in minor units plus a currency code** — paisa, cents —
never a floating-point number. BDT and USD are never added together.

**A fact has three separate properties**, not one enum: *origin* (printed,
user, derived, inferred), *review* (unreviewed, confirmed, rejected) and
*validity* (current, superseded, outdated). Today's `FactSource` mixes them
(`verified` and `outdated` sit beside `printed`); v11 separates them.

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
- The encrypted backup (F3) exists before schema v11 touches a real wallet.
  (v10 only adds tables; it still gets the same phone backup first.)

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

Fixed 2026-09-29: **first Play release 20 Oct**, **final submission 10 Nov**.
Every update carries only finished features: a feature not done by its week
waits for the next update instead of shipping half-built.

The 20 Oct date is set by Google, not by us. A new personal developer account
must run a closed test with 12+ opted-in testers for 14 continuous days before
it can apply for production, and that review can take up to about a week. So
the closed test has to be live by **~3 Oct** (6 Oct only if the review is
instant), with the build we have then.

| Dates | Build | Play Store / evidence |
|---|---|---|
| 29 Sep – 2 Oct | ✅ F1–F4 · store listing, screenshots, upload-key bundle | **Owner:** Play Console account and ID check, upload key, `applicationId`, 12+ testers (aim for 20), merchant profile |
| **by ~3 Oct** | current build (F1–F4) | internal test → **closed test live**: Google's 14-day clock starts |
| 3 – 9 Oct | A1 ✅ + A2 ✅ checked on the phone · A3 ✅ intro handoff · A4 ✅ My Card QR · billing no-INTERNET spike ✅ (permissions; purchase waits on Play Console) · CI runner pinned ✅ | update to testers; OCR labels from real cards |
| 10 – 16 Oct | A7 Offline Plus · A8 gates | update to testers; licence-test purchases |
| ~17 Oct | — | 14 days done → **apply for production** |
| **20 Oct** | **First release on Play: Release A core** (A1–A4, A7, A8) | public |
| 20 – 26 Oct | A5 Event Mode · A6 people search · B1 schema v11 (rehearsed on a copy; backup first) | update |
| 27 Oct – 2 Nov | B2 receipts + warranties · B3 linking + expiry · B4 spending totals | update; receipt / warranty labels; retrieval query set |
| 3 – 7 Nov | B5 Ask RecallOS · evaluation runs (OCR, retrieval) · short usability study | update |
| 8 – 9 Nov | freeze — fixes only; golden journeys on the phone | report and demo rehearsal |
| **10 Nov** | **Final release on Play + final code** | **submitted to the university; judged on this** |

**Stop rules:**
- No destructive data change before a restore is proven — met (F3, 29 Sep).
- Closed test not live by 6 Oct → the 20 Oct date cannot hold; Play Console
  and testers come before any feature until it is.
- Purchase not working by 16 Oct → the first release ships free, and billing
  comes before Release B.
- From 8 Nov → fixes, evidence and the report only; anything unfinished stays
  out of the final release rather than shipping half-built.

## 8. Only the owner can do these

- [x] ✅ Tagged `b48d429` as `cse499b-start` and committed the 499B work so far (2026-09-29, pushed at the owner's request). If a separate 499A submission exists, tag that commit too.
- [ ] **A written agreement with the group partner** (and the university, if its rules need it) on ownership, revenue and maintenance **before anything is sold**.
- [x] ✅ **Play Console account** — exists and verified (email and phone), checked 2026-10-04.
- [x] ✅ **Personal account.** Once Plus is on sale, Google Play shows the account's address publicly.
- [x] ✅ **Upload key made and wired** (2026-10-04): the key file outside the repository, `android/key.properties` written by the owner (gitignored, mode 600). The first signed bundle verified: signed by the upload key (CN=Arafat, O=RecallOS, SHA256withRSA 2048), the eight allowlisted permissions, no `INTERNET`. Still the owner's: back the key file and its passwords up in two places off this laptop.
- [x] ✅ **App created in Play Console, 2026-10-04:** title *RecallOS*, package `com.recallos.recallos` — registered at creation under Android developer verification, so it is permanent now — English (US), App, **Free** (Plus is sold inside it), Play App Signing terms accepted, Google's automatic protection left on. **To check after the first upload:** download the APK Play delivers (App bundle explorer) and confirm it still carries no `INTERNET` — the protection adds code after upload, where our own check cannot see it; if it does, turn protection off.
- [x] ✅ **Payments profile created** (2026-10-04). Still the owner's: the bank details for payouts when Google asks, and the **15% service-fee enrolment** (Play Console notification of 4 Oct) — without it Google takes 30%.
- [x] ✅ **Licence key in the app** (2026-10-04, `lib/features/plus/data/play_key.dart`; a 2048-bit RSA key, checked by `release_surface_test.dart`). Plus is offered from this build on.
- [ ] **For RecallOS Plus (A7):** create the one-time product `recallos_plus` and set its price; add licence testers (Settings → Licence testing) so test purchases are free.
- [ ] **By 2 Oct:** about 20 closed testers lined up (Gmail addresses); at least 12 must opt in and stay for all 14 days.
- [ ] Hand-label cards (by 16 Oct), receipts and warranties (by 2 Nov) for §6.
- [x] ✅ Dates set (2026-09-29): first Play release 20 Oct, final submission 10 Nov.
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
