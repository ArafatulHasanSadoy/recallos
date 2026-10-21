/// Money as RecallOS stores it: whole minor units and a currency — paisa,
/// cents — never a floating-point number (PLAN §5).
///
/// 0.1 + 0.2 is not 0.3 in a double, and a spending total that is off by a
/// paisa is a total nobody can trust. Every amount read off a receipt goes
/// through [Money.parse] into an integer, and amounts in different
/// currencies are never added: BDT and USD stay apart.
library;

class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);

  /// The amount in the currency's smallest unit: 845050 is BDT 8,450.50.
  final int minor;

  /// ISO 4217, upper case: `BDT`, `USD`.
  final String currency;

  /// Decimal places of [currency]. Two unless listed: most currencies,
  /// including BDT and USD, have two; a few have none or three.
  static int decimalsOf(String currency) =>
      _decimals[currency.toUpperCase()] ?? 2;

  static const Map<String, int> _decimals = <String, int>{
    'JPY': 0,
    'KRW': 0,
    'VND': 0,
    'IDR': 0,
    'BHD': 3,
    'KWD': 3,
    'OMR': 3,
    'JOD': 3,
    'TND': 3,
  };

  /// Reads an amount as printed — "8,450.50", "৮,৪৫০", "Tk 1,23,456.00",
  /// "(120.00)" — in [currency]. Null when there is no amount in it.
  ///
  /// The last `.` or `,` is the decimal point when what follows it is short
  /// enough to be the currency's fraction (1 or 2 digits for BDT); every
  /// other separator groups thousands. So "8,450" is eight thousand four
  /// hundred and fifty, and "8.450,50" and "8,450.50" are the same amount.
  /// Bangla digits are read as digits. A leading minus or brackets make it
  /// negative, as refunds are printed.
  static Money? parse(String text, {required String currency}) {
    final String code = currency.toUpperCase();
    final int decimals = decimalsOf(code);

    String s = _westernDigits(text).trim();
    final bool negative =
        s.startsWith('-') ||
        s.startsWith('−') ||
        (s.startsWith('(') && s.endsWith(')'));
    // Everything that is not part of the number: symbols, codes, spaces.
    s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (!RegExp(r'[0-9]').hasMatch(s)) return null;

    final int point = s.lastIndexOf(RegExp(r'[.,]'));
    String whole = s;
    String fraction = '';
    if (point >= 0) {
      final String after = s.substring(point + 1);
      if (decimals > 0 && after.isNotEmpty && after.length <= decimals) {
        whole = s.substring(0, point);
        fraction = after;
      }
    }
    whole = whole.replaceAll(RegExp(r'[.,]'), '');
    if (whole.isEmpty) whole = '0';
    if (!RegExp(r'^[0-9]+$').hasMatch(whole) ||
        !RegExp(r'^[0-9]*$').hasMatch(fraction)) {
      return null;
    }

    final int unit = _pow10(decimals);
    final int minor =
        int.parse(whole) * unit +
        (fraction.isEmpty ? 0 : int.parse(fraction.padRight(decimals, '0')));
    return Money(negative ? -minor : minor, code);
  }

  /// The sum, in the same currency. Adding two currencies is a mistake in
  /// the caller, not something to convert silently, so it throws.
  Money operator +(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Cannot add $currency and ${other.currency}: totals are kept per '
        'currency, never converted.',
      );
    }
    return Money(minor + other.minor, currency);
  }

  /// "BDT 8,450.50", "USD 12.00", "JPY 1,200".
  String format() {
    final int decimals = decimalsOf(currency);
    final int unit = _pow10(decimals);
    final int abs = minor.abs();
    final String whole = _group((abs ~/ unit).toString());
    final String fraction = decimals == 0
        ? ''
        : '.${(abs % unit).toString().padLeft(decimals, '0')}';
    return '${minor < 0 ? '-' : ''}$currency $whole$fraction';
  }

  @override
  int compareTo(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Cannot compare $currency and ${other.currency}.');
    }
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => format();

  static int _pow10(int n) {
    int v = 1;
    for (int i = 0; i < n; i++) {
      v *= 10;
    }
    return v;
  }

  static String _group(String digits) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  /// Bangla (০–৯) and other Unicode decimal digits a receipt may print, as
  /// ASCII.
  static String _westernDigits(String s) {
    final StringBuffer out = StringBuffer();
    for (final int rune in s.runes) {
      if (rune >= 0x09E6 && rune <= 0x09EF) {
        out.writeCharCode(0x30 + rune - 0x09E6);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }
}
