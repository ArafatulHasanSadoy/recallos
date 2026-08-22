import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extraction/card_extractor.dart';
import '../../../core/intelligence/ocr_engine.dart';
import '../../../core/intelligence/ocr_engine_provider.dart';
import '../../capture/data/card_repository.dart';
import '../../contacts/data/identity_repository.dart';
import '../../search/data/search_repository.dart';

final rescanServiceProvider = Provider<RescanService>(
  (Ref ref) => RescanService(ref),
);

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
class RescanService {
  RescanService(this._ref);

  final Ref _ref;

  Future<RescanOutcome> rescan(int cardId) async {
    final CardRepository repo = _ref.read(cardRepositoryProvider);
    final CardDetail? before = await repo.watchCard(cardId).first;
    if (before == null) return RescanOutcome.failed;

    final File image = File(before.card.imagePath);
    // A card whose image has been deleted underneath us cannot be re-read.
    // Saying so is more useful than an engine error about a missing path.
    if (!image.existsSync()) return RescanOutcome.imageMissing;

    final int fieldsBefore = before.fields.length;

    try {
      final OcrEngine engine = _ref.read(ocrEngineProvider);
      final OcrResult result = await engine.recognize(image);
      final CardExtraction extraction =
          CardFieldExtractor.extract(result.blocks);

      await repo.attachExtraction(
        cardId: cardId,
        result: result,
        extraction: extraction,
      );
      await _ref.read(searchRepositoryProvider).reindexCard(cardId);
      await _ref.read(identityRepositoryProvider).promote(cardId);
    } on Object {
      return RescanOutcome.failed;
    }

    final CardDetail? after = await repo.watchCard(cardId).first;
    if (after == null) return RescanOutcome.failed;

    // Judged on fields rather than on status, because a card that went from
    // one field to four is a real improvement even though both runs land on
    // `partial`.
    return after.fields.length > fieldsBefore
        ? RescanOutcome.improved
        : RescanOutcome.unchanged;
  }
}
