# RecallOS — architecture

How the app is put together, for the report and for whoever maintains it. The
diagrams are Mermaid, so GitHub draws them. Where this file and the code
disagree, the code is right and this file is out of date.

## In one paragraph

RecallOS is a single Android app with no server. Flutter draws it; Riverpod
wires it; Drift over SQLCipher stores it; GoRouter moves between screens. Text
is read on the phone by ML Kit, and search runs on the phone with a bundled
embedding model. The release build has no `INTERNET` permission, so "nothing
leaves the phone" is enforced by the operating system rather than promised.

## Layers

```mermaid
flowchart TB
  subgraph UI["lib/features/*/presentation"]
    Home[Home and search]
    Capture[Capture and review]
    Card[Card, receipt, warranty]
    Today[Today and reminders]
    Spend[Receipt totals]
    Set[Settings, backup, Plus]
  end

  subgraph Data["lib/features/*/data — repositories and services"]
    CardRepo[CardRepository]
    SearchRepo[SearchRepository]
    Identity[IdentityRepository]
    FollowUp[FollowUpRepository]
    Engine[ReminderEngine]
    Links[PurchaseLinks]
    SpendRepo[SpendingRepository]
    Backup[BackupService]
  end

  subgraph Core["lib/core — pure logic and storage"]
    Extract[extraction: card, receipt, warranty readers]
    OCR[intelligence: OCR, embeddings]
    Query[search: typed query plans, fusion]
    Money[spending, domain: Money, LocalDate]
    Vault[imaging: sealed photographs]
    Format[backup: archive format]
    DB[(db: Drift + SQLCipher, schema v11)]
    Theme[theme and ui: the design system]
  end

  subgraph Android["Android"]
    MLKit[ML Kit scanner and text recognition]
    Keystore[Android Keystore]
    Alarm[AlarmManager and notifications]
    Pdf[PdfRenderer]
    Billing[Google Play Billing]
  end

  UI --> Data
  Data --> Core
  OCR --> MLKit
  Vault --> Keystore
  DB --> Keystore
  Engine --> Alarm
  CardRepo --> Vault
  Capture --> Pdf
  Set --> Billing
```

The rule of the layers: `lib/core` knows nothing about screens, and most of it
is pure Dart so it can run in isolates and in tests. Screens read repositories
through Riverpod providers and never touch the database.

## What happens to a scan

Save first: the photograph and the row exist before anything is read, so a
crash leaves a card to recover rather than nothing.

```mermaid
sequenceDiagram
  actor U as Owner
  participant S as Scanner or file
  participant C as CaptureScreen
  participant R as CardRepository
  participant V as PhotoVault
  participant O as OCR engine
  participant X as Document reader
  participant I as Search and identity

  U->>S: Scan, or choose a PDF or picture
  S-->>C: One picture, in the cache
  C->>R: createPending(picture)
  R->>V: Seal a copy (encrypted)
  R-->>C: Card row written
  C->>O: Read the sealed picture
  O-->>C: Text blocks with their regions
  C->>X: Which kind of paper? Which fields?
  X-->>C: Fields, each with where it came from
  C->>R: attachExtraction, setKind
  C->>I: Index it, link the person and company
  U->>C: Corrects, writes why it mattered, saves
```

A record that is typed in skips everything down to *attachExtraction*. It has
an empty `image_path` and `extraction_status = manual`.

## Data flow, and where data can leave

```mermaid
flowchart LR
  subgraph Phone["The phone (no INTERNET permission)"]
    Paper[Paper, camera or file] --> Vault[(Sealed photographs)]
    Vault --> OCR[On-device OCR]
    OCR --> DB[(Encrypted database)]
    Type[What the owner types] --> DB
    DB --> Search[On-device search and Ask]
    DB --> Notify[Reminders]
  end

  DB -. "only when the owner taps Back up" .-> Backup[Encrypted backup file]
  DB -. "only when the owner taps Take a copy" .-> Copy[Plain archive]
  DB -. "after a preview" .-> Share[Shared papers, totals, vCard, QR]
  DB -. "the owner edits and sends it" .-> Hello[WhatsApp, SMS, email]
  Backup --> Chosen[Wherever the owner saves it]
  Copy --> Chosen
  Share --> Other[The app the owner chose]
  Hello --> Other
  Play[Google Play] -. "purchase record only" .-> Phone
```

Every dotted line starts with the owner doing something. There is no dotted
line the app can draw by itself.

## The database

Schema v11: 27 tables in `lib/core/db/tables.dart`. The ones that carry the
product:

```mermaid
erDiagram
  CARDS ||--o{ CARD_FIELDS : "has"
  CARDS ||--o{ OCR_BLOCKS : "read from"
  CARDS ||--o{ EXTRACTION_ATTEMPTS : "tried"
  CARDS ||--o{ ENCOUNTERS : "met at"
  CARDS ||--o{ IMPORTANT_DATES : "due"
  CARDS ||--o{ ITEM_LINKS : "from"
  CARDS ||--o{ ITEM_LINKS : "to"
  IMPORTANT_DATES ||--o{ REMINDERS : "reminds"
  CARD_FIELDS ||--o{ OCR_BLOCKS : "claimed by"
  PEOPLE ||--o{ ROLES : "holds"
  ORGANIZATIONS ||--o{ ROLES : "employs"
  ORGANIZATIONS ||--o{ ORG_BRANCHES : "has"
  PEOPLE ||--o{ CARDS : "appears on"
  ORGANIZATIONS ||--o{ CARDS : "appears on"
  ROLES ||--o{ CARDS : "appears on"
  ROLES ||--o{ CONTACT_POINTS : "reached at"
  CARDS ||--o{ CONTACT_POINTS : "source of"
  PROFILES ||--o{ PROFILE_FIELDS : "has"

  CARDS {
    int id PK
    text type "card, receipt, invoice, warranty"
    text image_path "empty when typed in"
    text back_image_path
    text extraction_status "pending, partial, complete, failed, manual"
    text capture_source "documentScanner, gallery, file, typed, unknown"
    text title
    datetime deleted_at "soft delete"
  }
  CARD_FIELDS {
    int id PK
    int card_id FK
    text field_key
    text value
    text source "printed, user, aiInferred, outdated"
    text side "front or back"
    text region_rect "where on the photograph"
    int amount_minor "money as whole minor units"
    text currency
    text date_value "a calendar day, YYYY-MM-DD"
  }
  ITEM_LINKS {
    int from_card_id FK
    int to_card_id FK
    text kind "warrantyOf, related, duplicateOf"
    text status "suggested, confirmed, dismissed"
    text reasons "why, as evidence"
  }
  IMPORTANT_DATES {
    int id PK
    int card_id FK
    datetime due_on "local midnight of the day"
  }
  REMINDERS {
    int id PK
    int important_date_id FK
    datetime remind_at
    int snooze_count
  }
```

Facts that outlive any one feature:

- **Provenance travels with every value.** A guess must never look printed.
- **Nothing merges people automatically.** Merges are pointers, so they undo.
- **Deleting is soft** until *Delete for good*.
- **The identity graph and the search index are derived.** They can be rebuilt.
- **Money is integer minor units and a currency**, never a floating point.
- **A due day is stored as local midnight**, so `followZone` carries it across
  time zones. A new column that holds a day has to be added there.

## Reminders

```mermaid
flowchart LR
  Change[A step added, snoozed, done or deleted] --> Rec[ReminderEngine.reconcile]
  Resume[App opened or resumed] --> Rec
  Rec --> Zone[followZone: carry days and times to the phone's zone]
  Zone --> Plan[Pending reminders from the database]
  Plan --> Alarm[Android alarms made to match]
  Boot[Restart or app update] --> Recv[Plugin's boot receiver]
  Recv --> Alarm
  Alarm --> N[Notification]
```

The database is the truth and Android's alarms are a copy of it. Each
reminder is scheduled on its own, so one that cannot be set costs nothing but
itself.

## Search and Ask

A question becomes a **typed plan**, never SQL or generated text.

1. `query_plan.dart` works out what kind of question it is.
2. Lookups, totals and "what expires" go to code that reads the database.
3. Open questions run keyword search (FTS) and meaning search (the bundled
   embedding model) together, and the two rankings are merged.
4. An answer cites the papers it came from, or says it cannot answer.

No language model reads anything on a paper, so text on a paper cannot
instruct the app.

## Files

| Where | What |
|---|---|
| `recallos.sqlite` (app documents) | The database, encrypted by SQLCipher |
| `cards/` (app documents) | Sealed photographs |
| App cache | Hand-offs only; `lib/core/storage/hand_offs.dart` says how long each may live |
| Android Keystore | The database key and the photograph key |
| A file the owner chooses | Encrypted backup (Argon2id over the passphrase) |

## Build

Pinned toolchain in `.github/workflows/ci.yml`: analyze, test, release build,
and a check of the merged permissions. `docs/RELEASE.md` has the release steps.
`kEvaluationTools` (`lib/core/build_flags.dart`) is a const, so the development
screens are not in a Play build at all.
