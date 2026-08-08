import 'package:drift/drift.dart';

import 'enums.dart';

/// Timestamps every mutable row carries. `deletedAt` gives us tombstones now so
/// that sync in Stage 2 does not need a migration.
mixin _Timestamps on Table {
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// ---------------------------------------------------------------------------
// Identity graph
//
// Deliberately not one flat `contacts` table. The motivating case is a person
// who is a bank manager, a watch-shop owner, and a marketing partner — with a
// different phone for each. A flat table collapses that; person/org/role does
// not.
// ---------------------------------------------------------------------------

class People extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get displayName => text().withLength(min: 1, max: 200)();
  TextColumn get photoPath => text().nullable()();

  /// Free text: "met at CSE Fest", "cousin's friend".
  TextColumn get relationship => text().nullable()();

  /// Private, per-user, learned from feedback. 0.0–1.0, 0.5 = no signal.
  RealColumn get trustScore => real().withDefault(const Constant(0.5))();
}

class Organizations extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 300)();
  TextColumn get category => text().nullable()();
  TextColumn get website => text().nullable()();

  /// Normalised registrable domain, used as a strong duplicate signal.
  TextColumn get websiteDomain => text().nullable()();
}

class OrgBranches extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orgId => integer().references(Organizations, #id)();
  TextColumn get address => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
}

/// A person's job at an organization. This is the join that makes one human
/// with three businesses representable.
class Roles extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().references(People, #id)();
  IntColumn get orgId => integer().references(Organizations, #id)();
  TextColumn get title => text().nullable()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
}

// ---------------------------------------------------------------------------
// Cards and fields
// ---------------------------------------------------------------------------

@DataClassName('CardRow')
class Cards extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<CardType>()
      .withDefault(Constant(CardType.unknown.name))();

  /// Full-resolution capture. Re-running OCR later needs the pixels, so this is
  /// kept until the user chooses otherwise.
  TextColumn get imagePath => text()();
  TextColumn get backImagePath => text().nullable()();
  TextColumn get thumbPath => text().nullable()();

  /// Everything the engines read, joined. Feeds keyword search and gives the
  /// user something to read themselves when field assignment failed.
  TextColumn get rawOcrText => text().nullable()();

  /// Engine or routing strategy that produced the current fields.
  TextColumn get ocrEngine => text().nullable()();
  RealColumn get ocrConfidence => real().nullable()();

  TextColumn get extractionStatus => textEnum<ExtractionStatus>()
      .withDefault(Constant(ExtractionStatus.pending.name))();

  DateTimeColumn get capturedAt => dateTime()();

  IntColumn get personId => integer().nullable().references(People, #id)();
  IntColumn get orgId =>
      integer().nullable().references(Organizations, #id)();
  IntColumn get roleId => integer().nullable().references(Roles, #id)();
}

/// One extracted field, with provenance and a link back to the pixels it came
/// from.
///
/// `regionRect` is what powers tap-a-field-to-highlight-its-source. When
/// `valueKind` is [FieldValueKind.imageCrop] the value is a file path, not text:
/// that is how an unreadable Bengali company name still shows up correctly.
class CardFields extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();

  /// Controlled vocabulary: `person_name`, `company`, `designation`,
  /// `phone`, `email`, `website`, `address`, `services`.
  TextColumn get fieldKey => text()();

  TextColumn get value => text()();

  /// Canonical form for matching: E.164 phones, lowercased emails, bare domains.
  TextColumn get normalizedValue => text().nullable()();

  TextColumn get source => textEnum<FactSource>()();
  RealColumn get confidence => real().nullable()();

  /// True once the user has confirmed or corrected this. Drives the manual
  /// correction rate metric, straight out of real usage.
  BoolColumn get verifiedByUser =>
      boolean().withDefault(const Constant(false))();

  /// Set when a validator disagreed with the extracted value — an 8-digit
  /// "mobile", an email with no plausible TLD. Flagged, never silently kept.
  TextColumn get validationIssue => text().nullable()();

  TextColumn get valueKind => textEnum<FieldValueKind>()
      .withDefault(Constant(FieldValueKind.text.name))();

  /// "left,top,right,bottom" in the source image's coordinate space.
  TextColumn get regionRect => text().nullable()();
}

class ContactPoints extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();

  /// `person` or `organization`.
  TextColumn get ownerType => text()();
  IntColumn get ownerId => integer()();

  TextColumn get kind => textEnum<ContactKind>()();
  TextColumn get value => text()();

  /// E.164 for phones, lowercased for email, registrable domain for sites.
  /// Duplicate detection blocks on this, so it must be canonical.
  TextColumn get normalizedValue => text().nullable()();

  /// "office", "mobile", "the watch shop one".
  TextColumn get label => text().nullable()();

  /// Which role this endpoint belongs to, when the person has several jobs.
  IntColumn get roleId => integer().nullable().references(Roles, #id)();

  TextColumn get source => textEnum<FactSource>()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// ---------------------------------------------------------------------------
// OCR recovery infrastructure
//
// These two tables are why a failed scan is recoverable rather than lost.
// ---------------------------------------------------------------------------

/// Every text region an engine found, whether or not it made it into a field.
///
/// This is the table behind tap-to-assign. When OCR read the text correctly but
/// the layout defeated field assignment — the common failure on unusual cards —
/// the words are already here, and repair costs three taps instead of typing.
///
/// The row class is named `OcrBlockRow` so it does not collide with the
/// [OcrBlock] domain type that engines return; the two are different things and
/// several files legitimately need both.
@DataClassName('OcrBlockRow')
class OcrBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();

  /// Named `blockText` rather than `text` because a getter called `text` would
  /// shadow Drift's own `text()` column builder.
  TextColumn get blockText => text().named('text')();

  /// "left,top,right,bottom" in the source image's coordinate space.
  TextColumn get rect => text()();

  /// Negative means the engine reported no confidence signal.
  RealColumn get confidence => real()();

  /// `latin`, `bengali`, `unknown`.
  TextColumn get script => text()();

  TextColumn get engine => text().nullable()();

  /// Which field this block was assigned to, if any. Null means unassigned and
  /// therefore available in the tap-to-assign picker.
  TextColumn get assignedFieldKey => text().nullable()();

  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

/// One run of one engine over one card.
///
/// Recorded for every attempt including failures. Gives per-engine accuracy and
/// latency for the report, and drives the "retry these when a better engine
/// arrives" queue. Local only — nothing here leaves the device.
class ExtractionAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();

  TextColumn get engine => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMs => integer()();

  TextColumn get status => textEnum<AttemptStatus>()();
  IntColumn get fieldsFound => integer().withDefault(const Constant(0))();

  /// Matches [OcrFailure] names when OCR was the failing stage.
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorDetail => text().nullable()();
}

// ---------------------------------------------------------------------------
// Memory
// ---------------------------------------------------------------------------

/// The user's own words about why something mattered.
///
/// This is the single most valuable column in the database. A card with nothing
/// but a note is still fully retrievable; a card with perfect OCR and no note
/// is just a contact.
class Notes extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subjectType => text()();
  IntColumn get subjectId => integer()();

  TextColumn get body => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  TextColumn get transcript => text().nullable()();

  /// BCP-47-ish tag; `bn-Latn` marks romanised Bangla.
  TextColumn get language => text().nullable()();
}

class Attributes extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subjectType => text()();
  IntColumn get subjectId => integer()();

  /// Controlled: `price_tier`, `min_order`, `delivery_reliability`, `quality`.
  TextColumn get key => text()();
  TextColumn get value => text()();

  TextColumn get source => textEnum<FactSource>()();
  RealColumn get confidence => real().nullable()();
}

/// English rendering of what a card can do for you, generated once at save
/// time. Embedding this rather than the raw code-mixed text is what makes
/// Banglish retrieval work without a Bangla-specific embedding model.
class CapabilityProfiles extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subjectType => text()();
  IntColumn get subjectId => integer()();

  TextColumn get canonicalEn => text()();
  TextColumn get servicesJson => text().nullable()();
  TextColumn get categoriesJson => text().nullable()();

  /// Lets profiles be regenerated selectively when a better model arrives.
  TextColumn get model => text()();
}

/// Vectors stored as raw float32 bytes.
///
/// No vector index: a personal corpus is hundreds to low thousands of rows, and
/// brute-force cosine in Dart over that is about a millisecond. `dim` and
/// `model` are stored so vectors from different models are never compared.
class Embeddings extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subjectType => text()();
  IntColumn get subjectId => integer()();

  BlobColumn get vector => blob()();
  IntColumn get dim => integer()();
  TextColumn get model => text()();
}

class Interactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subjectType => text()();
  IntColumn get subjectId => integer()();

  TextColumn get kind => textEnum<InteractionKind>()();
  TextColumn get detail => text().nullable()();
  DateTimeColumn get occurredAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Tags extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class SubjectTags extends Table {
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  TextColumn get subjectType => text()();
  IntColumn get subjectId => integer()();

  @override
  Set<Column<Object>> get primaryKey => {tagId, subjectType, subjectId};
}

// ---------------------------------------------------------------------------
// Retrieval
// ---------------------------------------------------------------------------

class SearchQueries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get raw => text()();

  /// Serialised [QueryIntent]. Kept so the raw-vs-normalised ablation can be
  /// run over real queries later.
  TextColumn get normalizedJson => text().nullable()();
  TextColumn get lang => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class SearchFeedback extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get queryId =>
      integer().references(SearchQueries, #id, onDelete: KeyAction.cascade)();
  TextColumn get subjectType => text()();
  IntColumn get subjectId => integer()();

  /// `useful`, `not_relevant`, `outdated`, `wrong_person`, `wrong_category`.
  TextColumn get verdict => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Ranking weights live in the database, not in code, so they can be tuned
/// against labelled queries and nudged per user by feedback.
class RankingWeights extends Table {
  TextColumn get key => text()();
  RealColumn get value => real()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// A possible identity match, awaiting the user's decision.
///
/// Nothing is ever merged automatically. A wrong merge is far more damaging
/// than a missed one — it destroys trust in everything else the app claims.
class DuplicateCandidates extends Table with _Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get subjectType => text()();
  IntColumn get aId => integer()();
  IntColumn get bId => integer()();

  RealColumn get score => real()();

  /// Which signals fired, so the prompt can explain itself: "same phone number,
  /// similar name".
  TextColumn get signalsJson => text().nullable()();

  /// `pending`, `linked`, `rejected`.
  TextColumn get status => text().withDefault(const Constant('pending'))();
}
