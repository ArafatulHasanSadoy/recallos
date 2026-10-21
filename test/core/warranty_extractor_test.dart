import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/warranty_extractor.dart';

import '../support/ocr_layout.dart';

/// Invented warranty cards in common shapes — an appliance card, a phone's
/// certificate with an IMEI, a laptop's with a printed expiry.
void main() {
  ExtractedField? f(CardExtraction e, String key) => e.firstOfKey(key);

  group('an appliance warranty card', () {
    final CardExtraction e = WarrantyExtractor.extract(
      paper(<Object>[
        'WALTON',
        'WARRANTY CARD',
        'Product: Refrigerator',
        'Model: WFC-3F5-GDEL',
        'Serial No: 2309WF0045812',
        'Date of Purchase: 01/09/2026',
        'Warranty Period: 5 Years Compressor, 1 Year Parts',
        'Warranty is valid from the date of purchase',
        'Authorized Service Centre: 16267',
      ]),
    );

    test('what it is and how to identify it', () {
      expect(f(e, WarrantyKeys.brand)!.value, 'WALTON');
      expect(f(e, WarrantyKeys.product)!.value, 'Refrigerator');
      expect(f(e, WarrantyKeys.model)!.normalizedValue, 'WFC-3F5-GDEL');
      final ExtractedField serial = f(e, WarrantyKeys.serial)!;
      expect(serial.value, '2309WF0045812');
      expect(serial.normalizedValue, '2309WF0045812');
    });

    test('how long, from when — and a split cover is flagged', () {
      final ExtractedField cover = f(e, WarrantyKeys.coverMonths)!;
      expect(cover.normalizedValue, '60');
      expect(cover.value, '5 years');
      expect(cover.needsReview, isTrue);
      expect(cover.issue, 'split_cover');
      expect(f(e, WarrantyKeys.startBasis)!.normalizedValue, 'purchase');
      expect(f(e, WarrantyKeys.purchaseDate)!.dateValue, LocalDate(2026, 9, 1));
    });

    test('no expiry is invented when none is printed', () {
      expect(f(e, WarrantyKeys.expiryDate), isNull);
    });
  });

  test('a phone certificate: IMEI, months, a printed expiry', () {
    final CardExtraction e = WarrantyExtractor.extract(
      paper(<Object>[
        'realme',
        'Warranty Certificate',
        'Model Name: realme 12 Pro',
        'IMEI 1: 864392051234567',
        'Purchase Date: 15-Sep-2026',
        'Warranty: 12 months',
        'Valid till: 14/09/2027',
      ]),
    );
    expect(f(e, WarrantyKeys.brand)!.value, 'realme');
    expect(f(e, WarrantyKeys.model)!.value, 'realme 12 Pro');
    expect(f(e, WarrantyKeys.serial)!.value, '864392051234567');
    expect(f(e, WarrantyKeys.coverMonths)!.normalizedValue, '12');
    expect(f(e, WarrantyKeys.coverMonths)!.issue, isNull);
    final ExtractedField expiry = f(e, WarrantyKeys.expiryDate)!;
    expect(expiry.dateValue, LocalDate(2027, 9, 14));
    expect(expiry.needsReview, isTrue);
    expect(f(e, WarrantyKeys.purchaseDate)!.dateValue, LocalDate(2026, 9, 15));
  });

  test('a label and its value in two columns', () {
    final CardExtraction e = WarrantyExtractor.extract(
      paper(<Object>[
        'Star Tech',
        ('Serial', 'PF3XK92L'),
        ('Warranty', '2 Years'),
      ]),
    );
    expect(f(e, WarrantyKeys.serial)!.value, 'PF3XK92L');
    expect(f(e, WarrantyKeys.coverMonths)!.normalizedValue, '24');
  });

  test('a period with no warranty words near it is not the cover', () {
    final CardExtraction e = WarrantyExtractor.extract(
      paper(<Object>['Gadget Shop', 'Open 7 days, 10 months of the year']),
    );
    expect(f(e, WarrantyKeys.coverMonths), isNull);
  });

  test('"Serial Number" with no number is not a serial', () {
    final CardExtraction e = WarrantyExtractor.extract(
      paper(<Object>['Brand', 'Serial Number: ________']),
    );
    expect(f(e, WarrantyKeys.serial), isNull);
  });
}
