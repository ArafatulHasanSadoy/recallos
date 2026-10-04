import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/features/plus/data/purchase_check.dart';

import '../support/play_fixtures.dart';

/// Plus turns on only for a receipt Google signed, for Plus, fully paid.
///
/// The keys and signatures are real (openssl, see `play_fixtures.dart`), so
/// these exercise the same RSA check a Play receipt meets on the phone.
void main() {
  bool check(String json, String signature, {String key = testPlayKey}) =>
      isGenuinePlusReceipt(originalJson: json, signature: signature, key: key);

  test('a receipt Google signed for Plus checks out', () {
    expect(check(plusReceipt, plusSignature), isTrue);
  });

  test('a changed receipt, another key or a forged signature does not', () {
    expect(
      check(
        plusReceipt.replaceFirst('test-token-1', 'test-token-9'),
        plusSignature,
      ),
      isFalse,
      reason: 'one character of the receipt changed',
    );
    expect(check(plusReceipt, plusSignature, key: otherPlayKey), isFalse);
    expect(check(plusReceipt, plusSignatureWrongKey), isFalse);
    expect(check(plusReceipt, ''), isFalse);
    expect(check(plusReceipt, 'not a signature at all'), isFalse);
  });

  test('genuine but not a paid purchase of Plus is not enough', () {
    expect(
      check(pendingReceipt, pendingSignature),
      isFalse,
      reason: 'still waiting on payment',
    );
    expect(
      check(otherProductReceipt, otherProductSignature),
      isFalse,
      reason: 'another product',
    );
  });

  test('without a licence key nothing checks out', () {
    expect(parsePlayKey(''), isNull);
    expect(parsePlayKey('not a key'), isNull);
    expect(parsePlayKey(testPlayKey), isNotNull);
    expect(check(plusReceipt, plusSignature, key: ''), isFalse);
  });
}
