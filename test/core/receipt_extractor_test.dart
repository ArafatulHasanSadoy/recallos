import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/receipt_extractor.dart';

import '../support/ocr_layout.dart';

ExtractedField? field(CardExtraction e, String key) => e.firstOfKey(key);

void main() {
  group('a supermarket receipt', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>[
        'SHOPNO SUPER SHOP',
        'Banani, Dhaka',
        'Invoice No: 4432-118',
        'Date: 12/10/2026 18:42',
        ('Milk 1L 2 x 95.00', '190.00'),
        ('Bread 1 x 60.00', '60.00'),
        ('Subtotal', '412.00'),
        ('VAT 5%', '20.60'),
        ('Grand Total', '432.60'),
        ('Cash', '500.00'),
        ('Change', '67.40'),
      ]),
    );

    test('the total is the grand total, in paisa, in taka', () {
      final ExtractedField total = field(e, ReceiptKeys.total)!;
      expect(total.amountMinor, 43260);
      expect(total.currency, 'BDT');
      expect(total.value, 'BDT 432.60');
      expect(total.needsReview, isTrue, reason: 'a total is always checked');
    });

    test('the merchant, the day and the invoice number', () {
      expect(field(e, ReceiptKeys.merchant)!.value, 'SHOPNO SUPER SHOP');
      final ExtractedField date = field(e, ReceiptKeys.purchaseDate)!;
      expect(date.dateValue, LocalDate(2026, 10, 12));
      expect(date.value, '12 Oct 2026');
      expect(date.needsReview, isTrue);
      expect(field(e, ReceiptKeys.invoiceNumber)!.value, '4432-118');
    });

    test('a category is offered as a guess', () {
      final ExtractedField c = field(e, ReceiptKeys.category)!;
      expect(c.value, 'Groceries');
      expect(c.issue, 'guessed');
    });

    test('the line items stay for the picker', () {
      expect(e.unassignedBlockIndices, isNotEmpty);
    });
  });

  test('an electronics invoice: "Net Payable Tk" and a month name', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>[
        'STAR TECH & ENGINEERING LTD',
        'Multiplan Center, Elephant Road',
        'SALES INVOICE',
        'Invoice: ST-889201 Date: 05-Oct-2026',
        ('Lenovo IdeaPad Slim 3 1', '72,500.00'),
        'Warranty: 2 Years',
        ('Sub Total', '72,500.00'),
        ('Net Payable', 'Tk 72,500.00'),
        'Paid by bKash',
      ]),
    );
    expect(
      field(e, ReceiptKeys.merchant)!.value,
      'STAR TECH & ENGINEERING LTD',
    );
    expect(field(e, ReceiptKeys.total)!.amountMinor, 7250000);
    expect(
      field(e, ReceiptKeys.purchaseDate)!.dateValue,
      LocalDate(2026, 10, 5),
    );
    expect(field(e, ReceiptKeys.invoiceNumber)!.value, 'ST-889201');
    expect(field(e, ReceiptKeys.category)!.value, 'Electronics');
  });

  test('a restaurant bill: net payable beats a plain total', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>[
        'Kacchi Bhai',
        'Gulshan 1',
        ('Kacchi Basmati 2 x 450', '900'),
        ('Borhani 3 x 80', '240'),
        ('Total', '1,140.00'),
        ('VAT 7.5%', '85.50'),
        ('Net Payable', '1,225.50'),
      ]),
    );
    expect(field(e, ReceiptKeys.total)!.amountMinor, 122550);
    expect(field(e, ReceiptKeys.category)!.value, 'Food and drink');
    expect(field(e, ReceiptKeys.purchaseDate), isNull, reason: 'none printed');
  });

  test('a plain "Total 900" counts when it is the only total', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>['Tea Stall Rahman', ('Cha 6', '90'), ('Total', '900')]),
    );
    expect(field(e, ReceiptKeys.total)!.amountMinor, 90000);
  });

  test('a total wrapped onto the row below', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>['Daily Bazar', 'Grand Total', '8,450.00', 'Thank you']),
    );
    expect(field(e, ReceiptKeys.total)!.amountMinor, 845000);
  });

  test('subtotal, total quantity and change are never the total', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>[
        'Corner Shop',
        ('Total Qty', '3'),
        ('Sub Total', '1,000.00'),
        ('Change', '20.00'),
      ]),
    );
    expect(field(e, ReceiptKeys.total), isNull);
  });

  test('no labelled total: no total, rather than a guess', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>['Corner Shop', ('Rice 5kg', '450.00')]),
    );
    expect(field(e, ReceiptKeys.total), isNull);
  });

  test('Bangla: সর্বমোট and Bangla digits', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>[
        'মিনা বাজার',
        'তারিখ: ১২/১০/২০২৬',
        ('মোট', '১,২০০.০০'),
        ('সর্বমোট', '১,২৬০.০০'),
      ]),
    );
    expect(field(e, ReceiptKeys.total)!.amountMinor, 126000);
    expect(
      field(e, ReceiptKeys.purchaseDate)!.dateValue,
      LocalDate(2026, 10, 12),
    );
  });

  test('a receipt in dollars says so', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>['Duty Free Shop', ('Total USD', '12.50')]),
    );
    final ExtractedField total = field(e, ReceiptKeys.total)!;
    expect(total.currency, 'USD');
    expect(total.amountMinor, 1250);
  });

  test('a warranty date on the receipt is not the purchase date', () {
    final CardExtraction e = ReceiptExtractor.extract(
      paper(<Object>[
        'Ryans Computers',
        'Warranty valid till 05/10/2028',
        'Date: 05/10/2026',
        ('Grand Total', '45,000.00'),
      ]),
    );
    expect(
      field(e, ReceiptKeys.purchaseDate)!.dateValue,
      LocalDate(2026, 10, 5),
    );
  });
}
