import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/linking/warranty_expiry.dart';
import '../../../core/search/fts_query.dart' show textWords;
import '../../../core/search/query_plan.dart';
import '../../../core/spending/spending_totals.dart';
import '../../spending/data/spending_repository.dart';
import '../../warranty/data/purchase_links.dart';

/// A warranty an answer names: its end and how that is known, and the
/// receipt it was bought with when the user linked one — so "when does my
/// laptop warranty expire?" cites both papers (PLAN §3).
class WarrantyAnswer {
  const WarrantyAnswer({
    required this.card,
    required this.fields,
    this.expiry,
    this.receipt,
  });

  final CardRow card;
  final List<CardField> fields;

  /// Null when the end is not known yet, which the answer says.
  final ExpiryView? expiry;

  /// The confirmed receipt, if any.
  final PurchaseLink? receipt;
}

/// One warranty in an "ends in the next 90 days" list.
class ExpiringAnswer {
  const ExpiringAnswer({required this.card, required this.fields, this.expiry});

  final CardRow card;
  final List<CardField> fields;

  /// Null only in "every warranty", for one whose end is not known.
  final WarrantyExpiry? expiry;
}

/// A total of saved receipts, or why there is none.
class SpendingAnswer {
  const SpendingAnswer({this.summary, this.focusLabel, this.cannot});

  /// The totals for the period, narrowed to the focus. Null with [cannot].
  final SpendingSummary? summary;

  /// The shop or category the total is for, as saved: "Electronics".
  final String? focusLabel;

  /// Said instead of a figure: a week, a month still to come, a shop with
  /// no receipts.
  final String? cannot;
}

/// Carries out B5's purchase plans over what B3 and B4 already keep: the
/// warranty links and calculated expiry, and the receipt totals. Nothing
/// here writes, and nothing is worked out a second way — an answer is the
/// same figure the card screen and the Receipt totals screen show.
class PurchaseAnswers {
  PurchaseAnswers(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _links = PurchaseLinks(_db, now: now),
      _receipts = SpendingRepository(_db, now: now);

  final AppDatabase _db;
  final DateTime Function() _now;
  final PurchaseLinks _links;
  final SpendingRepository _receipts;

  // ---------------------------------------------------------------------------
  // One warranty
  // ---------------------------------------------------------------------------

  /// The warranties for [subject]: every word of it found on the warranty
  /// (its title, product, brand, model, serial or note), allowing the usual
  /// other names ("fridge" finds "Refrigerator"). Every match is listed —
  /// two laptops are two warranties, and picking one would be a guess.
  Future<List<WarrantyAnswer>> warranties(String subject) async {
    final List<String> want = textWords(subject);
    if (want.isEmpty) return const <WarrantyAnswer>[];

    final List<WarrantyAnswer> out = <WarrantyAnswer>[];
    for (final CardRow card in await _liveWarranties()) {
      final List<CardField> fields = await _fields(card.id);
      final Set<String> words = <String>{
        ...textWords(card.title ?? ''),
        for (final CardField f in fields)
          if (_describing.contains(f.fieldKey)) ...textWords(f.value),
        ...textWords(await _note(card.id)),
      };
      if (!want.every((String w) => _found(w, words))) continue;

      final List<PurchaseLink> links = await _links.watchLinks(card.id).first;
      out.add(
        WarrantyAnswer(
          card: card,
          fields: fields,
          expiry: await _links.expiry(card.id),
          receipt: links.where((PurchaseLink l) => l.isConfirmed).firstOrNull,
        ),
      );
    }
    return out;
  }

  static const Set<String> _describing = <String>{
    WarrantyKeys.product,
    WarrantyKeys.brand,
    WarrantyKeys.model,
    WarrantyKeys.serial,
  };

  /// Other names for the same thing, both ways round.
  static const List<Set<String>> _sameThing = <Set<String>>[
    <String>{'fridge', 'refrigerator', 'freezer'},
    <String>{'ac', 'aircon', 'airconditioner', 'conditioner'},
    <String>{'phone', 'mobile', 'smartphone', 'handset'},
    <String>{'tv', 'television', 'led'},
    <String>{'laptop', 'notebook'},
    <String>{'oven', 'microwave'},
    <String>{'washer', 'washing'},
  ];

  static bool _found(String want, Set<String> words) {
    bool has(String w) =>
        words.any((String x) => x == w || (w.length >= 3 && x.startsWith(w)));
    if (has(want)) return true;
    for (final Set<String> same in _sameThing) {
      if (same.contains(want) && same.any(has)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // What ends when
  // ---------------------------------------------------------------------------

  /// The warranties that end in [plan]'s window — soonest first, or most
  /// recently over first for ones already ended. "Every warranty" lists
  /// them all, those with no known end last, said so.
  Future<List<ExpiringAnswer>> expiring(ExpiringPlan plan) async {
    final List<ExpiringAnswer> out = <ExpiringAnswer>[];
    for (final CardRow card in await _liveWarranties()) {
      final ExpiryView? view = await _links.expiry(card.id);
      final LocalDate? day = view?.expiry.day;
      final bool inWindow;
      if (plan.from == null && plan.until == null) {
        inWindow = true;
      } else if (day == null) {
        inWindow = false;
      } else {
        final LocalDate? from = plan.from;
        final LocalDate? until = plan.until;
        inWindow =
            (from == null || !day.isBefore(from)) &&
            (until == null || !day.isAfter(until));
      }
      if (!inWindow) continue;
      out.add(
        ExpiringAnswer(
          card: card,
          fields: await _fields(card.id),
          expiry: view?.expiry,
        ),
      );
    }
    out.sort((ExpiringAnswer a, ExpiringAnswer b) {
      final LocalDate? x = a.expiry?.day;
      final LocalDate? y = b.expiry?.day;
      if (x == null || y == null) {
        return x == null ? (y == null ? 0 : 1) : -1;
      }
      return plan.ended ? y.compareTo(x) : x.compareTo(y);
    });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  /// The total [plan] asks for, as B4 works it out: checked receipts only,
  /// one currency at a time, the rest listed apart. Says why instead when
  /// the question cannot be answered.
  Future<SpendingAnswer> spending(SpendingPlan plan) async {
    final String? unsupported = plan.unsupported;
    if (unsupported != null) {
      return SpendingAnswer(
        cannot:
            'Receipt totals go by month or year, so there is no total for '
            '“$unsupported”. Try “this month”.',
      );
    }
    if (plan.period.isFuture(_now())) {
      return SpendingAnswer(
        cannot:
            'Nothing can have been bought in ${plan.period.label} yet, so '
            'there is no total for it.',
      );
    }

    final List<ReceiptFacts> receipts = await _receipts.receipts();
    SpendingFocus? focus;
    String? label;
    final String? asked = plan.focus;
    if (asked != null) {
      final ({SpendingFocus focus, String label})? found = _focusFor(
        asked,
        receipts,
        shopOnly: plan.shopOnly,
      );
      if (found == null) {
        return SpendingAnswer(
          cannot:
              'No saved receipt is from a ${plan.shopOnly ? 'shop' : 'shop or category'} '
              'called “$asked”, so there is no total for it.',
        );
      }
      focus = found.focus;
      label = found.label;
    }
    return SpendingAnswer(
      summary: SpendingSummary.of(receipts, period: plan.period, focus: focus),
      focusLabel: label,
    );
  }

  /// What a category is also called.
  static const Map<String, Set<String>> _categoryNames = <String, Set<String>>{
    'electronics': <String>{'electronic', 'gadget', 'gadgets', 'tech'},
    'groceries': <String>{'grocery', 'bazar', 'bazaar', 'supershop'},
    'food and drink': <String>{
      'food',
      'foods',
      'restaurant',
      'restaurants',
      'eating',
      'drinks',
      'coffee',
      'khabar',
    },
    'health': <String>{'medicine', 'medicines', 'medical', 'pharmacy'},
    'clothing': <String>{'clothes', 'fashion', 'shoes', 'dress'},
    'transport': <String>{'travel', 'fuel', 'petrol', 'rides', 'ride'},
    'home': <String>{'furniture', 'household', 'hardware'},
  };

  /// A category first (unless it was said with "at"), then a shop whose
  /// name holds every word asked.
  static ({SpendingFocus focus, String label})? _focusFor(
    String asked,
    List<ReceiptFacts> receipts, {
    required bool shopOnly,
  }) {
    final String key = categoryKey(asked);
    if (!shopOnly) {
      for (final ReceiptFacts r in receipts) {
        final String? category = r.category;
        if (category == null) continue;
        final String c = categoryKey(category);
        final bool same =
            c == key ||
            c == '${key}s' ||
            '${c}s' == key ||
            (_categoryNames[c]?.contains(key) ?? false);
        if (same) {
          return (focus: SpendingFocus.category(c, category), label: category);
        }
      }
    }
    final List<String> want = textWords(asked);
    for (final ReceiptFacts r in receipts) {
      final String? shop = r.shop;
      if (shop == null) continue;
      final List<String> words = textWords(shopKey(shop));
      if (want.every(
        (String w) => words.any((String x) => x == w || x.startsWith(w)),
      )) {
        return (focus: SpendingFocus.shop(shopKey(shop), shop), label: shop);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------

  Future<List<CardRow>> _liveWarranties() =>
      (_db.select(_db.cards)
            ..where(
              ($CardsTable c) =>
                  c.deletedAt.isNull() &
                  c.type.isIn(kWarrantyTypes.map((CardType t) => t.name)),
            )
            ..orderBy(<OrderClauseGenerator<$CardsTable>>[
              ($CardsTable c) => OrderingTerm.desc(c.capturedAt),
            ]))
          .get();

  Future<List<CardField>> _fields(int cardId) => (_db.select(
    _db.cardFields,
  )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();

  Future<String> _note(int cardId) async =>
      (await (_db.select(_db.notes)..where(
                ($NotesTable n) =>
                    n.subjectType.equals('card') & n.subjectId.equals(cardId),
              ))
              .get())
          .map((Note n) => n.body ?? '')
          .join(' ');
}
