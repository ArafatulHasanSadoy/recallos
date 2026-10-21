import 'dart:io';

// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/platform/external_opener.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/search/presentation/home_screen.dart';
import 'package:recallos/router.dart';

import '../support/fake_store.dart';
import '../support/play_fixtures.dart';

/// Answers on home, read the way a person reads them: "Rahim's number" as
/// the number itself, where it came from, and a tap that dials it; people
/// filters as an exact list (or the way to Plus); and every result saying
/// which of its words matched.
void main() {
  late AppDatabase db;
  late SearchRepository search;
  late List<Uri> opened;

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
    search = SearchRepository(db, loadEmbedder);
    opened = <Uri>[];
  });
  tearDown(() async => db.close());

  Future<int> person(String name, String phone, String e164) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/$name.jpg',
            capturedAt: DateTime.now().subtract(const Duration(days: 3)),
            extractionStatus: const Value<ExtractionStatus>(
              ExtractionStatus.complete,
            ),
          ),
        );
    await db
        .into(db.cardFields)
        .insert(
          CardFieldsCompanion.insert(
            cardId: id,
            fieldKey: FieldKeys.personName,
            value: name,
            source: FactSource.printed,
          ),
        );
    await db
        .into(db.cardFields)
        .insert(
          CardFieldsCompanion.insert(
            cardId: id,
            fieldKey: FieldKeys.phone,
            value: phone,
            normalizedValue: Value<String?>(e164),
            source: FactSource.printed,
          ),
        );
    await search.reindexCard(id);
    return id;
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          searchRepositoryProvider.overrideWithValue(search),
          externalOpenerProvider.overrideWithValue((Uri u) async {
            opened.add(u);
            return true;
          }),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> typeQuery(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField), q);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('both Rahims, each number with where it came from', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await person('Md. Rahim Uddin', '01711-223344', '+8801711223344');
      await person('Rahim Chowdhury', '01911-556677', '+8801911556677');
      await person('Nusrat Jahan', '01812-445566', '+8801812445566');
    });
    await pumpHome(tester);

    await typeQuery(tester, "Rahim's number");

    expect(find.text('01711-223344'), findsOneWidget);
    expect(find.text('01911-556677'), findsOneWidget);
    expect(find.text('01812-445566'), findsNothing);
    // Provenance on every value, from the same chip the card screen uses.
    expect(find.text('ON THE CARD'), findsNWidgets(2));
    expect(find.textContaining('FROM THIS CARD'), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('tapping the number dials it and is remembered', (
    WidgetTester tester,
  ) async {
    late int id;
    await tester.runAsync(() async {
      id = await person('Md. Rahim Uddin', '01711-223344', '+8801711223344');
    });
    await pumpHome(tester);
    await typeQuery(tester, 'rahim er number');

    await tester.tap(find.text('01711-223344'));
    await tester.pump();
    await tester.pump();

    expect(opened.single, Uri(scheme: 'tel', path: '+8801711223344'));
    final List<Interaction> rows =
        await tester.runAsync(() => db.select(db.interactions).get()) ??
        <Interaction>[];
    expect(rows.single.kind, InteractionKind.callOpened);
    expect(rows.single.subjectId, id);
    await unmount(tester);
  });

  group('people filters on home', () {
    Future<List<String>> pumpRouted(
      WidgetTester tester, {
      required bool plus,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final MemoryGrants grants = MemoryGrants();
      if (plus) {
        grants.kept = (originalJson: plusReceipt, signature: plusSignature);
      }
      final List<String> pushed = <String>[];
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: Routes.plus,
            builder: (_, _) {
              pushed.add(Routes.plus);
              return const Scaffold(body: Text('plus screen'));
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

    Future<void> seedMet() async {
      final int a = await person(
        'Nusrat Jahan',
        '01812-445566',
        '+8801812445566',
      );
      final int b = await person(
        'Kamal Uddin',
        '01711-000001',
        '+8801711000001',
      );
      final FollowUpRepository repo = FollowUpRepository(db);
      await repo.setEncounter(cardId: a, place: 'CSE fest at NSU');
      await repo.setEncounter(cardId: b, place: 'Tech expo');
      await search.reindexCard(a);
      await search.reindexCard(b);
    }

    testWidgets('with Plus: exactly the people met there', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(seedMet);
      await pumpRouted(tester, plus: true);

      await typeQuery(tester, 'met at CSE fest');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Nusrat Jahan'), findsOneWidget);
      expect(find.text('Kamal Uddin'), findsNothing);
      expect(find.text('MET AT CSE FEST'), findsOneWidget);
      expect(find.textContaining('comes with RecallOS Plus'), findsNothing);
      await unmount(tester);
    });

    testWidgets('free: the words are searched, and the line opens Plus', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(seedMet);
      final List<String> pushed = await pumpRouted(tester, plus: false);

      await typeQuery(tester, 'met at CSE fest');

      final Finder line = find.text(
        'Filtering by when you met comes with RecallOS Plus',
      );
      expect(line, findsOneWidget);
      // The free where-you-met index still finds her.
      expect(find.text('Nusrat Jahan'), findsWidgets);

      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(pushed, <String>[Routes.plus]);
      await unmount(tester);
    });
  });

  group('why a card matched', () {
    Future<void> printedCard({required String note}) async {
      final int id = await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              imagePath: '/nonexistent/techfix.jpg',
              capturedAt: DateTime.now().subtract(const Duration(days: 3)),
              rawOcrText: const Value<String?>(
                'TechFix Repair Centre\nLaptop and Mobile Servicing\n'
                'Shop 12, Multiplan Center, Elephant Road',
              ),
              extractionStatus: const Value<ExtractionStatus>(
                ExtractionStatus.complete,
              ),
            ),
          );
      await db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: FieldKeys.company,
              value: 'TechFix Repair Centre',
              source: FactSource.printed,
            ),
          );
      await db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: FieldKeys.personName,
              value: 'Kamal Hossain',
              source: FactSource.printed,
            ),
          );
      await CardRepository(db).addNote(cardId: id, body: note);
      await search.reindexCard(id);
    }

    testWidgets('a match in the printed text shows the words, marked', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => printedCard(note: 'laptop repair'));
      await pumpHome(tester);

      await typeQuery(tester, 'elephant road');

      expect(find.text('PRINTED ON THE CARD'), findsOneWidget);
      expect(
        find.textContaining(
          'Multiplan Center, Elephant Road',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('a note match: the note once, under the tile, word marked', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => printedCard(note: 'laptop repair'));
      await pumpHome(tester);

      await typeQuery(tester, 'laptop');

      expect(find.text('YOUR NOTE'), findsOneWidget);
      // Said once: in the block, not again on the tile.
      expect(find.text('laptop repair'), findsOneWidget);
      // The tile's second line says who it is instead.
      expect(find.text('Kamal Hossain'), findsOneWidget);
      await unmount(tester);
    });
  });

  // The floor in CLAUDE.md: a 360dp phone at 1.3× text. A Row that fits at
  // 1.0 can overflow here, which only a phone shows — so it is pinned.
  group('at 1.3× text on a narrow phone', () {
    Future<void> pumpScaled(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            databaseProvider.overrideWithValue(db),
            searchRepositoryProvider.overrideWithValue(search),
            externalOpenerProvider.overrideWithValue((Uri u) async => true),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a lookup answer with a long value lays out', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(
        () => person(
          'Mohammad Abdur Rahim Chowdhury',
          '+880 1711-223344 ext. 2209',
          '+8801711223344',
        ),
      );
      await pumpScaled(tester);
      await typeQuery(tester, "Rahim's number");

      expect(tester.takeException(), isNull);
      expect(find.text('+880 1711-223344 ext. 2209'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a result with its why block lays out', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final int id = await person(
          'Kamal Hossain',
          '01711-000001',
          '+8801711000001',
        );
        await CardRepository(db).addNote(
          cardId: id,
          body: 'AC servicing before summer, also fixes the fridge compressor',
        );
        await search.reindexCard(id);
      });
      await pumpScaled(tester);
      await typeQuery(tester, 'AC repair');

      expect(tester.takeException(), isNull);
      expect(find.text('YOUR NOTE'), findsOneWidget);
      await unmount(tester);
    });
  });
}
