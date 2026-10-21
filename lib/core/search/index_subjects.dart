/// What the search index stores rows under.
///
/// `embeddings` and `search_index` hang off a polymorphic subject rather
/// than a foreign key, so every path that removes a card's index — re-index,
/// purge — has to name each kind of row it wrote. One list, used by all of
/// them, so a new kind of vector cannot be left behind by one of them.
library;

/// The card itself: its printed text, fields and notes together.
const String kCardSubject = 'card';

/// A card's notes on their own.
///
/// In the whole-card vector the note is a few words beside a full OCR dump,
/// and is drowned by it: "AC repair" scored a laptop repairer's card above
/// the card whose note says "AC servicing" (0.44 against 0.34), though the
/// notes alone say the opposite (0.51 against 0.73).
const String kCardNoteSubject = 'card_note';

/// Every embedding subject that belongs to one card.
const List<String> kCardVectorSubjects = <String>[
  kCardSubject,
  kCardNoteSubject,
];
