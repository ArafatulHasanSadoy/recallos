# RecallOS — readiness against the 7 Nov handoff

The owner's handoff, `RecallOS_Complete_Product_Readiness_and_Claude_Code_Handoff.docx`
(repo root, 7 Nov 2026), is a completion checklist in five gates. It was
written from GitHub's **7 Oct** snapshot (`01884e6`, schema v10, 744 tests),
so it lists as open much that has been built since. This file maps every
item to what is true in the working tree, with the evidence. It does not
replace `docs/PLAN.md` (the plan, and the evidence behind each ✅) or
`docs/STATUS.md` (where things stand now).

Audited **8 Nov 2026** against local `main` `f9dba7f` plus the staged merge
of PR #1 and this chat's work (M11), and updated **9 Nov** with M12 and M13:
schema **v11**, `flutter analyze` clean, **all tests pass**, 2 skipped (the
count is in STATUS). Play Console facts are as last checked on 15 Oct
(STATUS); they were not re-checked this time.

**Statuses** (the handoff's own): **DONE** — built, tested and walked on the
phone · **CODE READY** — built and tested; the phone, Play or a real paper
is still owed · **OPEN** — not built · **EXTERNAL** — needs the owner, Play,
testers or a lawyer · **DEFERRED** — outside the finite core by decision.
**Priority:** P0 blocks the first public release · P1 full core · P2
improvement · P3 later.

## The two scopes

- **Earliest safe public release** — Release A (people) with B1–B5 as
  built. Nothing in code blocks it. What blocks it is Google's clock: 12
  testers opted in for 14 continuous days (4 of 14 on 15 Oct), then the
  production review. Then versionCode 2 to the tracks and A7's real Play
  purchase test (if that fails, Plus is hidden; it does not block release).
- **Complete core product** — everything in Gates 1–3 below that is not
  DEFERRED, with Gate 5's measurements run on labelled data.

## What blocks the first public release (P0)

| ID | What | Status | Owner |
|---|---|---|---|
| REL-001 | 12+ testers opted in for 14 days, then *Apply for production* | EXTERNAL | Owner (testers) |
| REL-002 | Commit the staged PR #1 merge and the `1.0.0+2` bump, push, CI green | EXTERNAL | Git chat |
| REL-003 | Build the v2 AAB with the upload key, stamped with the real SHA; permissions, backup off, 16 KB, signature (`docs/RELEASE.md`) | OPEN (needs REL-002) | Developer |
| REL-004 | Upload v2 to Internal and Alpha; re-answer *Financial features* | EXTERNAL | Owner (drag the AAB) |
| REL-005 | A7 on a Play-installed build: licence-test purchase, refund, restore after reinstall, promo code | EXTERNAL | Owner + developer |
| REL-006 | The three §3 stories on the phone in airplane mode, on the release candidate | OPEN (dry run on the emulator 9 Nov, STATUS M13) | Developer (phone) |
| LEG-001 | Written agreement with the group partner before anything is sold | EXTERNAL | Owner |

## Gate 1 — the professional-memory release

### 1. A6 grounded relationship search — DONE (7 Oct)

| Item | Status | Evidence |
|---|---|---|
| Index meeting place, date, events, roles, organisations, notes | DONE | `index_subjects.dart`; PLAN A6 ("CSE fest" finds people by where they were met) |
| Indexes and embeddings kept in step with edits, notes, encounters | DONE | `search_repository_test.dart`, `home_search_refresh_test.dart` |
| Person, company, service, event, place and need queries | DONE | `query_plan_test.dart`, `search_test.dart` |
| Role-specific phones and emails; same-name people kept apart | DONE | `identity_repository_test.dart` (merged roles, PR #1) |
| Exact match for names, numbers, rare words, businesses | DONE | rarity-weighted coverage, exact short words (PLAN A6) |
| Interaction history as a signal; an opened draft is not a sent message | DONE | `interaction_log_test.dart`; *Say hello* records "handed off", never "sent" |
| Deleted records excluded before limits | DONE | PLAN §1 known defects (40 deleted cards outranking one live) |
| Match reasons from real evidence | DONE | `match_evidence_test.dart` (stop words never marked, M7½) |
| Lexical results when embeddings are missing | DONE | `search_test.dart` lexical mode |
| Lexical vs semantic vs hybrid on held-out queries | CODE READY → EXTERNAL | harness in `eval_runner.dart`; needs the owner's labelled questions (M8) |

### 2. A7 RecallOS Plus — CODE READY

| Item | Status | Evidence / what is left |
|---|---|---|
| `recallos_plus` exists and is active in Play | DONE | STATUS *Google Play* (owner activated it, 4 Oct) |
| Play's localised price, not an invented one | DONE | the Plus screen shows `ProductDetails.price` (`plus_screen_test.dart`) |
| Pending, cancelled, failed, purchased, acknowledged | CODE READY | `plus_controller_test.dart`, `purchase_check_test.dart` (signature checked on the phone) |
| Refund and revocation, offline reconciliation | CODE READY | refunded-while-away in `plus_controller_test.dart`; offline changes nothing |
| Real licence-test purchase, refund, restore on a Play build | EXTERNAL | REL-005 |
| Premium only after a verified purchase | DONE | SHA1withRSA against the licence key, re-checked every launch |
| Five active reminders free; no limit with Plus | DONE | `free_reminder_limit_test.dart` |
| Event Mode and other paid boundaries | DONE | Plus screen lists exactly what it unlocks (`plus_screen_test.dart`) |
| Entitlement change never touches data | DONE | the grant lives outside the database, never in a backup |
| Server-side verification | DEFERRED (decided) | PLAN §5: no `INTERNET`; on-device signature check. Replay risk accepted and documented |
| Purchase records kept apart from backups | DONE | grant store is not in `kManagedFolders` |

### 3. Existing workflows — DONE, with phone checks owed

| Item | Status | Evidence / what is left |
|---|---|---|
| Event Mode: start, capture, override, end, summary, undo | DONE | `event_mode_test.dart`; walked 3–7 Oct |
| Overnight events, time-zone changes, edits | DONE | overnight events fixed in PR #1 (staged); days and reminder times follow the phone's zone (`zone_change_test.dart`); walked on an Android emulator, Dhaka to Dubai, 9 Nov |
| Reminders after reboot, upgrade, restore, deleted card, denied permission | DONE | `reminder_engine_test.dart`; on the phone 9 Nov (`dumpsys alarm`): back after an update and after a restart without the app being opened, on an R8 build; after a restart, only once the phone is first unlocked |
| Snooze, complete, cancel, restore against alarms | DONE | walked 3–7 Oct; `reminder_responder_test.dart`; undo fixed in PR #1 |
| Finished and removed steps findable and reversible | DONE | *Finished recently*, Undo |
| Identity, merged roles, reversible duplicates | DONE | `identity_repository_test.dart`; pointer merges |
| Say hello via WhatsApp, SMS, email | DONE | `say_hello_test.dart`; walked |
| Wording: prepared, handed off, never "sent" | DONE | `hello.dart` |
| vCard / QR in both themes, English and Bangla | CODE READY | `my_card_qr_test.dart` decodes the QR; Bangla text on a real scanner not tried |
| Onboarding, first use, empty states | DONE | M7½ (`ux_pass_test.dart`) |

## Gate 2 — people and purchases

### 4. B1 generalised memory — DONE (15 Oct), multi-page DEFERRED

| Item | Status | Evidence |
|---|---|---|
| One memory model across cards and new kinds; no parallel database | DONE | v11 in place: `cards.type`, `title`, `capture_source` |
| Fact origin, review and validity, separately | DONE | `FactOrigin` / `FactReview` / `FactValidity`; `field_provenance_test.dart` |
| Money as integer minor units + ISO code | DONE | `money.dart`, `money_test.dart` |
| Calendar days apart from timestamps | DONE | `LocalDate`, stored `YYYY-MM-DD` |
| Item links: reversible, unique, cascading | DONE | `item_links`; `migration_v11_test.dart` |
| Stable IDs, people, merges, notes, reminders, corrections kept | DONE | the real wallet migrated with every count the same (15 Oct) |
| Rebuildable indexes and embeddings | DONE | derived data; `rulesVersion` |
| Migration tests | DONE | v1 → now (`database_test.dart`), frozen v10 → v11 (`migration_v11_test.dart`), crash halfway |
| Backup format for the new data; v10 backup restores into v11 | DONE | `backup_roundtrip_test.dart` |
| Many pages / PDFs per item (`item_assets`) | DEFERRED | PLAN §4 B1 (cut 7 Oct); front + back only |
| Indexed filters by type, date, shop, amount | CODE READY | typed columns; queries filter in Dart at wallet scale |

### 5. Capture, import, OCR and review

| Item | Status | Evidence / what is left |
|---|---|---|
| Camera and gallery import | DONE | ML Kit scanner, gallery picker |
| File import (PDF) with type limits | DONE (10 Nov) | Home → *From a file*: PDF, JPG, PNG, 25 MB, judged by content, page 1 only (`paper_import_test.dart`); walked on the phone, and on the emulator with a password-protected PDF and a two-page one |
| Front and back; manual correction of every field | DONE | `card_sides_view_test.dart`; the field editor |
| A record with **no** photograph, typed by hand | DONE (10 Nov) | Home → *Type it in* (`add_without_scanning_test.dart`); walked on the phone and the emulator |
| Original saved encrypted before OCR | DONE | save first (CLAUDE.md); `photo_vault_test.dart` |
| The chosen kind wins; ask only when unsure | DONE | `kind_change_test.dart`, `document_classifier_test.dart` |
| Raw OCR kept with its regions | DONE | `ocr_blocks` with side and region |
| Re-reading never overwrites what the user confirmed | DONE | `field_provenance_test.dart` |
| Blurry, skewed, thermal, mixed language | CODE READY → EXTERNAL | release OCR read sample papers; real thermal receipts owed |
| Duplicate imports suggested, never merged silently | DONE | people: duplicate candidates; receipts: *Possible second copies* |
| Temporary plaintext cleaned | DONE | `hand_offs.dart`, `retention_sweep_test.dart` |
| An item OCR could not read is still findable by its note | DONE | save first; the note is indexed; *Needs attention* |
| "… House" companies read as addresses | DONE (10 Nov) | M11 step 1; a card PDF through real ML Kit on the phone read *Dhaka Print House* as the company and *Sales Lead* as the title |
| Limits of Latin vs Bangla OCR stated | CODE READY | `docs/help.html` says so; for the report, it is the owner's |

### 6–7. B2 receipts and warranties — CODE READY (sample papers walked)

| Item | Status | Evidence / what is left |
|---|---|---|
| Shop, date, total, currency, invoice no., category | DONE | `receipt_extractor_test.dart`, `receipt_storage_test.dart` |
| Search by shop, product, date, amount, category | DONE | `library_items_test.dart`, `ask_purchases_test.dart` |
| Second copies suggested, never double-counted | DONE | B4 `findCopies` |
| Refunds read as negative amounts | CODE READY (9 Nov) | a paper headed *Refund*, or a refund total, reads negative with or without a minus (`receipt_extractor_test.dart`); walked on the emulator |
| Print date apart from purchase date | DONE for reading (9 Nov) | a reprint stamp is not read as the purchase date (`receipt_extractor_test.dart`); one date is stored |
| Unlabelled total → no total, not a guess | DONE | `receipt_extractor_test.dart` |
| Warranty: product, brand, model, serial, cover, start, printed expiry | DONE | `warranty_extractor_test.dart` |
| Printed vs typed vs calculated, on every value | DONE | `SourceChip` (`describeProvenance`) |
| No claim of manufacturer coverage | DONE | wording; the shared note says "not a statement from the shop or the maker" |
| Export of a paper and its evidence | CODE READY (8 Nov) | M11 step 4 |
| A real receipt and warranty through the camera; 1.3× text | EXTERNAL | owner's papers |
| Line items | DEFERRED | PLAN §7 cuts |

### 8. B3 linking and calculated expiry — CODE READY

| Item | Status | Evidence |
|---|---|---|
| Suggest from serial, invoice, model, brand, shop, date | DONE | `purchase_link_rules_test.dart` (18) |
| Reasons shown; confirm, reject, unlink, link by hand | DONE | `purchase_blocks_test.dart` |
| No false links from look-alikes | DONE | weak cues never suggest alone; precision harness for §6 |
| Expiry only from confirmed inputs, labelled, recomputed | DONE | `warranty_expiry_test.dart`, `purchase_links_test.dart` |
| Reminder moved or cancelled with its inputs | DONE | `dumpsys alarm` 15 Oct |
| Deleted or rejected evidence never authoritative | DONE | `purchase_links_test.dart` (bin, restore, purge) |
| Linked purchase view | DONE | *Its receipt* / *Its warranty* |
| **Purchase evidence export with a preview** | DONE (8 Nov) | `purchase_papers_test.dart` (9); walked on the phone with the sample papers |
| Originals, user edits and calculated values told apart in the export | CODE READY (8 Nov) | the note labels every value |

### 9. B4 exact spending — CODE READY

| Item | Status | Evidence |
|---|---|---|
| Exact sums, one currency at a time | DONE | `spending_totals_test.dart` |
| Period, category, shop | DONE | Plus breakdowns |
| Duplicates and unchecked totals held back, said why | DONE | *Not added yet*, *Possible second copies*, *No date* |
| Currencies never converted | DONE | chips per currency |
| Source count and date boundaries stated | DONE | `scope` |
| Drill-down to each receipt | DONE | every row opens it |
| **Export with record references and scope** | DONE (9 Nov) | `spending_export_test.dart`, 4 screen tests; walked on the emulator to the share sheet |
| "in saved receipts", never "spent" | DONE | tests assert no "spent" |
| Returns and refunds as their own entries | CODE READY (9 Nov) | counted rows say *Refund*; the figure says how much came back; the export marks the row (`spending_export_test.dart`). Refunds have no paper kind of their own: they are receipts with a negative total |
| Copy binned, currency switched on real receipts | EXTERNAL | owner's receipts |

### 10. B5 grounded Ask — CODE READY

| Item | Status | Evidence |
|---|---|---|
| Question box, suggestions, answers on home | DONE | `ask_home_test.dart` |
| Typed plans only, never generated SQL | DONE | `query_plan.dart` |
| Identity-aware person lookup | DONE | A6 |
| Money arithmetic in code | DONE | B4's `SpendingSummary` |
| Every answer cites its papers; says when it cannot | DONE | `ask_purchases_test.dart`, `ask_question_set_test.dart` |
| Prompt injection in OCR text | DONE by design | no language model reads OCR text; spreadsheet export escapes formulas (8 Nov) |
| Offline, within memory | DONE | no `INTERNET`; walked 15 Oct |
| Ask cannot send, share, merge or change anything | DONE | `PurchaseAnswers` reads only |
| Fixed question set: plans, sources, abstentions | DONE (fixture) → EXTERNAL (real) | 20/20, 13/13, 5/5 on the fixture wallet; real run needs the owner's questions |

### 11. More kinds of record — DEFERRED

Tickets, coupons, memberships, insurance, multiple personal cards, cloud
snapshots, sync, ID vault, CRM, NFC, generative text: none built, none
blocking. Each needs its own gate (PLAN Release C).

## Gate 3 — production quality and safety

### 12. UI/UX and accessibility

| Item | Status | Evidence / what is left |
|---|---|---|
| Audit of every core screen | DONE | M7½ (STATUS) |
| Empty, loading, error, denied-permission states | DONE | ghosts, `EmptyState`, the notifications way out |
| Predictable back, dialogs | DONE | go_router; walked |
| One type scale, spacing, wording | DONE | design system; `design_system_test.dart` |
| Text scaling | CODE READY | renders at 1.3× pass; the phone at 1.3× is owed |
| Screen readers, 52 px targets | DONE | `Semantics` labels; `kMinTarget` |
| Reduced motion (Android *Remove animations*) | CODE READY (9 Nov) | Flutter already shortens finite animations; the two loops now hold still (`reduced_motion_test.dart`). A system setting, so not switched on any device |
| Keyboard overlap, narrow screens | DONE | `field_editor_keyboard_test.dart` |
| Destructive actions confirmed, with Undo | DONE | soft delete everywhere |
| Unverified, inferred and derived facts told apart | DONE | `describeProvenance` |
| Lock-screen notification content | DONE | `NotificationVisibility.private` |
| Testing with people who did not build it | EXTERNAL | SUS survey (M8) |

### 13. Security, privacy, backup and recovery

| Item | Status | Evidence / what is left |
|---|---|---|
| SQLCipher in the released artifact | CODE READY | `encrypted_database_test.dart`; the Settings row reports the real open. Check that row on the Play build |
| Photos, thumbnails, portraits encrypted at rest | DONE | `photo_vault_test.dart`, `sealed_file_image_test.dart` |
| Keystore, platform lock | DONE | `lock_gate_test.dart`, `lock_row_test.dart` |
| Plaintext in cache, previews, exports | DONE | `retention_sweep_test.dart`; exports deleted when the share sheet returns |
| No sensitive data in logs | DONE | no `print`, `debugPrint` or `developer.log` in `lib/` (8 Nov grep); no analytics SDK |
| Orphaned files, aborted imports | DONE | launch sweep |
| Backup and restore of every table | DONE | `kManagedFolders`; round trip |
| Wrong passphrase, tampering, traversal, truncation, oversize, interrupted swap, failed restore rolled back | DONE | `backup_roundtrip_test.dart` (each a test) |
| Restore on another phone | CODE READY | re-sealed for the restoring phone in tests; two phones not tried |
| Lost passphrase warned about | DONE | the passphrase sheet |
| Merged permissions reviewed | DONE | `tool/ci/check_permissions.sh` in CI; no `INTERNET` |
| No automatic upload | DONE | no network permission at all |
| OCR text treated as data | DONE | typed plans; CSV formula escaping (8 Nov) |
| Vulnerability reporting, incident procedure | CODE READY (8 Nov) | `SECURITY.md` |

### 14. Release engineering, CI and phone QA

| Item | Status | Evidence / what is left |
|---|---|---|
| Protected `main`, required CI | EXTERNAL | GitHub settings, owner |
| Pinned toolchain | DONE | CI pins Flutter 3.44.6 stable |
| Analyze, test, release build gates | DONE | `.github/workflows/ci.yml` |
| Merged permissions, version code, signing | DONE (15 Oct) | STATUS M8–M9 item 7 |
| Target SDK 36, 16 KB pages | DONE (15 Oct) | same |
| No debug routes or benchmark flags in release | DONE | `release_surface_test.dart` |
| Migration and restore tests | DONE | as above |
| Upgrade over an installed app | DONE | v10 → v11 on the real wallet; rules 5 → 6 (21 Oct) |
| OCR in a release (R8) build | DONE (15 Oct) | sample papers read on the phone |
| Reboot | DONE | walked 9 Nov, as above |
| Time zone | DONE (9 Nov) | a real Android emulator rebooted from Dhaka to Dubai: alarm back unopened, then moved to 9 AM local, every day unchanged. Not done on the owner's phone: its zone is a system setting |
| Low storage | CODE READY | a real SQLite full-database error, and a failed file write, in `out_of_space_test.dart`; `photo_vault_test.dart`. Not walked on a truly full phone |
| Low memory, large libraries | CODE READY (9 Nov) | memory: trim levels and a background kill on the emulator, no crash, alarm kept, wallet back. Large: a per-card query removed, `large_wallet_test.dart`, and 3,000 cards on the emulator. Not a low-end phone |
| Other phones and Android versions | EXTERNAL | testers' devices |
| Crashes, ANRs, startup and search latency | EXTERNAL | Play vitals once installs exist |
| Build SHA, notes, evidence archived per release | CODE READY | stamped builds; STATUS session log |

## Gate 4 — publication, legal and operations

### 15. Google Play — EXTERNAL (state as of 15 Oct)

Account, app, App signing, listing, all 10 App content declarations, the
Plus product, licence testers and the closed track are done (PLAN §8). The
delivered build has our eight permissions plus `CHECK_LICENSE` and no
`INTERNET`. **Not done:** 12 testers for 14 days, production access,
versionCode 2, and a fresh check of the listing against Release B (the
store text in `store/listing.md` was updated 15 Oct but not yet pasted).

### 16. Legal and licensing

| Item | Status | Evidence / what is left |
|---|---|---|
| Ownership, partner agreement, university IP rules | EXTERNAL | Owner (LEG-001) |
| Name and trademark clearance | EXTERNAL | Owner |
| Third-party inventory with licences | DONE (8 Nov, walked) | Settings → *Licences*: every package's licence, plus Archivo and Instrument Serif (OFL 1.1) and potion-base-8M (MIT), registered by `licences.dart`. ML Kit's own Android notices are not listed there (they are Google's SDK terms) |
| Privacy policy matches the build | DONE (15 Oct) | `docs/privacy-policy.html` covers Release B |
| Retention and deletion explained | DONE | *Recently deleted*, the policy |
| Warranty, spending and reminder wording | DONE | "calculated", "in saved receipts", no guarantees |
| Payout, taxes, 15% fee enrolment, refund policy | EXTERNAL | Owner |

### 17. Support and incidents

| Item | Status | Evidence / what is left |
|---|---|---|
| Support email and feedback route | DONE | Settings → *Send feedback* (build filled in, `about_rows_test.dart`) |
| Help for capture, corrections, notifications, recovery | CODE READY (8 Nov) | `docs/help.html` |
| Backup and restore instructions; lost passphrase stated honestly | CODE READY (8 Nov) | same page |
| Purchase restore and refund help | CODE READY (8 Nov) | same page |
| Bug reports without private content | DONE | the feedback email carries only build and device |
| Security reporting and triage | CODE READY (8 Nov) | `SECURITY.md` |
| Escalation, patch and rollout practice | CODE READY | `docs/RELEASE.md` |
| Who supports and maintains it | EXTERNAL | Owner |

### 18. Monetisation and acquisition — EXTERNAL

Segment, interviews, price tests, payout, and real (not licence-test)
revenue are the owner's. The app counts nothing about its users (no
analytics SDK, no network), so activation and retention come from Play
Console and voluntary feedback only.

## Gate 5 — evaluation and documentation

### 19. Evaluation — harnesses CODE READY, data EXTERNAL

Card OCR (CER, field F1), receipt and warranty fields, classification
(accuracy, macro-F1, confusion), retrieval (P@3, MRR, NDCG, latency), link
precision and false links, and Ask (plan, sources, abstention) all have
harnesses (STATUS M8–M9 item 5). None has been run on real labelled data:
that needs the owner's 30+ labelled cards, 10–20 receipts and warranties,
and a question set. Nothing in this repository claims a measured accuracy.

### 20. Documentation

| Item | Status | Where |
|---|---|---|
| Free / Plus definition and scope | DONE | PLAN §4, `business/STRATEGY.md` |
| Fact provenance and derivation rules | DONE | PLAN B1, B3; `field_provenance.dart`, `warranty_expiry.dart` |
| Capture and evidence design | DONE | PLAN B2, CLAUDE.md *Architecture notes* |
| Ask intent schema and ranking | DONE | PLAN A6, B5; `query_plan.dart` |
| Backup, restore and recovery | DONE | PLAN F2, `lib/core/backup/` |
| Purchase state machine, Play record | DONE | PLAN A7, STATUS |
| Design system and screens | DONE | `design/DESIGN.md`, `design/screens.html` |
| Release checklist and build evidence | DONE | `docs/RELEASE.md` |
| Licence inventory | CODE READY (8 Nov) | the *Licences* screen; this file §16 |
| Architecture and ER diagrams, threat model, data-flow diagram | DONE (9 Nov) | `docs/ARCHITECTURE.md`, `docs/THREAT-MODEL.md` |
| Evaluation method and results | CODE READY → EXTERNAL | harnesses; results need data |

## Next work packages, in order

1. **P0, owner:** testers (REL-001), the git chat (REL-002), the partner
   agreement (LEG-001).
2. **P0, developer once REL-002 lands:** the v2 AAB and its checks
   (REL-003), then the airplane-mode stories on it (REL-006).
3. **Owner, any time:** labelled cards, receipts and questions for §19, a
   real receipt and warranty through the camera, and the phone at 1.3× text.

Nothing else in this file is open for a developer. What remains is outside
the code: Google's clock, the git chat, the owner's papers, agreements and
accounts. DEFERRED items stay deferred by decision.
