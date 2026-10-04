/// Checks a Google Play receipt on the phone.
///
/// Play signs every purchase with a key only Google and the developer's Play
/// Console hold, and hands the app the purchase as JSON plus that signature.
/// Checking it here — rather than on a server — is what lets RecallOS sell
/// Plus without the `INTERNET` permission: the receipt arrives through the
/// Play Store app on the phone, and its signature is proof enough that Google
/// issued it. A server check would be stronger against a tampered phone; it
/// arrives with the online features, when the app has a network anyway.
///
/// Pure Dart, so it is tested against keys and receipts made with openssl.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// The one product RecallOS sells. Created in Play Console with exactly this
/// ID, which can never be changed or reused there.
const String kPlusProductId = 'recallos_plus';

/// Reads a base64 X.509 public key, as Play Console prints it. Null when it
/// is not one.
RSAPublicKey? parsePlayKey(String base64Der) {
  try {
    final Uint8List der = base64.decode(
      base64Der.replaceAll(RegExp(r'\s'), ''),
    );
    final ASN1Sequence info = ASN1Parser(der).nextObject() as ASN1Sequence;
    final ASN1BitString bits = info.elements![1] as ASN1BitString;
    final ASN1Sequence rsa =
        ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject()
            as ASN1Sequence;
    return RSAPublicKey(
      (rsa.elements![0] as ASN1Integer).integer!,
      (rsa.elements![1] as ASN1Integer).integer!,
    );
  } on Object {
    return null;
  }
}

/// True when [signature] is Google's signature of [originalJson] under
/// [key], *and* the receipt is a completed purchase of RecallOS Plus.
///
/// Both halves matter: a genuine receipt for a different product, or for a
/// purchase still waiting on payment, is no reason to turn Plus on.
bool isGenuinePlusReceipt({
  required String originalJson,
  required String signature,
  required String key,
}) {
  final RSAPublicKey? publicKey = parsePlayKey(key);
  if (publicKey == null || signature.isEmpty) return false;

  try {
    // Play's purchase signatures are SHA1withRSA, PKCS #1 v1.5.
    final Signer signer = Signer('SHA-1/RSA')
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
    final bool signed = signer.verifySignature(
      Uint8List.fromList(utf8.encode(originalJson)),
      RSASignature(base64.decode(signature)),
    );
    if (!signed) return false;

    final Object? receipt = jsonDecode(originalJson);
    return receipt is Map<String, Object?> &&
        receipt['productId'] == kPlusProductId &&
        // 0 is "purchased"; a pending one carries another state.
        receipt['purchaseState'] == 0;
  } on Object {
    return false;
  }
}
