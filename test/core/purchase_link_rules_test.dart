import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/linking/purchase_link_rules.dart';

/// The laptop from PLAN §3's *Purchase* story, on both papers.
const String _receiptText = '''
STAR TECH & ENGINEERING LTD
Multiplan Center, Elephant Road, Dhaka
Invoice No: ST-2026-0412
Date: 12/10/2026
HP 15s-fq5111TU Laptop  1  78,500.00
S/N: 5CD3281XYZ
Grand Total  78,500.00
''';

const String _warrantyText = '''
HP
Warranty Card
Product: Laptop
Model: 15s-fq5111TU
Serial No: 5CD3281XYZ
Warranty: 2 Years from the date of purchase
Date of Purchase: 12/10/2026
Invoice No: ST-2026-0412
Dealer: Star Tech & Engineering Ltd
''';

PaperFacts _warranty({
  int id = 1,
  String text = _warrantyText,
  String? serial = '5CD3281XYZ',
  LocalDate? purchaseDate,
  String? model = '15s-fq5111TU',
  String? brand = 'HP',
}) => PaperFacts(
  id: id,
  text: text,
  serial: serial,
  purchaseDate: purchaseDate ?? LocalDate(2026, 10, 12),
  model: model,
  brand: brand,
);

PaperFacts _receipt({
  int id = 2,
  String text = _receiptText,
  String? invoice = 'ST-2026-0412',
  LocalDate? purchaseDate,
  String? merchant = 'Star Tech & Engineering Ltd',
}) => PaperFacts(
  id: id,
  text: text,
  invoiceNumber: invoice,
  purchaseDate: purchaseDate ?? LocalDate(2026, 10, 12),
  merchant: merchant,
);

List<LinkCue> _cues(LinkSuggestion? s) =>
    s!.reasons.map((LinkReason r) => r.cue).toList();

void main() {
  group('strong evidence', () {
    test('the serial printed on the receipt links them, strongest first', () {
      final LinkSuggestion? s = PurchaseLinkRules.compare(
        _warranty(),
        _receipt(),
      );
      expect(s, isNotNull);
      expect(s!.warrantyId, 1);
      expect(s.receiptId, 2);
      expect(s.confidence, greaterThan(0.95));
      expect(_cues(s).first, LinkCue.serial);
      expect(s.reasons.first.describe(), 'Serial 5CD3281XYZ is on both');
      expect(
        _cues(s),
        containsAll(<LinkCue>[
          LinkCue.serial,
          LinkCue.invoice,
          LinkCue.sameDay,
          LinkCue.model,
          LinkCue.brand,
          LinkCue.shop,
        ]),
      );
    });

    test('a serial alone is enough', () {
      final LinkSuggestion? s = PurchaseLinkRules.compare(
        PaperFacts(id: 1, text: 'Warranty', serial: '5CD3281XYZ'),
        PaperFacts(id: 2, text: 'Item  S/N 5CD3281XYZ  78,500'),
      );
      expect(_cues(s), <LinkCue>[LinkCue.serial]);
    });

    test('the invoice number printed on the warranty is enough', () {
      final LinkSuggestion? s = PurchaseLinkRules.compare(
        PaperFacts(id: 1, text: 'Warranty card\nInvoice: ST-2026-0412'),
        PaperFacts(id: 2, text: _receiptText, invoiceNumber: 'ST-2026-0412'),
      );
      expect(_cues(s), <LinkCue>[LinkCue.invoice]);
      expect(s!.reasons.single.describe(), 'Invoice ST-2026-0412 is on both');
    });

    test('a serial with its spacing lost is still found when long', () {
      final LinkSuggestion? s = PurchaseLinkRules.compare(
        PaperFacts(id: 1, text: '', serial: 'R58-N9 2KXYZ'),
        PaperFacts(id: 2, text: 'IMEI R58N92KXYZ'),
      );
      expect(_cues(s), <LinkCue>[LinkCue.serial]);
    });

    test('Bangla digits match Latin ones', () {
      final LinkSuggestion? s = PurchaseLinkRules.compare(
        PaperFacts(id: 1, text: '', serial: '356789012345678'),
        PaperFacts(id: 2, text: 'IMEI: ৩৫৬৭৮৯০১২৩৪৫৬৭৮'),
      );
      expect(_cues(s), <LinkCue>[LinkCue.serial]);
    });
  });

  group('not by chance', () {
    test('a short number is not evidence', () {
      // "1234" and "20261" turn up on any receipt.
      expect(
        PurchaseLinkRules.compare(
          PaperFacts(id: 1, text: 'Invoice 1234', serial: '1234'),
          PaperFacts(id: 2, text: 'Qty 1234', invoiceNumber: '1234'),
        ),
        isNull,
      );
    });

    test('a value is found as whole words, not inside a longer one', () {
      expect(
        PurchaseLinkRules.compare(
          PaperFacts(id: 1, text: '', serial: 'AB123'),
          PaperFacts(id: 2, text: 'Code XAB1234'),
        ),
        isNull,
      );
    });

    test('the same day alone is not enough', () {
      expect(
        PurchaseLinkRules.compare(
          PaperFacts(id: 1, text: '', purchaseDate: LocalDate(2026, 10, 12)),
          PaperFacts(id: 2, text: '', purchaseDate: LocalDate(2026, 10, 12)),
        ),
        isNull,
      );
    });

    test('a brand and a shop alone are a shop that sells the brand', () {
      expect(
        PurchaseLinkRules.compare(
          PaperFacts(id: 1, text: 'Dealer: Star Tech', brand: 'HP'),
          PaperFacts(id: 2, text: 'HP mouse 850', merchant: 'Star Tech'),
        ),
        isNull,
      );
    });

    test('the same day and the model together are enough', () {
      final LinkSuggestion? s = PurchaseLinkRules.compare(
        _warranty(serial: null, brand: null),
        _receipt(invoice: null, merchant: null, text: 'HP 15s-fq5111TU 78,500'),
      );
      expect(_cues(s), <LinkCue>[LinkCue.model, LinkCue.sameDay]);
      expect(s!.confidence, inInclusiveRange(0.5, 0.8));
    });

    test('dates weeks apart silence the weak cues', () {
      expect(
        PurchaseLinkRules.compare(
          _warranty(serial: null, purchaseDate: LocalDate(2026, 9, 1)),
          _receipt(invoice: null),
        ),
        isNull,
      );
    });

    test('a serial still counts across dates that disagree, a little less', () {
      final LinkSuggestion? s = PurchaseLinkRules.compare(
        _warranty(purchaseDate: LocalDate(2026, 11, 20)),
        _receipt(invoice: null),
      );
      expect(_cues(s), <LinkCue>[LinkCue.serial]);
      expect(s!.confidence, lessThan(0.95));
      expect(s.confidence, greaterThan(PurchaseLinkRules.threshold));
    });

    test('a paper is never linked to itself', () {
      expect(
        PurchaseLinkRules.compare(_warranty(id: 3), _receipt(id: 3)),
        isNull,
      );
    });
  });

  group('choosing among several', () {
    test('the likeliest receipt first, unrelated ones left out', () {
      final List<LinkSuggestion> out =
          PurchaseLinkRules.forWarranty(_warranty(), <PaperFacts>[
            PaperFacts(id: 10, text: 'Shwapno  Rice 5kg  450.00'),
            _receipt(id: 11, invoice: null, text: 'HP 15s-fq5111TU 78,500'),
            _receipt(id: 12),
          ]);
      expect(out.map((LinkSuggestion s) => s.receiptId), <int>[12, 11]);
    });

    test('from a receipt, the warranties it may be for', () {
      final List<LinkSuggestion> out = PurchaseLinkRules.forReceipt(
        _receipt(),
        <PaperFacts>[_warranty(id: 20), _warranty(id: 21, serial: 'ZZZ99999')],
      );
      expect(out.first.warrantyId, 20);
      expect(out.first.receiptId, 2);
    });
  });

  group('reasons', () {
    test('survive being stored and read back', () {
      const LinkReason r = LinkReason(LinkCue.serial, '5CD3281XYZ');
      expect(LinkReason.fromJson(r.toJson()), r);
    });

    test('a cue this build does not know is skipped, not a crash', () {
      expect(
        LinkReason.fromJson(<String, String>{'cue': 'barcode', 'value': 'x'}),
        isNull,
      );
      expect(LinkReason.fromJson('serial'), isNull);
    });

    test('each reads as a plain line', () {
      expect(
        const LinkReason(LinkCue.sameDay, '12 Oct 2026').describe(),
        'Both dated 12 Oct 2026',
      );
      expect(
        const LinkReason(LinkCue.model, '15s-fq5111TU').describe(),
        'Model 15s-fq5111TU is on the receipt',
      );
      expect(
        const LinkReason(LinkCue.shop, 'Star Tech').describe(),
        'Star Tech is on the warranty',
      );
      expect(const LinkReason(LinkCue.chosen).describe(), 'You linked these');
    });
  });
}
