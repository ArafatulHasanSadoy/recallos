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
