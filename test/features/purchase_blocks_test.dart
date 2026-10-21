import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';

import '../support/fake_notification_port.dart';
import '../support/ocr_layout.dart';

/// B3 on the card screen, tapped the way a person taps it. Each test ends on
/// what the tap did to the wallet, not only on what is drawn: a button that
/// renders and does nothing would pass an assertion about the screen.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late FakePort port;

  // Dated today, so the calculated end and its reminder are always ahead
  // of whenever the suite runs.
  final DateTime now = DateTime.now();
  final String today =
      '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/${now.year}';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cards = CardRepository(db);
    port = FakePort()..allowed = true;
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
    return id;
  }

  Future<int> receipt() => store(
    paper(<Object>[
      'STAR TECH & ENGINEERING LTD',
      'Invoice No: ST-2026-0412',
      'Date: $today',
      ('HP 15s-fq5111TU Laptop', '78,500.00'),
      'S/N: 5CD3281XYZ',
      ('Grand Total', '78,500.00'),
    ]),
    CardType.receipt,
  );

  Future<int> warranty({String serial = '5CD3281XYZ', String model = '15s'}) =>
      store(
        paper(<Object>[
          'HP',
          'WARRANTY CARD',
          'Product: Laptop',
          'Model: $model-fq5111TU',
          'Serial No: $serial',
          'Warranty Period: 2 Years from the date of purchase',
        ]),
        CardType.warrantyCard,
      );

  Future<ItemLink> theLink() => db.select(db.itemLinks).getSingle();

  Future<void> pump(WidgetTester tester, int cardId) async {
    // Tall enough that every block is built at once: a list scrolled down
    // to a button would otherwise not build the block above it.
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationPortProvider.overrideWithValue(port),
        ],
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

  Future<void> tap(WidgetTester tester, String text) async {
    final Finder f = find.text(text);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('a suggestion asks once, shows its evidence, and Yes links '
      'them', (WidgetTester tester) async {
    await receipt();
    final int w = await warranty();
    await pump(tester, w);

    expect(find.text('COVERED UNTIL'), findsOneWidget);
    expect(find.textContaining('Not known yet'), findsOneWidget);
    expect(find.text('Is this its receipt?'), findsOneWidget);
    expect(find.text('Serial 5CD3281XYZ is on both'), findsOneWidget);
    expect(find.text('STAR TECH & ENGINEERING LTD'), findsOneWidget);

    await tap(tester, 'Yes, link them');

    expect((await theLink()).status, LinkStatus.confirmed);
    expect(find.text('Is this its receipt?'), findsNothing);
    expect(find.text('Unlink'), findsOneWidget);
    expect(
      find.textContaining("Calculated from the receipt's purchase date"),
      findsOneWidget,
    );
    expect(find.textContaining('Reminder 9 AM'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Not this one dismisses it; Undo offers it again', (
    WidgetTester tester,
  ) async {
    await receipt();
    final int w = await warranty();
    await pump(tester, w);

    await tap(tester, 'Not this one');
    expect((await theLink()).status, LinkStatus.dismissed);
    expect(find.text('Is this its receipt?'), findsNothing);
    expect(find.text('Link its receipt'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await theLink()).status, LinkStatus.suggested);
    expect(find.text('Is this its receipt?'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Unlink, then Undo puts it back', (WidgetTester tester) async {
    await receipt();
    final int w = await warranty();
    await pump(tester, w);
    await tap(tester, 'Yes, link them');

    await tap(tester, 'Unlink');
    expect((await theLink()).status, LinkStatus.dismissed);
    expect(find.textContaining('Not known yet'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await theLink()).status, LinkStatus.confirmed);
    expect(find.text('Unlink'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('linked by hand from the picker when nothing printed matches', (
    WidgetTester tester,
  ) async {
    await receipt();
    final int w = await warranty(serial: 'ZZ00000000', model: 'X9');
    expect(await db.select(db.itemLinks).get(), isEmpty);
    await pump(tester, w);

    await tap(tester, 'Link its receipt');
    expect(find.text('Which receipt is it?'), findsOneWidget);
    await tap(tester, 'STAR TECH & ENGINEERING LTD');

    final ItemLink l = await theLink();
    expect(l.status, LinkStatus.confirmed);
    expect(l.reasons, contains('chosen'));
    expect(find.text('You linked these'), findsNothing);
    expect(find.text('Unlink'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('with no receipts saved, the picker says what to do', (
    WidgetTester tester,
  ) async {
    final int w = await warranty();
    await pump(tester, w);
    await tap(tester, 'Link its receipt');
    expect(find.textContaining('No receipts saved yet'), findsOneWidget);
    await tap(tester, 'Cancel');
    expect(await db.select(db.itemLinks).get(), isEmpty);
    await unmount(tester);
  });

  testWidgets('notifications off: the way out, and it is taken', (
    WidgetTester tester,
  ) async {
    port
      ..allowed = false
      ..grantOnAsk = false;
    await receipt();
    final int w = await warranty();
    await pump(tester, w);
    await tap(tester, 'Yes, link them');

    expect(find.textContaining('cannot reach you'), findsOneWidget);
    await tap(tester, 'Turn on notifications');
    expect(port.asked, 1);
    expect(port.settingsOpened, 1, reason: 'refused once, so to settings');
    await unmount(tester);
  });

  testWidgets('notifications on: nothing about them', (
    WidgetTester tester,
  ) async {
    await receipt();
    final int w = await warranty();
    await pump(tester, w);
    await tap(tester, 'Yes, link them');
    expect(find.text('Turn on notifications'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a receipt alone: no warranty block, no "where you met", '
      'and the paper named', (WidgetTester tester) async {
    final int r = await receipt();
    await pump(tester, r);
    expect(find.text('STAR TECH & ENGINEERING LTD'), findsWidgets);
    expect(find.text('ITS WARRANTY'), findsNothing);
    expect(find.text('COVERED UNTIL'), findsNothing);
    expect(find.text('WHERE YOU MET'), findsNothing);
    expect(find.text('ON THE RECEIPT'), findsWidgets);
    expect(find.text('RECEIPT'), findsOneWidget, reason: 'the header');
    expect(find.textContaining('find this receipt later'), findsOneWidget);
    expect(
      find.text('ON THE CARD'),
      findsNothing,
      reason: 'a value read off a receipt says so, heading and chips alike',
    );
    await unmount(tester);
  });

  testWidgets('a receipt with its warranty linked shows it', (
    WidgetTester tester,
  ) async {
    final int r = await receipt();
    await warranty();
    await pump(tester, r);
    expect(find.text('ITS WARRANTY'), findsOneWidget);
    expect(find.text('Is this its warranty?'), findsOneWidget);
    await tap(tester, 'Yes, link them');
    expect((await theLink()).status, LinkStatus.confirmed);
    expect(find.text('HP Laptop'), findsOneWidget);
    await unmount(tester);
  });
}
