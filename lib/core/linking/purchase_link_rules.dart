/// Whether a warranty and a receipt are papers for the same purchase (B3).
///
/// Pure, so the same rules that suggest a link on the phone are the ones the
/// §6 evaluation measures (precision, recall, the false-link rate) over
/// labelled pairs.
///
/// A suggestion is only ever a suggestion: it is shown with its reasons and
/// counts for nothing until the user confirms it. That is why the rules can
/// afford to say "probably" — and also why they must not say it often. A
/// wrong suggestion costs a tap and some trust; so the strong evidence is a
/// number printed on both papers, and the weak evidence (a day, a brand, a
/// shop) only counts when more than one piece of it agrees.
library;

import '../domain/local_date.dart';
import '../extraction/document_lines.dart' show asciiDigits;
import '../extraction/receipt_extractor.dart' show formatDay;

/// One paper's side of the comparison: the facts read off it, and every word
/// on it.
class PaperFacts {
  const PaperFacts({
    required this.id,
    required this.text,
    this.serial,
    this.invoiceNumber,
    this.purchaseDate,
    this.model,
    this.brand,
    this.merchant,
  });

  /// The card's id, so a suggestion can say which paper it means.
  final int id;

  /// Everything OCR read on the paper, front and back. A receipt rarely has
  /// a field for the serial it prints in an item line, so the other paper's
  /// numbers are looked for here rather than in its fields.
  final String text;

  final String? serial;
  final String? invoiceNumber;
  final LocalDate? purchaseDate;
  final String? model;
  final String? brand;

  /// The shop, on a receipt.
  final String? merchant;
}

/// What made two papers look like one purchase.
enum LinkCue {
  /// The warranty's serial or IMEI is printed on the receipt.
  serial,

  /// The receipt's invoice number is printed on the warranty.
  invoice,

  /// Both papers carry the same purchase date.
  sameDay,

  /// The warranty's model is on the receipt.
  model,

  /// The warranty's brand is on the receipt.
  brand,

  /// The receipt's shop is on the warranty.
  shop,

  /// The user linked them by hand.
  chosen,
}

/// One reason, with the value that matched, so the screen can show its
/// evidence rather than a bare "these seem related".
class LinkReason {
  const LinkReason(this.cue, [this.value = '']);

  /// Reads one reason back from `item_links.reasons`. Null for a cue this
  /// build does not know, so a newer build's reasons never break an older
  /// screen.
  static LinkReason? fromJson(Object? json) {
    if (json is! Map) return null;
    final LinkCue? cue = LinkCue.values
        .where((LinkCue c) => c.name == json['cue'])
        .firstOrNull;
    if (cue == null) return null;
    final Object? value = json['value'];
    return LinkReason(cue, value is String ? value : '');
  }

  final LinkCue cue;
  final String value;

  Map<String, String> toJson() => <String, String>{
    'cue': cue.name,
    'value': value,
  };

  /// The reason as a line under the suggestion.
  String describe() => switch (cue) {
    LinkCue.serial => 'Serial $value is on both',
    LinkCue.invoice => 'Invoice $value is on both',
    LinkCue.sameDay => 'Both dated $value',
    LinkCue.model => 'Model $value is on the receipt',
    LinkCue.brand => '$value is on the receipt',
    LinkCue.shop => '$value is on the warranty',
    LinkCue.chosen => 'You linked these',
  };

  @override
  bool operator ==(Object other) =>
      other is LinkReason && other.cue == cue && other.value == value;

  @override
  int get hashCode => Object.hash(cue, value);

  @override
  String toString() => '${cue.name}($value)';
}

/// A warranty and a receipt that may belong together.
class LinkSuggestion {
  const LinkSuggestion({
    required this.warrantyId,
    required this.receiptId,
    required this.confidence,
    required this.reasons,
  });

  final int warrantyId;
  final int receiptId;

  /// 0–1. At or above [PurchaseLinkRules.threshold] by construction.
  final double confidence;

  /// Strongest first.
  final List<LinkReason> reasons;
}

abstract final class PurchaseLinkRules {
  /// How sure the rules must be before saying anything.
  static const double threshold = 0.5;

  /// Two papers whose purchase dates are further apart than this are not
  /// one purchase on the strength of a brand and a shop. A warranty is often
  /// filled in a day or two after the sale, so a few days are allowed.
  static const int datesApartDays = 3;

  /// What each cue is worth on its own. Combined as independent evidence —
  /// one minus the chance that every cue is a coincidence — so two weak cues
  /// together say more than either, and never more than certain.
  static const Map<LinkCue, double> weight = <LinkCue, double>{
    LinkCue.serial: 0.95,
    LinkCue.invoice: 0.9,
    LinkCue.model: 0.45,
    LinkCue.sameDay: 0.35,
    LinkCue.shop: 0.2,
    LinkCue.brand: 0.15,
  };

  /// Compares [warranty] with [receipt]. Null when there is too little to go
  /// on, which is the usual answer.
  static LinkSuggestion? compare(PaperFacts warranty, PaperFacts receipt) {
    if (warranty.id == receipt.id) return null;

    final _Words onReceipt = _Words(receipt.text);
    final _Words onWarranty = _Words(warranty.text);
    final List<LinkReason> found = <LinkReason>[];

    final String? serial = warranty.serial;
    if (serial != null && _isIdentifier(serial) && onReceipt.has(serial)) {
      found.add(LinkReason(LinkCue.serial, serial.trim()));
    }

    final String? invoice = receipt.invoiceNumber;
    if (invoice != null && _isIdentifier(invoice) && onWarranty.has(invoice)) {
      found.add(LinkReason(LinkCue.invoice, invoice.trim()));
    }

    final LocalDate? a = warranty.purchaseDate;
    final LocalDate? b = receipt.purchaseDate;
    final bool datesDisagree =
        a != null && b != null && _daysApart(a, b) > datesApartDays;
    if (a != null && b != null && a == b) {
      found.add(LinkReason(LinkCue.sameDay, formatDay(a)));
    }

    // The weak cues only count while nothing contradicts them: a brand and a
    // shop shared by papers from different weeks are a shop that sells that
    // brand, not one purchase.
    if (!datesDisagree) {
      final String? model = warranty.model;
      if (model != null && _isModel(model) && onReceipt.has(model)) {
        found.add(LinkReason(LinkCue.model, model.trim()));
      }
      final String? brand = warranty.brand;
      if (brand != null && _isName(brand) && onReceipt.has(brand)) {
        found.add(LinkReason(LinkCue.brand, brand.trim()));
      }
      final String? shop = receipt.merchant;
      if (shop != null && _isName(shop) && onWarranty.has(shop)) {
        found.add(LinkReason(LinkCue.shop, shop.trim()));
      }
    }

    if (found.isEmpty) return null;

    double doubt = 1;
    for (final LinkReason r in found) {
      doubt *= 1 - weight[r.cue]!;
    }
    double confidence = 1 - doubt;
    // A number on both papers outweighs dates that disagree — a warranty is
    // sometimes dated when it was registered — but not entirely.
    if (datesDisagree) confidence *= 0.85;
    if (confidence < threshold) return null;

    found.sort(
      (LinkReason x, LinkReason y) => weight[y.cue]!.compareTo(weight[x.cue]!),
    );
    return LinkSuggestion(
      warrantyId: warranty.id,
      receiptId: receipt.id,
      confidence: double.parse(confidence.toStringAsFixed(3)),
      reasons: found,
    );
  }

  /// Every receipt in [receipts] that [warranty] may belong to, likeliest
  /// first, at most [limit] of them.
  static List<LinkSuggestion> forWarranty(
    PaperFacts warranty,
    Iterable<PaperFacts> receipts, {
    int limit = 3,
  }) => _best(<LinkSuggestion?>[
    for (final PaperFacts r in receipts) compare(warranty, r),
  ], limit);

  /// Every warranty in [warranties] that may be for what [receipt] bought.
  static List<LinkSuggestion> forReceipt(
    PaperFacts receipt,
    Iterable<PaperFacts> warranties, {
    int limit = 3,
  }) => _best(<LinkSuggestion?>[
    for (final PaperFacts w in warranties) compare(w, receipt),
  ], limit);

  static List<LinkSuggestion> _best(List<LinkSuggestion?> all, int limit) {
    final List<LinkSuggestion> out = all.whereType<LinkSuggestion>().toList()
      ..sort(
        (LinkSuggestion a, LinkSuggestion b) =>
            b.confidence.compareTo(a.confidence),
      );
    return out.take(limit).toList();
  }

  /// A serial or an invoice number long enough not to turn up by chance: a
  /// digit in it, four characters at least, and five if it is only digits —
  /// "1234" is on half the receipts in a drawer.
  static bool _isIdentifier(String s) {
    final String q = _squash(s);
    if (!RegExp(r'\d').hasMatch(q) || q.length < 4) return false;
    return RegExp(r'\D').hasMatch(q) || q.length >= 5;
  }

  /// A model is only evidence when it looks like one: letters and digits,
  /// "WR-123" or "15s-fq5111TU", not "Pro".
  static bool _isModel(String s) {
    final String q = _squash(s);
    return q.length >= 4 &&
        RegExp(r'\d').hasMatch(q) &&
        RegExp(r'\D').hasMatch(q);
  }

  static bool _isName(String s) => _squash(s).length >= 2;

  static int _daysApart(LocalDate a, LocalDate b) => DateTime.utc(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime.utc(b.year, b.month, b.day)).inDays.abs();

  /// Upper case, Bangla digits as Latin, nothing but letters and digits.
  static String _squash(String s) =>
      asciiDigits(s).toUpperCase().replaceAll(_notWord, '');
}

final RegExp _notWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// The words on a paper, for asking whether a value is printed on it.
class _Words {
  _Words(String text)
    : _words = asciiDigits(text)
          .toUpperCase()
          .split(_notWord)
          .where((String w) => w.isNotEmpty)
          .toList(),
      _squashed = asciiDigits(text).toUpperCase().replaceAll(_notWord, '');

  final List<String> _words;
  final String _squashed;

  /// Whether [value] is on the paper as whole words, in order — "C02-XL0" is
  /// found in "S/N: C02-XL0" but "A15" is not found inside "A150". A long
  /// value is also found with its spacing lost ("15SFQ5111TU" for
  /// "15s-fq5111TU"), where eight characters are too many to be chance.
  bool has(String value) {
    final List<String> want = asciiDigits(
      value,
    ).toUpperCase().split(_notWord).where((String w) => w.isNotEmpty).toList();
    if (want.isEmpty) return false;
    for (int i = 0; i + want.length <= _words.length; i++) {
      bool all = true;
      for (int j = 0; j < want.length && all; j++) {
        all = _words[i + j] == want[j];
      }
      if (all) return true;
    }
    final String q = want.join();
    return q.length >= 8 && RegExp(r'\d').hasMatch(q) && _squashed.contains(q);
  }
}
