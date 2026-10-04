import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/events/data/wallet_events.dart';
import 'package:recallos/features/events/presentation/event_screen.dart';
import 'package:recallos/features/events/presentation/event_widgets.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/followup/presentation/card_follow_up_blocks.dart';
import 'package:recallos/features/plus/data/plus_controller.dart';
import 'package:recallos/router.dart';

import '../support/fake_notification_port.dart';
import '../support/fake_store.dart';
import '../support/play_fixtures.dart';

/// A5, Event Mode: name an event once, and every card scanned until it ends
/// is marked as met there; when it ends, everyone met and what is next.
///
/// The screens are tapped the way a person taps them. A Start button that
/// rendered and stored nothing, or a free user shown a Start that could not
/// start, would pass any assertion about what is on screen — so these follow
/// the tap to what it changed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MemoryGrants grants;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    grants = MemoryGrants();
  });
  tearDown(() async => db.close());

  Future<int> seedCard(String company, {String? person}) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/$company.jpg',
            capturedAt: DateTime.now(),
          ),
        );
    await db
        .into(db.cardFields)
        .insert(
          CardFieldsCompanion.insert(
            cardId: id,
            fieldKey: FieldKeys.company,
            value: company,
            source: FactSource.printed,
          ),
        );
    if (person != null) {
      await db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: FieldKeys.personName,
              value: person,
              source: FactSource.printed,
            ),
          );
    }
    return id;
  }

  Future<void> meet(
    int cardId,
    String place,
    DateTime day, {
    EncounterOrigin origin = EncounterOrigin.event,
  }) => db
      .into(db.encounters)
      .insert(
        EncountersCompanion.insert(
          cardId: cardId,
          place: Value<String?>(place),
          metOn: Value<DateTime?>(dayOf(day)),
          origin: Value<EncounterOrigin>(origin),
        ),
      );

  group('the event store', () {
    test('one event runs at a time: starting another ends the first', () async {
      DateTime clock = DateTime(2026, 10, 4, 10);
      final EventStore store = EventStore(db, now: () => clock);

      final WalletEvent fest = await store.start('  CSE fest   at NSU ');
      expect(fest.name, 'CSE fest at NSU');
      expect((await store.active())?.id, fest.id);

      clock = DateTime(2026, 10, 4, 15);
      final WalletEvent expo = await store.start('BASIS SoftExpo');
      final List<WalletEvent> all = await store.all();
      expect(all.map((WalletEvent e) => e.name), <String>[
        'BASIS SoftExpo',
        'CSE fest at NSU',
      ]);
      expect(all.where((WalletEvent e) => e.active), <WalletEvent>[expo]);
      expect(all.last.endedAt, DateTime(2026, 10, 4, 15));
    });

    test('ending can be undone, unless another event has started', () async {
      final EventStore store = EventStore(db);
      final WalletEvent fest = await store.start('CSE fest');

      final WalletEvent? ended = await store.end();
      expect(ended?.id, fest.id);
      expect(await store.active(), isNull);

      await store.reopen(fest.id);
      expect((await store.active())?.id, fest.id);

      await store.end();
      await store.start('Something else');
      await store.reopen(fest.id);
      expect((await store.active())?.name, 'Something else');
      expect(
        (await store.all()).where((WalletEvent e) => e.active),
        hasLength(1),
      );
    });

    test(
      'an ended event can be removed and put back; a running one stays',
      () async {
        final EventStore store = EventStore(db);
        final WalletEvent fest = await store.start('CSE fest');
        expect(await store.forget(fest.id), isNull, reason: 'still running');

        await store.end();
        final WalletEvent? gone = await store.forget(fest.id);
        expect(gone?.name, 'CSE fest');
        expect(await store.all(), isEmpty);

        await store.putBack(gone!);
        await store.putBack(gone);
        expect((await store.all()).map((WalletEvent e) => e.id), <int>[
          fest.id,
        ]);
      },
    );

    test(
      'an empty name is refused, and an unreadable list reads empty',
      () async {
        final EventStore store = EventStore(db);
        await expectLater(store.start('   '), throwsArgumentError);
        expect(await store.all(), isEmpty);

        await db
            .into(db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(key: EventStore.key, value: 'not json'),
            );
        expect(await store.all(), isEmpty);
        expect((await store.start('CSE fest')).id, 1);
      },
    );
  });

  group('cards met at an event', () {
    late Directory documents;

    setUp(() async {
      documents = await Directory.systemTemp.createTemp('recallos_docs');
      PathProviderPlatform.instance = _FakePathProvider(documents.path);
    });
    tearDown(() async => documents.delete(recursive: true));

    File photo() =>
        File(p.join(documents.path, 'scan_${DateTime.now().microsecond}.jpg'))
          ..writeAsBytesSync(img.encodeJpg(img.Image(width: 100, height: 60)));

    test('a card saved during an event is marked as met there, today, by '
        'Event Mode', () async {
      final CardRepository repo = CardRepository(db);
      final int during = (await repo.createPending(
        photo(),
        metAt: 'CSE fest at NSU',
      )).id;
      final int outside = (await repo.createPending(photo())).id;

      final List<Encounter> met = await db.select(db.encounters).get();
      expect(met, hasLength(1));
      expect(met.single.cardId, during);
      expect(met.single.place, 'CSE fest at NSU');
      expect(met.single.metOn, dayOf(DateTime.now()));
      expect(met.single.origin, EncounterOrigin.event);
      expect(
        met.where((Encounter e) => e.cardId == outside),
        isEmpty,
        reason: 'no event running, nothing assumed',
      );

      // Retake discards the attempt; its mark goes with it.
      await repo.discard(during);
      expect(await db.select(db.encounters).get(), isEmpty);
    });

    test('belonging follows what the card says now', () async {
      final FollowUpRepository repo = FollowUpRepository(db);
      final DateTime day = DateTime(2026, 10, 4);
      final int a = await seedCard('Green Leaf Printing');
      final int b = await seedCard('Pixel Studio BD');
      final int c = await seedCard('Moments Studio');
      final int d = await seedCard('Earlier Ltd');
      final int deleted = await seedCard('Gone Ltd');
      await meet(a, 'CSE fest at NSU', day);
      await meet(b, 'cse FEST at nsu', day); // case is not a different place
      await meet(c, 'Somewhere else', day);
      await meet(d, 'CSE fest at NSU', DateTime(2026, 9, 1)); // last year's
      await meet(deleted, 'CSE fest at NSU', day);
      await CardRepository(db).softDelete(deleted);

      Future<List<int>> members() async =>
          (await repo
                  .watchMetAt(
                    place: 'CSE fest at NSU',
                    from: day,
                    until: day.add(const Duration(days: 1)),
                  )
                  .first)
              .map((MetCard m) => m.cardId)
              .toList();

      expect(await members(), <int>[a, b]);

      // The user says they met b somewhere else: b has left.
      await repo.setEncounter(cardId: b, metOn: day, place: 'Office');
      // ...and types the event in by hand for c: c has joined.
      await repo.setEncounter(cardId: c, metOn: day, place: 'CSE fest at NSU');
      expect(await members(), <int>[a, c]);

      // "Not sure when" is not "at this event".
      await repo.setEncounter(cardId: a, place: 'CSE fest at NSU');
      expect(await members(), <int>[c]);
    });
  });

  group('the Event Mode screen', () {
    Future<List<String>> pumpScreen(
      WidgetTester tester, {
      required bool plus,
      int? eventId,
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      if (plus) {
        grants.kept = (originalJson: plusReceipt, signature: plusSignature);
      }
      final List<String> opened = <String>[];
      final GoRouter router = GoRouter(
        initialLocation: eventId == null ? '/' : '/e/$eventId',
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const EventScreen()),
          GoRoute(
            path: '/e/:id',
            builder: (_, GoRouterState s) =>
                EventScreen(eventId: int.parse(s.pathParameters['id']!)),
          ),
          GoRoute(
            path: Routes.plus,
            builder: (_, _) {
              opened.add(Routes.plus);
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
            notificationPortProvider.overrideWithValue(
              FakePort()..allowed = true,
            ),
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
      await tester.pumpAndSettle();
      return opened;
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    testWidgets('free: an example and the way to Plus — no Start that cannot '
        'start', (WidgetTester tester) async {
      final List<String> opened = await pumpScreen(tester, plus: false);

      expect(find.text('Off to an event?'), findsOneWidget);
      expect(find.text('EXAMPLE'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Start the event'), findsNothing);

      await tapText(tester, 'Comes with RecallOS Plus');
      expect(opened, <String>[Routes.plus]);
      expect(await EventStore(db).all(), isEmpty);
      await unmount(tester);
    });

    testWidgets('Plus: name it, start it, and it is running', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, plus: true);

      // Start with no name: says why, starts nothing.
      await tapText(tester, 'Start the event');
      expect(find.textContaining('Name the event first'), findsOneWidget);
      expect(await EventStore(db).all(), isEmpty);

      await tester.enterText(find.byType(TextField), 'CSE fest at NSU');
      await tapText(tester, 'Start the event');

      final WalletEvent? running = await EventStore(db).active();
      expect(running?.name, 'CSE fest at NSU');
      expect(find.text('CSE fest at NSU'), findsOneWidget);
      expect(find.text('End the event'), findsOneWidget);
      expect(find.text('Scan a card'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ending shows everyone met, and who still needs a next step', (
      WidgetTester tester,
    ) async {
      final EventStore store = EventStore(db);
      await store.start('CSE fest at NSU');
      final int planned = await seedCard(
        'Green Leaf Printing',
        person: 'Shafiq Rahman',
      );
      final int open = await seedCard(
        'Bengal Event Solutions',
        person: 'Nusrat Jahan',
      );
      await meet(planned, 'CSE fest at NSU', DateTime.now());
      await meet(open, 'CSE fest at NSU', DateTime.now());
      await FollowUpRepository(db).addStep(
        cardId: planned,
        title: 'Ask for a quote',
        dueOn: DateTime.now().add(const Duration(days: 1)),
      );
      await pumpScreen(tester, plus: true);

      await tapText(tester, 'End the event');
      expect(await store.active(), isNull);
      expect(
        find.text('You met 2 people here. 1 still needs a next step.'),
        findsOneWidget,
      );
      expect(find.text('NO NEXT STEP YET'), findsOneWidget);
      expect(find.text('NEXT STEP PLANNED'), findsOneWidget);
      expect(find.text('Ask for a quote · Due tomorrow'), findsOneWidget);

      // The follow-through, from the summary itself.
      await tapText(tester, 'Add a next step');
      expect(find.text("What's the next step?"), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Send our deck');
      await tapText(tester, 'Add step');

      expect(
        find.text('You met 2 people here, each with a next step planned.'),
        findsOneWidget,
      );
      expect(find.text('NO NEXT STEP YET'), findsNothing);
      final List<NextStep> steps = await FollowUpRepository(
        db,
      ).watchOpenSteps(open).first;
      expect(steps.single.date.title, 'Send our deck');
      await unmount(tester);
    });

    testWidgets('an earlier event opens on its own summary', (
      WidgetTester tester,
    ) async {
      final EventStore store = EventStore(db);
      final WalletEvent fest = await store.start('CSE fest at NSU');
      await store.end();
      final int id = await seedCard('Pixel Studio BD');
      await meet(id, 'CSE fest at NSU', DateTime.now());

      await pumpScreen(tester, plus: true, eventId: fest.id);
      expect(find.text('CSE fest at NSU'), findsOneWidget);
      expect(find.text('Pixel Studio BD'), findsOneWidget);
      expect(
        find.text('You met 1 person here, with no next step yet.'),
        findsOneWidget,
      );
      expect(find.text('End the event'), findsNothing);

      await tapText(tester, 'Remove from your events');
      expect(await store.all(), isEmpty);
      expect(
        await db.select(db.encounters).get(),
        hasLength(1),
        reason: 'the card keeps where it was met',
      );
      await unmount(tester);
    });
  });

  group('overriding Event Mode', () {
    Future<void> pumpWidget(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: SingleChildScrollView(child: child)),
          ),
          GoRoute(
            path: '/event/:id',
            builder: (_, GoRouterState s) =>
                Scaffold(body: Text('event ${s.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            databaseProvider.overrideWithValue(db),
            notificationPortProvider.overrideWithValue(FakePort()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('"Not met there" on the scan takes the mark off', (
      WidgetTester tester,
    ) async {
      final int id = await seedCard('Handed Over Ltd');
      await meet(id, 'CSE fest at NSU', DateTime.now());
      await pumpWidget(tester, EventMark(cardId: id));

      expect(find.text('Met at CSE fest at NSU, today'), findsOneWidget);
      await tester.tap(find.text('Not met there'));
      await tester.pumpAndSettle();

      expect(await db.select(db.encounters).get(), isEmpty);
      expect(find.text('Met at CSE fest at NSU, today'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a place the user wrote is theirs: no Event Mode mark', (
      WidgetTester tester,
    ) async {
      final int id = await seedCard('Told Me Myself Ltd');
      await meet(
        id,
        'CSE fest at NSU',
        DateTime.now(),
        origin: EncounterOrigin.user,
      );
      await pumpWidget(tester, EventMark(cardId: id));
      expect(find.textContaining('Met at'), findsNothing);
      await unmount(tester);
    });

    testWidgets('the card says Event Mode marked it, and leads to the event', (
      WidgetTester tester,
    ) async {
      final WalletEvent fest = await EventStore(db).start('CSE fest at NSU');
      final int id = await seedCard('Green Leaf Printing');
      await meet(id, 'CSE fest at NSU', DateTime.now());
      await pumpWidget(tester, MetBlock(cardId: id, scannedOn: DateTime.now()));

      expect(find.text('Marked by Event Mode'), findsOneWidget);
      await tester.tap(find.text('Everyone met there'));
      await tester.pumpAndSettle();
      expect(find.text('event ${fest.id}'), findsOneWidget);
      await unmount(tester);
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}
