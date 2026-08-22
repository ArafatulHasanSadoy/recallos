import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/identity/resolution.dart';
import 'package:recallos/core/identity/similarity.dart';

/// The measure that decides whether two OCR reads are the same name.
///
/// Its whole job is to separate two cases that look alike numerically: one
/// word mangled by the engine, versus two different businesses that share a
/// family name. The threshold has to fall between them, so both are pinned
/// here with the real strings that motivated it.
void main() {
  group('edit distance', () {
    test('counts the obvious cases', () {
      expect(editDistance('abc', 'abc'), 0);
      expect(editDistance('', 'abc'), 3);
      expect(editDistance('abc', ''), 3);
      expect(editDistance('kitten', 'sitting'), 3);
    });

    test('is symmetric', () {
      expect(editDistance('target', 'ctargei'),
          editDistance('ctargei', 'target'));
    });
  });

  group('plausible names', () {
    test('a real name passes', () {
      for (final String name in <String>[
        'Md. Abul Bashar Sarker',
        'Asif Ahmed Peal',
        'A. K. M. Rahman',
        'Peal',
      ]) {
        expect(looksLikePersonName(name), isTrue, reason: name);
      }
    });

    test('an address that landed in the name field does not', () {
      // A real read, off the email row of a shop card whose text ran
      // together. Promoted, it becomes a contact named after an email.
      expect(looksLikePersonName('OE-mgil: targetbrand2015@gm'), isFalse);
      expect(looksLikePersonName('targetbrand2015@gmail.com'), isFalse);
      expect(looksLikePersonName('www.techlandbd.com'), isTrue,
          reason: 'a bare domain has no @ or colon and reads as a name; the '
              'website extractor is what keeps it out of this field');
    });

    test('a label that came along with its colon does not', () {
      expect(looksLikePersonName('Cell: 01711363991'), isFalse);
      expect(looksLikePersonName('E-mail: someone'), isFalse);
    });

    test('something mostly digits does not', () {
      expect(looksLikePersonName('220/D 1216'), isFalse);
      expect(looksLikePersonName(''), isFalse);
      expect(looksLikePersonName(null), isFalse);
    });
  });

  group('name similarity', () {
    test('an OCR variant of one word still reads as the same name', () {
      // Two reads of the same shop sign, minutes apart. This is the pair the
      // whole feature exists for, and exact equality finds nothing in it.
      final double score = nameSimilarity(
        normalizeOrgName('TARGET, CENTER,'),
        normalizeOrgName('CTARGEI. CENTER'),
      );

      expect(score, greaterThan(proposeSimilarity));
    });

    test('two businesses sharing a family name stay apart', () {
      final double score = nameSimilarity(
        normalizeOrgName('Rahman Traders'),
        normalizeOrgName('Rahman Motors'),
      );

      expect(score, lessThan(proposeSimilarity),
          reason: 'these are two different shops and must not be proposed');
    });

    test('a shared word alone is not a match', () {
      // "Hospital" appears on half the cards in a medical district.
      final double score = nameSimilarity(
        normalizeOrgName('Olympus Hospital'),
        normalizeOrgName('Green Hospital'),
      );
      expect(score, lessThan(proposeSimilarity));
    });

    test('a longer name is not matched by one of its words', () {
      final double score = nameSimilarity(
        normalizeOrgName('Target'),
        normalizeOrgName('Target Center Dhaka Limited'),
      );
      // Dividing by the longer token count is what stops this scoring 1.0.
      expect(score, lessThan(proposeSimilarity));
    });

    test('identical names score 1', () {
      expect(nameSimilarity('aquarius pet shop', 'aquarius pet shop'), 1);
    });

    test('null is never similar to anything', () {
      expect(nameSimilarity(null, 'anything'), 0);
      expect(nameSimilarity('anything', null), 0);
    });

    test('word order does not matter', () {
      // Extraction takes tokens off a card in layout order, which is not
      // always reading order.
      expect(
        nameSimilarity('center target', 'target center'),
        1,
      );
    });
  });
}
