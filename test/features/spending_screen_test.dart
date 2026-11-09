import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/db/field_provenance.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/domain/money.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/receipt_extractor.dart' show formatDay;
import 'package:recallos/core/spending/spending_totals.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/features/spending/data/spending_share.dart';
import 'package:recallos/features/spending/presentation/spending_screen.dart';
import 'package:recallos/router.dart';

import '../support/fake_store.dart';
import '../support/play_fixtures.dart';

/// B4's screen, tapped the way a person taps it. Each test ends on what the
/// tap did — to the figure, to the wallet, or to where it led — because a
/// total that renders and a button that does nothing would pass an
/// assertion about what is drawn.
void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 10, 15, 10);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> addField(
    int cardId,
    String key,
    String value,
    FieldProvenance as, {
    Money? money,
    LocalDate? day,
  }) => db
      .into(db.cardFields)
      .insert(
        as.applyTo(
          CardFieldsCompanion.insert(
            cardId: cardId,
            fieldKey: key,
            value: value,
            source: as.source,
            amountMinor: Value<int?>(money?.minor),
            currency: Value<String?>(money?.currency),
            dateValue: Value<LocalDate?>(day),
          ),
        ),
      );

  /// A receipt as B2 stores it, its total and date checked unless told not.
  Future<int> receipt({
    String? shop = 'Shwapno',
    int? minor = 43260,
    String currency = 'BDT',
    LocalDate? date,
    bool totalChecked = true,
    bool dateChecked = true,
    String? category,
  }) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/r.jpg',
            capturedAt: now.subtract(const Duration(days: 1)),
            type: const Value<CardType>(CardType.receipt),
          ),
        );
    if (shop != null) {
      await addField(id, ReceiptKeys.merchant, shop, FieldProvenance.printed);
    }
    if (minor != null) {
      final Money m = Money(minor, currency);
      await addField(
        id,
        ReceiptKeys.total,
        m.format(),
        totalChecked ? FieldProvenance.userConfirmed : FieldProvenance.printed,
        money: m,
      );
    }
    final LocalDate day = date ?? LocalDate(2026, 10, 12);
    await addField(
      id,
      ReceiptKeys.purchaseDate,
      formatDay(day),
      dateChecked ? FieldProvenance.userConfirmed : FieldProvenance.printed,
      day: day,
    );
    if (category != null) {
      await addField(
        id,
        ReceiptKeys.category,
        category,
        FieldProvenance.inferred,
      );
    }
    return id;
  }

  /// No date at all.
  Future<int> undated(String shop) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/r.jpg',
            capturedAt: now,
            type: const Value<CardType>(CardType.receipt),
          ),
        );
    await addField(id, ReceiptKeys.merchant, shop, FieldProvenance.printed);
    const Money m = Money(4000, 'BDT');
    await addField(
      id,
      ReceiptKeys.total,
      m.format(),
      FieldProvenance.userConfirmed,
      money: m,
    );
    return id;
  }

  Future<void> pump(
    WidgetTester tester, {
    bool plus = false,
    double textScale = 1,
    SpendingShare? sharer,
  }) async {
    // Tall, so every section is built at once.
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final MemoryGrants grants = MemoryGrants();
    if (plus) {
      grants.kept = (originalJson: plusReceipt, signature: plusSignature);
    }
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => SpendingScreen(now: () => now),
        ),
        GoRoute(
          path: Routes.capture,
          builder: (_, _) => const Scaffold(body: Text('capture page')),
        ),
        GoRoute(
          path: Routes.plus,
          builder: (_, _) => const Scaffold(body: Text('plus page')),
        ),
        GoRoute(
          path: '/card/:id',
          builder: (_, GoRouterState s) =>
              Scaffold(body: Text('card ${s.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          storePortProvider.overrideWithValue(FakeStore()),
          grantStoreProvider.overrideWithValue(grants),
          playKeyProvider.overrideWithValue(testPlayKey),
          if (sharer != null) spendingShareProvider.overrideWithValue(sharer),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drift closes a watched query on a zero-length timer; letting it run
  /// before the test ends keeps the binding's pending-timer check quiet.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty wallet says so, and its action opens the scanner', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    expect(find.text('No receipts saved yet'), findsOneWidget);
    await tap(tester, find.text('Scan a receipt'));
    expect(find.text('capture page'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('free: this month\'s figure with its scope, and everything not '
      'added listed with what to do', (WidgetTester tester) async {
    await receipt();
    final int agora = await receipt(
      shop: 'Agora',
      minor: 100000,
      totalChecked: false,
      dateChecked: false,
    );
    await receipt(shop: 'September shop', date: LocalDate(2026, 9, 30));
    await undated('Rahim Tea Stall');
    await pump(tester);

    expect(find.text('THIS MONTH · OCTOBER 2026'), findsOneWidget);
    // The figure and its one counted row.
    expect(find.text('BDT 432.60'), findsNWidgets(2));
    expect(find.text('in saved receipts'), findsOneWidget);
    expect(find.text('1–31 Oct 2026 · 1 receipt you checked'), findsOneWidget);
    expect(find.text('September shop'), findsNothing);

    expect(find.text('NOT ADDED YET'), findsOneWidget);
    expect(find.text('Check the total and the date'), findsOneWidget);
    expect(find.text('NO DATE'), findsOneWidget);
    expect(find.text('Add the date'), findsOneWidget);

    // Without Plus there is no arrow to another month — and no dead one.
    expect(find.bySemanticsLabel('Month before'), findsNothing);
    expect(find.text('BY SHOP'), findsNothing);

    await tap(tester, find.text('Agora'));
    expect(find.text('card $agora'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('free: the row about Plus opens Plus', (
    WidgetTester tester,
  ) async {
    await receipt();
    await pump(tester);
    await tap(tester, find.text('Other months, shops and categories'));
    expect(find.text('plus page'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('nothing counted this month says so, and what is waiting', (
    WidgetTester tester,
  ) async {
    await receipt(totalChecked: false);
    await pump(tester);
    expect(find.text('Nothing counted this month'), findsOneWidget);
    expect(find.textContaining('One is waiting below.'), findsOneWidget);
    expect(find.text('Check the total'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a possible second copy: No, count both adds it; Undo asks '
      'again', (WidgetTester tester) async {
    await receipt();
    await receipt();
    await pump(tester);

    expect(find.text('Is this a second copy?'), findsOneWidget);
    expect(find.text('Same total, BDT 432.60'), findsOneWidget);
    expect(find.text('Same shop, Shwapno'), findsOneWidget);
    expect(find.text('BDT 432.60'), findsNWidgets(2));

    await tap(tester, find.text('No, count both'));
    expect(find.text('Is this a second copy?'), findsNothing);
    expect(find.text('BDT 865.20'), findsOneWidget);
    final ItemLink answer = await db.select(db.itemLinks).getSingle();
    expect(answer.kind, LinkKind.duplicateOf);
    expect(answer.status, LinkStatus.dismissed);

    await tap(tester, find.text('Undo'));
    expect(find.text('Is this a second copy?'), findsOneWidget);
    expect(find.text('BDT 865.20'), findsNothing);
    expect(await db.select(db.itemLinks).get(), isEmpty);
    await unmount(tester);
  });

  testWidgets('Yes, bin this copy moves it to the bin; Undo brings it back', (
    WidgetTester tester,
  ) async {
    await receipt();
    final int copy = await receipt();
    await pump(tester);

    await tap(tester, find.text('Yes, bin this copy'));
    expect(find.text('Is this a second copy?'), findsNothing);
    Future<DateTime?> binned() async => (await (db.select(
      db.cards,
    )..where(($CardsTable c) => c.id.equals(copy))).getSingle()).deletedAt;
    expect(await binned(), isNotNull);
    expect(find.text('BDT 432.60'), findsNWidgets(2));

    await tap(tester, find.text('Undo'));
    expect(await binned(), isNull);
    expect(find.text('Is this a second copy?'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('two currencies are never added; a chip chooses which is '
      'summed', (WidgetTester tester) async {
    await receipt();
    await receipt(shop: 'Amazon', minor: 1200, currency: 'USD');
    await pump(tester);

    expect(find.text('BDT 432.60'), findsNWidgets(2));
    expect(find.text('USD 12.00'), findsNothing);
    await tap(tester, find.text('USD'));
    expect(find.text('USD 12.00'), findsNWidgets(2));
    expect(find.text('BDT 432.60'), findsNothing);
    await unmount(tester);
  });

  testWidgets('with Plus: the month before, a year by month, and a shop that '
      'narrows the figure', (WidgetTester tester) async {
    await receipt(category: 'Groceries');
    await receipt(shop: 'Star Tech', minor: 7850000, category: 'Electronics');
    await receipt(
      shop: 'Star Tech',
      minor: 150000,
      date: LocalDate(2026, 9, 3),
      category: 'Electronics',
    );
    await pump(tester, plus: true);

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Other months, shops and categories'), findsNothing);
    // Nothing can have been bought next month yet.
    expect(find.bySemanticsLabel('Month after'), findsNothing);
    expect(find.text('BDT 78,932.60'), findsOneWidget);

    await tap(tester, find.bySemanticsLabel('Month before'));
    expect(find.text('September 2026'), findsOneWidget);
    // The figure, its shop, its category and its row.
    expect(find.text('BDT 1,500.00'), findsNWidgets(4));
    expect(find.text('1 receipt · category guessed'), findsWidgets);
    expect(find.text('1–30 Sep 2026 · 1 receipt you checked'), findsOneWidget);

    await tap(tester, find.text('Year'));
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('BDT 80,432.60'), findsOneWidget);
    expect(find.text('BY MONTH'), findsOneWidget);
    expect(find.text('BY SHOP'), findsOneWidget);
    expect(find.text('BY CATEGORY'), findsOneWidget);

    await tap(tester, find.text('Star Tech').first);
    expect(find.text('BDT 80,000.00'), findsOneWidget);
    expect(find.text('in saved receipts from Star Tech'), findsOneWidget);
    expect(find.text('BY SHOP'), findsNothing);

    await tap(tester, find.text('Show every shop'));
    expect(find.text('BDT 80,432.60'), findsOneWidget);

    await tap(tester, find.text('October'));
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('BDT 78,932.60'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('at 1.3× a long shop name beside its amount is never broken '
      'mid-word', (WidgetTester tester) async {
    await receipt(shop: 'STAR TECH & ENGINEERING LTD', minor: 7850000);
    await pump(tester, plus: true, textScale: 1.3);

    // Every row that names the shop — by shop, and counted — gives the name
    // a column at least as wide as its longest word. Measured with the
    // row's own style and scale, so it holds whatever the font.
    final Finder names = find.text('STAR TECH & ENGINEERING LTD');
    expect(names, findsNWidgets(2));
    for (final Element e in names.evaluate()) {
      final RenderParagraph p = e.renderObject! as RenderParagraph;
      final TextPainter word = TextPainter(
        text: TextSpan(text: 'ENGINEERING', style: p.text.style),
        textDirection: TextDirection.ltr,
        textScaler: p.textScaler,
      )..layout();
      expect(p.constraints.maxWidth, greaterThanOrEqualTo(word.width));
      word.dispose();
    }
    await unmount(tester);
  });

  // B4's export: the month on screen, asked about first.
  group('Share this total', () {
    testWidgets('asks first, and Cancel shares nothing', (
      WidgetTester tester,
    ) async {
      final FakeSharer sharer = FakeSharer();
      await tester.runAsync(() async {
        await receipt();
        await receipt(shop: 'Agora', minor: 999, totalChecked: false);
      });
      await pump(tester, sharer: sharer);

      await tester.tap(find.bySemanticsLabel('Share this total'));
      await tester.pumpAndSettle();
      expect(find.text('Share this total?'), findsOneWidget);
      expect(
        find.textContaining('October 2026: BDT 432.60 in saved receipts'),
        findsOneWidget,
      );
      expect(find.textContaining('the 1 held back'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(sharer.shared, isEmpty);
      await unmount(tester);
    });

    testWidgets('Share hands over what the screen shows', (
      WidgetTester tester,
    ) async {
      final FakeSharer sharer = FakeSharer();
      await tester.runAsync(() async {
        await receipt();
        await receipt(shop: 'Agora', minor: 999, totalChecked: false);
      });
      await pump(tester, sharer: sharer);

      await tester.tap(find.bySemanticsLabel('Share this total'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      final SpendingSummary s = sharer.shared.single;
      expect(s.period, const SpendingPeriod.month(2026, 10));
      expect(s.total, const Money(43260, 'BDT'));
      expect(s.counted, hasLength(1));
      expect(s.notAdded, hasLength(1));
      expect(find.text('Handed to the app you chose.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a failed share says so', (WidgetTester tester) async {
      final FakeSharer sharer = FakeSharer(ok: false);
      await tester.runAsync(() async => receipt());
      await pump(tester, sharer: sharer);

      await tester.tap(find.bySemanticsLabel('Share this total'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(
        find.text('That did not work. Nothing was shared.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('an empty wallet has nothing to share', (
      WidgetTester tester,
    ) async {
      await pump(tester, sharer: FakeSharer());
      expect(find.bySemanticsLabel('Share this total'), findsNothing);
      await unmount(tester);
    });
  });
}

class FakeSharer extends SpendingShare {
  FakeSharer({this.ok = true});

  final bool ok;
  final List<SpendingSummary> shared = <SpendingSummary>[];

  @override
  Future<bool> share(SpendingSummary s) async {
    shared.add(s);
    return ok;
  }
}
