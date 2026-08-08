import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/extraction/digits.dart';
import 'package:recallos/core/extraction/phone.dart';

void main() {
  group('Digits', () {
    test('converts Bengali numerals to Latin', () {
      expect(Digits.toLatin('০১৭১১২২৩৩৪৪'), '01711223344');
      expect(Digits.toLatin('৯৮৭৬৫৪৩২১০'), '987654321 0'.replaceAll(' ', ''));
    });

    test('leaves Bengali letters untouched', () {
      // Only numerals convert; the script itself must survive intact.
      const String company = 'মেডিকা বুকস';
      expect(Digits.toLatin(company), company);
    });

    test('handles mixed script in one string', () {
      expect(Digits.toLatin('মোবাইল ০১৭১১-২২৩৩৪৪'), 'মোবাইল 01711-223344');
    });

    test('digitRatio distinguishes numbers from words', () {
      expect(Digits.digitRatio('01711223344'), 1.0);
      expect(Digits.digitRatio('Dhanmondi'), 0.0);
      expect(Digits.digitRatio('0171122334O'), greaterThan(0.9));
    });

    test('repairConfusables only rewrites known lookalikes', () {
      expect(Digits.repairConfusables('O1711223344'), '01711223344');
      expect(Digits.repairConfusables('0l7ll223344'), '017112233 44'.replaceAll(' ', ''));
    });
  });

  group('PhoneExtractor — valid Bangladeshi mobiles', () {
    test('normalises every common way of writing the same number', () {
      const List<String> variants = <String>[
        '01711223344',
        '01711-223344',
        '017 1122 3344',
        '+8801711223344',
        '8801711223344',
        '008801711223344',
        '(017) 1122-3344',
      ];

      for (final String v in variants) {
        final PhoneMatch? m = PhoneExtractor.parse(v);
        expect(m, isNotNull, reason: 'failed to parse "$v"');
        expect(m!.isValid, isTrue, reason: '"$v" should be valid');
        expect(m.e164, '+8801711223344', reason: 'wrong E.164 for "$v"');
      }
    });

    test('accepts every allocated operator prefix', () {
      for (final String prefix in PhoneExtractor.mobileOperators.keys) {
        // Keys are the full national prefix as printed: 013 … 019.
        final String number = '${prefix}12233445';
        expect(number, hasLength(11));

        final PhoneMatch? m = PhoneExtractor.parse(number);
        expect(m?.isValid, isTrue, reason: 'prefix $prefix should be valid');
        expect(m?.kind, PhoneKind.mobile);
      }
    });

    test('rejects the spare and retired prefixes', () {
      for (final String prefix in <String>['010', '011', '012']) {
        final PhoneMatch? m = PhoneExtractor.parse('${prefix}12233445');
        expect(m?.isValid, isFalse, reason: '$prefix should not be valid');
        expect(m?.issue, PhoneIssue.unknownOperator);
      }
    });

    test('reads Bengali numerals', () {
      final PhoneMatch? m = PhoneExtractor.parse('০১৭১১২২৩৩৪৪');
      expect(m?.isValid, isTrue);
      expect(m?.e164, '+8801711223344');
    });

    test('identifies mobiles for WhatsApp actions', () {
      expect(PhoneExtractor.isMobile('+8801711223344'), isTrue);
      // Dhaka landline — no WhatsApp.
      expect(PhoneExtractor.isMobile('+880255012345'), isFalse);
      expect(PhoneExtractor.isMobile('+14155552671'), isFalse);
    });
  });

  group('PhoneExtractor — rejects wrong data', () {
    test('flags retired and unallocated prefixes instead of accepting them', () {
      // 011 was Citycell, shut down in 2016. Right length, wrong number.
      final PhoneMatch? m = PhoneExtractor.parse('01111223344');
      expect(m, isNotNull);
      expect(m!.isValid, isFalse);
      expect(m.issue, PhoneIssue.unknownOperator);
    });

    test('rejects a number one digit short', () {
      final PhoneMatch? m = PhoneExtractor.parse('0171122334');
      expect(m?.isValid, isFalse);
    });

    test('does not turn words into numbers', () {
      // The confusable map could mangle these into digits; the digit-ratio
      // gate is what stops it.
      for (final String word in <String>['Dhanmondi', 'GOOD', 'Books', 'Sales']) {
        expect(
          PhoneExtractor.parse(word),
          isNull,
          reason: '"$word" must not parse as a phone number',
        );
      }
    });

    test('repairs OCR confusables but marks the result for review', () {
      // "O" for zero and "l" for one — the classic card OCR mistakes.
      final PhoneMatch? m = PhoneExtractor.parse('Ol711223344');
      expect(m, isNotNull);
      expect(m!.isValid, isTrue);
      expect(m.e164, '+8801711223344');
      expect(m.repaired, isTrue, reason: 'a guess must be flagged');
      expect(m.needsReview, isTrue);
    });

    test('a clean valid number is not marked for review', () {
      final PhoneMatch? m = PhoneExtractor.parse('01711223344');
      expect(m!.repaired, isFalse);
      expect(m.needsReview, isFalse);
    });
  });

  group('PhoneExtractor — real card text', () {
    test('pulls several numbers out of one line', () {
      const String line = 'Mob: 01711-223344, 01911-556677';
      final List<PhoneMatch> found = PhoneExtractor.extractAll(line);

      final List<String> valid = found
          .where((PhoneMatch m) => m.isValid)
          .map((PhoneMatch m) => m.e164)
          .toList();
      expect(valid, containsAll(<String>['+8801711223344', '+8801911556677']));
    });

    test('de-duplicates the same number written two ways', () {
      const String card = '''
        Rahim Uddin
        Cell: 01711-223344
        WhatsApp: +880 1711 223344
      ''';
      final List<PhoneMatch> found = PhoneExtractor.extractAll(card);
      final Set<String> unique = found
          .where((PhoneMatch m) => m.isValid)
          .map((PhoneMatch m) => m.e164)
          .toSet();
      expect(unique, hasLength(1));
    });

    test('handles a mixed Bangla-English card', () {
      const String card = '''
        মেডিকা বুকস
        Medica Books
        ফোন: ০১৭১১-২২৩৩৪৪
        Email: info@medicabooks.com.bd
      ''';
      final List<PhoneMatch> found = PhoneExtractor.extractAll(card);
      expect(
        found.where((PhoneMatch m) => m.isValid).map((PhoneMatch m) => m.e164),
        contains('+8801711223344'),
      );
    });

    test('returns nothing for text with no numbers', () {
      expect(PhoneExtractor.extractAll('Medica Books, Dhanmondi'), isEmpty);
      expect(PhoneExtractor.extractAll(''), isEmpty);
    });
  });
}
