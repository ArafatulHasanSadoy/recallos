import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/imaging/card_image_processor.dart';
import '../../../core/intelligence/ocr_engine.dart';
import '../../../core/intelligence/ocr_engine_provider.dart';
import '../../contacts/data/identity_repository.dart';
import '../../search/data/search_repository.dart';
import 'card_repository.dart';

final backCaptureServiceProvider = Provider<BackCaptureService>((Ref ref) {
  // Everything resolved here, once, rather than looked up later through a
  // `Ref`. Providers are auto-disposed when nothing listens to them, and this
  // service is read for its side effect and then left to run — `ref.read(...)`
  // after an `await` would land on a disposed container and throw, which is
  // caught and swallowed a few lines further down. The back would be
  // photographed, stored, and silently never read.
  return BackCaptureService(
    cards: ref.watch(cardRepositoryProvider),
    search: ref.watch(searchRepositoryProvider),
    identity: ref.watch(identityRepositoryProvider),
    engine: ref.watch(ocrEngineProvider),
  );
});

/// Opens the scanner and returns the pages it kept, or null if the user left.
///
/// A seam rather than a direct static call, so the rest of this service —
/// downscaling into app storage, attaching to the card, cleaning up — can be
/// driven by a test with real image bytes. Without it the only testable
/// version of a back capture is a stub of the whole thing, which proves the
/// button is wired to *something* and nothing about whether a back is stored.
typedef ScannerLaunch = Future<List<String>?> Function();

/// How a back capture ended.
enum BackCaptureOutcome {
  /// The back is photographed, stored, attached and read.
  ///
  /// Also the outcome when the read found nothing, which is the ordinary case:
  /// most backs are blank, or carry a logo and no words. A back with no text on
  /// it is a successful capture of a back with no text on it.
  captured,

  /// The user left the scanner without keeping a page. Not an error, and
  /// nothing should be said about it.
  cancelled,

  /// Camera access was refused.
  permissionDenied,

  /// The scanner or the write failed. [BackCapture.message] says how.
  failed,
}

/// The outcome, and the detail a message needs.
typedef BackCapture = ({BackCaptureOutcome outcome, String? message});

/// Photographs the back of a card and files it beside the front.
///
/// A separate scanner session rather than a two-page one, which is the part of
/// this worth explaining. The scanner takes a page limit, so asking it for two
/// would be a one-line change — but it would also put every scan into a
/// multi-page flow to serve the minority of cards whose back is worth keeping,
/// make two cards photographed in one session silently become the two sides of
/// one card, and leave no way at all to add a back to something scanned last
/// week. A second session costs one more tap and none of that.
///
/// The whole tail of a scan runs here, in the same order a fresh capture uses
/// it: store, read, fold in, re-index, re-promote. Keeping the five together is
/// the point — a back read but not re-indexed is a back whose text nothing can
/// find, and a back read but not re-promoted is a phone number that never
/// reaches the person it belongs to.
class BackCaptureService {
  BackCaptureService({
    required this.cards,
    required this.search,
    required this.identity,
    required this.engine,
    ScannerLaunch? scanner,
  }) : _scanner = scanner ?? _openScanner;

  final CardRepository cards;
  final SearchRepository search;
  final IdentityRepository identity;

  /// The shared recogniser. Held rather than looked up, for the reason on the
  /// provider above.
  final OcrEngine engine;

  final ScannerLaunch _scanner;

  static Future<List<String>?> _openScanner() =>
      CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: ScannerSource.cameraAndGallery,
        androidScannerMode: AndroidScannerMode.full,
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.9,
        ),
      );

  Future<BackCapture> capture(int cardId) async {
    final List<String>? pages;
    try {
      pages = await _scanner();
    } on CunningDocumentScannerException catch (e) {
      return e.code == 'permission_denied'
          ? (outcome: BackCaptureOutcome.permissionDenied, message: null)
          : (
              outcome: BackCaptureOutcome.failed,
              message: 'Could not open the scanner: ${e.message}',
            );
    } on Object catch (e) {
      return (
        outcome: BackCaptureOutcome.failed,
        message: 'Could not open the scanner: $e',
      );
    }

    if (pages == null || pages.isEmpty) {
      return (outcome: BackCaptureOutcome.cancelled, message: null);
    }

    final File scanned = File(pages.first);
    final String stored;
    try {
      stored = await _store(cardId, scanned);
      await cards.attachBackImage(cardId: cardId, backImagePath: stored);
      unawaited(_cleanScannerCache());
    } on Object catch (e) {
      return (
        outcome: BackCaptureOutcome.failed,
        message: 'Could not save the back: $e',
      );
    }

    // Save first, read second — the same rule the front follows. By this point
    // the back is on disk and pointed at, so everything below can fail without
    // costing the user the photograph they just took. A read that goes wrong
    // leaves a back that can be looked at and re-read later, which is why this
    // reports `captured` either way rather than `failed`.
    await _read(cardId, File(stored));
    return (outcome: BackCaptureOutcome.captured, message: null);
  }

  /// Reads any back that was photographed before backs could be read.
  ///
  /// The same problem `SearchRepository.backfill` exists for, and answered the
  /// same way. Backs have been storable for a while and readable only now, so
  /// without this the feature would appear to do nothing on exactly the cards
  /// somebody already has — they would have to retake a photograph they had
  /// already taken to get anything out of it.
  ///
  /// Returns how many were read. One card at a time and awaited throughout:
  /// this runs at launch beside everything else the first screen is doing, and
  /// a burst of parallel OCR on a phone this app is aimed at would be felt.
  Future<int> backfill() async {
    final List<({int id, String path})> pending = await cards
        .cardsWithUnreadBacks();

    int read = 0;
    for (final ({int id, String path}) card in pending) {
      final File back = File(card.path);
      // The row still points at it but the file is gone. Nothing to read, and
      // nothing to fix from here.
      if (!back.existsSync()) continue;
      await _read(card.id, back);
      read++;
    }
    return read;
  }

  /// Recognises the stored back and folds it into the card it belongs to.
  ///
  /// Scoped to [CardSide.back] throughout, so nothing the front contributed is
  /// touched. Swallows its own failures for the reason above; the card's own
  /// status still records that the read found nothing.
  Future<void> _read(int cardId, File back) async {
    try {
      final OcrResult result = await engine.recognize(back);
      await cards.attachExtraction(
        cardId: cardId,
        result: result,
        extraction: CardFieldExtractor.extract(result.blocks),
        side: CardSide.back,
      );
      await search.reindexCard(cardId);
      await identity.promote(cardId);
    } on Object {
      // Deliberately ignored; see above.
    }
  }

  /// Drops the scanner's copy now that the pixels are ours.
  ///
  /// Swallows its own failures rather than being fired off bare. Unawaited, a
  /// throw here becomes an unhandled async error — it cannot reach the caller
  /// to be reported and cannot be caught by the block it sits in, so it
  /// surfaces as a red screen in debug and a log line in release, long after
  /// the capture it belongs to succeeded. Failing to tidy up is not a failed
  /// capture: the back is already stored and attached by this point.
  Future<void> _cleanScannerCache() async {
    try {
      await CunningDocumentScanner.cleanCache();
    } on Object {
      // Nothing to do and nothing to say. The leftover is the plugin's own
      // cache file, which the OS reclaims.
    }
  }

  /// Moves the capture out of the scanner's cache and into our own storage.
  ///
  /// Downscaled the same way the front is, so a back costs about what a front
  /// costs rather than a full sensor frame. No thumbnail: the library lists one
  /// tile per card and that tile is the front, so nothing would ever read it.
  ///
  /// Falls back to a straight copy if the resize fails. The same rule as the
  /// front — an image step must not be the reason a capture is lost — and it
  /// is safe here in a way it is not there, because no field regions are
  /// measured against this image.
  Future<String> _store(int cardId, File scanned) async {
    final Directory directory = await cards.cardsDirectory();
    final String targetDir = directory.path;
    final String baseName =
        'card_${cardId}_back_${DateTime.now().microsecondsSinceEpoch}';

    try {
      final PreparedImage prepared = await Isolate.run(
        () => prepareCardImage(
          CardImageRequest(
            sourcePath: scanned.path,
            targetDir: targetDir,
            baseName: baseName,
            thumbnail: false,
          ),
        ),
      );
      return prepared.imagePath;
    } on Object {
      final File copy = await scanned.copy(
        p.join(targetDir, '$baseName${p.extension(scanned.path)}'),
      );
      return copy.path;
    }
  }
}
