import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/data/card_repository.dart';
import 'purchase_links.dart';

/// The links and calculated expiries, for the screens' own actions — confirm,
/// dismiss, unlink, link by hand. (`CardRepository` keeps its own instance
/// over the same database for the refreshes it runs after every write.)
final purchaseLinksProvider = Provider<PurchaseLinks>(
  (Ref ref) => PurchaseLinks(ref.watch(databaseProvider)),
);

/// A card's links still in play, with the paper on the other end.
final cardLinksProvider = StreamProvider.family<List<PurchaseLink>, int>(
  (Ref ref, int cardId) => ref.watch(purchaseLinksProvider).watchLinks(cardId),
);

/// A warranty's end, its working, and when it will be mentioned.
final warrantyExpiryProvider = StreamProvider.family<ExpiryView?, int>(
  (Ref ref, int cardId) => ref.watch(purchaseLinksProvider).watchExpiry(cardId),
);
