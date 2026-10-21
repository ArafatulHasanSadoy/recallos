import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';
import 'package:recallos/features/cards/presentation/widgets/card_image_overlay.dart'
    show StandInImage;
import 'package:recallos/features/contacts/data/identity_repository.dart';
import 'package:recallos/features/contacts/presentation/contacts_screen.dart';
import 'package:recallos/features/contacts/presentation/person_screen.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/followup/presentation/today_screen.dart';
import 'package:recallos/features/search/data/search_repository.dart';
import 'package:recallos/features/search/presentation/home_screen.dart';
import 'package:recallos/features/settings/presentation/onboarding_screen.dart';
import 'package:recallos/main.dart' show kAppLocale, kAppLocalizations;
import 'package:recallos/router.dart';

import '../support/fake_notification_port.dart';

/// The UX pass over the core flow (M7½), one fix per test, each checked
/// the way it was found: by what is on the screen and what it does.
void main() {
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

  Future<int> company(String name, String note) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/$name.jpg',
            capturedAt: DateTime.now().subtract(const Duration(days: 2)),
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
            value: name,
            source: FactSource.printed,
          ),
        );
    await CardRepository(db).addNote(cardId: id, body: note);
    await search.reindexCard(id);
    return id;
  }

  /// Somebody's card — a name, a number, the company — and optionally why
  /// it was kept.
  Future<int> person(String name, String phone, {String? note}) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/nonexistent/$name.jpg',
            capturedAt: DateTime.now().subtract(const Duration(days: 2)),
            extractionStatus: const Value<ExtractionStatus>(
              ExtractionStatus.complete,
            ),
          ),
        );
    // A real scan stores a number's E.164 form beside it; without it the
    // person gets no number at all.
    final String digits = phone.replaceAll(RegExp(r'\D'), '');
    for (final (String key, String value, String? normalized) f
        in <(String, String, String?)>[
          (FieldKeys.personName, name, null),
          (FieldKeys.company, 'CoolAir Services', null),
          (FieldKeys.phone, phone, '+880${digits.substring(1)}'),
        ]) {
      await db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: f.$1,
              value: f.$2,
              normalizedValue: Value<String?>(f.$3),
              source: FactSource.printed,
            ),
          );
    }
    if (note != null) await CardRepository(db).addNote(cardId: id, body: note);
    await IdentityRepository(db).promote(id);
    return id;
  }

  /// [screen] under a router whose card route records where it went.
  Future<List<String>> pumpRouted(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final List<String> opened = <String>[];
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: '/card/:id',
          builder: (_, GoRouterState s) {
            opened.add('/card/${s.pathParameters['id']}');
            return const Scaffold(body: Text('card'));
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

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          searchRepositoryProvider.overrideWithValue(search),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  group('1. onboarding says only what is true', () {
    testWidgets('the second page names notifications, and not "nothing else"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OnboardingScreen(),
          ),
        ),
      );
      expect(
        find.textContaining('or the receipt, or the warranty'),
        findsOneWidget,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('show notifications only when you set a reminder'),
        findsOneWidget,
      );
      expect(find.textContaining('nothing else'), findsNothing);
    });
  });

  group('2–3. home', () {
    const String heading = 'What do you\nneed?';

    testWidgets('the heading folds away while there is a question, and comes '
        'back when it is cleared', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await company('CoolAir Services', 'AC servicing before summer');
        await company('TechFix Repair Centre', 'Laptop repair near campus');
      });
      await pumpHome(tester);
      final double fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      expect(find.text(heading).hitTestable(), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'repair');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(AppMotion.normal);
      await tester.pump(AppMotion.normal);

      expect(find.text(heading).hitTestable(), findsNothing);
      expect(
        tester.getTopLeft(find.byType(TextField)).dy,
        lessThan(fieldTop - 100),
        reason: 'the field rises, so the answers start higher',
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(AppMotion.normal);
      await tester.pump(AppMotion.normal);
      expect(find.text(heading).hitTestable(), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('one Scan button, not "Scan a card", once the wallet has '
        'anything', (WidgetTester tester) async {
      await tester.runAsync(
        () => company('CoolAir Services', 'AC servicing before summer'),
      );
      await pumpHome(tester);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Scan a card'), findsNothing);
      await unmount(tester);
    });
  });

  group('4. the card leads with what you came to do', () {
    testWidgets('Call sits above the note, next step and where you met', (
      WidgetTester tester,
    ) async {
      late int id;
      await tester.runAsync(() async {
        id = await person(
          'Mehedi Hasan',
          '01711-223344',
          note: 'AC servicing before summer',
        );
      });
      await pumpRouted(tester, CardDetailScreen(cardId: id));
      final double call = tester.getTopLeft(find.text('Call')).dy;
      expect(
        call,
        lessThan(tester.getTopLeft(find.text('WHY YOU SAVED THIS')).dy),
      );
      expect(call, lessThan(tester.getTopLeft(find.text('NEXT STEP')).dy));
      await unmount(tester);
    });
  });

  group('5. a person shows why you kept them', () {
    testWidgets('the note and the next step, each opening its card', (
      WidgetTester tester,
    ) async {
      late int card;
      late int personId;
      await tester.runAsync(() async {
        card = await person(
          'Mehedi Hasan',
          '01711-223344',
          note: 'AC servicing before summer',
        );
        await FollowUpRepository(db).addStep(
          cardId: card,
          title: 'Ask for the summer price',
          dueOn: DateTime.now().add(const Duration(days: 1)),
        );
        personId = (await db.select(db.people).getSingle()).id;
      });
      final List<String> opened = await pumpRouted(
        tester,
        PersonScreen(personId: personId),
      );

      expect(find.text('WHY YOU SAVED THEM'), findsOneWidget);
      expect(find.text('AC servicing before summer'), findsOneWidget);
      expect(find.text('Ask for the summer price'), findsOneWidget);
      expect(find.text('Due tomorrow'), findsOneWidget);

      await tester.tap(find.text('AC servicing before summer'));
      await tester.pumpAndSettle();
      expect(opened, <String>['/card/$card']);
      await unmount(tester);
    });

    testWidgets('nothing written yet: the way to write it, on their card', (
      WidgetTester tester,
    ) async {
      late int card;
      late int personId;
      await tester.runAsync(() async {
        card = await person('Nabila Rahman', '01812-445566');
        personId = (await db.select(db.people).getSingle()).id;
      });
      final List<String> opened = await pumpRouted(
        tester,
        PersonScreen(personId: personId),
      );
      final Finder hint = find.textContaining('Nothing written yet');
      expect(hint, findsOneWidget);
      await tester.tap(hint);
      await tester.pumpAndSettle();
      expect(opened, <String>['/card/$card']);
      await unmount(tester);
    });
  });

  group('6. numbers read the way they are written', () {
    testWidgets('a mobile stored as digits shows 01711-223344, on the card '
        'and on the person', (WidgetTester tester) async {
      late int card;
      late int personId;
      await tester.runAsync(() async {
        card = await person('Mehedi Hasan', '01711223344');
        personId = (await db.select(db.people).getSingle()).id;
      });
      await pumpRouted(tester, CardDetailScreen(cardId: card));
      expect(find.text('01711-223344'), findsOneWidget);
      expect(find.text('01711223344'), findsNothing);
      await unmount(tester);

      await pumpRouted(tester, PersonScreen(personId: personId));
      expect(find.text('01711-223344'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('7. Today shows warranties ending soon', () {
    Future<int> warranty(String title, DateTime lastDay) async {
      final int id = await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              imagePath: '/nonexistent/w.jpg',
              capturedAt: DateTime(2026, 9, 1),
              type: const Value<CardType>(CardType.warrantyCard),
              title: Value<String?>(title),
            ),
          );
      await db
          .into(db.importantDates)
          .insert(
            ImportantDatesCompanion.insert(
              cardId: id,
              kind: DateKind.warrantyExpiry,
              title: 'Warranty ends',
              dueOn: lastDay,
            ),
          );
      return id;
    }

    testWidgets('within a month, and nothing later or already over; the row '
        'opens the warranty', (WidgetTester tester) async {
      final DateTime now = DateTime(2026, 10, 1, 10, 30);
      late int iron;
      await tester.runAsync(() async {
        iron = await warranty('SINGER Iron', DateTime(2026, 10, 20));
        await warranty('HP Laptop', DateTime(2028, 10, 11));
        await warranty('VISION Kettle', DateTime(2026, 9, 20));
      });
      final List<String> opened = await pumpRouted(
        tester,
        TodayScreen(now: () => now),
      );

      expect(find.text('ENDING SOON'), findsOneWidget);
      expect(find.text('SINGER Iron'), findsOneWidget);
      expect(
        find.text('Covered until 20 Oct · ends in 19 days'),
        findsOneWidget,
      );
      expect(find.text('HP Laptop'), findsNothing);
      expect(find.text('VISION Kettle'), findsNothing);
      expect(find.text('Nothing due'), findsNothing);

      await tester.tap(find.text('SINGER Iron'));
      await tester.pumpAndSettle();
      expect(opened, <String>['/card/$iron']);
      await unmount(tester);
    });
  });

  group('8. one name for people', () {
    testWidgets('the list says People, and a person says Person', (
      WidgetTester tester,
    ) async {
      late int personId;
      await tester.runAsync(() async {
        await person('Mehedi Hasan', '01711223344');
        personId = (await db.select(db.people).getSingle()).id;
      });
      await pumpRouted(tester, const ContactsScreen());
      expect(find.text('PEOPLE'), findsWidgets);
      expect(find.text('CONTACTS'), findsNothing);
      await unmount(tester);
      await pumpRouted(tester, PersonScreen(personId: personId));
      expect(find.text('PERSON'), findsOneWidget);
      expect(find.text('CONTACT'), findsNothing);
      await unmount(tester);
    });
  });

  group('10. the date picker in paper', () {
    test('a paper card; the chosen day filled as a primary button is', () {
      for (final bool dark in <bool>[false, true]) {
        final ThemeData theme = dark ? AppTheme.dark() : AppTheme.light();
        final AppColors c = theme.extension<AppColors>()!;
        final DatePickerThemeData d = theme.datePickerTheme;
        expect(d.backgroundColor, c.card);
        final Set<WidgetState> chosen = <WidgetState>{WidgetState.selected};
        // Rule 2: ochre never fills in light mode; in dark it takes the
        // primary, because ink on ink has no contrast.
        expect(d.dayBackgroundColor!.resolve(chosen), dark ? c.ochre : c.ink);
        expect(
          d.dayBackgroundColor!.resolve(<WidgetState>{}),
          Colors.transparent,
        );
        expect(d.todayBorder!.color, c.ochre, reason: 'a marker, not a fill');
      }
    });
  });

  group('10b. dates day-first, in the date picker too', () {
    testWidgets(
      'the app\'s language puts the day first: "Fri 16 Oct", not "Fri, Oct 16"',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: kAppLocale,
            supportedLocales: const <Locale>[kAppLocale],
            localizationsDelegates: kAppLocalizations,
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showDatePicker(
                      context: context,
                      initialDate: DateTime(2026, 10, 16),
                      firstDate: DateTime(2026, 10, 1),
                      lastDate: DateTime(2027, 12, 31),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        // Day first, as GB English writes it — the order the rest of the app
        // uses ("Fri, 16 Oct").
        expect(find.text('Fri 16 Oct'), findsOneWidget);
        expect(find.text('Fri, Oct 16'), findsNothing);
      },
    );
  });

  group('found on the phone walk (15 Oct)', () {
    testWidgets('typing a question keeps the same search field, focused — '
        'the heading folding must not rebuild it', (WidgetTester tester) async {
      await tester.runAsync(
        () => company('CoolAir Services', 'AC servicing before summer'),
      );
      await pumpHome(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final EditableTextState before = tester.state<EditableTextState>(
        find.byType(EditableText),
      );

      // The first letter is what folds the heading.
      await tester.enterText(find.byType(TextField), 'W');
      await tester.pump(AppMotion.normal);
      await tester.pump(AppMotion.normal);
      final EditableTextState after = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(
        identical(before, after),
        isTrue,
        reason: 'a rebuilt field drops the keyboard mid-word',
      );
      expect(after.widget.focusNode.hasFocus, isTrue);

      await tester.enterText(find.byType(TextField), 'When does it end');
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        identical(
          before,
          tester.state<EditableTextState>(find.byType(EditableText)),
        ),
        isTrue,
      );
      await unmount(tester);
    });

    testWidgets("a receipt's note suggests a receipt's kind of note", (
      WidgetTester tester,
    ) async {
      late int id;
      await tester.runAsync(() async {
        id = await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(
                imagePath: '/nonexistent/r.jpg',
                capturedAt: DateTime(2026, 10, 12),
                type: const Value<CardType>(CardType.receipt),
                title: const Value<String?>('Shwapno'),
              ),
            );
      });
      await pumpRouted(tester, CardDetailScreen(cardId: id));
      await tester.tap(find.text('WHY YOU SAVED THIS'));
      await tester.pumpAndSettle();
      expect(find.text('new office chair, for home'), findsOneWidget);
      expect(
        find.text('cheap t-shirt printing, did our fest shirts'),
        findsNothing,
      );
      await unmount(tester);
    });
  });

  testWidgets('a tall paper does not keep a blurred copy of itself down '
      'its sides: the stand-in goes at the first frame', (
    WidgetTester tester,
  ) async {
    // A receipt's shape: much taller than the card-shaped box.
    final Uint8List tall = Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 120)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 160,
            child: StandInImage(
              image: MemoryImage(tall),
              standIn: Container(key: const Key('stand-in')),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('stand-in')),
      findsOneWidget,
      reason: 'before the photograph is decoded',
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('stand-in')),
      findsNothing,
      reason: 'gone once the photograph has its first frame',
    );
  });

  group('found on the phone walk, round two (15 Oct)', () {
    // Measured with the app's own font: the test default draws every letter
    // as a wide square, so no real sentence fits where it fits on a phone.
    setUpAll(() async {
      final FontLoader archivo = FontLoader('Archivo')
        ..addFont(
          Future<ByteData>.value(
            ByteData.sublistView(
              File('assets/fonts/Archivo.ttf').readAsBytesSync(),
            ),
          ),
        );
      await archivo.load();
    });

    testWidgets("home's receipts row shows its whole sentence at phone width", (
      WidgetTester tester,
    ) async {
      final DateTime today = DateTime.now();
      final String day =
          '${today.day.toString().padLeft(2, '0')}/'
          '${today.month.toString().padLeft(2, '0')}/${today.year}';
      await tester.runAsync(() async {
        final int id = await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(
                imagePath: '/nonexistent/r.jpg',
                capturedAt: today,
                type: const Value<CardType>(CardType.receipt),
                title: const Value<String?>('Star Tech'),
              ),
            );
        final CardRepository cards = CardRepository(db);
        await cards.addField(
          cardId: id,
          fieldKey: ReceiptKeys.total,
          value: 'BDT 78,500.00',
        );
        await cards.addField(
          cardId: id,
          fieldKey: ReceiptKeys.purchaseDate,
          value: day,
        );
      });
      await pumpHome(tester);
      final Finder row = find.text('BDT 78,500.00 in receipts this month');
      expect(row, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(row).didExceedMaxLines,
        isFalse,
        reason: 'it was cut to "BDT 78,500.00 in receipts this m…"',
      );
      await unmount(tester);
    });

    testWidgets('back from the scanner, the search field does not raise the '
        'keyboard by itself', (WidgetTester tester) async {
      await tester.runAsync(
        () => company('CoolAir Services', 'AC servicing before summer'),
      );
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: Routes.capture,
            builder: (_, _) => const Scaffold(body: Text('scanner')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
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
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('scanner'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isFalse,
      );
      await unmount(tester);
    });
  });
}
