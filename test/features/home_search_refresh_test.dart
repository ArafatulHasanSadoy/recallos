import 'dart:io';

// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/events/data/wallet_events.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/search/presentation/home_screen.dart';

/// Open search results follow the data.
///
/// Found on the phone: a card deleted from its own screen stayed in the open
/// results, because results were a snapshot refreshed only by typing. The
/// same held for a restore or a new note. These tests change the data behind
/// the screen's back — the way another screen does — and look at what the
/// home screen shows.
void main() {
  late AppDatabase db;
  late SearchRepository search;

  StaticEmbedder? shared;
  Future<StaticEmbedder> loadEmbedder() async => shared ??= StaticEmbedder.fromBytes(
    matrixBytes: File('assets/embedding/matrix.bin').readAsBytesSync(),
    tokenizer: WordPieceTokenizer.fromAssets(
      vocabText: File('assets/embedding/vocab.txt').readAsStringSync(),
      normalizerJson: File('assets/embedding/normalizer.json').readAsStringSync(),
    ),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    search = SearchRepository(db, loadEmbedder);
  });
  tearDown(() async => db.close());

  Future<int> seed(String company, String note) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/$company.jpg',
            capturedAt: DateTime(2026, 9, 28),
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
            fieldKey: 'company',
            value: company,
            source: FactSource.printed,
          ),
        );
    await CardRepository(db).addNote(cardId: id, body: note);
    await search.reindexCard(id);
    return id;
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          searchRepositoryProvider.overrideWithValue(search),
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
  }

  /// Lets the change notification, the 150 ms coalescing timer and the
  /// re-run search all land.
  Future<void> settleRefresh(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('the home row says what is due, and is absent when nothing is',
      (WidgetTester tester) async {
    final int id = await seed('Spice Route Catering', 'catering');
    await pumpHome(tester);
    expect(find.textContaining('due today'), findsNothing);
    expect(find.textContaining('Next:'), findsNothing,
        reason: 'no steps, no row: a row that says nothing trains people to '
            'ignore it');

    // Written behind the screen's back, the way the card screen writes it.
    final FollowUpRepository repo = FollowUpRepository(db);
    await repo.addStep(
      cardId: id,
      title: 'Confirm menu',
      dueOn: DateTime.now().add(const Duration(days: 3)),
    );
    await settleRefresh(tester);
    expect(find.textContaining('Next: Confirm menu'), findsOneWidget);

    await repo.addStep(cardId: id, title: 'Send CVs', dueOn: DateTime.now());
    await settleRefresh(tester);
    expect(find.text('1 step due today'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the scan button stands aside while a search is being typed', (
    WidgetTester tester,
  ) async {
    // Found on the phone: with the keyboard up the body shrinks, and the pill
    // pinned to its bottom sat on top of the answer being typed for.
    await tester.runAsync(() => seed('Padma Soft Ltd', 'Flutter internships'));
    await pumpHome(tester);
    final Finder pill = find.text('Scan a card');
    expect(pill, findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await typeQuery(tester, 'internship');
    expect(pill, findsNothing);

    tester.view.resetViewInsets();
    await tester.pump();
    expect(pill, findsOneWidget, reason: 'back once the keyboard goes');
    await unmount(tester);
  });

  testWidgets('a card deleted elsewhere leaves the open results', (
    WidgetTester tester,
  ) async {
    final int id = await seed('Sonar Bangla Press', 'printing guy from fest');
    await pumpHome(tester);

    await typeQuery(tester, 'printing');
    expect(find.text('printing guy from fest'), findsOneWidget);

    // What the card screen's trash button does.
    await CardRepository(db).softDelete(id);
    await settleRefresh(tester);

    expect(find.text('printing guy from fest'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a restored card comes back into the open results', (
    WidgetTester tester,
  ) async {
    final int id = await seed('Sonar Bangla Press', 'printing guy from fest');
    await CardRepository(db).softDelete(id);
    await pumpHome(tester);

    await typeQuery(tester, 'printing');
    expect(find.text('printing guy from fest'), findsNothing);

    await CardRepository(db).restore(id);
    await settleRefresh(tester);

    expect(find.text('printing guy from fest'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a note edited elsewhere is what the open results show', (
    WidgetTester tester,
  ) async {
    final int id = await seed('Sonar Bangla Press', 'printing guy from fest');
    await pumpHome(tester);

    await typeQuery(tester, 'printing');
    expect(find.text('printing guy from fest'), findsOneWidget);

    // What the note sheet does: write the note, then re-index.
    await CardRepository(db).setNote(cardId: id, body: 'printing and banners');
    await search.reindexCard(id);
    await settleRefresh(tester);

    expect(find.text('printing and banners'), findsOneWidget);
    expect(find.text('printing guy from fest'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a running event shows on home with its count, and goes when it '
      'ends', (WidgetTester tester) async {
    final int id = await seed('Green Leaf Printing', 'printing');
    final EventStore events = EventStore(db);
    await pumpHome(tester);
    expect(find.textContaining('At CSE fest'), findsNothing);
    expect(find.bySemanticsLabel('Event Mode'), findsOneWidget,
        reason: 'the way in, beside Scan a card, when nothing runs');

    await events.start('CSE fest at NSU');
    await db.into(db.encounters).insert(
          EncountersCompanion.insert(
            cardId: id,
            place: const Value<String?>('CSE fest at NSU'),
            metOn: Value<DateTime?>(dayOf(DateTime.now())),
            origin: const Value<EncounterOrigin>(EncounterOrigin.event),
          ),
        );
    await settleRefresh(tester);
    expect(find.text('At CSE fest at NSU · 1 card'), findsOneWidget);
    expect(find.bySemanticsLabel('Event Mode, running'), findsOneWidget);

    await events.end();
    await settleRefresh(tester);
    expect(find.textContaining('At CSE fest'), findsNothing);
    await unmount(tester);
  });
}
