/// Digit normalisation for cards that mix Bengali and Latin numerals.
///
/// Two different problems live here, and keeping them apart matters:
///
///  * **Script conversion** — `০১২` really are digits, just written in Bengali.
///    Converting them is lossless and always safe.
///  * **Confusable repair** — `O` for `0`, `l` for `1`. This is *guessing at an
///    OCR mistake*, so it is only ever applied where the surrounding text says
///    we should be looking at a number.
///
/// Applying the second one globally would corrupt real words, which is why it
/// is a separate function that callers opt into.
abstract final class Digits {
  /// Bengali–Assamese numerals, in value order from zero.
  static const String bengaliZeroToNine = '০১২৩৪৫৬৭৮৯';

  /// Rewrites Bengali numerals as Latin ones, leaving everything else alone.
  ///
  /// Safe to run over any text: these code points have no other meaning.
  static String toLatin(String input) {
    if (input.isEmpty) return input;

    final StringBuffer out = StringBuffer();
    for (final int rune in input.runes) {
      final int index = bengaliZeroToNine.runes.toList().indexOf(rune);
      if (index >= 0) {
        out.write(index);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// True when [input] contains at least one Bengali numeral.
  static bool hasBengaliDigits(String input) =>
      input.runes.any((int r) => bengaliZeroToNine.runes.contains(r));

  /// Letters an OCR engine commonly returns in place of a digit.
  ///
  /// Only the high-frequency, visually unambiguous cases. Adding marginal ones
  /// buys a little recall and costs a lot of precision — and a silently wrong
  /// phone number is the failure mode that loses a user for good.
  static const Map<String, String> _confusables = <String, String>{
    'O': '0', 'o': '0', 'D': '0', 'Q': '0',
    'I': '1', 'l': '1', '|': '1', 'i': '1',
    'Z': '2', 'z': '2',
    'A': '4',
    'S': '5', 's': '5',
    'G': '6', 'b': '6',
    'T': '7',
    'B': '8',
    'g': '9', 'q': '9',
  };

  /// Repairs letters that should have been digits.
  ///
  /// Call this only for text already believed to be a number — a phone label,
  /// a serial number — never over a whole card.
  static String repairConfusables(String input) {
    if (input.isEmpty) return input;

    final StringBuffer out = StringBuffer();
    for (final String ch in input.split('')) {
      out.write(_confusables[ch] ?? ch);
    }
    return out.toString();
  }

  /// How much of [input] is already a digit, ignoring separators.
  ///
  /// Used to decide whether a token is number-shaped enough to be worth
  /// repairing. A token that is mostly letters is a word, not a mangled number.
  static double digitRatio(String input) {
    final String stripped =
        input.replaceAll(RegExp(r'[\s\-().+/]'), '');
    if (stripped.isEmpty) return 0;

    final int digits =
        stripped.split('').where((String c) => _isAsciiDigit(c)).length;
    return digits / stripped.length;
  }

  static bool _isAsciiDigit(String c) {
    if (c.length != 1) return false;
    final int code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  /// Every ASCII digit in [input], separators and letters removed.
  static String digitsOnly(String input) =>
      input.split('').where(_isAsciiDigit).join();
}
