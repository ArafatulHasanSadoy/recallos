import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';

/// Regressions from real cards scanned on a real device.
///
/// Every group here is transcribed from an actual ML Kit result, including its
/// mistakes. Synthetic fixtures were passing while the app was visibly wrong on
/// the first card anyone pointed at it, which is the usual reason to keep a file
/// like this separate: these cases are evidence, not invention.
void main() {
  group('G Ahmed / President — a shop card, no person on it', () {
    // Photographed rotated 90°, which matters: ML Kit returns axis-aligned
    // boxes, so a vertical line of text is tall and narrow. Prominence has to
    // be measured as the *short* side of the box, not its height.
    //
    // Card reads:
    //   G AHMED           (large brand)
    //   Travel with us    (tagline)
    //   President         (large shop name)
    //   01673465717
    //   01714066410       <- ML Kit dropped the leading 0
    //   Shop No:278
    //   New Market
    //   Dhaka-1205
    List<OcrBlock> blocks() => <OcrBlock>[
          _rotated('G AHMED', across: 62, along: 300, offset: 40),
          _rotated('Travel with us', across: 26, along: 260, offset: 120),
          _rotated('President', across: 60, along: 290, offset: 170),
          _rotated('01673465717', across: 34, along: 250, offset: 250),
          // The zero really is missing — this is what the engine returned.
          _rotated('1714066410', across: 34, along: 235, offset: 300),
          _rotated('Shop No:278', across: 24, along: 150, offset: 380),
          _rotated('New Market', across: 24, along: 150, offset: 420),
          _rotated('Dhaka-1205', across: 24, along: 150, offset: 460),
          _rotated('MasterCard', across: 14, along: 70, offset: 520),
          _rotated('VISA', across: 14, along: 50, offset: 560),
          _rotated('bKash', across: 14, along: 50, offset: 600),
        ];

    late CardExtraction result;
    setUp(() => result = CardFieldExtractor.extract(blocks()));

    test('recovers the phone number ML Kit truncated', () {
      final List<ExtractedField> phones = result.ofKey(FieldKeys.phone).toList();
      expect(phones, hasLength(2));

      expect(
        phones.map((ExtractedField f) => f.normalizedValue),
        containsAll(<String>['+8801673465717', '+8801714066410']),
      );
    });

    test('displays a dialable number, not the OCR mistake', () {
      // The user reads this to call someone. Showing "1714066410" because the
      // engine lost a character is not faithful, it is just wrong.
      final ExtractedField truncated = result
          .ofKey(FieldKeys.phone)
          .firstWhere((ExtractedField f) => f.normalizedValue!.endsWith('066410'));

      expect(truncated.value, '01714066410');
      expect(truncated.rawText, '1714066410');
      // Still flagged, because a repaired reading is a guess.
      expect(truncated.needsReview, isTrue);
    });

    test('does not invent a person', () {
      // There is no human on this card. "G AHMED" is a brand and inventing a
      // contact called that pollutes the identity graph permanently.
      expect(result.firstOfKey(FieldKeys.personName), isNull);
    });

    test('does not read the shop name as a job title', () {
      // "President" is a designation keyword, but it is also the largest text
      // on the card, and a job title is never the biggest thing printed.
      expect(result.firstOfKey(FieldKeys.designation), isNull);
    });

    test('treats the brand as the company', () {
      final ExtractedField? company = result.firstOfKey(FieldKeys.company);
      expect(company, isNotNull);
      expect(
        company!.value,
        anyOf('G AHMED', 'President'),
        reason: 'the company should be one of the two prominent brand lines',
      );
    });

    test('joins the whole address, including the shop number', () {
      final ExtractedField? address = result.firstOfKey(FieldKeys.address);
      expect(address, isNotNull);

      // "Shop No:278" is where the shop *is*, not who it is.
      expect(address!.value, contains('Shop No:278'));
      expect(address.value, contains('New Market'));
      expect(address.value, contains('Dhaka-1205'));
    });

    test('does not file the shop number as the company', () {
      final ExtractedField? company = result.firstOfKey(FieldKeys.company);
      expect(company?.value, isNot(contains('278')));
    });

    test('leaves payment logos unassigned rather than guessing', () {
      final List<String> unassigned = result.unassignedBlockIndices
          .map((int i) => blocks()[i].text)
          .toList();
      expect(unassigned, containsAll(<String>['MasterCard', 'VISA', 'bKash']));
    });
  });

  group('address patterns', () {
    test('recognises numbered units without a street keyword', () {
      for (final String line in <String>[
        'Shop No:278',
        'Shop # 12',
        'House 42',
        'Flat No. 5B',
        'Level 3',
        'Holding No: 91',
      ]) {
        final CardExtraction r = CardFieldExtractor.extract(<OcrBlock>[
          _line('Acme Traders', top: 0, height: 30),
          _line(line, top: 60, height: 16),
          _line('01711223344', top: 90, height: 16),
        ]);
        expect(
          r.firstOfKey(FieldKeys.address)?.value,
          contains(line),
          reason: '"$line" should read as an address',
        );
      }
    });

    test('does not mistake a shop-named business for an address', () {
      // The word "shop" alone must not trigger; only the numbered-unit form.
      final CardExtraction r = CardFieldExtractor.extract(<OcrBlock>[
        _line('The Coffee Shop', top: 0, height: 30),
        _line('01711223344', top: 60, height: 16),
      ]);
      expect(r.firstOfKey(FieldKeys.address), isNull);
      expect(r.firstOfKey(FieldKeys.company)?.value, 'The Coffee Shop');
    });
  });

  group('person cards still work', () {
    test('a card with a real designation still yields a person', () {
      // The no-person rule must not break ordinary business cards: a job title
      // in small print is exactly the evidence that a human is on the card.
      final CardExtraction r = CardFieldExtractor.extract(<OcrBlock>[
        _line('Medica Books Ltd', top: 10, height: 34),
        _line('Rahim Uddin', top: 60, height: 26),
        _line('Senior Sales Manager', top: 95, height: 15),
        _line('01711223344', top: 125, height: 15),
      ]);

      expect(r.firstOfKey(FieldKeys.personName)?.value, 'Rahim Uddin');
      expect(r.firstOfKey(FieldKeys.company)?.value, 'Medica Books Ltd');
      expect(r.firstOfKey(FieldKeys.designation)?.value, 'Senior Sales Manager');
    });

    test('a personal email is enough evidence of a person', () {
      final CardExtraction r = CardFieldExtractor.extract(<OcrBlock>[
        _line('Acme Trading', top: 10, height: 30),
        _line('Kamal Hossain', top: 55, height: 22),
        _line('kamal@acmetrading.com', top: 90, height: 14),
      ]);
      expect(r.firstOfKey(FieldKeys.personName)?.value, 'Kamal Hossain');
    });
  });
}

/// A horizontal line of text: box height is the text size.
OcrBlock _line(String text, {required double top, required double height}) =>
    OcrBlock(
      text: text,
      rect: Rect.fromLTWH(10, top, 20.0 * text.length, height),
      confidence: 0.9,
      script: Script.latin,
    );

/// A line of text rotated 90°, as it comes back when the card is photographed
/// sideways: [across] is the text size, [along] is the line length.
OcrBlock _rotated(
  String text, {
  required double across,
  required double along,
  required double offset,
}) =>
    OcrBlock(
      text: text,
      rect: Rect.fromLTWH(offset, 100, across, along),
      confidence: 0.9,
      script: Script.latin,
    );
