import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/document_classifier.dart';
import 'package:recallos/core/extraction/document_lines.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';

/// Invented documents in the shapes common in Bangladesh. Not copies of any
/// real receipt; the readers are tuned on the owner's own paper later.
const String techFixCard = '''
TechFix Repair Centre
Kamal Hossain
Service Manager
+880 1617-223311
kamal@techfixrepair.com
www.techfixrepair.com
Shop 14, Elephant Road, Dhaka''';

const String superShopReceipt = '''
SHOPNO SUPER SHOP
Banani, Dhaka
Invoice No: 4432-118
Date: 12/10/2026 18:42
Item Qty Price Amount
Milk 1L 2 95.00 190.00
Bread 1 60.00 60.00
Eggs 12 13.50 162.00
Subtotal 412.00
VAT 5% 20.60
Grand Total 432.60
Cash 500.00
Change 67.40''';

const String electronicsInvoice = '''
STAR TECH & ENGINEERING LTD
Multiplan Center, Elephant Road
SALES INVOICE
Invoice: ST-889201 Date: 05-Oct-2026
Product Qty Unit Price Total
Lenovo IdeaPad Slim 3 1 72,500.00 72,500.00
Warranty: 2 Years
Sub Total 72,500.00
Net Payable Tk 72,500.00
Paid by bKash''';

const String restaurantBill = '''
Kacchi Bhai
Gulshan 1
Table 7 Guest 3
Kacchi Basmati 2 x 450 900.00
Borhani 3 x 80 240.00
Total 1,140.00
VAT 7.5% 85.50
Net Payable 1,225.50''';

const String warrantyCard = '''
WALTON
WARRANTY CARD
Product: Refrigerator
Model: WFC-3F5-GDEL
Serial No: 2309WF0045812
Date of Purchase: 01/09/2026
Warranty Period: 5 Years Compressor
Authorized Service Centre: 16267''';

void main() {
  group('classifyDocument', () {
    test('a business card', () {
      final Classification c = classifyDocument(techFixCard);
      expect(c.kind, DocumentKind.businessCard);
      expect(c.isSure, isTrue, reason: '$c');
    });

    test('a supermarket receipt', () {
      final Classification c = classifyDocument(superShopReceipt);
      expect(c.kind, DocumentKind.receipt);
      expect(c.isSure, isTrue, reason: '$c');
      expect(c.reasons, contains('a total'));
    });

    test('an invoice that mentions its warranty is still the invoice', () {
      final Classification c = classifyDocument(electronicsInvoice);
      expect(c.kind, DocumentKind.receipt, reason: '$c');
    });

    test('a restaurant bill', () {
      expect(classifyDocument(restaurantBill).kind, DocumentKind.receipt);
    });

    test('a warranty card', () {
      final Classification c = classifyDocument(warrantyCard);
      expect(c.kind, DocumentKind.warranty);
      expect(c.isSure, isTrue, reason: '$c');
      expect(c.reasons, contains('a serial number'));
    });

    test('a slogan with "total" in it is not a bill', () {
      // A shop's card: "total" with no amount after it says nothing about
      // money.
      final Classification c = classifyDocument(
        'Rahim Traders\nTotal solutions for your home\n01711-223344',
      );
      expect(c.kind, DocumentKind.businessCard, reason: '$c');
    });

    test('too little to go on is "not sure", so the user is asked', () {
      final Classification c = classifyDocument('Thank you, come again');
      expect(c.isSure, isFalse, reason: '$c');
    });

    test('nothing readable is not sure either', () {
      expect(classifyDocument('').isSure, isFalse);
    });
  });

  group('findDates', () {
    LocalDate only(String s) {
      final List<FoundDate> found = findDates(s);
      expect(found, hasLength(1), reason: s);
      return found.single.date;
    }

    test('day first, as Bangladeshi paper prints it', () {
      expect(only('Date: 12/10/2026'), LocalDate(2026, 10, 12));
      expect(only('05.10.2026'), LocalDate(2026, 10, 5));
      expect(only('12/10/26'), LocalDate(2026, 10, 12));
    });

    test('month names and ISO', () {
      expect(only('05-Oct-2026'), LocalDate(2026, 10, 5));
      expect(only('5th October 2026'), LocalDate(2026, 10, 5));
      expect(only('Oct 5, 2026'), LocalDate(2026, 10, 5));
      expect(only('2026-10-05'), LocalDate(2026, 10, 5));
    });

    test('Bangla digits', () {
      expect(only('তারিখ: ১২/১০/২০২৬'), LocalDate(2026, 10, 12));
    });

    test('impossible days and phone numbers are not dates', () {
      expect(findDates('31/02/2026'), isEmpty);
      expect(findDates('01711-223344'), isEmpty);
      expect(findDates('Total 1,140.00'), isEmpty);
    });
  });

  group('rowsOf', () {
    OcrBlock block(String text, double left, double top) => OcrBlock(
      text: text,
      rect: Rect.fromLTWH(left, top, 120, 20),
      confidence: 0.9,
      script: Script.latin,
    );

    test('a label and its amount in two columns are one row', () {
      final List<DocLine> rows = rowsOf(<OcrBlock>[
        block('8,450.00', 300, 502),
        block('Grand Total', 10, 500),
        block('Cash', 10, 540),
        block('9,000.00', 300, 541),
      ]);
      expect(rows.map((DocLine r) => r.text), <String>[
        'Grand Total 8,450.00',
        'Cash 9,000.00',
      ]);
      expect(rows.first.parts, <String>['Grand Total', '8,450.00']);
      expect(rows.first.blockIndices, <int>[1, 0]);
    });
  });

  group('moneyPattern and currencyOf', () {
    test('finds prices, not quantities or years', () {
      final List<String> found = moneyPattern
          .allMatches('Eggs 12 13.50 162.00 in 2026, total 1,23,456')
          .map((RegExpMatch m) => m[0]!)
          .toList();
      expect(found, <String>['13.50', '162.00', '1,23,456']);
    });

    test('says which currency, or nothing', () {
      expect(currencyOf('Net Payable Tk 72,500.00'), 'BDT');
      expect(currencyOf('৳ 99'), 'BDT');
      expect(currencyOf('Total USD 12.00'), 'USD');
      expect(currencyOf('Grand Total 432.60'), isNull);
    });
  });
}
