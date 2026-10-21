import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/linking/warranty_expiry.dart';

void main() {
  final LocalDate bought = LocalDate(2026, 10, 12);

  group('a stated expiry', () {
    test('printed on the warranty wins over any calculation', () {
      final WarrantyExpiry? e = warrantyExpiry(
        stated: LocalDate(2028, 12, 31),
        statedOrigin: FactOrigin.printed,
        coverMonths: 24,
        ownPurchaseDate: bought,
      );
      expect(e!.day, LocalDate(2028, 12, 31));
      expect(e.basis, ExpiryBasis.printed);
      expect(e.isCalculated, isFalse);
      expect(e.explain().replaceAll('\u00A0', ' '), 'Printed on the warranty');
    });

    test('typed or confirmed by the user is theirs', () {
      expect(
        warrantyExpiry(
          stated: LocalDate(2028, 1, 1),
          statedOrigin: FactOrigin.user,
        )!.explain(),
        'You confirmed it',
      );
      expect(
        warrantyExpiry(
          stated: LocalDate(2028, 1, 1),
          statedOrigin: FactOrigin.printed,
          statedConfirmed: true,
        )!.basis,
        ExpiryBasis.confirmed,
      );
    });

    test('an earlier calculation is never read back as an input', () {
      final WarrantyExpiry? e = warrantyExpiry(
        stated: LocalDate(2030, 1, 1),
        statedOrigin: FactOrigin.derived,
        coverMonths: 12,
        ownPurchaseDate: bought,
      );
      expect(e!.day, LocalDate(2027, 10, 11));
      expect(e.isCalculated, isTrue);
    });
  });

  group('a calculated expiry', () {
    test('ends the day before the anniversary', () {
      final WarrantyExpiry? e = warrantyExpiry(
        coverMonths: 24,
        ownPurchaseDate: bought,
      );
      expect(e!.day, LocalDate(2028, 10, 11));
      expect(e.from, bought);
      expect(e.months, 24);
      expect(e.start, ExpiryStart.warranty);
      expect(
        e.explain().replaceAll('\u00A0', ' '),
        'Calculated from the purchase date, 12 Oct 2026, plus 2 years',
      );
      expect(e.caveat, isNull);
    });

    test('keeps the date and the cover whole on a narrow line', () {
      final String line = warrantyExpiry(
        coverMonths: 24,
        ownPurchaseDate: bought,
      )!.explain();
      expect(line, contains('12\u00A0Oct\u00A02026'));
      expect(line, contains('2\u00A0years'));
    });

    test("uses a confirmed receipt's date when the warranty has none", () {
      final WarrantyExpiry? e = warrantyExpiry(
        coverMonths: 18,
        receiptPurchaseDate: bought,
      );
      expect(e!.day, LocalDate(2028, 4, 11));
      expect(e.start, ExpiryStart.receipt);
      expect(
        e.explain().replaceAll('\u00A0', ' '),
        "Calculated from the receipt's purchase date, 12 Oct 2026, "
        'plus 18 months',
      );
    });

    test("prefers the warranty's own date over the receipt's", () {
      expect(
        warrantyExpiry(
          coverMonths: 12,
          ownPurchaseDate: LocalDate(2026, 10, 14),
          receiptPurchaseDate: bought,
        )!.from,
        LocalDate(2026, 10, 14),
      );
    });

    test('counts months the way a calendar does', () {
      // 31 Jan + 1 month is the end of February, never 3 March.
      expect(
        warrantyExpiry(
          coverMonths: 1,
          ownPurchaseDate: LocalDate(2027, 1, 31),
        )!.day,
        LocalDate(2027, 2, 27),
      );
      // A leap day plus a year lands in February of a common year.
      expect(
        warrantyExpiry(
          coverMonths: 12,
          ownPurchaseDate: LocalDate(2028, 2, 29),
        )!.day,
        LocalDate(2029, 2, 27),
      );
      // Across a year end.
      expect(
        warrantyExpiry(
          coverMonths: 3,
          ownPurchaseDate: LocalDate(2026, 11, 1),
        )!.day,
        LocalDate(2027, 1, 31),
      );
    });

    test('says so when the cover counts from something later', () {
      final WarrantyExpiry? e = warrantyExpiry(
        coverMonths: 60,
        ownPurchaseDate: bought,
        startBasis: 'installation',
      );
      expect(e!.countsFrom, 'installation');
      expect(
        e.caveat,
        'The cover counts from the installation, so it may end later.',
      );
      expect(
        warrantyExpiry(
          coverMonths: 12,
          ownPurchaseDate: bought,
          startBasis: 'invoice',
        )!.caveat,
        isNull,
      );
    });

    test('needs both a start and a cover', () {
      expect(warrantyExpiry(coverMonths: 24), isNull);
      expect(warrantyExpiry(ownPurchaseDate: bought), isNull);
      expect(warrantyExpiry(coverMonths: 0, ownPurchaseDate: bought), isNull);
      expect(warrantyExpiry(), isNull);
    });
  });

  group('the reminder', () {
    final LocalDate lastDay = LocalDate(2028, 10, 11);

    test('comes at 9 AM a month before the last day', () {
      expect(
        expiryReminderTime(lastDay, DateTime(2026, 10, 15, 20)),
        DateTime(2028, 9, 11, 9),
      );
    });

    test('a week before, when saved too late for a month', () {
      expect(
        expiryReminderTime(lastDay, DateTime(2028, 9, 20, 12)),
        DateTime(2028, 10, 4, 9),
      );
    });

    test('the morning of the last day, when later still', () {
      expect(
        expiryReminderTime(lastDay, DateTime(2028, 10, 6, 12)),
        DateTime(2028, 10, 11, 9),
      );
    });

    test('none once the last morning has gone', () {
      expect(expiryReminderTime(lastDay, DateTime(2028, 10, 11, 10)), isNull);
      expect(expiryReminderTime(lastDay, DateTime(2029, 1, 1)), isNull);
    });
  });

  test('cover in words', () {
    expect(coverWords(12), '1 year');
    expect(coverWords(24), '2 years');
    expect(coverWords(1), '1 month');
    expect(coverWords(18), '18 months');
  });
}
