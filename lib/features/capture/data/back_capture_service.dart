import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/imaging/card_image_processor.dart';
import 'card_repository.dart';

final backCaptureServiceProvider = Provider<BackCaptureService>(
  (Ref ref) => BackCaptureService(ref),
);

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
  /// The back is photographed, stored and attached.
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
/// Deliberately does **not** run OCR. See [CardRepository.attachBackImage] for
/// why reading the back would need a schema change first.
class BackCaptureService {
  BackCaptureService(this._ref, {ScannerLaunch? scanner})
      : _scanner = scanner ?? _openScanner;

  final Ref _ref;
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
    final CardRepository repo = _ref.read(cardRepositoryProvider);

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
    try {
      final String stored = await _store(repo, cardId, scanned);
      await repo.attachBackImage(cardId: cardId, backImagePath: stored);
      unawaited(_cleanScannerCache());
      return (outcome: BackCaptureOutcome.captured, message: null);
    } on Object catch (e) {
      return (
        outcome: BackCaptureOutcome.failed,
        message: 'Could not save the back: $e',
      );
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
  Future<String> _store(CardRepository repo, int cardId, File scanned) async {
    final Directory cards = await repo.cardsDirectory();
    final String targetDir = cards.path;
    final String baseName =
        'card_${cardId}_back_${DateTime.now().microsecondsSinceEpoch}';

    try {
      final PreparedImage prepared = await Isolate.run(
        () => prepareCardImage(CardImageRequest(
          sourcePath: scanned.path,
          targetDir: targetDir,
          baseName: baseName,
          thumbnail: false,
        )),
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
