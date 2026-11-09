/// One way in for every kind of paper (B2): work out what was scanned, then
/// read it with the reader made for it.
library;

import '../db/enums.dart';
import '../intelligence/ocr_engine.dart';
import 'card_extractor.dart';
import 'document_classifier.dart';
import 'document_lines.dart';
import 'receipt_extractor.dart';
import 'warranty_extractor.dart';

/// What a scan was read as, and what was read.
class DocumentReading {
  const DocumentReading({
    required this.type,
    required this.extraction,
    required this.classification,
    required this.chosen,
  });

  /// The card type the reading was made as.
  final CardType type;

  final CardExtraction extraction;

  /// What the classifier made of the page, whether or not it decided.
  final Classification classification;

  /// True when the type was given — chosen by the user, or the type an
  /// existing card already has — rather than classified.
  final bool chosen;

  /// Whether the app should ask "What did you save?" before trusting the
  /// type: never when it was chosen, otherwise when the classifier is not
  /// sure.
  bool get shouldAsk => !chosen && !classification.isSure;

  /// A name for the library when the paper is not somebody's card.
  String? get title => titleFor(type, extraction);
}

/// Reads [blocks]: as [as] when the type is known, otherwise as whatever
/// the page most looks like.
DocumentReading readDocument(List<OcrBlock> blocks, {CardType? as}) {
  final String text = rowsOf(
    withLeadingIRepaired(blocks),
  ).map((DocLine r) => r.text).join('\n');
  final Classification c = classifyDocument(text);
  final CardType type = as ?? cardTypeOf(c.kind);
  return DocumentReading(
    type: type,
    extraction: extractAs(type, blocks),
    classification: c,
    chosen: as != null,
  );
}

/// The reader for [type]. Types without a reader of their own — service
/// centre cards, the older `unknown` — are read as business cards, which is
/// what every one of them has been so far.
CardExtraction extractAs(CardType type, List<OcrBlock> blocks) =>
    switch (type) {
      CardType.receipt || CardType.invoice => ReceiptExtractor.extract(blocks),
      CardType.warrantyCard => WarrantyExtractor.extract(blocks),
      _ => CardFieldExtractor.extract(blocks),
    };

CardType cardTypeOf(DocumentKind kind) => switch (kind) {
  DocumentKind.businessCard => CardType.visitingCard,
  DocumentKind.receipt => CardType.receipt,
  DocumentKind.warranty => CardType.warrantyCard,
};

DocumentKind? documentKindOf(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => DocumentKind.receipt,
  CardType.warrantyCard => DocumentKind.warranty,
  CardType.visitingCard ||
  CardType.serviceCentreCard ||
  CardType.unknown => DocumentKind.businessCard,
  _ => null,
};

/// "Star Tech & Engineering", "Walton Refrigerator" — what a receipt or a
/// warranty is called in the library. Null for business cards, which are
/// titled from their company or person.
String? titleFor(CardType type, CardExtraction e) {
  String? v(String key) => e.firstOfKey(key)?.value;
  switch (type) {
    case CardType.receipt || CardType.invoice:
      return v(ReceiptKeys.merchant);
    case CardType.warrantyCard:
      final String? product = v(WarrantyKeys.product) ?? v(WarrantyKeys.model);
      final String? brand = v(WarrantyKeys.brand);
      if (product == null) return brand;
      if (brand == null ||
          product.toLowerCase().contains(brand.toLowerCase())) {
        return product;
      }
      return '$brand $product';
    default:
      return null;
  }
}
