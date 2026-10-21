import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/domain/money.dart';
import 'package:recallos/core/spending/spending_totals.dart';

/// B4's arithmetic and its honesty rules, without a database: what is added,
/// what is held back and why, and that no two currencies ever meet.
void main() {
  int nextId = 0;

  ReceiptFacts receipt({
    int? id,
    String? shop = 'Shwapno',
    int? minor = 43260,
    String currency = 'BDT',
    LocalDate? date,
    FactState total = FactState.checked,
    FactState day = FactState.checked,
    String? category,
    bool guessed = false,
    String? invoice,
    DateTime? savedAt,
    Set<int> notCopiesOf = const <int>{},
  }) {
    final int cardId = id ?? ++nextId;
    return ReceiptFacts(
      cardId: cardId,
      savedAt: savedAt ?? DateTime(2026, 10, 1).add(Duration(minutes: cardId)),
      title: shop,
      shop: shop,
      category: category,
      categoryGuessed: guessed,
      total: minor == null ? null : Money(minor, currency),
      totalState: minor == null && total == FactState.checked
          ? FactState.missing
          : total,
      date: date ?? LocalDate(2026, 10, 12),
      dateState: day,
      invoiceNumber: invoice,
      notCopiesOf: notCopiesOf,
    );
  }

  const SpendingPeriod october = SpendingPeriod.month(2026, 10);

  group('what is counted', () {
    test('only receipts whose total and date were both checked are added, '
        'to the paisa', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(shop: 'A', minor: 10),
        receipt(shop: 'B', minor: 20),
        receipt(shop: 'C', minor: 99900, total: FactState.unchecked),
        receipt(shop: 'D', minor: 88800, day: FactState.unchecked),
      ], period: october);

      // 0.10 + 0.20 is 0.30 exactly — what a double would not give.
      expect(s.total, const Money(30, 'BDT'));
      expect(s.counted.map((ReceiptFacts r) => r.shop), <String>['B', 'A']);
      expect(s.notAdded.map((ReceiptFacts r) => r.shop), <String>['D', 'C']);
      expect(s.scope, '1–31 Oct 2026 · 2 receipts you checked');
    });

    test('what to do before a receipt counts, in a few words', () {
      expect(
        receipt(total: FactState.unchecked, day: FactState.unchecked).whatToDo,
        'Check the total and the date',
      );
      expect(receipt(total: FactState.unchecked).whatToDo, 'Check the total');
      expect(receipt(day: FactState.unchecked).whatToDo, 'Check the date');
      expect(receipt(minor: null).whatToDo, 'Add the total');
      expect(
        receipt(minor: null, day: FactState.unchecked).whatToDo,
        'Add the total and check the date',
      );
      expect(
        receipt(minor: null, total: FactState.unreadable).whatToDo,
        'Correct the total',
      );
      expect(receipt().whatToDo, isNull);
    });

    test('a receipt with no date is never placed by the day it was scanned: '
        'it is listed apart in every period', () {
      final ReceiptFacts undated = ReceiptFacts(
        cardId: 99,
        savedAt: DateTime(2026, 10, 12),
        shop: 'Tea stall',
        total: const Money(2000, 'BDT'),
        totalState: FactState.checked,
      );
      for (final SpendingPeriod p in <SpendingPeriod>[
        october,
        const SpendingPeriod.month(2026, 9),
        const SpendingPeriod.year(2026),
      ]) {
        final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
          undated,
        ], period: p);
        expect(s.total, isNull, reason: '$p');
        expect(s.undated.single.cardId, 99, reason: '$p');
        expect(s.undated.single.whatToDo, 'Add the date');
      }
    });

    test('a refund printed in brackets takes its amount off', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(minor: 50000),
        receipt(shop: 'Aarong', minor: -12000),
      ], period: october);
      expect(s.total, const Money(38000, 'BDT'));
    });

    test('nothing at all: no total, nothing listed', () {
      final SpendingSummary s = SpendingSummary.of(
        const <ReceiptFacts>[],
        period: october,
      );
      expect(s.total, isNull);
      expect(s.currency, isNull);
      expect(s.isEmpty, isTrue);
      expect(s.heldBack, 0);
    });
  });

  group('one currency at a time', () {
    final List<ReceiptFacts> mixed = <ReceiptFacts>[
      receipt(shop: 'A', minor: 1000, currency: 'USD'),
      receipt(shop: 'B', minor: 2000, currency: 'USD'),
      receipt(shop: 'C', minor: 845000),
    ];

    test('taka and dollars are never added together; the currency with the '
        'most receipts is shown first', () {
      final SpendingSummary s = SpendingSummary.of(mixed, period: october);
      expect(s.currencies, <String>['USD', 'BDT']);
      expect(s.currency, 'USD');
      expect(s.total, const Money(3000, 'USD'));
      expect(s.counted, hasLength(2));
    });

    test('the other currency on its own', () {
      final SpendingSummary s = SpendingSummary.of(
        mixed,
        period: october,
        currency: 'BDT',
      );
      expect(s.total, const Money(845000, 'BDT'));
      expect(s.counted.single.shop, 'C');
      expect(s.byShop.single.label, 'C');
    });

    test('a tie goes to taka, and a currency not in the period falls back', () {
      final SpendingSummary s = SpendingSummary.of(
        <ReceiptFacts>[
          receipt(shop: 'A', minor: 1000, currency: 'USD'),
          receipt(shop: 'B', minor: 5000),
        ],
        period: october,
        currency: 'EUR',
      );
      expect(s.currencies, <String>['BDT', 'USD']);
      expect(s.currency, 'BDT');
    });

    test('receipts held back are listed whatever their currency', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(minor: 1000, currency: 'USD', total: FactState.unchecked),
        receipt(minor: 5000),
      ], period: october);
      expect(s.currency, 'BDT');
      expect(s.notAdded.single.total, const Money(1000, 'USD'));
    });
  });

  group('possible second copies', () {
    test('the same shop, day and total: the first saved is counted, the '
        'later one is held back with its reasons', () {
      final ReceiptFacts first = receipt(id: 1);
      final ReceiptFacts again = receipt(id: 2);
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        again,
        first,
      ], period: october);

      expect(s.total, const Money(43260, 'BDT'));
      expect(s.counted.single.cardId, 1);
      final PossibleCopy copy = s.copies.single;
      expect(copy.receipt.cardId, 2);
      expect(copy.original.cardId, 1);
      expect(copy.reasons.map((CopyReason r) => r.describe()), <String>[
        'Same total, BDT 432.60',
        'Same day, 12 Oct 2026',
        'Same shop, Shwapno',
      ]);
      expect(s.heldBack, 1);
    });

    test('a shop name written differently is still the same shop', () {
      final Map<int, PossibleCopy> copies = findCopies(<ReceiptFacts>[
        receipt(id: 1, shop: 'STAR TECH & ENGINEERING LTD.'),
        receipt(id: 2, shop: 'Star Tech & Engineering Ltd'),
      ]);
      expect(copies.keys, <int>[2]);
    });

    test('the same invoice number is the strongest reason', () {
      final PossibleCopy copy = findCopies(<ReceiptFacts>[
        receipt(id: 1, invoice: 'ST-2026-0412'),
        receipt(id: 2, invoice: 'st 2026 0412'),
      ])[2]!;
      expect(copy.reasons.first.describe(), 'Same invoice no., ST-2026-0412');
    });

    test('different shops, or different invoice numbers, are two '
        'purchases', () {
      expect(
        findCopies(<ReceiptFacts>[
          receipt(id: 1, shop: 'Shwapno'),
          receipt(id: 2, shop: 'Agora'),
        ]),
        isEmpty,
      );
      expect(
        findCopies(<ReceiptFacts>[
          receipt(id: 1, invoice: 'INV-1001'),
          receipt(id: 2, invoice: 'INV-1002'),
        ]),
        isEmpty,
      );
      expect(
        findCopies(<ReceiptFacts>[
          receipt(id: 1),
          receipt(id: 2, minor: 43261),
        ]),
        isEmpty,
      );
      expect(
        findCopies(<ReceiptFacts>[
          receipt(id: 1),
          receipt(id: 2, date: LocalDate(2026, 10, 13)),
        ]),
        isEmpty,
      );
      expect(
        findCopies(<ReceiptFacts>[
          receipt(id: 1),
          receipt(id: 2, currency: 'USD'),
        ]),
        isEmpty,
      );
    });

    test('a shop not read tells nothing apart, so it is asked about', () {
      final PossibleCopy copy = findCopies(<ReceiptFacts>[
        receipt(id: 1, shop: 'Shwapno'),
        receipt(id: 2, shop: null),
      ])[2]!;
      expect(copy.reasons.map((CopyReason r) => r.cue), <CopyCue>[
        CopyCue.total,
        CopyCue.day,
      ]);
    });

    test('once the user says they are different purchases, both count', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(id: 1),
        receipt(id: 2, notCopiesOf: <int>{1}),
      ], period: october);
      expect(s.copies, isEmpty);
      expect(s.total, const Money(86520, 'BDT'));
    });

    test('a copy of a copy points at the original; one that differs from '
        'the original counts', () {
      final Map<int, PossibleCopy> copies = findCopies(<ReceiptFacts>[
        receipt(id: 1, shop: 'Shwapno'),
        receipt(id: 2, shop: null),
        receipt(id: 3, shop: 'Agora'),
        receipt(id: 4, shop: 'Shwapno'),
      ]);
      expect(copies.keys.toSet(), <int>{2, 4});
      expect(copies[2]!.original.cardId, 1);
      expect(copies[4]!.original.cardId, 1);
    });

    test('a receipt waiting for a check is not compared until it is '
        'checked', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(id: 1),
        receipt(id: 2, total: FactState.unchecked),
      ], period: october);
      expect(s.copies, isEmpty);
      expect(s.notAdded.single.cardId, 2);
    });
  });

  group('periods', () {
    test('a month runs from its first day to its last', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(shop: 'A', date: LocalDate(2026, 10, 1)),
        receipt(shop: 'B', date: LocalDate(2026, 10, 31)),
        receipt(shop: 'C', date: LocalDate(2026, 9, 30)),
        receipt(shop: 'D', date: LocalDate(2026, 11, 1)),
      ], period: october);
      expect(s.counted.map((ReceiptFacts r) => r.shop), <String>['B', 'A']);
    });

    test('a year, by month in calendar order', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(shop: 'A', minor: 100, date: LocalDate(2026, 10, 3)),
        receipt(shop: 'B', minor: 200, date: LocalDate(2026, 2, 3)),
        receipt(shop: 'C', minor: 300, date: LocalDate(2026, 10, 9)),
        receipt(shop: 'D', minor: 999, date: LocalDate(2025, 12, 31)),
      ], period: const SpendingPeriod.year(2026));
      expect(s.total, const Money(600, 'BDT'));
      expect(
        s.byMonth.map((SpendingGroup g) => '${g.key} ${g.label} ${g.total}'),
        <String>['2026-02 February BDT 2.00', '2026-10 October BDT 4.00'],
      );
      expect(s.scope, '1 Jan – 31 Dec 2026 · 3 receipts you checked');
    });

    test('labels, spans and stepping across a year end', () {
      expect(october.label, 'October 2026');
      expect(october.span, '1–31 Oct 2026');
      expect(const SpendingPeriod.month(2028, 2).span, '1–29 Feb 2028');
      expect(const SpendingPeriod.year(2026).label, '2026');
      expect(
        const SpendingPeriod.month(2026, 1).previous,
        const SpendingPeriod.month(2025, 12),
      );
      expect(
        const SpendingPeriod.month(2026, 12).next,
        const SpendingPeriod.month(2027, 1),
      );
      expect(october.wholeYear, const SpendingPeriod.year(2026));
      final DateTime now = DateTime(2026, 10, 15, 9);
      expect(SpendingPeriod.monthOf(now), october);
      expect(october.isCurrent(now), isTrue);
      expect(october.next.isFuture(now), isTrue);
      expect(october.isFuture(now), isFalse);
    });
  });

  group('shops and categories', () {
    test('grouped by shop, largest first, one shop however it is written, '
        'and the unnamed last', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(shop: 'Star Tech Ltd', minor: 7850000),
        receipt(shop: 'STAR TECH', minor: 150000),
        receipt(shop: 'Shwapno', minor: 43260),
        receipt(shop: null, minor: 9999999),
      ], period: october);
      expect(
        s.byShop.map(
          (SpendingGroup g) => '${g.label}: ${g.total} ×${g.receipts}',
        ),
        <String>[
          'STAR TECH: BDT 80,000.00 ×2',
          'Shwapno: BDT 432.60 ×1',
          'No shop name: BDT 99,999.99 ×1',
        ],
      );
    });

    test('a category says how many of its receipts are guesses', () {
      final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
        receipt(shop: 'A', category: 'Groceries', guessed: true),
        receipt(shop: 'B', category: 'groceries'),
        receipt(shop: 'C', category: null),
      ], period: october);
      final SpendingGroup groceries = s.byCategory.first;
      expect(groceries.receipts, 2);
      expect(groceries.guessed, 1);
      expect(s.byCategory.last.label, 'No category');
    });

    test('a focus narrows the total and every list, but not the groups it is '
        'picked from', () {
      final List<ReceiptFacts> all = <ReceiptFacts>[
        receipt(id: 1, shop: 'Star Tech', minor: 100),
        receipt(id: 2, shop: 'Star Tech', minor: 100),
        receipt(
          id: 3,
          shop: 'Star Tech',
          minor: 500,
          total: FactState.unchecked,
        ),
        receipt(id: 4, shop: 'Shwapno', minor: 900),
        receipt(id: 5, shop: 'Shwapno', minor: 700, day: FactState.unchecked),
      ];
      final SpendingSummary s = SpendingSummary.of(
        all,
        period: october,
        focus: const SpendingFocus.shop('star tech', 'Star Tech'),
      );
      expect(s.total, const Money(100, 'BDT'));
      expect(s.counted.single.cardId, 1);
      expect(s.copies.single.receipt.cardId, 2);
      expect(s.notAdded.single.cardId, 3);
      expect(s.byShop, hasLength(2));
    });
  });
}
