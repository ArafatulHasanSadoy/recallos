import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/field_validator.dart';

void main() {
  group('validateField — phone', () {
    test('normalises a valid mobile to E.164', () {
      final FieldValidation r = validateField(FieldKeys.phone, '01711-223344');
      expect(r.normalized, '+8801711223344');
      expect(r.isClean, isTrue);
    });

    test('flags a number too short to be real', () {
      // The failure that matters most: a wrong number is worse than none,
      // because it is only discovered by dialling it.
      final FieldValidation r = validateField(FieldKeys.phone, '01711223');
      expect(r.isClean, isFalse);
      expect(r.normalized, isNull);
    });

    test('flags an unallocated operator prefix', () {
      final FieldValidation r = validateField(FieldKeys.phone, '01011-223344');
      expect(r.isClean, isFalse);
    });

    test('flags a number that only parses after repairing a confusable', () {
      // "O" for zero and "l" for one. It reaches a dialable form, but only by
      // inference — so it is shown as an inference rather than accepted quietly.
      final FieldValidation r = validateField(FieldKeys.phone, 'Ol711223344');
      expect(r.normalized, '+8801711223344');
      expect(r.issue, 'ocr_repaired');
    });
  });

  group('validateField — email and website', () {
    test('lowercases a valid address', () {
      final FieldValidation r =
          validateField(FieldKeys.email, 'Info@MedicaBooks.com.bd');
      expect(r.normalized, 'info@medicabooks.com.bd');
      expect(r.isClean, isTrue);
    });

    test('rejects something that is not an address at all', () {
      final FieldValidation r = validateField(FieldKeys.email, 'Rahim Uddin');
      expect(r.issue, 'not_an_email');
    });

    test('reduces a website to its registrable domain', () {
      final FieldValidation r =
          validateField(FieldKeys.website, 'www.medicabooks.com.bd');
      expect(r.normalized, 'medicabooks.com.bd');
    });

    test('rejects a bare word as a website', () {
      final FieldValidation r = validateField(FieldKeys.website, 'Medica');
      expect(r.issue, 'not_a_website');
    });
  });

  group('validateField — names and free text', () {
    test('flags a name that is really an address line', () {
      final FieldValidation r =
          validateField(FieldKeys.personName, 'House 42, Road 7, Dhanmondi');
      expect(r.issue, 'looks_like_address');
    });

    test('accepts an ordinary name', () {
      expect(validateField(FieldKeys.personName, 'Rahim Uddin').isClean, isTrue);
    });

    test('accepts any company name without normalising it', () {
      final FieldValidation r =
          validateField(FieldKeys.company, 'AQUARIUS Pet Shop');
      expect(r.isClean, isTrue);
      expect(r.normalized, isNull);
    });

    test('rejects a blank value for every key', () {
      for (final String key in FieldKeys.all) {
        expect(validateField(key, '   ').issue, 'empty', reason: key);
      }
    });
  });
}
