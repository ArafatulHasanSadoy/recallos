import 'package:drift/drift.dart';

import '../extraction/card_extractor.dart';
import 'database.dart';
import 'enums.dart';

/// Where a card field came from, written in both of its forms.
///
/// Schema v11 split the old `source` + `verified_by_user` pair into
/// `origin`, `review` and `validity`. Both forms are kept until nothing
/// reads the old one, and the way to keep them from ever disagreeing is
/// that no write site sets them by hand: every field written goes through
/// one of these.
class FieldProvenance {
  const FieldProvenance._({
    required this.source,
    required this.verified,
    required this.origin,
    required this.review,
  });

  /// Read off the photograph, not yet looked at.
  static const FieldProvenance printed = FieldProvenance._(
    source: FactSource.printed,
    verified: false,
    origin: FactOrigin.printed,
    review: FactReview.unreviewed,
  );

  /// A guess — a receipt's category worked out from the shop's name. Shown
  /// as a guess until the user confirms it.
  static const FieldProvenance inferred = FieldProvenance._(
    source: FactSource.aiInferred,
    verified: false,
    origin: FactOrigin.inferred,
    review: FactReview.unreviewed,
  );

  /// Worked out from other facts by a rule — a warranty's expiry from its
  /// purchase date and cover (B3). Shown as *calculated*, and recomputed
  /// whenever those facts change, so it is never reviewed on its own: what
  /// a person checks is what it was worked out from.
  ///
  /// The old `source` has no word for this. `aiInferred` is the nearest —
  /// neither on the card nor the user's — and nothing reads `source` for a
  /// card field any more.
  static const FieldProvenance derived = FieldProvenance._(
    source: FactSource.aiInferred,
    verified: false,
    origin: FactOrigin.derived,
    review: FactReview.unreviewed,
  );

  /// Typed or corrected by the user, which is also confirming it.
  static const FieldProvenance userConfirmed = FieldProvenance._(
    source: FactSource.user,
    verified: true,
    origin: FactOrigin.user,
    review: FactReview.confirmed,
  );

  final FactSource source;
  final bool verified;
  final FactOrigin origin;
  final FactReview review;

  /// [row] with this provenance on it, in both forms, and current.
  CardFieldsCompanion applyTo(CardFieldsCompanion row) => row.copyWith(
    source: Value<FactSource>(source),
    verifiedByUser: Value<bool>(verified),
    origin: Value<FactOrigin>(origin),
    review: Value<FactReview>(review),
    validity: const Value<FactValidity>(FactValidity.current),
  );
}

/// Whether the user has confirmed or corrected [field] — the v11 reading of
/// what `verified_by_user` used to say on its own.
bool isConfirmed(CardField field) => field.review == FactReview.confirmed;

/// Issues that describe *how* a value was arrived at rather than something
/// still wrong with it. A user confirmation settles these.
const Set<String> _provenanceIssues = <String>{
  'digit_restored',
  'ocr_repaired',
};

/// Whether a field still has an objection nobody has resolved.
bool needsALook(CardField field) =>
    field.validationIssue != null &&
    !_provenanceIssues.contains(field.validationIssue);

/// How a provenance reads: a fault, the user's own word, printed, or worked
/// out by a rule. The screen gives each its colour.
enum ProvenanceTone { alert, yours, printed, worked }

/// Where [field] came from, in the words the app uses for it everywhere: the
/// chip on the card screen and the summary that goes with shared papers.
/// [paper] names what it was printed on — "card", "receipt", "warranty".
(String, ProvenanceTone) describeProvenance(
  CardField field, {
  String paper = 'card',
}) {
  // An unresolved objection outranks even the user's own confirmation. A
  // number too short to dial must not read as settled just because somebody
  // tapped Save on it — silent wrong data is the failure mode that costs
  // trust in everything else the app says.
  if (needsALook(field)) return ('needs a look', ProvenanceTone.alert);
  if (isConfirmed(field)) return ('you confirmed', ProvenanceTone.yours);
  if (field.validity == FactValidity.outdated) {
    return ('may be old', ProvenanceTone.alert);
  }

  return switch (field.validationIssue) {
    'digit_restored' => ('digit restored', ProvenanceTone.worked),
    'ocr_repaired' => ('OCR repaired', ProvenanceTone.worked),
    _ => switch (field.origin) {
      FactOrigin.printed => ('on the $paper', ProvenanceTone.printed),
      FactOrigin.user => ('you typed', ProvenanceTone.yours),
      // Worked out from other facts by a rule — a warranty's expiry from
      // its purchase date. Said so, never shown as printed.
      FactOrigin.derived => ('calculated', ProvenanceTone.worked),
      FactOrigin.inferred => ('guess', ProvenanceTone.worked),
    },
  };
}

/// The provenance a freshly read [field] is stored with: printed, unless the
/// reader guessed it.
FieldProvenance provenanceOf(ExtractedField field) =>
    field.issue == kGuessedIssue
    ? FieldProvenance.inferred
    : FieldProvenance.printed;
