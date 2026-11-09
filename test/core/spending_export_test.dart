import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/domain/money.dart';
import 'package:recallos/core/spending/spending_export.dart';
import 'package:recallos/core/spending/spending_totals.dart';

/// B4's export: every receipt behind the figure, every one held back and
/// why, and a note that says what the figure is — and is not.
void main() {
  ReceiptFacts receipt(
    int id, {
    String? shop = 'Shwapno',
    int minor = 43260,
    String currency = 'BDT',
    LocalDate? date,
    bool undated = false,
    FactState total = FactState.checked,
    String? category,
    bool guessed = false,
  }) => ReceiptFacts(
    cardId: id,
    savedAt: DateTime(2026, 10, 1).add(Duration(minutes: id)),
    title: shop,
    shop: shop,
    category: category,
    categoryGuessed: guessed,
    total: Money(minor, currency),
    totalState: total,
    date: undated ? null : (date ?? LocalDate(2026, 10, 12)),
    dateState: undated ? FactState.missing : FactState.checked,
  );

  const SpendingPeriod october = SpendingPeriod.month(2026, 10);

  List<List<String>> rowsOf(String csv) =>
      csv.trim().split('\r\n').map((String line) => line.split(',')).toList();

  test('every receipt is a row, counted first, the rest saying why', () {
    final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
      receipt(1, category: 'Groceries', guessed: true),
      receipt(2, shop: 'Ryans', minor: 4500000, date: LocalDate(2026, 10, 5)),
      receipt(3, shop: 'Agora', total: FactState.unchecked),
      // The same paper scanned twice: held back as a copy of 1.
      receipt(4),
      receipt(5, shop: 'Tea stall', minor: 3000, undated: true),
    ], period: october);

    final List<List<String>> rows = rowsOf(SpendingExport.csv(s));
    expect(rows.first.first, 'Status');
    expect(rows.skip(1).map((List<String> r) => r.first).toList(), <String>[
      'Counted',
      'Counted',
      'Not added yet',
      'Possible second copy',
      'No date',
    ]);

    // The figure can be added again by hand from the rows marked Counted.
    final int counted = rows
        .skip(1)
        .where((List<String> r) => r.first == 'Counted')
        .map((List<String> r) => (double.parse(r[5]) * 100).round())
        .fold(0, (int a, int b) => a + b);
    expect(counted, s.total!.minor);

    final String csv = SpendingExport.csv(s);
    expect(csv, contains('Not added yet,2026-10-12,Agora'));
    expect(csv, contains('Check the total'));
    expect(csv, contains('may be a second copy of RecallOS id 1'));
    expect(csv, contains('Groceries,yes,432.60,BDT'));
  });

  test('amounts as a spreadsheet reads them, in each currency', () {
    expect(SpendingExport.plainAmount(const Money(845050, 'BDT')), '8450.50');
    expect(SpendingExport.plainAmount(const Money(-12000, 'BDT')), '-120.00');
    expect(SpendingExport.plainAmount(const Money(1200, 'JPY')), '1200');
    expect(SpendingExport.plainAmount(const Money(1234, 'KWD')), '1.234');
    expect(SpendingExport.plainAmount(const Money(5, 'USD')), '0.05');
  });

  test('text read off a paper is never a formula, and commas stay put', () {
    final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
      receipt(1, shop: '=HYPERLINK("x")'),
      receipt(
        2,
        shop: 'Star Tech, Ltd',
        minor: 100,
        date: LocalDate(2026, 10, 2),
      ),
    ], period: october);
    final String csv = SpendingExport.csv(s);

    expect(csv, contains('"\'=HYPERLINK(""x"")"'));
    expect(csv, isNot(contains(',=HYPERLINK')));
    expect(csv, contains('"Star Tech, Ltd"'));
  });

  test('the note says what the figure covers, and what it is not', () {
    final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
      receipt(1, minor: 845050),
      receipt(2, shop: 'Agora', total: FactState.unchecked, minor: 999),
      receipt(3, shop: 'Duty Free', currency: 'USD', minor: 1250),
    ], period: october);

    final String note = SpendingExport.note(s, sharedOn: DateTime(2026, 11, 8));
    expect(note, contains('BDT 8,450.50 in saved receipts.'));
    expect(note, contains('1–31 Oct 2026 · 1 receipt you checked'));
    expect(note, contains('1 receipt not added yet'));
    expect(note, contains('kept apart, never converted: USD'));
    expect(note, contains('not all spending'));
    expect(note.toLowerCase(), isNot(contains('spent')));
    expect(
      SpendingExport.fileName(s),
      'RecallOS receipts - October 2026 - BDT.csv',
    );
  });

  test('a refund is marked in its row and said in the note', () {
    final SpendingSummary s = SpendingSummary.of(
      <ReceiptFacts>[receipt(1, minor: 100000), receipt(2, minor: -25000)],
      period: const SpendingPeriod.month(2026, 10),
    );
    expect(s.total, const Money(75000, 'BDT'));
    expect(s.refunded, const Money(25000, 'BDT'));
    expect(s.refundCount, 1);
    expect(SpendingExport.csv(s), contains('Refund, comes off the figure'));
    expect(
      SpendingExport.note(s, sharedOn: DateTime(2026, 11, 9)),
      contains('After BDT 250.00 refunded on 1 receipt.'),
    );
  });

  test('nothing refunded says nothing about refunds', () {
    final SpendingSummary s = SpendingSummary.of(
      <ReceiptFacts>[receipt(1)],
      period: const SpendingPeriod.month(2026, 10),
    );
    expect(s.refunded, isNull);
    expect(
      SpendingExport.note(s, sharedOn: DateTime(2026, 11, 9)),
      isNot(contains('refunded')),
    );
  });

  test('nothing counted says so, rather than a zero', () {
    final SpendingSummary s = SpendingSummary.of(<ReceiptFacts>[
      receipt(1, total: FactState.unchecked),
    ], period: october);
    expect(
      SpendingExport.note(s, sharedOn: DateTime(2026, 11, 8)),
      contains('Nothing counted yet'),
    );
    expect(
      SpendingExport.note(s, sharedOn: DateTime(2026, 11, 8)),
      isNot(contains('BDT 0')),
    );
  });
}
