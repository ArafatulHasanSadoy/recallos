import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/db/field_provenance.dart';
import '../../../core/domain/money.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/spending/spending_totals.dart';
import '../../capture/data/card_repository.dart';
import '../../warranty/data/purchase_links.dart' show kReceiptTypes;

final spendingRepositoryProvider = Provider<SpendingRepository>(
  (Ref ref) => SpendingRepository(ref.watch(databaseProvider)),
);

/// Every receipt in the wallet, as the totals see it — live, so a total
/// checked on the receipt's own screen is added the moment it is saved.
final receiptFactsProvider = StreamProvider<List<ReceiptFacts>>(
  (Ref ref) => ref.watch(spendingRepositoryProvider).watchReceipts(),
);

/// The saved receipts' facts for the totals (B4), and the one answer the
/// totals store: that two look-alike receipts are two purchases.
///
/// Nothing here is a copy of a fact. The totals are worked out afresh from
/// `card_fields` each time — what was read, what the user checked — so
/// there is no stored sum to drift away from the receipts it came from.
class SpendingRepository {
  SpendingRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Receipts and invoices not in the bin, as a live stream.
  Stream<List<ReceiptFacts>> watchReceipts() => _db
      .customSelect(
        _receiptIds,
        readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
          _db.cards,
          _db.cardFields,
          _db.itemLinks,
        },
      )
      .watch()
      .asyncMap(
        (List<QueryRow> rows) =>
            _facts(<int>[for (final QueryRow r in rows) r.read<int>('id')]),
      );

  /// The same, once.
  Future<List<ReceiptFacts>> receipts() async {
    final List<QueryRow> rows = await _db.customSelect(_receiptIds).get();
    return _facts(<int>[for (final QueryRow r in rows) r.read<int>('id')]);
  }

  /// The user said [cardId] is a different purchase from each of [others],
  /// though they look alike: both are counted, and the pairs are not asked
  /// about again.
  Future<void> countBoth(int cardId, Iterable<int> others) =>
      _db.transaction(() async {
        for (final int other in others) {
          if (other == cardId) continue;
          final ItemLink? existing = await _answer(cardId, other);
          if (existing == null) {
            await _db
                .into(_db.itemLinks)
                .insert(
                  ItemLinksCompanion.insert(
                    fromCardId: cardId,
                    toCardId: other,
                    kind: LinkKind.duplicateOf,
                    status: const Value<LinkStatus>(LinkStatus.dismissed),
                  ),
                );
          } else if (existing.status != LinkStatus.dismissed) {
            await (_db.update(
              _db.itemLinks,
            )..where(($ItemLinksTable l) => l.id.equals(existing.id))).write(
              ItemLinksCompanion(
                status: const Value<LinkStatus>(LinkStatus.dismissed),
                updatedAt: Value<DateTime>(_now()),
              ),
            );
          }
        }
      });

  /// Undoes [countBoth]: the pairs are asked about again.
  Future<void> undoCountBoth(int cardId, Iterable<int> others) =>
      (_db.delete(_db.itemLinks)..where(
            ($ItemLinksTable l) =>
                l.fromCardId.equals(cardId) &
                l.toCardId.isIn(others) &
                l.kind.equalsValue(LinkKind.duplicateOf),
          ))
          .go();

  // ---------------------------------------------------------------------------

  static final String _receiptIds =
      'SELECT id FROM cards WHERE deleted_at IS NULL AND type IN '
      '(${kReceiptTypes.map((CardType t) => "'${t.name}'").join(', ')}) '
      'ORDER BY captured_at DESC, id DESC';

  Future<ItemLink?> _answer(int from, int to) =>
      (_db.select(_db.itemLinks)..where(
            ($ItemLinksTable l) =>
                l.fromCardId.equals(from) &
                l.toCardId.equals(to) &
                l.kind.equalsValue(LinkKind.duplicateOf),
          ))
          .getSingleOrNull();

  Future<List<ReceiptFacts>> _facts(List<int> ids) async {
    if (ids.isEmpty) return const <ReceiptFacts>[];

    final List<CardRow> cards = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.isIn(ids))).get();
    final Map<int, List<CardField>> fieldsOf = <int, List<CardField>>{};
    for (final CardField f
        in await (_db.select(_db.cardFields)
              ..where(($CardFieldsTable f) => f.cardId.isIn(ids))
              ..orderBy(<OrderClauseGenerator<$CardFieldsTable>>[
                ($CardFieldsTable f) => OrderingTerm.asc(f.id),
              ]))
            .get()) {
      fieldsOf.putIfAbsent(f.cardId, () => <CardField>[]).add(f);
    }

    // The user's "these are two purchases" answers, either way round.
    final Map<int, Set<int>> different = <int, Set<int>>{};
    for (final ItemLink l
        in await (_db.select(_db.itemLinks)..where(
              ($ItemLinksTable l) =>
                  l.kind.equalsValue(LinkKind.duplicateOf) &
                  l.status.equalsValue(LinkStatus.dismissed) &
                  l.deletedAt.isNull(),
            ))
            .get()) {
      different.putIfAbsent(l.fromCardId, () => <int>{}).add(l.toCardId);
      different.putIfAbsent(l.toCardId, () => <int>{}).add(l.fromCardId);
    }

    final Map<int, CardRow> byId = <int, CardRow>{
      for (final CardRow c in cards) c.id: c,
    };
    return <ReceiptFacts>[
      for (final int id in ids)
        if (byId[id] case final CardRow card)
          receiptFactsOf(
            card,
            fieldsOf[id] ?? const <CardField>[],
            notCopiesOf: different[id] ?? const <int>{},
          ),
    ];
  }
}

/// One receipt's stored facts, as the totals read them.
///
/// A total or date counts as *checked* only when the user confirmed or typed
/// it and nothing still objects to it — exactly when the receipt's own screen
/// stops saying *check this*. A value that was read but not as an amount (or
/// a day) is *unreadable*, so the totals can say to correct it rather than
/// to check it.
ReceiptFacts receiptFactsOf(
  CardRow card,
  List<CardField> fields, {
  Set<int> notCopiesOf = const <int>{},
}) {
  final CardField? total = _best(fields, ReceiptKeys.total);
  final CardField? date = _best(fields, ReceiptKeys.purchaseDate);
  final CardField? category = _best(fields, ReceiptKeys.category);

  final int? minor = total?.amountMinor;
  final String? currency = total?.currency;
  final Money? money = minor == null || currency == null
      ? null
      : Money(minor, currency);

  return ReceiptFacts(
    cardId: card.id,
    savedAt: card.capturedAt,
    title: describeCard(card, fields).title,
    shop: _best(fields, ReceiptKeys.merchant)?.value,
    category: category?.value,
    categoryGuessed:
        category != null &&
        category.origin == FactOrigin.inferred &&
        !isConfirmed(category),
    total: money,
    totalState: _state(total, readAs: money),
    date: date?.dateValue,
    dateState: _state(date, readAs: date?.dateValue),
    invoiceNumber: _best(fields, ReceiptKeys.invoiceNumber)?.value,
    notCopiesOf: notCopiesOf,
  );
}

FactState _state(CardField? field, {required Object? readAs}) {
  if (field == null) return FactState.missing;
  if (readAs == null) return FactState.unreadable;
  if (!isConfirmed(field) ||
      field.validity != FactValidity.current ||
      field.validationIssue != null) {
    return FactState.unchecked;
  }
  return FactState.checked;
}

/// The field for [key]: one the user confirmed first, then the front's, then
/// the first read.
CardField? _best(List<CardField> fields, String key) {
  CardField? found;
  for (final CardField f in fields) {
    if (f.fieldKey != key) continue;
    if (found == null) {
      found = f;
      continue;
    }
    final bool better =
        (isConfirmed(f) && !isConfirmed(found)) ||
        (isConfirmed(f) == isConfirmed(found) &&
            f.side == CardSide.front &&
            found.side != CardSide.front);
    if (better) found = f;
  }
  return found;
}
