import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/platform/external_opener.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';

import '../support/fake_notification_port.dart';

/// Call, WhatsApp and Email on a card, tapped the way a person taps them.
///
/// The record is what people search ranks by, so the test is about the
/// link the other app was handed and the row written — and about nothing
/// being written when no app took the link.
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

  Future<int> seed() async {
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
    await field(FieldKeys.phone, '01812-445566', '+8801812445566');
    await field(FieldKeys.email, 'nusrat@bengalevents.com');
    return id;
  }

  Future<void> pump(WidgetTester tester, int cardId) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          notificationPortProvider.overrideWithValue(FakePort()),
          externalOpenerProvider.overrideWithValue((Uri u) async {
            opened.add(u);
            return openWorks;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CardDetailScreen(cardId: cardId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final Finder f = find.text(label);
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<List<Interaction>> reached() async =>
      (await db.select(db.interactions).get())
          .where((Interaction i) => i.kind != InteractionKind.scanned)
          .toList();

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('Call hands the number to the dialler and records it', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    await pump(tester, id);

    await tap(tester, 'Call');

    expect(opened.single.scheme, 'tel');
    expect(opened.single.path, '+8801812445566');
    final List<Interaction> rows =
        await tester.runAsync(reached) ?? <Interaction>[];
    expect(rows.single.kind, InteractionKind.callOpened);
    expect(rows.single.subjectId, id);
    await unmount(tester);
  });

  testWidgets('WhatsApp and Email are recorded as opened, each its own kind', (
    WidgetTester tester,
  ) async {
    final int id = await seed();
    await pump(tester, id);

    await tap(tester, 'WhatsApp');
    await tap(tester, 'Email');

    expect(opened.map((Uri u) => u.scheme), <String>['https', 'mailto']);
    final List<Interaction> rows =
        await tester.runAsync(reached) ?? <Interaction>[];
    expect(rows.map((Interaction i) => i.kind), <InteractionKind>[
      InteractionKind.messageOpened,
      InteractionKind.emailOpened,
    ]);
    await unmount(tester);
  });

  testWidgets('nothing is recorded when no app could take the link', (
    WidgetTester tester,
  ) async {
    openWorks = false;
    final int id = await seed();
    await pump(tester, id);

    await tap(tester, 'Call');

    expect(opened, hasLength(1));
    expect(await tester.runAsync(reached), isEmpty);
    expect(
      find.textContaining('Nothing on this phone can open'),
      findsOneWidget,
    );
    await unmount(tester);
  });
}
