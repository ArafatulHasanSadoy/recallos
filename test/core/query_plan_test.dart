import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/search/query_plan.dart';
import 'package:recallos/core/spending/spending_totals.dart';

void main() {
  void lookup(String raw, String fieldKey, String subject) {
    final QueryPlan plan = planQuery(raw);
    expect(plan, isA<LookupPlan>(), reason: raw);
    plan as LookupPlan;
    expect(plan.fieldKey, fieldKey, reason: raw);
    expect(plan.subject, subject, reason: raw);
  }

  void search(String raw) =>
      expect(planQuery(raw), isA<SearchPlan>(), reason: raw);

  test('the ways people ask for one fact', () {
    lookup("Rahim's number", FieldKeys.phone, 'rahim');
    lookup('Rahim’s number', FieldKeys.phone, 'rahim');
    lookup('rahim number', FieldKeys.phone, 'rahim');
    lookup('Rahim phone number', FieldKeys.phone, 'rahim');
    lookup('email of Nusrat', FieldKeys.email, 'nusrat');
    lookup('phone number of Rahim Uddin', FieldKeys.phone, 'rahim uddin');
    lookup('TechFix address', FieldKeys.address, 'techfix');
    lookup("what's Karim's email", FieldKeys.email, 'karim');
    lookup('give me the number for CoolAir', FieldKeys.phone, 'coolair');
    lookup('Nusrat email address', FieldKeys.email, 'nusrat');
    lookup('Sonar Bangla website', FieldKeys.website, 'sonar bangla');
  });

  test('Banglish', () {
    lookup('Rahim er number', FieldKeys.phone, 'rahim');
    lookup('rahim er number ki', FieldKeys.phone, 'rahim');
    lookup('TechFix er thikana', FieldKeys.address, 'techfix');
  });

  test('a need with a field word in it is still a search', () {
    search('number plate');
    search('phone repair');
    search('mobile servicing near campus');
    search('office furniture');
  });

  test('a field word alone, or nothing, is a search', () {
    search('number');
    search("what's the number");
    search('');
    search('cheap printing');
  });

  test('a need can be the subject: "AC repair number"', () {
    lookup('AC repair number', FieldKeys.phone, 'ac repair');
  });

  test('says the field back in words', () {
    expect((planQuery("Rahim's number") as LookupPlan).fieldLabel, 'number');
    expect((planQuery('TechFix address') as LookupPlan).fieldLabel, 'address');
  });

  group('people filters', () {
    final DateTime now = DateTime(2026, 10, 7, 15); // a Wednesday

    PeopleFilterPlan people(String raw) {
      final QueryPlan plan = planQuery(raw, now: now);
      expect(plan, isA<PeopleFilterPlan>(), reason: raw);
      return plan as PeopleFilterPlan;
    }

    test('where they were met', () {
      expect(people('met at CSE fest').place, 'cse fest');
      expect(
        people('people I met at CSE fest at NSU').place,
        'cse fest at nsu',
      );
      expect(people('who did I meet at the tech expo').place, 'the tech expo');
    });

    test('when they were met, with the window said back', () {
      final PeopleFilterPlan week = people('people I met last week');
      expect(week.from, DateTime(2026, 9, 24));
      expect(week.until, DateTime(2026, 10, 1));
      expect(week.describe, 'Met last week');

      final PeopleFilterPlan month = people('met this month');
      expect(month.from, DateTime(2026, 10));
      expect(month.until, DateTime(2026, 11));

      final PeopleFilterPlan today = people('scanned today');
      expect(today.from, DateTime(2026, 10, 7));
      expect(today.until, DateTime(2026, 10, 8));
    });

    test('follow-up state', () {
      expect(people('who needs a next step').followUp, FollowUpFilter.none);
      expect(
        people('who do I need to follow up with').followUp,
        FollowUpFilter.open,
      );
    });

    test('together', () {
      final PeopleFilterPlan both = people(
        'met at CSE fest without a next step',
      );
      expect(both.place, 'cse fest');
      expect(both.followUp, FollowUpFilter.none);
      expect(both.describe, 'Met at cse fest · No next step yet');

      final PeopleFilterPlan placeAndDay = people('met at CSE fest last week');
      expect(placeAndDay.place, 'cse fest');
      expect(placeAndDay.windowLabel, 'last week');
    });

    test('a time without "met" is a need, not a filter', () {
      expect(planQuery('last month invoices', now: now), isA<SearchPlan>());
      expect(planQuery('this week offers', now: now), isA<SearchPlan>());
      expect(planQuery('meeting room booking', now: now), isA<SearchPlan>());
    });
  });

  group('purchases (B5)', () {
    // A Thursday in October, so "this month" and "last month" are fixed.
    final DateTime now = DateTime(2026, 10, 15, 10);
    QueryPlan plan(String raw) => planQuery(raw, now: now);

    void warranty(String raw, String subject) {
      final QueryPlan p = plan(raw);
      expect(p, isA<WarrantyPlan>(), reason: raw);
      expect((p as WarrantyPlan).subject, subject, reason: raw);
    }

    ExpiringPlan expiring(String raw) {
      final QueryPlan p = plan(raw);
      expect(p, isA<ExpiringPlan>(), reason: raw);
      return p as ExpiringPlan;
    }

    SpendingPlan spending(String raw) {
      final QueryPlan p = plan(raw);
      expect(p, isA<SpendingPlan>(), reason: raw);
      return p as SpendingPlan;
    }

    test('one warranty, by what it covers', () {
      warranty('When does my laptop warranty expire?', 'laptop');
      warranty('laptop warranty', 'laptop');
      warranty('is my fridge still under warranty', 'fridge');
      warranty('where is my phone warranty', 'phone');
      warranty('warranty of the AC', 'ac');
      warranty('HP laptop warranty end date', 'hp laptop');
      warranty("Walton fridge's warranty", 'walton fridge');
      warranty('AC er warranty kobe shesh', 'ac');
    });

    test('what ends in a stretch of days', () {
      final ExpiringPlan ninety = expiring('What expires in the next 90 days?');
      expect(ninety.from, LocalDate(2026, 10, 15));
      expect(ninety.until, LocalDate(2027, 1, 12));
      expect(ninety.label, 'in the next 90 days');

      final ExpiringPlan month = expiring('warranties ending this month');
      expect(month.until, LocalDate(2026, 10, 31));
      expect(month.label, 'this month');

      final ExpiringPlan next = expiring('what expires next month');
      expect(
        (next.from, next.until),
        (LocalDate(2026, 11, 1), LocalDate(2026, 11, 30)),
      );

      expect(expiring('anything expiring soon').label, 'in the next 90 days');
      expect(
        expiring('warranties ending within 3 months').until,
        LocalDate(2027, 1, 14),
      );

      final ExpiringPlan over = expiring('what has expired');
      expect(over.ended, isTrue);
      expect(over.until, LocalDate(2026, 10, 14));

      final ExpiringPlan all = expiring('my warranties');
      expect((all.from, all.until), (null, null));
    });

    test('a total of saved receipts', () {
      final SpendingPlan a = spending(
        'How much did I spend on electronics this month?',
      );
      expect(a.period, const SpendingPeriod.month(2026, 10));
      expect(a.focus, 'electronics');
      expect(a.shopOnly, isFalse);
      expect(a.isFreeAt(now), isFalse, reason: 'a category is Plus');

      final SpendingPlan b = spending('spent at Star Tech last month');
      expect(b.period, const SpendingPeriod.month(2026, 9));
      expect(b.focus, 'star tech');
      expect(b.shopOnly, isTrue);

      final SpendingPlan c = spending('receipts total in September');
      expect(c.period, const SpendingPeriod.month(2026, 9));
      expect(c.focus, isNull);

      // A month still to come this year is last year's.
      expect(
        spending('how much did I spend in December').period,
        const SpendingPeriod.month(2025, 12),
      );
      expect(
        spending('spending in 2025').period,
        const SpendingPeriod.year(2025),
      );
      expect(
        spending('how much have I spent this year').period,
        const SpendingPeriod.year(2026),
      );

      final SpendingPlan plain = spending('how much did I spend this month');
      expect(plain.focus, isNull);
      expect(plain.isFreeAt(now), isTrue, reason: 'the free screen shows it');

      expect(spending('spent this week').unsupported, 'this week');
      expect(spending('koto khoroch holo ei mash e').focus, isNull);
      expect(
        spending('gato mash e koto khoroch').period,
        const SpendingPeriod.month(2026, 9),
      );
    });

    test('needs that only look like purchase questions stay searches', () {
      void stays(String raw) => expect(
        plan(raw),
        isNot(
          anyOf(isA<WarrantyPlan>(), isA<ExpiringPlan>(), isA<SpendingPlan>()),
        ),
        reason: raw,
      );
      stays('Samsung warranty service center');
      stays('warranty claim repair shop');
      stays('cover photo design');
      stays('end to end testing company');
      stays('valid ID card printing');
      stays('expense tracker app developer');
      stays('Total Solutions');
      stays('passport expiry renewal agent');
    });

    test("A6's questions keep their plans", () {
      expect(plan("Rahim's number"), isA<LookupPlan>());
      expect(plan('Total Solutions number'), isA<LookupPlan>());
      expect(plan('met at CSE fest'), isA<PeopleFilterPlan>());
      expect(plan('people I met last month'), isA<PeopleFilterPlan>());
      expect(plan('cheap t-shirt print'), isA<SearchPlan>());
    });
  });
}
