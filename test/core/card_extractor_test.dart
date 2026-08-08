import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';

/// Builds a block laid out like a line of text on a card.
///
/// `height` stands in for font size, which is the signal the name/company
/// heuristic actually uses.
OcrBlock block(
  String text, {
  double top = 0,
  double height = 20,
  double confidence = 0.9,
  Script script = Script.latin,
}) {
  return OcrBlock(
    text: text,
    rect: Rect.fromLTWH(10, top, 300, height),
    confidence: confidence,
    script: script,
  );
}

void main() {
  group('CardFieldExtractor — a well-formed card', () {
    late CardExtraction result;

    setUp(() {
      result = CardFieldExtractor.extract(<OcrBlock>[
        block('Medica Books Ltd', top: 10, height: 34),
        block('Rahim Uddin', top: 60, height: 26),
        block('Senior Sales Manager', top: 92, height: 16),
        block('Mob: 01711-223344', top: 120, height: 16),
        block('info@medicabooks.com.bd', top: 142, height: 16),
        block('www.medicabooks.com.bd', top: 164, height: 16),
        block('House 42, Road 7, Dhanmondi, Dhaka', top: 186, height: 16),
      ]);
    });

    test('finds the phone and normalises it', () {
      final ExtractedField? phone = result.firstOfKey(FieldKeys.phone);
      expect(phone, isNotNull);
      expect(phone!.normalizedValue, '+8801711223344');
    });

    test('finds the email and the website without confusing them', () {
      expect(
        result.firstOfKey(FieldKeys.email)?.normalizedValue,
        'info@medicabooks.com.bd',
      );
      expect(
        result.firstOfKey(FieldKeys.website)?.normalizedValue,
        'medicabooks.com.bd',
      );
    });

    test('separates the person from the organization', () {
      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Rahim Uddin');
      expect(result.firstOfKey(FieldKeys.company)?.value, 'Medica Books Ltd');
    });

    test('reads the designation', () {
      expect(
        result.firstOfKey(FieldKeys.designation)?.value,
        'Senior Sales Manager',
      );
    });

    test('joins the address', () {
      expect(result.firstOfKey(FieldKeys.address)?.value, contains('Dhanmondi'));
    });

    test('every field carries the region it came from', () {
      for (final ExtractedField f in result.fields) {
        expect(f.regionRect, isNotNull, reason: '${f.fieldKey} lost its rect');
        expect(f.regionRect, matches(RegExp(r'^\d+,\d+,\d+,\d+$')));
      }
    });

    test('counts as useful', () {
      expect(result.isUseful, isTrue);
      expect(result.unassignedBlockIndices, isEmpty);
    });
  });

  group('CardFieldExtractor — the Bengali card case', () {
    // The important one. ML Kit cannot read Bengali, so the company name comes
    // back as unreadable — but phone, email and website are Latin on nearly
    // every Bangladeshi card, so the valuable fields still land.
    test('still extracts contact details when the Bengali name is lost', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('', top: 10, height: 34, script: Script.bengali, confidence: 0.2),
        block('Rahim Uddin', top: 60, height: 26),
        block('01711-223344', top: 120, height: 16),
        block('info@medicabooks.com.bd', top: 142, height: 16),
      ]);

      expect(
        result.firstOfKey(FieldKeys.phone)?.normalizedValue,
        '+8801711223344',
      );
      expect(result.firstOfKey(FieldKeys.email), isNotNull);
      expect(result.isUseful, isTrue);
    });

    test('matches a company line against its own domain', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Medica Books', top: 10, height: 30),
        block('Rahim Uddin', top: 50, height: 28),
        block('info@medicabooks.com.bd', top: 100, height: 16),
      ]);

      // "Medica Books" has no Ltd/Traders suffix; the domain is what identifies
      // it as the organization.
      expect(result.firstOfKey(FieldKeys.company)?.value, 'Medica Books');
      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Rahim Uddin');
    });
  });

  group('CardFieldExtractor — failure and recovery', () {
    test('an empty card yields an empty extraction rather than throwing', () {
      final CardExtraction result =
          CardFieldExtractor.extract(const <OcrBlock>[]);

      expect(result.isEmpty, isTrue);
      expect(result.isUseful, isFalse);
      expect(result.unassignedBlockIndices, isEmpty);
    });

    test('unclaimed blocks are offered for tap-to-assign', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Rahim Uddin', top: 10, height: 30),
        block('Medica Books Ltd', top: 50, height: 28),
        // Neither pattern nor keyword claims these.
        block('Est. 1998', top: 100, height: 14),
        block('Quality Guaranteed', top: 120, height: 14),
      ]);

      expect(result.unassignedBlockIndices, isNotEmpty);
      expect(result.unassignedBlockIndices, containsAll(<int>[2, 3]));
    });

    test('a card with only a phone number is still useful', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('01711-223344', top: 10, height: 20),
      ]);
      expect(result.isUseful, isTrue);
    });

    test('low OCR confidence carries through to the field', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('01711-223344', top: 10, height: 20, confidence: 0.35),
      ]);
      expect(result.firstOfKey(FieldKeys.phone)!.confidence, lessThan(0.5));
    });

    test('unknown OCR confidence is treated as middling, not as certain', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block(
          '01711-223344',
          top: 10,
          height: 20,
          confidence: OcrBlock.confidenceUnknown,
        ),
      ]);
      final double c = result.firstOfKey(FieldKeys.phone)!.confidence;
      expect(c, lessThan(1.0));
      expect(c, greaterThan(0.0));
    });
  });

  group('CardFieldExtractor — cross-field checks', () {
    test('flags a name identical to the company', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Medica Books Ltd', top: 10, height: 30),
        block('Medica Books Ltd', top: 50, height: 28),
        block('01711-223344', top: 90, height: 16),
      ]);

      final ExtractedField? name = result.firstOfKey(FieldKeys.personName);
      if (name != null) {
        expect(name.issue, 'same_as_company');
        expect(name.needsReview, isTrue);
      }
    });

    test('flags a name that is really an address line', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('House 42, Dhanmondi', top: 10, height: 30),
        block('01711-223344', top: 60, height: 16),
      ]);

      final ExtractedField? name = result.firstOfKey(FieldKeys.personName);
      // Either the address rule claimed it, or the name rule flagged it. What
      // must not happen is it being presented as a confident person name.
      if (name != null) {
        expect(name.needsReview, isTrue);
      }
    });

    test('does not mistake a company containing "MD" for a designation', () {
      // Whole-word matching is what keeps "Mdina" from reading as "MD".
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Mdina Traders', top: 10, height: 30),
        block('01711-223344', top: 60, height: 16),
      ]);
      expect(result.firstOfKey(FieldKeys.designation), isNull);
    });
  });

  group('CardFieldExtractor — multiple values', () {
    test('keeps every distinct phone number on the card', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Rahim Uddin', top: 10, height: 30),
        block('Office: 01711-223344', top: 60, height: 16),
        block('Cell: 01911-556677', top: 82, height: 16),
      ]);

      final List<String?> numbers = result
          .ofKey(FieldKeys.phone)
          .map((ExtractedField f) => f.normalizedValue)
          .toList();
      expect(numbers, hasLength(2));
      expect(
        numbers,
        containsAll(<String>['+8801711223344', '+8801911556677']),
      );
    });

    test('collapses the same number written twice', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Cell: 01711-223344', top: 10, height: 16),
        block('WhatsApp: +880 1711 223344', top: 32, height: 16),
      ]);
      expect(result.ofKey(FieldKeys.phone), hasLength(1));
    });
  });
}
