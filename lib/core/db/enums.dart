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

/// Where a fact came from — the first of three separate properties a stored
/// fact has (schema v11, PLAN §5).
///
/// [FactSource] mixed three questions in one value: `verified` and
/// `outdated` sat beside `printed`, so a printed number the user confirmed
/// and a printed number that has since changed could not both be said. Now
/// a fact has an origin, whether the user has looked at it ([FactReview]),
/// and whether it still holds ([FactValidity]).
enum FactOrigin {
  /// Read off the photograph.
  printed,

  /// Typed, spoken or corrected by the user.
  user,

  /// Worked out from other facts by a rule — a warranty's expiry from the
  /// purchase date and the cover. Always shown as calculated.
  derived,

  /// Suggested by a model or a heuristic. Always shown as a guess.
  inferred,
}

/// Whether the user has looked at a fact.
enum FactReview { unreviewed, confirmed, rejected }

/// Whether a fact still holds.
enum FactValidity {
  current,

  /// Replaced by a newer fact of the same kind — a new number on a newer
  /// card. Kept, so the history is there.
  superseded,

  /// Known to be out of date, with nothing newer yet.
  outdated,
}

/// How a card's photograph came into the app (schema v11).
enum CaptureSource {
  /// The document scanner — the camera, or a picture picked inside it.
  documentScanner,

  /// Chosen from the phone's gallery outside the scanner.
  gallery,

  /// Imported from a PDF or a picture file.
  file,

  /// There is no photograph: somebody typed it in.
  typed,

  /// Captured before this was recorded.
  unknown,
}

/// How two saved things belong together (schema v11, used from B3).
enum LinkKind {
  /// The `from` card is the warranty for what the `to` card — a receipt or
  /// an invoice — bought.
  warrantyOf,

  /// Related in some other way the user said.
  related,

  /// Two receipts that look like the same purchase — the same amount on the
  /// same day (B4). Only the user's answer is stored, never the question:
  /// *dismissed* means they said these are two purchases, so both are
  /// counted and the pair is not asked about again. The question itself is
  /// worked out afresh each time the totals are, from the receipts as they
  /// stand.
  duplicateOf,
}

/// Where a suggested link stands. A suggestion is never treated as true
/// until confirmed; a dismissed one is kept so it is not suggested again.
enum LinkStatus { suggested, confirmed, dismissed }

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

  /// A "Say hello" message was written and handed to Android for WhatsApp,
  /// SMS or mail. Never "sent": whether an app was chosen and the message
  /// went is out of sight, so the record claims only what RecallOS did.
  /// `detail` names the channel.
  helloOpened,

  /// The number was handed to the dialler. Not "called": whether the call
  /// was placed or answered is out of sight.
  callOpened,

  /// A chat was opened in WhatsApp. `detail` names the app.
  messageOpened,

  /// The address was handed to the mail app. Not "emailed".
  emailOpened,
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
/// Ticket dates and ID expiry arrive as more values here, not as more
/// tables: each is a date something has to happen by, with the same
/// open/done life and the same reminders.
enum DateKind {
  /// A next step the user set on a card.
  followUp,

  /// The day a warranty runs out (B3) — printed on it, or calculated from
  /// the purchase date and the cover, and said so. Not a next step: never
  /// listed as one, and never one of the free reminders.
  warrantyExpiry,
}

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
