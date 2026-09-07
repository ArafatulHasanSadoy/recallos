import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/intelligence/ocr_engine.dart';
import '../../../core/intelligence/ocr_engine_provider.dart';
import '../../capture/data/card_repository.dart';
import '../../contacts/data/identity_repository.dart';
import '../../search/data/search_repository.dart';

final rescanServiceProvider = Provider<RescanService>((Ref ref) {
  // Resolved up front rather than through a retained `Ref`. A provider with no
  // listeners is disposed, and a rescan is minutes of OCR long — a lookup
  // after the first `await` would land on a disposed container and turn a
  // working retry into `RescanOutcome.failed` for no visible reason.
  return RescanService(
    cards: ref.watch(cardRepositoryProvider),
    search: ref.watch(searchRepositoryProvider),
    identity: ref.watch(identityRepositoryProvider),
    engine: ref.watch(ocrEngineProvider),
  );
});

/// What happened to one card on a retry, in the words the queue shows.
enum RescanOutcome {
  /// Read something this time where there was nothing, or filled a gap.
  improved,

  /// Ran, but came back with no more than it had. The card is unchanged.
  unchanged,

  /// The image is gone, so there is nothing left to read.
  imageMissing,

  /// The engine itself failed.
  failed,
}

/// Runs a saved card back through recognition.
///
/// The same tail as a fresh scan — recognise, fold in, reindex, promote — but
/// starting from the stored image rather than the scanner, because by the time
/// a card reaches the attention queue the pixels are already ours. Keeping the
/// four steps together is the point: a card re-read but not re-indexed is
/// repaired everywhere except the place people look for it.
///
/// Both sides, when there are two. A card in the attention queue is one that
/// did not read cleanly, and re-reading only half of it would leave the retry
/// weaker than the capture that produced it.
class RescanService {
  RescanService({
    required this.cards,
    required this.search,
    required this.identity,
    required this.engine,
  });

  final CardRepository cards;
  final SearchRepository search;
  final IdentityRepository identity;
  final OcrEngine engine;

  Future<RescanOutcome> rescan(int cardId) async {
    final CardDetail? before = await cards.watchCard(cardId).first;
    if (before == null) return RescanOutcome.failed;

    final File image = File(before.card.imagePath);
    // A card whose image has been deleted underneath us cannot be re-read.
    // Saying so is more useful than an engine error about a missing path.
    if (!image.existsSync()) return RescanOutcome.imageMissing;

    final String? backPath = before.card.backImagePath;
    // A missing back is not a missing card. The front is what makes a rescan
    // possible, so a back whose file has gone is simply skipped.
    final File? back = (backPath != null && File(backPath).existsSync())
        ? File(backPath)
        : null;

    final int fieldsBefore = before.fields.length;

    try {
      await _readSide(cardId, image, CardSide.front);
      if (back != null) await _readSide(cardId, back, CardSide.back);
      await search.reindexCard(cardId);
      await identity.promote(cardId);
    } on Object {
      return RescanOutcome.failed;
    }

    final CardDetail? after = await cards.watchCard(cardId).first;
    if (after == null) return RescanOutcome.failed;

    // Judged on fields rather than on status, because a card that went from
    // one field to four is a real improvement even though both runs land on
    // `partial`.
    return after.fields.length > fieldsBefore
        ? RescanOutcome.improved
        : RescanOutcome.unchanged;
  }

  Future<void> _readSide(int cardId, File image, CardSide side) async {
    final OcrResult result = await engine.recognize(image);
    await cards.attachExtraction(
      cardId: cardId,
      result: result,
      extraction: CardFieldExtractor.extract(result.blocks),
      side: side,
    );
  }
}
