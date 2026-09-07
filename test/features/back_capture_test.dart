import 'dart:io';
import 'dart:ui' show Rect;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/intelligence/ocr_engine_provider.dart';
import 'package:recallos/features/capture/data/back_capture_service.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';

/// The whole back capture, minus the two parts that need a device.
///
/// The widget tests stub this service outright, which proves the button is
/// wired to something and nothing about whether a back actually lands on disk.
/// Everything after the scanner hands back a path — downscaling in an isolate,
/// writing into app storage, attaching to the card, recognising it, folding the
/// result in beside the front, replacing a previous attempt — runs for real
/// here, against real JPEG bytes and a scripted recogniser.
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

  /// The service as the provider builds it, with a scripted recogniser.
  BackCaptureService service(
    ProviderContainer container, {
    ScannerLaunch? scanner,
    OcrEngine? engine,
  }) =>
      BackCaptureService(
        cards: container.read(cardRepositoryProvider),
        search: container.read(searchRepositoryProvider),
        identity: container.read(identityRepositoryProvider),
        engine: engine ?? _FakeOcr.blank(),
        scanner: scanner,
      );

  Future<List<CardField>> fieldsOf(int id) => (db.select(db.cardFields)
        ..where(($CardFieldsTable f) => f.cardId.equals(id)))
      .get();

  /// A recognised card, one line per block, stacked down the image the way a
  /// real one is — the extractor reads position, so blocks piled at the origin
  /// would exercise nothing.
  OcrResult ocr(List<String> lines) => OcrResult(
        blocks: <OcrBlock>[
          for (int i = 0; i < lines.length; i++)
            OcrBlock(
              text: lines[i],
              rect: Rect.fromLTWH(40, 40.0 + i * 60, 420, 44),
              confidence: 0.9,
              script: Script.latin,
              engine: 'fake',
            ),
        ],
        engine: 'fake',
        duration: const Duration(milliseconds: 12),
      );

  test('stores the scanned back and points the card at it', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final String page = scannedPage('back.jpg');

    final BackCapture result = await service(
      fixture.container,
      scanner: () async => <String>[page],
      engine: _FakeOcr.blank(),
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

    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back.jpg')],
      engine: _FakeOcr.blank(),
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

    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back_1.jpg')],
      engine: _FakeOcr.blank(),
    ).capture(fixture.cardId);
    final String first = (await loadCard(fixture.cardId)).backImagePath!;

    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back_2.jpg')],
      engine: _FakeOcr.blank(),
    ).capture(fixture.cardId);
    final String second = (await loadCard(fixture.cardId)).backImagePath!;

    expect(second, isNot(first));
    expect(File(first).existsSync(), isFalse);
    expect(File(second).existsSync(), isTrue);
  });

  test('backing out of the scanner changes nothing', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();

    final BackCapture result = await service(
      fixture.container,
      scanner: () async => null,
      engine: _FakeOcr.blank(),
    ).capture(fixture.cardId);

    expect(result.outcome, BackCaptureOutcome.cancelled);
    expect((await loadCard(fixture.cardId)).backImagePath, isNull);
  });

  test('an unreadable page is still kept rather than lost', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final String notAnImage = p.join(scannerCache.path, 'broken.jpg');
    File(notAnImage).writeAsStringSync('this is not a jpeg');

    final BackCapture result = await service(
      fixture.container,
      scanner: () async => <String>[notAnImage],
      engine: _FakeOcr.blank(),
    ).capture(fixture.cardId);

    // The same rule as the front: an image step must never be the reason a
    // capture is lost. The resize fails, the bytes are copied anyway.
    expect(result.outcome, BackCaptureOutcome.captured);
    final CardRow card = await loadCard(fixture.cardId);
    expect(card.backImagePath, isNotNull);
    expect(File(card.backImagePath!).existsSync(), isTrue);
  });

  test('reads the back and files what it finds beside the front', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();

    // A front already read, the way a real card reaches this point.
    await fixture.container.read(cardRepositoryProvider).attachExtraction(
          cardId: fixture.cardId,
          result: ocr(<String>['Nusrat Jahan', '01711363991']),
          extraction: CardFieldExtractor.extract(
            ocr(<String>['Nusrat Jahan', '01711363991']).blocks,
          ),
        );

    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back.jpg')],
      // The half of the card that only ever appears on the back: the office.
      engine: _FakeOcr(<String>['nusrat@aquarius.com.bd', 'www.aquarius.com.bd']),
    ).capture(fixture.cardId);

    final List<CardField> fields = await fieldsOf(fixture.cardId);
    final CardField email = fields.firstWhere(
      (CardField f) => f.fieldKey == FieldKeys.email,
    );
    expect(email.value, 'nusrat@aquarius.com.bd');
    // The whole point of the side column: this value is boxed on the back.
    expect(email.side, CardSide.back);

    // And the front is untouched by a read of the other side.
    expect(
      fields
          .where((CardField f) => f.side == CardSide.front)
          .map((CardField f) => f.value),
      containsAll(<String>['Nusrat Jahan']),
    );

    final CardRow card = await loadCard(fixture.cardId);
    expect(card.backOcrText, contains('aquarius'));
    expect(card.rawOcrText, contains('Nusrat Jahan'));
  });

  test('a value printed on both sides is kept once, on the front', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final CardRepository repo =
        fixture.container.read(cardRepositoryProvider);

    await repo.attachExtraction(
      cardId: fixture.cardId,
      result: ocr(<String>['Nusrat Jahan', '01711363991']),
      extraction: CardFieldExtractor.extract(
        ocr(<String>['Nusrat Jahan', '01711363991']).blocks,
      ),
    );

    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back.jpg')],
      engine: _FakeOcr(<String>['01711363991', '01911223344']),
    ).capture(fixture.cardId);

    final List<CardField> phones = (await fieldsOf(fixture.cardId))
        .where((CardField f) => f.fieldKey == FieldKeys.phone)
        .toList();

    // The repeated number appears once, on the side every region is measured
    // against. The second number is a new fact and survives.
    expect(
      phones.where((CardField f) => f.normalizedValue == '+8801711363991'),
      hasLength(1),
    );
    expect(
      phones
          .firstWhere((CardField f) => f.normalizedValue == '+8801711363991')
          .side,
      CardSide.front,
    );
    expect(
      phones.where((CardField f) => f.side == CardSide.back),
      hasLength(1),
    );
  });

  test('a blank back does not make a well-read card look failed', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();

    await fixture.container.read(cardRepositoryProvider).attachExtraction(
          cardId: fixture.cardId,
          result: ocr(<String>['Nusrat Jahan', '01711363991']),
          extraction: CardFieldExtractor.extract(
            ocr(<String>['Nusrat Jahan', '01711363991']).blocks,
          ),
        );
    expect((await loadCard(fixture.cardId)).extractionStatus,
        ExtractionStatus.complete);

    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back.jpg')],
      engine: _FakeOcr.blank(),
    ).capture(fixture.cardId);

    // Most backs are blank. Reading one must not overwrite what the front
    // already established about the card.
    expect((await loadCard(fixture.cardId)).extractionStatus,
        ExtractionStatus.complete);
    expect(await fieldsOf(fixture.cardId), isNotEmpty);
  });

  test('reads backs that were stored before backs could be read', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final CardRepository repo =
        fixture.container.read(cardRepositoryProvider);

    // A card exactly as the old build left it: a back on disk, and nothing
    // ever read from it.
    final String stored = scannedPage('old_back.jpg');
    await repo.attachBackImage(cardId: fixture.cardId, backImagePath: stored);
    expect((await loadCard(fixture.cardId)).backOcrText, isNull);

    final int read = await service(
      fixture.container,
      engine: _FakeOcr(<String>['nusrat@aquarius.com.bd']),
    ).backfill();

    expect(read, 1);
    expect(
      (await fieldsOf(fixture.cardId))
          .where((CardField f) => f.side == CardSide.back)
          .map((CardField f) => f.value),
      contains('nusrat@aquarius.com.bd'),
    );
  });

  test('a back already read is not read again', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();

    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back.jpg')],
      // A blank back, which is the ordinary case and the one that would be
      // re-read on every single launch if "read" were judged by whether
      // anything was found rather than by whether anyone looked.
      engine: _FakeOcr.blank(),
    ).capture(fixture.cardId);

    final int read = await service(
      fixture.container,
      engine: _FakeOcr.blank(),
    ).backfill();

    expect(read, 0);
  });

  test('reads the back when built the way the app builds it', () async {
    // Through the provider, not the constructor. Every other test here hands
    // the service its dependencies directly, which is precisely how a real
    // failure hid: the shipped service looked its dependencies up through a
    // `Ref` after the first `await`, by which point the provider — listened to
    // by nobody — had been disposed. The lookup threw, the throw was caught
    // and swallowed, and the back was stored and silently never read. Nothing
    // logged, nothing failed, and no test that skipped the provider could see
    // it.
    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ocrEngineProvider
            .overrideWithValue(_FakeOcr(<String>['nusrat@aquarius.com.bd'])),
      ],
    );
    addTearDown(container.dispose);

    final int cardId = await container
        .read(cardRepositoryProvider)
        .createPending(
          File(p.join(documents.path, 'front2.jpg'))
            ..writeAsBytesSync(img.encodeJpg(img.Image(width: 100, height: 60))),
        )
        .then((({int id, File image}) c) => c.id);

    final BackCaptureService fromProvider =
        container.read(backCaptureServiceProvider);
    await container
        .read(cardRepositoryProvider)
        .attachBackImage(cardId: cardId, backImagePath: scannedPage('b.jpg'));

    // A turn of the event loop between reading the provider and using it, so
    // anything scheduled for disposal has been disposed.
    await Future<void>.delayed(Duration.zero);

    expect(await fromProvider.backfill(), 1);
    expect(
      (await fieldsOf(cardId))
          .where((CardField f) => f.side == CardSide.back)
          .map((CardField f) => f.value),
      contains('nusrat@aquarius.com.bd'),
    );
  });

  test('removing the back takes what was read off it too', () async {
    final ({ProviderContainer container, int cardId}) fixture =
        await setUpCard();
    final CardRepository repo =
        fixture.container.read(cardRepositoryProvider);

    await repo.attachExtraction(
      cardId: fixture.cardId,
      result: ocr(<String>['Nusrat Jahan', '01711363991']),
      extraction: CardFieldExtractor.extract(
        ocr(<String>['Nusrat Jahan', '01711363991']).blocks,
      ),
    );
    await service(
      fixture.container,
      scanner: () async => <String>[scannedPage('back.jpg')],
      engine: _FakeOcr(<String>['nusrat@aquarius.com.bd']),
    ).capture(fixture.cardId);
    expect(
      (await fieldsOf(fixture.cardId)).where((CardField f) => f.side == CardSide.back),
      isNotEmpty,
    );

    await repo.removeBackImage(fixture.cardId);

    // Those rows point at an image that no longer exists, so they go with it.
    final List<CardField> after = await fieldsOf(fixture.cardId);
    expect(after.where((CardField f) => f.side == CardSide.back), isEmpty);
    expect(after.where((CardField f) => f.side == CardSide.front), isNotEmpty);
    expect((await loadCard(fixture.cardId)).backOcrText, isNull);
    expect(
      await (db.select(db.ocrBlocks)
            ..where(($OcrBlocksTable b) => b.side.equalsValue(CardSide.back)))
          .get(),
      isEmpty,
    );
  });
}

/// Reads whatever it was told to read.
///
/// Stands in for ML Kit, which needs a device. Injected rather than overridden
/// through the provider so the real recogniser is never constructed at all —
/// it throws on `dispose` under a test binding, which fails the teardown of an
/// otherwise passing test.
class _FakeOcr implements OcrEngine {
  _FakeOcr(this.lines);

  /// A back with nothing on it — the ordinary case, and the one that must not
  /// disturb the front.
  factory _FakeOcr.blank() => _FakeOcr(const <String>[]);

  final List<String> lines;

  @override
  String get id => 'fake';

  @override
  Set<Script> get supportedScripts => const <Script>{Script.latin};

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<OcrResult> recognize(
    File image, {
    Set<Script> scripts = const <Script>{Script.latin},
    Duration timeout = const Duration(seconds: 15),
  }) async =>
      OcrResult(
        blocks: <OcrBlock>[
          for (int i = 0; i < lines.length; i++)
            OcrBlock(
              text: lines[i],
              rect: Rect.fromLTWH(40, 40.0 + i * 60, 420, 44),
              confidence: 0.9,
              script: Script.latin,
              engine: 'fake',
            ),
        ],
        engine: 'fake',
        duration: const Duration(milliseconds: 12),
      );

  @override
  Future<void> dispose() async {}
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}
