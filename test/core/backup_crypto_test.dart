import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart' show Argon2BytesGenerator, Argon2Parameters;
import 'package:recallos/core/backup/backup_crypto.dart';

/// The backup's cryptography, pinned to published test vectors.
///
/// A library that encrypts to the wrong bytes still round-trips with itself —
/// every "encrypt then decrypt gives the input back" test passes — and then no
/// other implementation can read what it wrote. The RFC's own vector is the
/// only check that proves the construction is the one it claims to be.
void main() {
  Uint8List hex(String s) {
    final String clean = s.replaceAll(RegExp(r'[\s:]'), '');
    return Uint8List.fromList(<int>[
      for (int i = 0; i < clean.length; i += 2)
        int.parse(clean.substring(i, i + 2), radix: 16),
    ]);
  }

  test('ChaCha20-Poly1305 matches RFC 8439 §2.8.2', () {
    final Uint8List key = hex(
      '808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f',
    );
    final Uint8List nonce = hex('070000004041424344454647');
    final Uint8List aad = hex('50515253c0c1c2c3c4c5c6c7');
    final Uint8List plaintext = Uint8List.fromList(
      utf8.encode(
        "Ladies and Gentlemen of the class of '99: If I could offer you only "
        'one tip for the future, sunscreen would be it.',
      ),
    );
    final Uint8List expected = hex(
      'd31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d6'
      '3dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b36'
      '92ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc'
      '3ff4def08e4b7a9de576d26586cec64b6116'
      // tag
      '1ae10b594f09e26a7e902ecbd0600691',
    );

    final Uint8List sealed = chacha20Poly1305ForTest(
      encrypt: true,
      key: key,
      nonce: nonce,
      aad: aad,
      input: plaintext,
    );
    expect(sealed, expected);

    final Uint8List opened = chacha20Poly1305ForTest(
      encrypt: false,
      key: key,
      nonce: nonce,
      aad: aad,
      input: expected,
    );
    expect(opened, plaintext);
  });

  group('seal and open', () {
    final Uint8List key = randomBytes(32);
    final Uint8List aad = Uint8List.fromList(utf8.encode('entry:data.bin'));
    final Uint8List message = Uint8List.fromList(utf8.encode('printing guy'));

    test('round-trips, with a fresh nonce every time', () {
      final Uint8List a = seal(key, message, aad);
      final Uint8List b = seal(key, message, aad);
      expect(open(key, a, aad), message);
      expect(a, isNot(b), reason: 'same input must not give the same box');
    });

    test('a wrong key does not open it', () {
      final Uint8List box = seal(key, message, aad);
      expect(
        () => open(randomBytes(32), box, aad),
        throwsA(isA<BackupAuthError>()),
      );
    });

    test('a box moved to another entry does not open', () {
      final Uint8List box = seal(key, message, aad);
      expect(
        () => open(key, box, Uint8List.fromList(utf8.encode('entry:assets/0.bin'))),
        throwsA(isA<BackupAuthError>()),
      );
    });

    test('one changed byte anywhere is caught', () {
      final Uint8List box = seal(key, message, aad);
      for (final int i in <int>[0, 12, box.length - 1]) {
        final Uint8List tampered = Uint8List.fromList(box)..[i] ^= 0x01;
        expect(
          () => open(key, tampered, aad),
          throwsA(isA<BackupAuthError>()),
          reason: 'byte $i',
        );
      }
    });

    test('a truncated box is rejected, not crashed on', () {
      expect(
        () => open(key, Uint8List(10), aad),
        throwsA(isA<BackupAuthError>()),
      );
    });
  });

  test('Argon2id matches RFC 9106 §5.3', () {
    // The library's own implementation, checked against the RFC — deriveKey
    // uses exactly this generator, without the secret and associated data the
    // vector exercises.
    final Argon2BytesGenerator generator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          Uint8List.fromList(List<int>.filled(16, 0x02)),
          secret: Uint8List.fromList(List<int>.filled(8, 0x03)),
          additional: Uint8List.fromList(List<int>.filled(12, 0x04)),
          desiredKeyLength: 32,
          iterations: 3,
          memory: 32,
          lanes: 4,
          version: Argon2Parameters.ARGON2_VERSION_13,
        ),
      );
    final Uint8List tag = generator.process(
      Uint8List.fromList(List<int>.filled(32, 0x01)),
    );
    expect(
      tag,
      hex(
        '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
      ),
    );
  });

  group('passphrase keys', () {
    test('the same passphrase and salt give the same key', () {
      final KdfParams params = KdfParams(
        memoryKiB: 8192,
        iterations: 1,
        lanes: 1,
        salt: Uint8List(16),
      );
      expect(deriveKey('correct horse', params), deriveKey('correct horse', params));
      expect(
        deriveKey('correct horse', params),
        isNot(deriveKey('correct horsf', params)),
      );
    });

    test('parameters from a file are bounded', () {
      // A forged header asking for 4 GiB must be refused before anything tries
      // to allocate it.
      final KdfParams greedy = KdfParams(
        memoryKiB: 4 * 1024 * 1024,
        iterations: 2,
        lanes: 1,
        salt: Uint8List(16),
      );
      expect(greedy.isWithinBounds, isFalse);
      expect(KdfParams.fresh().isWithinBounds, isTrue);
    });

    test('parameters survive their JSON form', () {
      final KdfParams fresh = KdfParams.fresh();
      final KdfParams? back = KdfParams.fromJson(
        jsonDecode(jsonEncode(fresh.toJson())) as Map<String, Object?>,
      );
      expect(back, isNotNull);
      expect(back!.memoryKiB, fresh.memoryKiB);
      expect(back.salt, fresh.salt);
      expect(KdfParams.fromJson(<String, Object?>{'algorithm': 'md5'}), isNull);
    });
  });
}
