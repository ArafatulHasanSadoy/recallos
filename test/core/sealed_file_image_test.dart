import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:recallos/core/backup/backup_crypto.dart';
import 'package:recallos/core/imaging/photo_keyring.dart';
import 'package:recallos/core/imaging/photo_vault.dart';
import 'package:recallos/core/imaging/sealed_file_image.dart';

/// Every stored photograph is drawn through [SealedFileImage]. If it could
/// not open a sealed file, every card in the wallet would render as blank —
/// and no test that only checks the database would notice.
void main() {
  final Uint8List key = randomBytes(32);
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recallos_sealed_image');
    PhotoKeyring.instance.debugUseKey(key);
  });
  tearDown(() async {
    PhotoKeyring.instance.debugUseKey(null);
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Uint8List png(int w, int h) =>
      Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

  Future<ImageInfo> resolve(WidgetTester tester, ImageProvider provider) async {
    final ImageInfo? info = await tester.runAsync(() async {
      final Completer<ImageInfo> done = Completer<ImageInfo>();
      final ImageStream stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener(
          (ImageInfo i, bool _) => done.complete(i),
          onError: (Object e, StackTrace? s) => done.completeError(e, s),
        ),
      );
      return done.future;
    });
    return info!;
  }

  testWidgets('a sealed photograph decodes to its real size', (
    WidgetTester tester,
  ) async {
    final String path = p.join(dir.path, 'card.jpg');
    writePhotoSync(path, png(160, 100), key);
    expect(isSealedPhoto(File(path).readAsBytesSync()), isTrue);

    final ImageInfo info = await resolve(tester, SealedFileImage(File(path)));
    expect(info.image.width, 160);
    expect(info.image.height, 100);
  });

  testWidgets('a plain photograph still shows', (WidgetTester tester) async {
    final File file = File(p.join(dir.path, 'plain.jpg'))
      ..writeAsBytesSync(png(40, 30));
    final ImageInfo info = await resolve(tester, SealedFileImage(file));
    expect(info.image.width, 40);
  });

  testWidgets('cache width still applies, as it did for Image.file', (
    WidgetTester tester,
  ) async {
    final String path = p.join(dir.path, 'thumb.jpg');
    writePhotoSync(path, png(400, 200), key);
    final ImageInfo info = await resolve(
      tester,
      sealedPhoto(File(path), cacheWidth: 100),
    );
    expect(info.image.width, 100);
  });

  test('two providers for one file are one cache entry', () {
    // The wallet tile and the card-opening flight share a decode; that only
    // works if equal paths make equal keys.
    expect(
      SealedFileImage(File('/x/card.jpg')),
      SealedFileImage(File('/x/card.jpg')),
    );
  });
}
