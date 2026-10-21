import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/db/field_provenance.dart';
import 'package:recallos/core/domain/local_date.dart';
import 'package:recallos/core/domain/money.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/spending/spending_totals.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/search/presentation/home_screen.dart';
import 'package:recallos/features/spending/presentation/spending_screen.dart'
    show homeReceiptsWords;
import 'package:recallos/router.dart';

/// The way into B4 from home: a row that is there only while the wallet
/// holds receipts, carries this month's figure, and opens the totals.
void main() {
  group('the row\'s words', () {
    ReceiptFacts counted(int minor, String currency) => ReceiptFacts(
      cardId: minor,
      savedAt: DateTime(2026, 10, 12),
      total: Money(minor, currency),
      totalState: FactState.checked,
      date: LocalDate(2026, 10, 12),
      dateState: FactState.checked,
    );
    const SpendingPeriod october = SpendingPeriod.month(2026, 10);

    test('the figure, in its currency, "in receipts" — never "spent"', () {
      expect(
        homeReceiptsWords(
          SpendingSummary.of(<ReceiptFacts>[
            counted(845000, 'BDT'),
          ], period: october),
        ),
        'BDT 8,450.00 in receipts this month',
      );
      expect(
        homeReceiptsWords(
          SpendingSummary.of(<ReceiptFacts>[
            counted(845000, 'BDT'),
            counted(1200, 'USD'),
          ], period: october),
        ),
        'BDT 8,450.00 + 1 other currency this month',
      );
    });

    test('nothing counted: how many are waiting, else just the way in', () {
      final ReceiptFacts waiting = ReceiptFacts(
        cardId: 1,
        savedAt: DateTime(2026, 10, 12),
        total: const Money(100, 'BDT'),
        totalState: FactState.unchecked,
        date: LocalDate(2026, 10, 12),
        dateState: FactState.checked,
      );
      expect(
        homeReceiptsWords(
          SpendingSummary.of(<ReceiptFacts>[waiting], period: october),
        ),
        '1 receipt this month to check',
      );
      expect(
        homeReceiptsWords(
          SpendingSummary.of(<ReceiptFacts>[
            waiting,
          ], period: const SpendingPeriod.month(2026, 11)),
        ),
        'Receipt totals',
      );
    });
  });

  group('on home', () {
    late AppDatabase db;
    late SearchRepository search;

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
    });
    tearDown(() async => db.close());

    Future<void> field(
      int cardId,
      String key,
      String value, {
      Money? money,
      LocalDate? day,
      bool checked = true,
    }) {
      final FieldProvenance as = checked
          ? FieldProvenance.userConfirmed
          : FieldProvenance.printed;
      return db
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
    }

    /// A receipt dated today, so "this month" holds whenever the suite runs.
    Future<int> receipt({bool checked = true}) async {
      final int id = await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              imagePath: '/nonexistent/r.jpg',
              capturedAt: DateTime.now(),
              type: const Value<CardType>(CardType.receipt),
              extractionStatus: const Value<ExtractionStatus>(
                ExtractionStatus.complete,
              ),
            ),
          );
      final LocalDate today = LocalDate.fromDateTime(DateTime.now());
      await field(id, ReceiptKeys.merchant, 'Shwapno');
      await field(
        id,
        ReceiptKeys.total,
        'BDT 432.60',
        money: const Money(43260, 'BDT'),
        checked: checked,
      );
      await field(id, ReceiptKeys.purchaseDate, today.toIso(), day: today);
      return id;
    }

    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: Routes.receiptTotals,
            builder: (_, _) => const Scaffold(body: Text('totals page')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            searchRepositoryProvider.overrideWithValue(search),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('a wallet of business cards has no receipts row', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(
                imagePath: '/nonexistent/c.jpg',
                capturedAt: DateTime.now(),
              ),
            );
      });
      await pumpHome(tester);
      expect(find.textContaining('this month'), findsNothing);
      expect(find.text('Receipt totals'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a checked receipt puts this month\'s figure on home, and the '
        'row opens the totals', (WidgetTester tester) async {
      await tester.runAsync(() => receipt());
      await pumpHome(tester);

      final Finder row = find.text('BDT 432.60 in receipts this month');
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('totals page'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an unchecked one says it is waiting', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() => receipt(checked: false));
      await pumpHome(tester);
      expect(find.text('1 receipt this month to check'), findsOneWidget);
      await unmount(tester);
    });
  });
}
