import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/features/capture/data/back_capture_service.dart';
import 'package:recallos/features/capture/data/card_repository.dart';

/// The whole back capture, minus the one part that needs a camera.
///
/// The widget tests stub this service outright, which proves the button is
/// wired to something and nothing about whether a back actually lands on disk.
/// Everything after the scanner hands back a path — downscaling in an isolate,
/// writing into app storage, attaching to the card, replacing a previous
/// attempt — runs for real here, against real JPEG bytes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory documents;
  late Directory scannerCache;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('recallos_docs');
    scannerCache = await Directory.systemTemp.createTemp('recallos_scan');
    PathProviderPlatform.instance = _FakePathProvider(documents.path);
  });

  tearDown(() async {
    await db.close();
    await documents.delete(recursive: true);
    await scannerCache.delete(recursive: true);
  });

  /// What the scanner hands back: a real, decodable JPEG in its own cache.
  String scannedPage(String name, {int width = 1800, int height = 1100}) {
    final img.Image image = img.Image(width: width, height: height);
    // Not a flat fill — a flat image is the one case the background trim
    // treats specially, and a back of a card is exactly where that shows up.
    img.fill(image, color: img.ColorRgb8(240, 240, 240));
    img.fillRect(image,
        x1: width ~/ 4,
        y1: height ~/ 4,
        x2: width ~/ 2,
        y2: height ~/ 2,
        color: img.ColorRgb8(20, 20, 20));

    final String path = p.join(scannerCache.path, name);
    File(path).writeAsBytesSync(img.encodeJpg(image));
    return path;
  }

  Future<({ProviderContainer container, int cardId})> setUpCard() async {
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final File front = File(p.join(documents.path, 'front.jpg'))
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 100, height: 60)));
    final int cardId = await container
        .read(cardRepositoryProvider)
        .createPending(front)
        .then((({int id, File image}) p) => p.id);

    return (container: container, cardId: cardId);
  }

  Future<CardRow> loadCard(int id) => (db.select(db.cards)
        ..where(($CardsTable c) => c.id.equals(id)))
      .getSingle();

  test('stores the scanned back and points the card at it', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final String page = scannedPage('back.jpg');

    final BackCapture result = await BackCaptureService(
      fixture.container.read(_refProbe),
      scanner: () async => <String>[page],
    ).capture(fixture.cardId);

    expect(result.outcome, BackCaptureOutcome.captured);

    final CardRow card = await loadCard(fixture.cardId);
    expect(card.backImagePath, isNotNull);
    // The file has to be real and decodable, not merely a path in a column.
    final File stored = File(card.backImagePath!);
    expect(stored.existsSync(), isTrue);
    expect(img.decodeImage(stored.readAsBytesSync()), isNotNull);

    // Out of the scanner's cache and into ours, or the OS reclaims it.
    expect(p.isWithin(documents.path, stored.path), isTrue);
    // No thumbnail: nothing lists the back.
    expect(File('${p.withoutExtension(stored.path)}_thumb.jpg').existsSync(),
        isFalse);
  });

  test('leaves the front exactly where it was', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final CardRow before = await loadCard(fixture.cardId);

    await BackCaptureService(
      fixture.container.read(_refProbe),
      scanner: () async => <String>[scannedPage('back.jpg')],
    ).capture(fixture.cardId);

    final CardRow after = await loadCard(fixture.cardId);
    // Every field region is measured against the front. A back capture that
    // moved it would put every highlight in the wrong place.
    expect(after.imagePath, before.imagePath);
    expect(File(after.imagePath).existsSync(), isTrue);
  });

  test('a second capture replaces the first', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();

    await BackCaptureService(
      fixture.container.read(_refProbe),
      scanner: () async => <String>[scannedPage('back_1.jpg')],
    ).capture(fixture.cardId);
    final String first = (await loadCard(fixture.cardId)).backImagePath!;

    await BackCaptureService(
      fixture.container.read(_refProbe),
      scanner: () async => <String>[scannedPage('back_2.jpg')],
    ).capture(fixture.cardId);
    final String second = (await loadCard(fixture.cardId)).backImagePath!;

    expect(second, isNot(first));
    expect(File(first).existsSync(), isFalse);
    expect(File(second).existsSync(), isTrue);
  });

  test('backing out of the scanner changes nothing', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();

    final BackCapture result = await BackCaptureService(
      fixture.container.read(_refProbe),
      scanner: () async => null,
    ).capture(fixture.cardId);

    expect(result.outcome, BackCaptureOutcome.cancelled);
    expect((await loadCard(fixture.cardId)).backImagePath, isNull);
  });

  test('an unreadable page is still kept rather than lost', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final String notAnImage = p.join(scannerCache.path, 'broken.jpg');
    File(notAnImage).writeAsStringSync('this is not a jpeg');

    final BackCapture result = await BackCaptureService(
      fixture.container.read(_refProbe),
      scanner: () async => <String>[notAnImage],
    ).capture(fixture.cardId);

    // The same rule as the front: an image step must never be the reason a
    // capture is lost. The resize fails, the bytes are copied anyway.
    expect(result.outcome, BackCaptureOutcome.captured);
    final CardRow card = await loadCard(fixture.cardId);
    expect(card.backImagePath, isNotNull);
    expect(File(card.backImagePath!).existsSync(), isTrue);
  });
}

/// Hands a real [Ref] to the service under test.
final Provider<Ref> _refProbe = Provider<Ref>((Ref ref) => ref);

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}
