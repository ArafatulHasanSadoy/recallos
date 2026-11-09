import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/capture/data/paper_import.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';
import 'package:recallos/features/cards/presentation/widgets/card_sides_view.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/search/presentation/home_screen.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';
import 'package:recallos/features/warranty/data/purchase_papers.dart';
import 'package:recallos/router.dart';

/// A record with no photograph: typed in, or brought in from a file.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late SearchRepository search;
  late Directory dir;
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
    cards = CardRepository(db);
    search = SearchRepository(db, loadEmbedder);
    dir = Directory.systemTemp.createTempSync('typed_test');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  group('what is saved', () {
    test('no photograph, nothing misread, the owner\'s own words', () async {
      final int id = await cards.createTyped(
        type: CardType.receipt,
        fieldKey: ReceiptKeys.merchant,
        value: 'Star Tech',
      );

      final CardRow row = await (db.select(
        db.cards,
      )..where(($CardsTable c) => c.id.equals(id))).getSingle();
      expect(row.imagePath, kNoPhotograph);
      expect(row.captureSource, CaptureSource.typed);
      expect(row.extractionStatus, ExtractionStatus.manual);

      final CardSummary summary = (await cards.watchCards().first).single;
      expect(summary.title, 'Star Tech');
      expect(summary.needsAttention, isFalse);
      expect(await cards.watchNeedsAttention().first, isEmpty);
    });

    test('deleted, restored and destroyed like anything else', () async {
      final int id = await cards.createTyped(
        type: CardType.visitingCard,
        fieldKey: FieldKeys.personName,
        value: 'Nusrat Jahan',
      );
      await cards.softDelete(id);
      expect(await cards.watchCards().first, isEmpty);
      await cards.restore(id);
      expect(await cards.watchCards().first, hasLength(1));
      await cards.purge(id);
      expect(await db.select(db.cards).get(), isEmpty);
    });

    test('shared papers do not claim a photograph went missing', () async {
      final PurchaseLinks links = PurchaseLinks(db);
      final int id = await cards.createTyped(
        type: CardType.warrantyCard,
        fieldKey: WarrantyKeys.product,
        value: 'Kitchen fridge',
      );
      final PurchasePapers papers = (await PurchasePapersReader(
        db,
        links,
        label: (String k) => k,
      ).read(id))!;
      expect(papers.papers.single.photos, isEmpty);
    });
  });

  testWidgets('the card screen has no empty picture frame', (
    WidgetTester t,
  ) async {
    final int id =
        await t.runAsync(
              () => cards.createTyped(
                type: CardType.visitingCard,
                fieldKey: FieldKeys.personName,
                value: 'Nusrat Jahan',
              ),
            )
            as int;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          searchRepositoryProvider.overrideWithValue(search),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CardDetailScreen(cardId: id),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(find.byType(CardSidesView), findsNothing);
    expect(find.text('Nusrat Jahan'), findsWidgets);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 500));
  });

  group('from home', () {
    Future<void> pump(
      WidgetTester t, {
      Future<File?> Function()? pick,
      PaperImporter? importer,
    }) async {
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/card/:id',
            builder: (_, GoRouterState s) =>
                Text('card ${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: Routes.capture,
            builder: (_, GoRouterState s) => Text(
              'capture ${p.basename((s.extra! as ImportedPaper).file.path)}',
            ),
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            searchRepositoryProvider.overrideWithValue(search),
            if (pick != null) pickPaperFileProvider.overrideWithValue(pick),
            if (importer != null)
              paperImporterProvider.overrideWithValue(() async => importer),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
    }

    Future<void> settle(WidgetTester t) async {
      for (int i = 0; i < 12; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> openWays(WidgetTester t) async {
      await t.tap(find.bySemanticsLabel('Add without scanning'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> finish(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 500));
    }

    testWidgets('typing one in saves it and opens it', (WidgetTester t) async {
      await pump(t);
      await openWays(t);
      await t.tap(find.text('Type it in'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // The keyboard coming up takes the bottom row, and the button that
      // started this, out of the tree. Found on a real device.
      t.view.devicePixelRatio = 3;
      t.view.physicalSize = const Size(1080, 2400);
      t.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(t.view.reset);
      await t.pump();

      await t.tap(find.text('Receipt'));
      await t.pump();
      expect(find.text('SHOP'), findsOneWidget, reason: 'asks by the kind');
      await t.enterText(find.byType(TextField).last, 'Star Tech');
      await t.pump();
      await t.tap(find.text('Add it'));
      await settle(t);

      final List<CardRow> rows =
          await t.runAsync(() => db.select(db.cards).get()) as List<CardRow>;
      expect(rows.single.type, CardType.receipt);
      expect(find.text('card ${rows.single.id}'), findsOneWidget);
      await finish(t);
    });

    testWidgets('with nothing typed, nothing can be added', (
      WidgetTester t,
    ) async {
      await pump(t);
      await openWays(t);
      await t.tap(find.text('Type it in'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Add it'));
      await t.pump();

      expect(find.textContaining('Write this first'), findsOneWidget);
      expect(await t.runAsync(() => db.select(db.cards).get()), isEmpty);
      await finish(t);
    });

    testWidgets('a file goes to capture', (WidgetTester t) async {
      final File chosen = File(p.join(dir.path, 'bill.jpg'))
        ..writeAsBytesSync(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      await pump(
        t,
        pick: () async => chosen,
        importer: PaperImporter(
          render: (String _, String _) async => 1,
          scratch: dir,
        ),
      );
      await openWays(t);
      await t.tap(find.text('From a file'));
      await settle(t);

      expect(find.text('capture bill.jpg'), findsOneWidget);
      await finish(t);
    });

    testWidgets('a refused file says why and stays on home', (
      WidgetTester t,
    ) async {
      final File chosen = File(p.join(dir.path, 'notes.pdf'))
        ..writeAsStringSync('hello there');
      await pump(
        t,
        pick: () async => chosen,
        importer: PaperImporter(
          render: (String _, String _) async => 1,
          scratch: dir,
        ),
      );
      await openWays(t);
      await t.tap(find.text('From a file'));
      await settle(t);

      expect(find.textContaining('PDF, a JPG or a PNG'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      await finish(t);
    });

    testWidgets('backing out of the picker does nothing', (
      WidgetTester t,
    ) async {
      await pump(t, pick: () async => null);
      await openWays(t);
      await t.tap(find.text('From a file'));
      await settle(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await finish(t);
    });
  });
}
