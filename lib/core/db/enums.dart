/// Where a stored fact came from.
///
/// Every displayed fact carries one of these. It is what keeps an AI guess from
/// looking like something printed on the card, and it is the schema-level
/// commitment behind the source chips in the UI.
enum FactSource {
  /// Read off the card by OCR.
  printed,

  /// Typed, spoken, or corrected by the user. Outranks everything else.
  user,

  /// Derived by a model. Always labelled as a guess, always dismissible.
  aiInferred,

  /// Was true once; a newer signal disagrees. Kept, but ranked down.
  outdated,

  /// Confirmed by the business itself. Unreachable until there is a backend —
  /// declared now so the enum does not need a migration later.
  verified,
}

/// How far extraction got on a card.
///
/// `pending` exists because the card row and its image are written *before*
/// OCR runs. A crash mid-extraction leaves a recoverable card, never a lost one.
enum ExtractionStatus {
  /// Saved, not yet processed.
  pending,

  /// Ran, but some expected fields are missing or failed validation.
  partial,

  /// Ran and produced a full set of plausible fields.
  complete,

  /// Ran and produced nothing usable. The card is still saved and searchable
  /// through its note.
  failed,

  /// The user entered the details themselves.
  manual,
}

/// What kind of artifact a card is.
enum CardType {
  visitingCard,
  warrantyCard,
  receipt,
  invoice,
  coupon,
  loyaltyCard,
  membershipCard,
  eventPass,
  serviceCentreCard,
  unknown,
}

/// A field's value is usually text — but when OCR cannot read a region and the
/// user should not be made to type it, we store the crop instead and show them
/// the actual pixels.
enum FieldValueKind { text, imageCrop }

/// Kinds of contact endpoint. Kept separate from the value so a person can have
/// several of each, with a different one per business role.
enum ContactKind { phone, whatsapp, email, website, social, fax }

/// Rows that a background job or a user action can act on.
enum InteractionKind {
  scanned,
  viewed,
  called,
  messaged,
  emailed,
  quoted,
  used,
  reminded,
  edited,
}

/// Result of one run of one engine over one image.
enum AttemptStatus { success, partial, failed }

/// Which face of a card a stored fact was read from.
///
/// `card_fields.region_rect` and `ocr_blocks.rect` are pixel coordinates, and
/// pixel coordinates are meaningless without the image they were measured
/// against. This column is that missing half. Without it the back could be
/// photographed but never read, because a value recognised on the back would
/// have boxed a spot on the front — wrong, and silently so.
enum CardSide { front, back }

/// Who put an encounter on a card.
///
/// Only two answers, and neither is a guess: the user typed it, or it came
/// from an event the user started (Event Mode). The scan date is offered as a
/// suggestion on screen and never written here unless the user takes it.
enum EncounterOrigin { user, event }

/// What an important date is about.
///
/// One kind today. Warranty expiry, ticket dates and ID expiry arrive as more
/// values here, not as more tables: each is a date something has to happen
/// by, with the same open/done life and the same reminders.
enum DateKind { followUp }

/// Where an obligation stands. `dismissed` is for "not doing this after all",
/// kept apart from `done` so a summary never counts a dropped task as work
/// finished.
enum DateStatus { open, done, dismissed }

/// Whether Android should still be asked to show a reminder.
///
/// There is no `delivered`: whether a notification appeared is Android's
/// business and cannot be known reliably from here. A scheduled reminder whose
/// time has passed is simply history.
enum ReminderStatus { scheduled, cancelled }
