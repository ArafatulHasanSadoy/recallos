import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../capture/data/card_repository.dart';
import '../../search/data/search_repository.dart';

/// Development only, behind `kEvaluationTools`: fills a wallet with invented
/// people, to see how the app behaves when there are thousands of them.
///
/// Typed records, because it is the list, the index and the search being
/// measured, not the camera. Goes through the same writes as real use so the
/// search index is real.
Future<int> fillWithTestCards(
  CardRepository cards,
  SearchRepository search, {
  int count = 3000,
}) async {
  const List<String> trades = <String>[
    'printing',
    'catering',
    'sound system',
    'photography',
    'event decor',
    'logistics',
    'stationery',
    'web design',
  ];
  for (int i = 0; i < count; i++) {
    final String n = '${i + 1}'.padLeft(4, '0');
    final String trade = trades[i % trades.length];
    final int id = await cards.createTyped(
      type: CardType.visitingCard,
      fieldKey: FieldKeys.personName,
      value: 'Test Person $n',
    );
    await cards.addField(
      cardId: id,
      fieldKey: FieldKeys.company,
      value: 'Test $trade $n Ltd',
    );
    await cards.addField(
      cardId: id,
      fieldKey: FieldKeys.phone,
      value: '+88017${n}0${i % 9}${i % 7}${i % 5}',
    );
    await cards.addNote(cardId: id, body: 'test card for $trade');
    await search.reindexCard(id);
  }
  return count;
}
