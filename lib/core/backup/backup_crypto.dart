/// The two cryptographic operations a backup needs, and nothing else.
///
/// Both come from `package:pointycastle` — the Dart port of BouncyCastle —
/// rather than being written here. Nothing in this file implements a
/// primitive; it chooses them, sizes their parameters, and fixes how they are
/// called so every caller does it the same way.
///
/// - **Argon2id** turns the user's passphrase into a key-encryption key. It is
///   memory-hard, so guessing passphrases costs an attacker memory as well as
///   time, and it is the current OWASP recommendation.
/// - **ChaCha20-Poly1305** (RFC 8439, the AEAD in TLS 1.3) encrypts and
///   authenticates everything else. Chosen over AES-GCM for a measured reason:
///   in pure Dart it ran ~30x faster (8 MiB in 150 ms against 4.8 s), which is
///   the difference between a backup of a full wallet taking seconds and
///   taking minutes on a mid-range phone. `test/core/backup_crypto_test.dart`
///   pins it to the RFC's own test vector.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// A sealed box failed to open: wrong key, or the bytes were changed.
///
/// Deliberately says nothing about which. Telling the two apart would tell an
/// attacker which half of a forged file was wrong.
class BackupAuthError implements Exception {
  const BackupAuthError();
  @override
  String toString() => 'BackupAuthError';
}

/// How a key is derived from a passphrase. Stored in the backup's header, so
/// the cost can be raised later without breaking older backups.
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.lanes,
    required this.salt,
  });

  /// Fresh parameters for a new backup.
  ///
  /// 64 MiB and two passes: above OWASP's Argon2id floor (19 MiB, two passes)
  /// and measured at ~0.4 s on a laptop, a few seconds on the target phone —
  /// paid once per backup and once per restore.
  factory KdfParams.fresh() => KdfParams(
    memoryKiB: 65536,
    iterations: 2,
    lanes: 1,
    salt: randomBytes(16),
  );

  final int memoryKiB;
  final int iterations;
  final int lanes;
  final Uint8List salt;

  /// Upper bounds for parameters read from a file. A header is untrusted
  /// input, and "use 64 GiB of memory" is an easy way to crash the reader.
  static const int maxMemoryKiB = 262144; // 256 MiB
  static const int maxIterations = 10;
  static const int maxLanes = 4;

  bool get isWithinBounds =>
      memoryKiB >= 8192 &&
      memoryKiB <= maxMemoryKiB &&
      iterations >= 1 &&
      iterations <= maxIterations &&
      lanes >= 1 &&
      lanes <= maxLanes &&
      salt.length >= 16 &&
      salt.length <= 64;

  Map<String, Object?> toJson() => <String, Object?>{
    'algorithm': 'argon2id',
    'version': 19,
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'lanes': lanes,
    'salt': base64.encode(salt),
  };

  /// Null when the JSON is not a set of parameters this app understands.
  static KdfParams? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    if (json['algorithm'] != 'argon2id' || json['version'] != 19) return null;
    final Object? m = json['memoryKiB'];
    final Object? t = json['iterations'];
    final Object? l = json['lanes'];
    final Object? s = json['salt'];
    if (m is! int || t is! int || l is! int || s is! String) return null;
    try {
      return KdfParams(
        memoryKiB: m,
        iterations: t,
        lanes: l,
        salt: base64.decode(s),
      );
    } on FormatException {
      return null;
    }
  }
}

/// Derives a 32-byte key from [passphrase]. Slow on purpose; call it off the
/// UI isolate.
Uint8List deriveKey(String passphrase, KdfParams params) {
  final Argon2BytesGenerator generator = Argon2BytesGenerator()
    ..init(
      Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        params.salt,
        desiredKeyLength: 32,
        iterations: params.iterations,
        memory: params.memoryKiB,
        lanes: params.lanes,
        version: Argon2Parameters.ARGON2_VERSION_13,
      ),
    );
  return generator.process(Uint8List.fromList(utf8.encode(passphrase)));
}

final Random _secure = Random.secure();

/// [length] bytes from the platform's secure random source.
Uint8List randomBytes(int length) =>
    Uint8List.fromList(List<int>.generate(length, (_) => _secure.nextInt(256)));

const int _nonceLength = 12;
const int _tagLength = 16;

/// Encrypts and authenticates [plaintext] under [key].
///
/// Returns `nonce ‖ ciphertext ‖ tag`. The nonce is 96 random bits, fresh for
/// every call; each backup has its own random content key, so the chance of a
/// repeat under one key is negligible. [aad] is authenticated but not
/// encrypted — it binds a box to where it belongs, so a valid box cannot be
/// moved to another entry or another backup.
Uint8List seal(Uint8List key, Uint8List plaintext, Uint8List aad) {
  final Uint8List nonce = randomBytes(_nonceLength);
  final Uint8List body = _run(true, key, nonce, aad, plaintext);
  return Uint8List(nonce.length + body.length)
    ..setRange(0, nonce.length, nonce)
    ..setRange(nonce.length, nonce.length + body.length, body);
}

/// Opens a box made by [seal]. Throws [BackupAuthError] if [key] is wrong,
/// [aad] differs, or a single byte of [sealed] changed.
Uint8List open(Uint8List key, Uint8List sealed, Uint8List aad) {
  if (sealed.length < _nonceLength + _tagLength) throw const BackupAuthError();
  final Uint8List nonce = Uint8List.sublistView(sealed, 0, _nonceLength);
  final Uint8List body = Uint8List.sublistView(sealed, _nonceLength);
  try {
    return _run(false, key, nonce, aad, body);
  } on InvalidCipherTextException {
    throw const BackupAuthError();
  } on ArgumentError {
    throw const BackupAuthError();
  }
}

/// Exposed for the RFC 8439 test vector only; production code uses
/// [seal]/[open], which choose the nonce.
Uint8List chacha20Poly1305ForTest({
  required bool encrypt,
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List aad,
  required Uint8List input,
}) => _run(encrypt, key, nonce, aad, input);

Uint8List _run(
  bool encrypt,
  Uint8List key,
  Uint8List nonce,
  Uint8List aad,
  Uint8List input,
) {
  final ChaCha20Poly1305 cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
    ..init(
      encrypt,
      AEADParameters(KeyParameter(key), _tagLength * 8, nonce, aad),
    );
  final Uint8List out = Uint8List(cipher.getOutputSize(input.length));
  int length = cipher.processBytes(input, 0, input.length, out, 0);
  length += cipher.doFinal(out, length);
  return Uint8List.sublistView(out, 0, length);
}
