import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/db/field_provenance.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/receipt_extractor.dart' show formatDay;
import '../../../core/linking/purchase_link_rules.dart';
import '../../../core/linking/warranty_expiry.dart';

/// The kinds of paper a warranty is linked to.
const Set<CardType> kReceiptTypes = <CardType>{
  CardType.receipt,
  CardType.invoice,
};

/// The kinds of paper that have a cover and an end.
const Set<CardType> kWarrantyTypes = <CardType>{CardType.warrantyCard};

/// A link from one card's point of view: the other paper, and why.
class PurchaseLink {
  const PurchaseLink({
    required this.row,
    required this.reasons,
    required this.other,
    required this.otherFields,
  });

  final ItemLink row;

  /// Strongest first, as the rules gave them.
  final List<LinkReason> reasons;

  /// The paper on the other end — the receipt, seen from a warranty.
  final CardRow other;
  final List<CardField> otherFields;

  int get id => row.id;
  bool get isConfirmed => row.status == LinkStatus.confirmed;
  int get warrantyId => row.fromCardId;
  int get receiptId => row.toCardId;
}

/// A warranty's end, as the card screen shows it.
class ExpiryView {
  const ExpiryView({required this.expiry, this.remindAt});

  final WarrantyExpiry expiry;

  /// When Android will mention it, or null when it will not.
  final DateTime? remindAt;
}

/// Warranties linked to their receipts, and everything worked out from that
/// (B3): the suggestions and their reasons, the calculated expiry, and the
/// date with its reminder.
///
/// All of it is derived, and kept in step the way the identity graph is:
/// [refresh] works it out again from the facts as they now stand. It is
/// called by `CardRepository` at the end of every write that can change an
/// input — a reading, a kind, a field, a delete, a restore — so no screen has
/// to remember to, and none can forget.
///
/// What the user decided is never re-derived. A confirmed link stays
/// confirmed and a dismissed one stays dismissed (so it is not suggested
/// again); only *suggested* rows come and go with the evidence.
class PurchaseLinks {
  PurchaseLinks(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Works out again everything that depends on [cardId]: its suggestions,
  /// and the expiry of every warranty it bears on — itself, or the ones it
  /// is the confirmed receipt for.
  Future<void> refresh(int cardId) => _db.transaction(() async {
    final CardRow? card = await _card(cardId);
    if (card == null) return;

    final Set<int> warranties = <int>{
      for (final ItemLink l in await _links(cardId))
        if (l.status == LinkStatus.confirmed) l.fromCardId,
    };

    if (card.deletedAt == null && _isPurchase(card.type)) {
      await _suggest(card);
    } else {
      // A card in the bin, or one that turned out to be somebody's card, is
      // no longer anything's receipt. Confirmed and dismissed rows stay: the
      // user's answers come back with the card.
      await _dropSuggestions(cardId);
    }

    if (kWarrantyTypes.contains(card.type)) {
      warranties.add(cardId);
    } else {
      warranties.remove(cardId);
      await _clearExpiry(cardId);
    }
    for (final int w in warranties) {
      await _settleExpiry(w);
    }
  });

  /// The warranties whose expiry leans on [cardId] — what has to be
  /// refreshed after it is purged, when its links have cascaded away and
  /// [refresh] can no longer find them.
  Future<List<int>> warrantiesLeaningOn(int cardId) async => <int>[
    for (final ItemLink l in await _links(cardId))
      if (l.status == LinkStatus.confirmed && l.fromCardId != cardId)
        l.fromCardId,
  ];

  /// What the matching rules would suggest across every live warranty and
  /// receipt, whatever the user has answered — the rules on their own, for
  /// PLAN §6's link precision and recall. Reads only.
  Future<List<LinkSuggestion>> ruleSuggestions() async {
    final List<CardRow> live = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.deletedAt.isNull())).get();
    final List<PaperFacts> receipts = <PaperFacts>[
      for (final CardRow c in live)
        if (kReceiptTypes.contains(c.type)) await _facts(c),
    ];
    return <LinkSuggestion>[
      for (final CardRow c in live)
        if (kWarrantyTypes.contains(c.type))
          ...PurchaseLinkRules.forWarranty(await _facts(c), receipts),
    ];
  }

  /// The user said yes: these two belong together.
  Future<void> confirm(int linkId) => _db.transaction(() async {
    final ItemLink? link = await _link(linkId);
    if (link == null) return;
    await _setStatus(linkId, LinkStatus.confirmed);
    await _settled(link.fromCardId);
  });

  /// The user said no to a suggestion. Kept as dismissed, so the same pair
  /// is not offered again.
  Future<void> dismiss(int linkId) => _setStatus(linkId, LinkStatus.dismissed);

  /// Undoes [dismiss]: the suggestion is offered again.
  Future<void> reopen(int linkId) => _setStatus(linkId, LinkStatus.suggested);

  /// Undoes a confirmed link. Dismissed rather than deleted, for the same
  /// reason as [dismiss]; [link] puts it back.
  Future<void> unlink(int linkId) async {
    final ItemLink? link = await _link(linkId);
    if (link == null) return;
    await _setStatus(linkId, LinkStatus.dismissed);
    // The warranty may now take another receipt's suggestion, and its
    // calculated expiry loses the receipt's date.
    await refresh(link.fromCardId);
  }

  /// Links [warrantyId] to [receiptId] because the user chose to — nothing
  /// printed had to match. A pair the rules had already found keeps its
  /// reasons.
  Future<void> link({required int warrantyId, required int receiptId}) =>
      _db.transaction(() async {
        final ItemLink? existing =
            await (_db.select(_db.itemLinks)..where(
                  ($ItemLinksTable l) =>
                      l.fromCardId.equals(warrantyId) &
                      l.toCardId.equals(receiptId) &
                      l.kind.equalsValue(LinkKind.warrantyOf),
                ))
                .getSingleOrNull();
        if (existing == null) {
          await _db
              .into(_db.itemLinks)
              .insert(
                ItemLinksCompanion.insert(
                  fromCardId: warrantyId,
                  toCardId: receiptId,
                  kind: LinkKind.warrantyOf,
                  status: const Value<LinkStatus>(LinkStatus.confirmed),
                  reasons: Value<String>(
                    _encode(const <LinkReason>[LinkReason(LinkCue.chosen)]),
                  ),
                ),
              );
        } else {
          final List<LinkReason> reasons = _decode(existing.reasons);
          await (_db.update(
            _db.itemLinks,
          )..where(($ItemLinksTable l) => l.id.equals(existing.id))).write(
            ItemLinksCompanion(
              status: const Value<LinkStatus>(LinkStatus.confirmed),
              reasons: reasons.isEmpty
                  ? Value<String>(
                      _encode(const <LinkReason>[LinkReason(LinkCue.chosen)]),
                    )
                  : const Value<String>.absent(),
              updatedAt: Value<DateTime>(_now()),
            ),
          );
        }
        await _settled(warrantyId);
      });

  /// The papers [cardId] could be linked to by hand — receipts for a
  /// warranty, warranties for a receipt — that are not in the bin and not
  /// already linked to it. Those dated the same day as it come first, then
  /// the most recently saved.
  Future<List<({CardRow card, List<CardField> fields})>> linkCandidates(
    int cardId,
  ) async {
    final CardRow? me = await _card(cardId);
    if (me == null || !_isPurchase(me.type)) return const [];
    final bool isWarranty = kWarrantyTypes.contains(me.type);
    final Set<int> linked = <int>{
      for (final ItemLink l in await _links(cardId))
        if (l.status == LinkStatus.confirmed)
          l.fromCardId == cardId ? l.toCardId : l.fromCardId,
    };
    final List<CardRow> rows =
        await (_db.select(_db.cards)
              ..where(
                ($CardsTable c) =>
                    c.deletedAt.isNull() &
                    c.type.isIn(
                      (isWarranty ? kReceiptTypes : kWarrantyTypes).map(
                        (CardType t) => t.name,
                      ),
                    ),
              )
              ..orderBy(<OrderClauseGenerator<$CardsTable>>[
                ($CardsTable c) => OrderingTerm.desc(c.capturedAt),
                ($CardsTable c) => OrderingTerm.desc(c.id),
              ]))
            .get();

    final LocalDate? myDay = _purchaseDate(await _fields(cardId));
    final List<({CardRow card, List<CardField> fields})> out =
        <({CardRow card, List<CardField> fields})>[
          for (final CardRow r in rows)
            if (r.id != cardId && !linked.contains(r.id))
              (card: r, fields: await _fields(r.id)),
        ];
    if (myDay == null) return out;
    final List<({CardRow card, List<CardField> fields})> sameDay = out
        .where((c) => _purchaseDate(c.fields) == myDay)
        .toList();
    return <({CardRow card, List<CardField> fields})>[
      ...sameDay,
      ...out.where((c) => !sameDay.contains(c)),
    ];
  }

  /// A card's links that are still in play — confirmed ones first, then
  /// suggestions, likeliest first — with the paper on the other end. Papers
  /// in the bin, and pairs that are no longer a warranty and a receipt, are
  /// left out.
  Stream<List<PurchaseLink>> watchLinks(int cardId) => _db
      .customSelect(
        'SELECT id FROM item_links '
        'WHERE (from_card_id = ? OR to_card_id = ?) '
        "AND kind = 'warrantyOf' "
        "AND status IN ('suggested', 'confirmed') AND deleted_at IS NULL",
        variables: <Variable<Object>>[
          Variable<int>(cardId),
          Variable<int>(cardId),
        ],
        readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
          _db.itemLinks,
          _db.cards,
          _db.cardFields,
        },
      )
      .watch()
      .asyncMap((List<QueryRow> rows) async {
        final CardRow? me = await _card(cardId);
        if (me == null) return const <PurchaseLink>[];
        final List<PurchaseLink> out = <PurchaseLink>[];
        for (final QueryRow r in rows) {
          final ItemLink? l = await _link(r.read<int>('id'));
          if (l == null) continue;
          final int otherId = l.fromCardId == cardId
              ? l.toCardId
              : l.fromCardId;
          final CardRow? other = await _card(otherId);
          if (other == null || other.deletedAt != null) continue;
          final bool fits = kWarrantyTypes.contains(me.type)
              ? kReceiptTypes.contains(other.type)
              : kReceiptTypes.contains(me.type) &&
                    kWarrantyTypes.contains(other.type);
          if (!fits) continue;
          out.add(
            PurchaseLink(
              row: l,
              reasons: _decode(l.reasons),
              other: other,
              otherFields: await _fields(otherId),
            ),
          );
        }
        out.sort((PurchaseLink a, PurchaseLink b) {
          if (a.isConfirmed != b.isConfirmed) return a.isConfirmed ? -1 : 1;
          return (b.row.confidence ?? 0).compareTo(a.row.confidence ?? 0);
        });
        return out;
      });

  /// A warranty's end, how it is known and when it will be mentioned. Null
  /// when nothing says yet.
  Stream<ExpiryView?> watchExpiry(int warrantyId) => _db
      .customSelect(
        'SELECT id FROM cards WHERE id = ?',
        variables: <Variable<Object>>[Variable<int>(warrantyId)],
        readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
          _db.cards,
          _db.cardFields,
          _db.itemLinks,
          _db.importantDates,
          _db.reminders,
        },
      )
      .watch()
      .asyncMap(
        (List<QueryRow> rows) async =>
            rows.isEmpty ? null : await expiry(warrantyId),
      );

  /// The same, once — for an answer that is worked out and shown, not
  /// watched (Ask RecallOS, B5).
  Future<ExpiryView?> expiry(int warrantyId) async {
    final WarrantyExpiry? expiry = await _expiryOf(warrantyId);
    if (expiry == null) return null;
    final ImportantDate? date = await _expiryDate(warrantyId);
    final Reminder? reminder = date == null
        ? null
        : await (_db.select(_db.reminders)
                ..where(
                  ($RemindersTable r) =>
                      r.importantDateId.equals(date.id) &
                      r.status.equalsValue(ReminderStatus.scheduled) &
                      r.deletedAt.isNull() &
                      r.remindAt.isBiggerThanValue(_now()),
                )
                ..orderBy(<OrderClauseGenerator<$RemindersTable>>[
                  ($RemindersTable r) => OrderingTerm.asc(r.remindAt),
                ])
                ..limit(1))
              .getSingleOrNull();
    return ExpiryView(expiry: expiry, remindAt: reminder?.remindAt);
  }

  // ---------------------------------------------------------------------------
  // Suggestions
  // ---------------------------------------------------------------------------

  Future<void> _suggest(CardRow card) async {
    final bool isWarranty = kWarrantyTypes.contains(card.type);
    final List<ItemLink> mine = await _links(card.id);

    // One purchase, one receipt: a warranty the user has already matched is
    // offered nothing more. A receipt can still be for several warranties —
    // a phone and its charger — but not for one that is already matched.
    final Set<int> matched = await _matchedWarranties();
    final List<LinkSuggestion> found;
    if (isWarranty && matched.contains(card.id)) {
      found = const <LinkSuggestion>[];
    } else {
      final List<CardRow> others =
          await (_db.select(_db.cards)..where(
                ($CardsTable c) =>
                    c.deletedAt.isNull() &
                    c.id.equals(card.id).not() &
                    c.type.isIn(
                      (isWarranty ? kReceiptTypes : kWarrantyTypes).map(
                        (CardType t) => t.name,
                      ),
                    ),
              ))
              .get();
      final PaperFacts me = await _facts(card);
      final List<PaperFacts> theirs = <PaperFacts>[
        for (final CardRow o in others)
          if (isWarranty || !matched.contains(o.id)) await _facts(o),
      ];
      found = isWarranty
          ? PurchaseLinkRules.forWarranty(me, theirs)
          : PurchaseLinkRules.forReceipt(me, theirs);
    }

    final Set<int> kept = <int>{};
    for (final LinkSuggestion s in found) {
      final ItemLink? existing = mine
          .where(
            (ItemLink l) =>
                l.fromCardId == s.warrantyId &&
                l.toCardId == s.receiptId &&
                l.kind == LinkKind.warrantyOf,
          )
          .firstOrNull;
      if (existing == null) {
        await _db
            .into(_db.itemLinks)
            .insert(
              ItemLinksCompanion.insert(
                fromCardId: s.warrantyId,
                toCardId: s.receiptId,
                kind: LinkKind.warrantyOf,
                reasons: Value<String>(_encode(s.reasons)),
                confidence: Value<double?>(s.confidence),
              ),
            );
        continue;
      }
      kept.add(existing.id);
      // The user's answer stands; only a suggestion's evidence is renewed.
      if (existing.status != LinkStatus.suggested) continue;
      await (_db.update(
        _db.itemLinks,
      )..where(($ItemLinksTable l) => l.id.equals(existing.id))).write(
        ItemLinksCompanion(
          reasons: Value<String>(_encode(s.reasons)),
          confidence: Value<double?>(s.confidence),
          updatedAt: Value<DateTime>(_now()),
        ),
      );
    }

    // A suggestion whose evidence has gone — the serial was corrected — goes
    // with it.
    for (final ItemLink l in mine) {
      if (l.status == LinkStatus.suggested && !kept.contains(l.id)) {
        await (_db.delete(
          _db.itemLinks,
        )..where(($ItemLinksTable t) => t.id.equals(l.id))).go();
      }
    }
  }

  Future<void> _dropSuggestions(int cardId) =>
      (_db.delete(_db.itemLinks)..where(
            ($ItemLinksTable l) =>
                (l.fromCardId.equals(cardId) | l.toCardId.equals(cardId)) &
                l.kind.equalsValue(LinkKind.warrantyOf) &
                l.status.equalsValue(LinkStatus.suggested),
          ))
          .go();

  /// After a warranty is matched: its other suggestions go, and its expiry
  /// can now count from the receipt.
  Future<void> _settled(int warrantyId) async {
    await (_db.delete(_db.itemLinks)..where(
          ($ItemLinksTable l) =>
              l.fromCardId.equals(warrantyId) &
              l.kind.equalsValue(LinkKind.warrantyOf) &
              l.status.equalsValue(LinkStatus.suggested),
        ))
        .go();
    await _settleExpiry(warrantyId);
  }

  Future<Set<int>> _matchedWarranties() async => <int>{
    for (final ItemLink l
        in await (_db.select(_db.itemLinks)..where(
              ($ItemLinksTable l) =>
                  l.kind.equalsValue(LinkKind.warrantyOf) &
                  l.status.equalsValue(LinkStatus.confirmed),
            ))
            .get())
      l.fromCardId,
  };

  Future<void> _setStatus(int linkId, LinkStatus status) =>
      (_db.update(
        _db.itemLinks,
      )..where(($ItemLinksTable l) => l.id.equals(linkId))).write(
        ItemLinksCompanion(
          status: Value<LinkStatus>(status),
          updatedAt: Value<DateTime>(_now()),
        ),
      );

  /// What the rules need to know about one paper.
  Future<PaperFacts> _facts(CardRow card) async {
    final List<CardField> fields = await _fields(card.id);
    String? valueOf(String key) =>
        fields.where((CardField f) => f.fieldKey == key).firstOrNull?.value;

    final CardField? serial = fields
        .where((CardField f) => f.fieldKey == WarrantyKeys.serial)
        .firstOrNull;
    return PaperFacts(
      id: card.id,
      text: <String?>[
        card.rawOcrText,
        card.backOcrText,
      ].whereType<String>().join('\n'),
      serial: serial == null ? null : serial.normalizedValue ?? serial.value,
      invoiceNumber: valueOf(ReceiptKeys.invoiceNumber),
      purchaseDate: _purchaseDate(fields),
      model: valueOf(WarrantyKeys.model),
      brand: valueOf(WarrantyKeys.brand),
      merchant: valueOf(ReceiptKeys.merchant),
    );
  }

  // ---------------------------------------------------------------------------
  // The expiry
  // ---------------------------------------------------------------------------

  /// Works a warranty's expiry out again, and makes the stored calculated
  /// field and the expiry date agree with it.
  Future<void> _settleExpiry(int warrantyId) async {
    final WarrantyExpiry? expiry = await _expiryOf(warrantyId);
    final List<CardField> calculated =
        (await _fields(warrantyId))
            .where(
              (CardField f) =>
                  f.fieldKey == WarrantyKeys.expiryDate &&
                  f.origin == FactOrigin.derived,
            )
            .toList()
          ..sort((CardField a, CardField b) => a.id.compareTo(b.id));

    if (expiry != null && expiry.isCalculated) {
      final LocalDate day = expiry.day;
      final CardField? current = calculated.firstOrNull;
      if (current == null) {
        await _db
            .into(_db.cardFields)
            .insert(
              FieldProvenance.derived.applyTo(
                CardFieldsCompanion.insert(
                  cardId: warrantyId,
                  fieldKey: WarrantyKeys.expiryDate,
                  value: formatDay(day),
                  normalizedValue: Value<String?>(day.toIso()),
                  source: FieldProvenance.derived.source,
                  dateValue: Value<LocalDate?>(day),
                ),
              ),
            );
      } else if (current.dateValue != day) {
        await (_db.update(
          _db.cardFields,
        )..where(($CardFieldsTable f) => f.id.equals(current.id))).write(
          CardFieldsCompanion(
            value: Value<String>(formatDay(day)),
            normalizedValue: Value<String?>(day.toIso()),
            dateValue: Value<LocalDate?>(day),
            updatedAt: Value<DateTime>(_now()),
          ),
        );
      }
      for (final CardField extra in calculated.skip(1)) {
        await _deleteField(extra.id);
      }
    } else {
      for (final CardField f in calculated) {
        await _deleteField(f.id);
      }
    }

    await _settleDate(warrantyId, expiry?.day);
  }

  /// A card that is no longer a warranty has no end.
  Future<void> _clearExpiry(int cardId) async {
    await (_db.delete(_db.cardFields)..where(
          ($CardFieldsTable f) =>
              f.cardId.equals(cardId) &
              f.fieldKey.equals(WarrantyKeys.expiryDate) &
              f.origin.equalsValue(FactOrigin.derived),
        ))
        .go();
    await _settleDate(cardId, null);
  }

  /// One `warrantyExpiry` date per warranty, on its last covered day, with a
  /// reminder set when the day is first known or moves — never re-timed
  /// otherwise, so a reminder already shown is not shown again.
  Future<void> _settleDate(int cardId, LocalDate? lastDay) async {
    final ImportantDate? current = await _expiryDate(cardId);
    if (lastDay == null) {
      if (current != null) {
        await (_db.delete(
          _db.importantDates,
        )..where(($ImportantDatesTable d) => d.id.equals(current.id))).go();
      }
      return;
    }

    final DateTime due = lastDay.toLocalDateTime();
    final int dateId;
    if (current == null) {
      dateId = await _db
          .into(_db.importantDates)
          .insert(
            ImportantDatesCompanion.insert(
              cardId: cardId,
              kind: DateKind.warrantyExpiry,
              title: 'Warranty ends',
              dueOn: due,
            ),
          );
    } else if (current.dueOn != due) {
      dateId = current.id;
      await (_db.update(
        _db.importantDates,
      )..where(($ImportantDatesTable d) => d.id.equals(current.id))).write(
        ImportantDatesCompanion(
          dueOn: Value<DateTime>(due),
          updatedAt: Value<DateTime>(_now()),
        ),
      );
      await (_db.update(_db.reminders)..where(
            ($RemindersTable r) =>
                r.importantDateId.equals(current.id) &
                r.status.equalsValue(ReminderStatus.scheduled),
          ))
          .write(
            RemindersCompanion(
              status: const Value<ReminderStatus>(ReminderStatus.cancelled),
              updatedAt: Value<DateTime>(_now()),
            ),
          );
    } else {
      return;
    }

    final DateTime? at = expiryReminderTime(lastDay, _now());
    if (at != null) {
      await _db
          .into(_db.reminders)
          .insert(
            RemindersCompanion.insert(importantDateId: dateId, remindAt: at),
          );
    }
  }

  Future<ImportantDate?> _expiryDate(int cardId) =>
      (_db.select(_db.importantDates)
            ..where(
              ($ImportantDatesTable d) =>
                  d.cardId.equals(cardId) &
                  d.kind.equalsValue(DateKind.warrantyExpiry) &
                  d.deletedAt.isNull(),
            )
            ..orderBy(<OrderClauseGenerator<$ImportantDatesTable>>[
              ($ImportantDatesTable d) => OrderingTerm.asc(d.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// The expiry as the facts now stand. A calculated one is an output and
  /// never read back in; a stated one that could not be read as a day stops
  /// the calculation, because that field already needs a look and a second,
  /// different expiry beside it would be worse.
  Future<WarrantyExpiry?> _expiryOf(int warrantyId) async {
    final CardRow? card = await _card(warrantyId);
    if (card == null || !kWarrantyTypes.contains(card.type)) return null;
    final List<CardField> fields = await _fields(warrantyId);

    final List<CardField> stated = fields
        .where(
          (CardField f) =>
              f.fieldKey == WarrantyKeys.expiryDate &&
              f.origin != FactOrigin.derived,
        )
        .toList();
    final CardField? readable = stated
        .where((CardField f) => f.dateValue != null)
        .firstOrNull;
    if (stated.isNotEmpty && readable == null) return null;

    final CardField? cover = fields
        .where((CardField f) => f.fieldKey == WarrantyKeys.coverMonths)
        .firstOrNull;
    final CardField? basis = fields
        .where((CardField f) => f.fieldKey == WarrantyKeys.startBasis)
        .firstOrNull;

    return warrantyExpiry(
      stated: readable?.dateValue,
      statedOrigin: readable?.origin,
      statedConfirmed: readable != null && isConfirmed(readable),
      coverMonths: cover == null
          ? null
          : int.tryParse(cover.normalizedValue ?? ''),
      ownPurchaseDate: _purchaseDate(fields),
      receiptPurchaseDate: await _confirmedReceiptDate(warrantyId),
      startBasis: basis == null ? null : basis.normalizedValue ?? basis.value,
    );
  }

  /// The earliest purchase date among the receipts the user has confirmed
  /// for [warrantyId] — the earliest, because a reminder that errs should
  /// err early. Receipts in the bin lend nothing.
  Future<LocalDate?> _confirmedReceiptDate(int warrantyId) async {
    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT l.to_card_id AS id FROM item_links l '
          'JOIN cards c ON c.id = l.to_card_id '
          "WHERE l.from_card_id = ? AND l.status = 'confirmed' "
          'AND l.deleted_at IS NULL AND c.deleted_at IS NULL '
          'AND c.type IN (${kReceiptTypes.map((CardType t) => "'${t.name}'").join(', ')})',
          variables: <Variable<Object>>[Variable<int>(warrantyId)],
        )
        .get();
    LocalDate? earliest;
    for (final QueryRow r in rows) {
      final LocalDate? d = _purchaseDate(await _fields(r.read<int>('id')));
      if (d != null && (earliest == null || d.isBefore(earliest))) {
        earliest = d;
      }
    }
    return earliest;
  }

  static LocalDate? _purchaseDate(List<CardField> fields) => fields
      .where(
        (CardField f) =>
            f.fieldKey == ReceiptKeys.purchaseDate &&
            f.origin != FactOrigin.derived &&
            f.dateValue != null,
      )
      .firstOrNull
      ?.dateValue;

  // ---------------------------------------------------------------------------

  static bool _isPurchase(CardType t) =>
      kReceiptTypes.contains(t) || kWarrantyTypes.contains(t);

  Future<CardRow?> _card(int id) => (_db.select(
    _db.cards,
  )..where(($CardsTable c) => c.id.equals(id))).getSingleOrNull();

  Future<List<CardField>> _fields(int cardId) =>
      (_db.select(_db.cardFields)
            ..where(($CardFieldsTable f) => f.cardId.equals(cardId))
            ..orderBy(<OrderClauseGenerator<$CardFieldsTable>>[
              ($CardFieldsTable f) => OrderingTerm.asc(f.id),
            ]))
          .get();

  Future<ItemLink?> _link(int id) => (_db.select(
    _db.itemLinks,
  )..where(($ItemLinksTable l) => l.id.equals(id))).getSingleOrNull();

  Future<List<ItemLink>> _links(int cardId) =>
      (_db.select(_db.itemLinks)..where(
            ($ItemLinksTable l) =>
                (l.fromCardId.equals(cardId) | l.toCardId.equals(cardId)) &
                l.kind.equalsValue(LinkKind.warrantyOf) &
                l.deletedAt.isNull(),
          ))
          .get();

  Future<void> _deleteField(int id) => (_db.delete(
    _db.cardFields,
  )..where(($CardFieldsTable f) => f.id.equals(id))).go();

  static String _encode(List<LinkReason> reasons) => jsonEncode(
    <Map<String, String>>[for (final LinkReason r in reasons) r.toJson()],
  );

  static List<LinkReason> _decode(String json) {
    try {
      final Object? list = jsonDecode(json);
      if (list is! List) return const <LinkReason>[];
      return list.map(LinkReason.fromJson).whereType<LinkReason>().toList();
    } on FormatException {
      return const <LinkReason>[];
    }
  }
}
