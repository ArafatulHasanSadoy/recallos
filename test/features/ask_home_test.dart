import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/search/presentation/home_screen.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';
import 'package:recallos/router.dart';

import '../support/fake_store.dart';
import '../support/ocr_layout.dart';
import '../support/play_fixtures.dart';

/// Ask RecallOS on home (B5), typed and tapped the way a person does: the
/// answer in the slot "Rahim's number" uses, every paper it came from
/// opening, the line to Plus where the question needs it, and a plain
/// sentence where it cannot be answered.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late SearchRepository search;
  late PurchaseLinks links;
  final DateTime now = DateTime(2026, 10, 15, 10);

  StaticEmbedder? shared;
  Future<StaticEmbedder> loadEmbedder() async =>
      shared ??= StaticEmbedder.fromBytes(
        matrixBytes: File('assets/embedding/matrix.bin').readAsBytesSync(),
        tokenizer: WordPieceTokenizer.fromAssets(
          vocabText: File('assets/embedding/vocab.txt').readAsStringSync(),
          normalizerJson: File(
            'assets/embedding/normalizer.json',
          ).readAsStringSync(),
        ),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    links = PurchaseLinks(db, now: () => now);
    cards = CardRepository(db, purchases: links);
    search = SearchRepository(db, loadEmbedder, now: () => now);
  });
  tearDown(() async => db.close());

  Future<int> store(List<OcrBlock> blocks, CardType type) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/p.jpg',
            capturedAt: now,
          ),
        );
    final DocumentReading reading = readDocument(blocks, as: type);
    await cards.attachExtraction(
      cardId: id,
      result: OcrResult(
        blocks: blocks,
        engine: 'test',
        duration: const Duration(milliseconds: 5),
      ),
      extraction: reading.extraction,
    );
    await cards.setKind(id, type, title: reading.title);
    await search.reindexCard(id);
    return id;
  }

  Future<void> check(int receipt) async {
    for (final String key in <String>[
      ReceiptKeys.total,
      ReceiptKeys.purchaseDate,
    ]) {
      final CardField f =
          await (db.select(db.cardFields)..where(
                ($CardFieldsTable t) =>
                    t.cardId.equals(receipt) & t.fieldKey.equals(key),
              ))
              .getSingle();
      await cards.updateField(fieldId: f.id, value: f.value);
    }
  }

  late int laptop;
  late int iron;

  /// A laptop receipt and its warranty (linked), an iron's warranty ending
  /// next month, and a grocery receipt — all checked.
  Future<void> seed({bool uncheckedExtra = false}) async {
    laptop = await store(
      paper(<Object>[
        'STAR TECH & ENGINEERING LTD',
        'Invoice No: ST-2026-0412',
        'Date: 12/10/2026',
        ('HP 15s-fq5111TU Laptop', '78,500.00'),
        'S/N: 5CD3281XYZ',
        ('Grand Total', '78,500.00'),
      ]),
      CardType.receipt,
    );
    await store(
      paper(<Object>[
        'HP',
        'WARRANTY CARD',
        'Product: Laptop',
        'Model: 15s-fq5111TU',
        'Serial No: 5CD3281XYZ',
        'Warranty Period: 2 Years from the date of purchase',
      ]),
      CardType.warrantyCard,
    );
    await links.confirm((await db.select(db.itemLinks).getSingle()).id);
    iron = await store(
      paper(<Object>[
        'SINGER',
        'WARRANTY CARD',
        'Product: Iron',
        'Valid till: 30/11/2026',
      ]),
      CardType.warrantyCard,
    );
    final int rice = await store(
      paper(<Object>[
        'SHWAPNO',
        'Banani, Dhaka',
        'Date: 13/10/2026',
        ('Rice 5kg', '432.60'),
        ('Grand Total', '432.60'),
      ]),
      CardType.receipt,
    );
    await check(laptop);
    await check(rice);
    if (uncheckedExtra) {
      await store(
        paper(<Object>[
          'AARONG',
          'Gulshan, Dhaka',
          'Date: 14/10/2026',
          ('Panjabi', '3,200.00'),
          ('Grand Total', '3,200.00'),
        ]),
        CardType.receipt,
      );
    }
  }

  Future<List<String>> pumpHome(
    WidgetTester tester, {
    bool plus = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final MemoryGrants grants = MemoryGrants();
    if (plus) {
      grants.kept = (originalJson: plusReceipt, signature: plusSignature);
    }
    final List<String> pushed = <String>[];
    Widget page(String name) => Scaffold(body: Text(name));
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: Routes.plus,
          builder: (_, _) {
            pushed.add(Routes.plus);
            return page('plus screen');
          },
        ),
        GoRoute(
          path: Routes.receiptTotals,
          builder: (_, _) {
            pushed.add(Routes.receiptTotals);
            return page('receipt totals');
          },
        ),
        GoRoute(
          path: '/card/:id',
          builder: (_, GoRouterState s) {
            pushed.add('/card/${s.pathParameters['id']}');
            return page('card');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          searchRepositoryProvider.overrideWithValue(search),
          storePortProvider.overrideWithValue(FakeStore()),
          grantStoreProvider.overrideWithValue(grants),
          playKeyProvider.overrideWithValue(testPlayKey),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return pushed;
  }

  Future<void> ask(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField), q);
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('"When does my laptop warranty expire?" — free, both papers '
      'cited, each one opens', (WidgetTester tester) async {
    await tester.runAsync(seed);
    final List<String> pushed = await pumpHome(tester);

    await ask(tester, 'When does my laptop warranty expire?');

    expect(find.text('LAPTOP WARRANTY'), findsOneWidget);
    expect(find.text('11 Oct 2028'), findsOneWidget);
    expect(
      find.textContaining("Calculated from the receipt's purchase date"),
      findsOneWidget,
    );
    // Both papers, as rows: the warranty and the receipt it was bought with.
    expect(find.text('HP Laptop'), findsOneWidget);
    expect(find.text('STAR TECH & ENGINEERING LTD'), findsOneWidget);
    expect(find.textContaining('comes with RecallOS Plus'), findsNothing);

    await tap(tester, find.text('STAR TECH & ENGINEERING LTD'));
    expect(pushed, <String>['/card/$laptop']);
    await unmount(tester);
  });

  testWidgets('no such warranty: a sentence, not an empty screen', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(seed);
    await pumpHome(tester);
    await ask(tester, 'when does my car warranty end');
    expect(find.text('No saved warranty matches “car”.'), findsOneWidget);
    expect(find.text('Nothing matched that'), findsNothing);
    await unmount(tester);
  });

  testWidgets('"What expires in the next 90 days?" with Plus: the iron, '
      'and it opens', (WidgetTester tester) async {
    await tester.runAsync(seed);
    final List<String> pushed = await pumpHome(tester, plus: true);

    await ask(tester, 'What expires in the next 90 days?');

    expect(find.text('ENDS IN THE NEXT 90 DAYS'), findsOneWidget);
    expect(find.text('SINGER Iron'), findsOneWidget);
    expect(find.text('30 Nov 2026 · printed'), findsOneWidget);
    expect(find.text('HP Laptop'), findsNothing, reason: 'ends in 2028');

    await tap(tester, find.text('SINGER Iron'));
    expect(pushed, <String>['/card/$iron']);
    await unmount(tester);
  });

  testWidgets('a date question without Plus: the line opens Plus', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(seed);
    final List<String> pushed = await pumpHome(tester);
    await ask(tester, 'What expires in the next 90 days?');

    await tap(
      tester,
      find.text('Questions about dates come with RecallOS Plus'),
    );
    expect(pushed, <String>[Routes.plus]);
    await unmount(tester);
  });

  testWidgets('"How much did I spend on electronics this month?" with Plus: '
      'the figure, its scope, its receipt', (WidgetTester tester) async {
    await tester.runAsync(seed);
    final List<String> pushed = await pumpHome(tester, plus: true);

    await ask(tester, 'How much did I spend on electronics this month?');

    expect(find.text('ELECTRONICS · IN SAVED RECEIPTS'), findsOneWidget);
    expect(find.text('BDT 78,500.00'), findsWidgets);
    expect(find.text('in saved receipts'), findsOneWidget);
    expect(find.text('1–31 Oct 2026 · 1 receipt you checked'), findsOneWidget);
    expect(find.textContaining('spent'), findsNothing, reason: 'PLAN §5');

    await tap(tester, find.text('STAR TECH & ENGINEERING LTD'));
    expect(pushed, <String>['/card/$laptop']);
    await unmount(tester);
  });

  testWidgets('free: this month in full, and what was not added opens '
      'Receipt totals', (WidgetTester tester) async {
    await tester.runAsync(() => seed(uncheckedExtra: true));
    final List<String> pushed = await pumpHome(tester);

    await ask(tester, 'how much did I spend this month');

    expect(find.text('BDT 78,932.60'), findsOneWidget);
    expect(find.text('1–31 Oct 2026 · 2 receipts you checked'), findsOneWidget);
    await tap(tester, find.text('1 not added yet · see Receipt totals'));
    expect(pushed, <String>[Routes.receiptTotals]);
    await unmount(tester);
  });

  testWidgets('free: a category comes with Plus', (WidgetTester tester) async {
    await tester.runAsync(seed);
    final List<String> pushed = await pumpHome(tester);
    await ask(tester, 'how much did I spend on electronics');
    await tap(
      tester,
      find.text(
        'Totals by category, shop and other months come with RecallOS Plus',
      ),
    );
    expect(pushed, <String>[Routes.plus]);
    await unmount(tester);
  });

  testWidgets('a week cannot be totalled, and says why', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(seed);
    await pumpHome(tester, plus: true);
    await ask(tester, 'how much did I spend this week');
    expect(
      find.textContaining('Receipt totals go by month or year'),
      findsOneWidget,
    );
    await unmount(tester);
  });
}
