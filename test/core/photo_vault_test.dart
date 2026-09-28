import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:recallos/core/backup/backup_crypto.dart';
import 'package:recallos/core/imaging/card_image_processor.dart';
import 'package:recallos/core/imaging/photo_vault.dart';
import 'package:recallos/core/imaging/portrait_image.dart';

/// Photographs sealed at rest.
///
/// The card photographs were the one part of the wallet stored in the clear.
/// These tests check the seal itself, the one-time conversion of photographs
/// already on a phone, and the two writers that produce new ones — each must
/// leave nothing readable without the key.
void main() {
  final Uint8List key = randomBytes(32);
  late Directory docs;

  setUp(() async => docs = await Directory.systemTemp.createTemp('recallos_photos'));
  tearDown(() async {
    if (docs.existsSync()) await docs.delete(recursive: true);
  });

  Uint8List jpeg({int w = 120, int h = 70}) =>
      Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));

  File put(String relative, List<int> bytes) =>
      File(p.join(docs.path, relative))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  group('the seal', () {
    test('round-trips, and the sealed bytes are not a JPEG', () {
      final Uint8List plain = jpeg();
      final Uint8List sealed = sealPhoto(key, plain);
      expect(isSealedPhoto(sealed), isTrue);
      expect(sealed.sublist(0, 2), isNot(<int>[0xFF, 0xD8]));
      expect(openPhoto(key, sealed), plain);
    });

    test('an unsealed photograph is read as it is', () {
      final Uint8List plain = jpeg();
      expect(isSealedPhoto(plain), isFalse);
      expect(openPhoto(null, plain), plain);
      expect(openPhoto(key, plain), plain);
    });

    test('a sealed photograph does not open without its key', () {
      final Uint8List sealed = sealPhoto(key, jpeg());
      expect(() => openPhoto(null, sealed), throwsA(isA<PhotoLockedException>()));
      expect(
        () => openPhoto(randomBytes(32), sealed),
        throwsA(isA<PhotoLockedException>()),
      );
    });

    test('one changed byte is caught', () {
      final Uint8List sealed = sealPhoto(key, jpeg())..[40] ^= 0x01;
      expect(() => openPhoto(key, sealed), throwsA(isA<PhotoLockedException>()));
    });

    test('writing is sealed and leaves no temporary file', () {
      final String path = p.join(docs.path, 'cards', 'card_1.jpg');
      final Uint8List plain = jpeg();
      writePhotoSync(path, plain, key);

      expect(isSealedPhoto(File(path).readAsBytesSync()), isTrue);
      expect(readPhotoSync(path, key), plain);
      expect(File('$path.writing').existsSync(), isFalse);
    });
  });

  group('photographs already on the phone', () {
    test('are sealed in place, and read back identically', () {
      final Uint8List front = jpeg();
      final Uint8List portrait = jpeg(w: 40, h: 40);
      final File a = put('cards/card_1.jpg', front);
      final File b = put('profile/portrait_1.jpg', portrait);

      final SealReport report = sealPlaintextPhotos(docs.path, key);

      expect(report.sealed, 2);
      expect(report.plaintextLeft, 0);
      expect(isSealedPhoto(a.readAsBytesSync()), isTrue);
      expect(readPhotoSync(a.path, key), front);
      expect(readPhotoSync(b.path, key), portrait);
    });

    test('a second pass has nothing to do', () {
      put('cards/card_1.jpg', jpeg());
      sealPlaintextPhotos(docs.path, key);
      final SealReport again = sealPlaintextPhotos(docs.path, key);
      expect(again.sealed, 0);
      expect(again.plaintextLeft, 0);
    });

    test('files outside the photograph folders are never touched', () {
      final Uint8List bytes = jpeg();
      final File db = put('recallos.sqlite', bytes);
      final File other = put('elsewhere/x.jpg', bytes);

      sealPlaintextPhotos(docs.path, key);

      expect(db.readAsBytesSync(), bytes);
      expect(other.readAsBytesSync(), bytes);
    });

    test('a write that never finished is cleared, the original kept', () {
      final Uint8List plain = jpeg();
      final File card = put('cards/card_1.jpg', plain);
      final File partial = put('cards/card_1.jpg.writing', <int>[1, 2, 3]);

      sealPlaintextPhotos(docs.path, key);

      expect(partial.existsSync(), isFalse);
      expect(readPhotoSync(card.path, key), plain);
    });
  });

  group('new photographs', () {
    test('a captured card and its thumbnail are written sealed', () {
      final File scan = put('scan.jpg', jpeg(w: 900, h: 560));
      final Directory cards = Directory(p.join(docs.path, 'cards'))..createSync();

      final PreparedImage out = prepareCardImage(
        CardImageRequest(
          sourcePath: scan.path,
          targetDir: cards.path,
          baseName: 'card_1',
          photoKey: key,
        ),
      );

      for (final String path in <String>[out.imagePath, out.thumbPath!]) {
        final Uint8List raw = File(path).readAsBytesSync();
        expect(isSealedPhoto(raw), isTrue, reason: path);
        expect(img.decodeImage(openPhoto(key, raw)), isNotNull, reason: path);
      }
    });

    test('a sealed stored card can be processed again', () {
      // The back and rescans read a photograph the app already stored.
      final File stored = File(p.join(docs.path, 'cards', 'card_1.jpg'));
      writePhotoSync(stored.path, jpeg(w: 900, h: 560), key);

      final PreparedImage out = prepareCardImage(
        CardImageRequest(
          sourcePath: stored.path,
          targetDir: stored.parent.path,
          baseName: 'card_1b',
          photoKey: key,
          thumbnail: false,
        ),
      );
      expect(img.decodeImage(readPhotoSync(out.imagePath, key)), isNotNull);
    });

    test('a portrait is written sealed', () {
      final File picked = put('picked.jpg', jpeg(w: 800, h: 800));
      final Directory profile = Directory(p.join(docs.path, 'profile'))..createSync();

      final String path = preparePortrait(
        PortraitRequest(
          sourcePath: picked.path,
          targetDir: profile.path,
          baseName: 'portrait_1',
          photoKey: key,
        ),
      );

      final Uint8List raw = File(path).readAsBytesSync();
      expect(isSealedPhoto(raw), isTrue);
      expect(img.decodeImage(openPhoto(key, raw)), isNotNull);
    });
  });
}
