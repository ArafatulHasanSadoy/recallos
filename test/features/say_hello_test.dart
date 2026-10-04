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
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/introduction/data/hello_repository.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';
import 'package:recallos/router.dart';

import '../support/fake_notification_port.dart';

/// A3 on the card: "Say hello", tapped the way a person taps it.
///
/// What matters is what reaches the other app and what the card claims
/// afterwards — so the opener is a spy, and the assertions are about the link
/// it was handed and the line the card shows, never about a flag in between.
void main() {
  late AppDatabase db;
  late List<Uri> opened;
  late bool openWorks;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    opened = <Uri>[];
    openWorks = true;
  });
  tearDown(() async => db.close());

  Future<int> seed({
    String phone = '01812-445566',
    String e164 = '+8801812445566',
    String? email = 'nusrat@bengalevents.com',
  }) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/card.jpg',
            capturedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        );
    Future<void> field(String key, String value, [String? normal]) => db
        .into(db.cardFields)
        .insert(
          CardFieldsCompanion.insert(
            cardId: id,
            fieldKey: key,
            value: value,
            normalizedValue: Value<String?>(normal),
            source: FactSource.printed,
          ),
        );
    await field(FieldKeys.personName, 'Nusrat Jahan');
    await field(FieldKeys.company, 'Bengal Event Solutions');
    await field(FieldKeys.phone, phone, e164);
    if (email != null) await field(FieldKeys.email, email, email);
    return id;
  }

  Future<void> makeMyCard() => ProfileRepository(db).save(
    const ProfileDraft(
      entries: <ProfileEntry>[
        ProfileEntry(fieldKey: FieldKeys.personName, value: 'Arafat Hasan'),
        ProfileEntry(fieldKey: FieldKeys.company, value: 'RecallOS'),
      ],
    ),
  );

  List<Override> overrides() => <Override>[
    databaseProvider.overrideWithValue(db),
    notificationPortProvider.overrideWithValue(FakePort()),
    helloOpenerProvider.overrideWithValue((Uri u) async {
      opened.add(u);
      return openWorks;
    }),
  ];

  Future<void> pump(WidgetTester tester, int cardId) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CardDetailScreen(cardId: cardId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// The actions sit under the note and the follow-up blocks, below the
  /// fold, where a lazy list has not built them yet; scroll as a person does.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await reveal(tester, f);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  String sheetText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).last).controller!.text;

  testWidgets('writes from your card and where you met, and opens WhatsApp', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    await makeMyCard();
    await FollowUpRepository(db).setEncounter(
      cardId: id,
      metOn: DateTime.now().subtract(const Duration(days: 1)),
      place: 'CSE fest at NSU',
    );
    await pump(tester, id);

    await tap(tester, find.text('Say hello'));
    expect(find.text('What would you like to say?'), findsOneWidget);
    expect(
      sheetText(tester),
      'Hi Nusrat, great meeting you at CSE fest at NSU yesterday. '
      'This is Arafat Hasan from RecallOS. '
      'Looking forward to staying in touch.',
    );
    for (final String chip in <String>['WhatsApp', 'SMS', 'Email']) {
      expect(find.text(chip), findsWidgets);
    }

    // The user's words, not the draft, are what goes.
    await tester.enterText(
      find.byType(TextField).last,
      'Hi Nusrat, lovely to meet you — Arafat',
    );
    await tap(tester, find.text('Open in WhatsApp'));

    final Uri sent = opened.single;
    expect(sent.host, 'wa.me');
    expect(sent.path, '/8801812445566');
    expect(
      sent.queryParameters['text'],
      'Hi Nusrat, lovely to meet you — Arafat',
    );
    expect(find.text('Hello written for WhatsApp today'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an app that does not open records nothing, and says so', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    await makeMyCard();
    openWorks = false;
    await pump(tester, id);

    await tap(tester, find.text('Say hello'));
    await tap(tester, find.text('Email').last);
    await tap(tester, find.text('Open as an email'));

    expect(opened.single.scheme, 'mailto');
    expect(find.text('Nothing on this phone sends email'), findsOneWidget);
    expect(find.textContaining('Hello written'), findsNothing);
    final List<Interaction> rows = await db.select(db.interactions).get();
    expect(
      rows.where((Interaction i) => i.kind == InteractionKind.helloOpened),
      isEmpty,
    );
    await unmount(tester);
  });

  testWidgets('a card with only a landline has no Say hello at all', (
    WidgetTester tester,
  ) async {
    final int id = await seed(
      phone: '02-9660000',
      e164: '+88029660000',
      email: null,
    );
    await pump(tester, id);

    await reveal(tester, find.text('Call'));
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Say hello'), findsNothing);
    await unmount(tester);
  });

  testWidgets('without a card of your own, it offers to make one', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => CardDetailScreen(cardId: id),
        ),
        GoRoute(
          path: Routes.myCardEdit,
          builder: (_, _) => const Scaffold(body: Text('card editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tap(tester, find.text('Say hello'));
    expect(
      sheetText(tester),
      'Hi Nusrat, great meeting you. Looking forward to staying in touch.',
      reason: 'unsigned rather than signed with a guess',
    );
    await tap(tester, find.text('Sign it — make your card'));
    expect(find.text('card editor'), findsOneWidget);
    expect(opened, isEmpty);
    await unmount(tester);
  });
}
