import '../domain/local_date.dart';
import '../domain/money.dart';
import '../extraction/receipt_extractor.dart' show formatDay;
import 'spending_totals.dart';

/// Receipt totals as they leave the phone (B4): a spreadsheet of every
/// receipt behind the figure and every one held back from it, and a note
/// saying what the figure covers.
///
/// Pure, so what is shared is tested exactly; the screen only writes the
/// file and opens the share sheet.
abstract final class SpendingExport {
  /// The spreadsheet. One row per receipt, counted first, then what was held
  /// back and why — so the figure can be re-added by hand from the rows
  /// marked *Counted*, and every other row says why it is not in it.
  static String csv(SpendingSummary s) {
    final StringBuffer b = StringBuffer()
      ..write(
        _row(<String>[
          'Status',
          'Date',
          'Shop',
          'Category',
          'Category is a guess',
          'Amount',
          'Currency',
          'Invoice no.',
          'Note',
          'RecallOS id',
        ]),
      );
    void add(ReceiptFacts r, String status, String note) => b.write(
      _row(<String>[
        status,
        r.date?.toIso() ?? '',
        _text(r.shop ?? r.title ?? ''),
        _text(r.category ?? ''),
        r.category == null ? '' : (r.categoryGuessed ? 'yes' : 'no'),
        r.total == null ? '' : plainAmount(r.total!),
        r.total?.currency ?? '',
        _text(r.invoiceNumber ?? ''),
        note,
        '${r.cardId}',
      ]),
    );

    for (final ReceiptFacts r in s.counted) {
      add(r, 'Counted', r.isRefund ? 'Refund, comes off the figure' : '');
    }
    for (final ReceiptFacts r in s.notAdded) {
      add(r, 'Not added yet', r.whatToDo ?? '');
    }
    for (final PossibleCopy c in s.copies) {
      add(
        c.receipt,
        'Possible second copy',
        'Not added: may be a second copy of RecallOS id '
            '${c.original.cardId} '
            '(${c.reasons.map((CopyReason r) => r.describe()).join('; ')})',
      );
    }
    for (final ReceiptFacts r in s.undated) {
      add(r, 'No date', r.whatToDo ?? 'Add the date');
    }
    return b.toString();
  }

  /// The note that goes with it: the figure, what it covers, what was held
  /// back, and what it is not.
  static String note(SpendingSummary s, {required DateTime sharedOn}) {
    final Money? total = s.total;
    final SpendingFocus? focus = s.focus;
    final StringBuffer b = StringBuffer()
      ..writeln(
        'RecallOS receipt totals — ${s.period.label}'
        '${focus == null ? '' : ' · ${focus.label}'}',
      )
      ..writeln('Shared on ${formatDay(LocalDate.fromDateTime(sharedOn))}.')
      ..writeln()
      ..writeln(
        total == null
            ? 'Nothing counted yet: no receipt in this period has both its '
                  'total and its date checked.'
            : '${total.format()} in saved receipts.',
      )
      ..writeln(s.scope);
    final Money? refunded = s.refunded;
    if (refunded != null) {
      b.writeln(
        'After ${refunded.format()} refunded on ${_count(s.refundCount)}.',
      );
    }
    if (s.notAdded.isNotEmpty) {
      b.writeln(
        '${_count(s.notAdded.length)} not added yet: the total or the date '
        'still needs checking.',
      );
    }
    if (s.copies.isNotEmpty) {
      b.writeln(
        '${_count(s.copies.length)} not added: '
        '${s.copies.length == 1 ? 'it looks' : 'they look'} like a second '
        'copy of one already counted.',
      );
    }
    if (s.undated.isNotEmpty) {
      b.writeln('${_count(s.undated.length)} with no date, so in no month.');
    }
    if (s.currencies.length > 1) {
      b.writeln(
        'Other currencies are kept apart, never converted: '
        '${s.currencies.where((String c) => c != s.currency).join(', ')}.',
      );
    }
    b
      ..writeln()
      ..writeln(
        'Every receipt is a row in the attached spreadsheet, with why it is '
        'or is not counted. This covers receipts saved in RecallOS and '
        'checked by their owner — not all spending.',
      );
    return b.toString();
  }

  /// "RecallOS receipts - October 2026 - BDT.csv".
  static String fileName(SpendingSummary s) {
    final String focus = s.focus == null ? '' : ' - ${s.focus!.label}';
    final String raw =
        'RecallOS receipts - ${s.period.label}$focus'
        '${s.currency == null ? '' : ' - ${s.currency}'}';
    return '${raw.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').trim()}.csv';
  }

  /// "8450.50", "-120.00", "1200" — what a spreadsheet reads as a number:
  /// no currency, no grouping, the currency's own decimals.
  static String plainAmount(Money m) {
    final int decimals = Money.decimalsOf(m.currency);
    int unit = 1;
    for (int i = 0; i < decimals; i++) {
      unit *= 10;
    }
    final int abs = m.minor.abs();
    final String fraction = decimals == 0
        ? ''
        : '.${(abs % unit).toString().padLeft(decimals, '0')}';
    return '${m.minor < 0 ? '-' : ''}${abs ~/ unit}$fraction';
  }

  static String _count(int n) => n == 1 ? '1 receipt' : '$n receipts';

  /// Text read off a paper is data, never a formula. A cell starting with
  /// `=`, `+`, `-`, `@` or a control character is run by a spreadsheet when
  /// opened; a leading apostrophe keeps it as text.
  static String _text(String s) =>
      RegExp(r'^[=+\-@\t\r]').hasMatch(s) ? "'$s" : s;

  static String _row(List<String> cells) => '${cells.map(_cell).join(',')}\r\n';

  static String _cell(String s) =>
      RegExp(r'[",\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}
