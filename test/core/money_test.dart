import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/domain/money.dart';

void main() {
  group('Money.parse', () {
    Money bdt(String s) => Money.parse(s, currency: 'BDT')!;

    test('reads amounts as receipts print them, into whole paisa', () {
      expect(bdt('8,450.50').minor, 845050);
      expect(bdt('8450.5').minor, 845050);
      expect(bdt('8,450').minor, 845000);
      expect(bdt('Tk 1,23,456.00').minor, 12345600);
      expect(bdt('৳ 99').minor, 9900);
    });

    test('either separator can be the decimal point', () {
      expect(bdt('8.450,50').minor, 845050);
      expect(bdt('8,450.50'), bdt('8.450,50'));
    });

    test('Bangla digits are digits', () {
      expect(bdt('৮,৪৫০.৫০').minor, 845050);
    });

    test('refunds are negative', () {
      expect(bdt('-120.00').minor, -12000);
      expect(bdt('(120.00)').minor, -12000);
    });

    test('a currency with no fraction, and one with three', () {
      expect(Money.parse('1,200', currency: 'JPY')!.minor, 1200);
      expect(Money.parse('1.250', currency: 'KWD')!.minor, 1250);
    });

    test('no amount is no Money', () {
      expect(Money.parse('', currency: 'BDT'), isNull);
      expect(Money.parse('Total', currency: 'BDT'), isNull);
      expect(Money.parse('৳', currency: 'BDT'), isNull);
    });

    test('never goes through a double', () {
      // 0.1 + 0.2 in a double is 0.30000000000000004.
      expect((bdt('0.10') + bdt('0.20')).minor, 30);
    });
  });

  group('Money arithmetic and display', () {
    test('adds within one currency', () {
      expect(Money(845050, 'BDT') + Money(150, 'BDT'), Money(845200, 'BDT'));
    });

    test('refuses to add two currencies', () {
      expect(() => Money(100, 'BDT') + Money(100, 'USD'), throwsArgumentError);
    });

    test('formats with the currency code and its own decimals', () {
      expect(Money(845050, 'BDT').format(), 'BDT 8,450.50');
      expect(Money(-12000, 'BDT').format(), '-BDT 120.00');
      expect(Money(1200, 'JPY').format(), 'JPY 1,200');
      expect(Money(5, 'USD').format(), 'USD 0.05');
    });
  });

  group('LocalDate', () {
    test('round-trips as YYYY-MM-DD and refuses impossible days', () {
      expect(LocalDate.tryParse('2026-10-08')!.toIso(), '2026-10-08');
      expect(LocalDate.tryParse('2026-02-30'), isNull);
      expect(LocalDate.tryParse('8 Oct 2026'), isNull);
    });

    test('adding months keeps the day, or ends the month', () {
      // How "24 months from purchase" is counted.
      expect(LocalDate(2026, 10, 8).addMonths(24), LocalDate(2028, 10, 8));
      expect(LocalDate(2026, 1, 31).addMonths(1), LocalDate(2026, 2, 28));
      expect(LocalDate(2028, 1, 31).addMonths(1), LocalDate(2028, 2, 29));
      expect(LocalDate(2026, 12, 15).addMonths(1), LocalDate(2027, 1, 15));
    });

    test('adding days crosses months and years', () {
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
    });

    test('compares by calendar day', () {
      expect(LocalDate(2026, 9, 30).isBefore(LocalDate(2026, 10, 1)), isTrue);
      expect(
        const LocalDateConverter().toSql(LocalDate(2026, 1, 5)),
        '2026-01-05',
      );
    });
  });
}
