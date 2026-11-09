import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_reader.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/card_detail_screen.dart';
import 'package:recallos/features/cards/presentation/widgets/editable_field_list.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';
import 'package:recallos/features/warranty/data/purchase_links.dart';
import 'package:recallos/features/warranty/data/purchase_papers.dart';
import 'package:recallos/features/warranty/presentation/purchase_papers_sheet.dart';

import '../support/fake_notification_port.dart';
import '../support/ocr_layout.dart';

/// B3's export: a receipt or warranty, and the paper confirmed to belong with
/// it, shared after a preview of everything that leaves the phone, with every
/// value marked printed, the owner's own, or calculated.
void main() {
  late AppDatabase db;
  late CardRepository cards;
  late PurchaseLinks links;
  late Directory dir;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    links = PurchaseLinks(db);
    cards = CardRepository(db, purchases: links);
    dir = Directory.systemTemp.createTempSync('papers_test');
  });
  tearDown(() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// A photograph on disk, standing in for a sealed one.
  String photo(String name) {
    final File f = File(p.join(dir.path, name))
      ..writeAsBytesSync(<int>[1, 2, 3, name.length]);
    return f.path;
  }

  Future<int> store(
    List<OcrBlock> blocks,
    CardType type, {
    required String imagePath,
  }) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: imagePath,
            capturedAt: DateTime(2026, 10, 12),
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

  Future<int> receipt({String? imagePath}) => store(
    paper(<Object>[
      'STAR TECH & ENGINEERING LTD',
      'Invoice No: ST-2026-0412',
      'Date: 12/10/2026',
      ('HP 15s-fq5111TU Laptop', '78,500.00'),
      'S/N: 5CD3281XYZ',
      ('Grand Total', '78,500.00'),
    ]),
    CardType.receipt,
    imagePath: imagePath ?? photo('receipt.jpg'),
  );

  Future<int> warranty() => store(
    paper(<Object>[
      'HP',
      'WARRANTY CARD',
      'Product: Laptop',
      'Model: 15s-fq5111TU',
      'Serial No: 5CD3281XYZ',
      'Warranty Period: 2 Years from the date of purchase',
    ]),
    CardType.warrantyCard,
    imagePath: photo('warranty.jpg'),
  );

  PurchasePapersReader reader() =>
      PurchasePapersReader(db, links, label: fieldLabel);

  Future<void> confirmTheLink() async {
    final ItemLink l = await db.select(db.itemLinks).getSingle();
    await links.confirm(l.id);
  }

  SharedValue valueOf(SharedPaper paper, String label) =>
      paper.values.firstWhere((SharedValue v) => v.label == label);

  group('what is shared', () {
    test(
      'a warranty brings its confirmed receipt, every value labelled',
      () async {
        final int r = await receipt();
        final int w = await warranty();
        await confirmTheLink();

        final PurchasePapers papers = (await reader().read(
          w,
          order: fieldKeysFor,
        ))!;
        expect(papers.papers.map((SharedPaper s) => s.cardId), <int>[w, r]);
        final SharedPaper wp = papers.papers.first;
        final SharedPaper rp = papers.papers.last;
        expect(wp.kind, 'Warranty');
        expect(rp.kind, 'Receipt');

        expect(valueOf(wp, 'Serial or IMEI').value, '5CD3281XYZ');
        expect(valueOf(wp, 'Serial or IMEI').source, 'on the warranty');
        // Worked out, and said so — with the working beside it.
        expect(valueOf(wp, 'Expires').source, 'calculated');
        expect(wp.working, contains('Calculated from the receipt'));
        expect(valueOf(rp, 'Shop').source, 'on the receipt');
        expect(papers.linkReasons, contains('Serial 5CD3281XYZ is on both'));
        expect(papers.attachments.map((SharedPhoto s) => s.name), <String>[
          'Warranty - HP Laptop.jpg',
          'Receipt - STAR TECH & ENGINEERING LTD.jpg',
        ]);

        final String note = papers.summary(sharedOn: DateTime(2026, 11, 8));
        expect(note, contains('Shared from RecallOS on 8 Nov 2026.'));
        expect(note, contains('Serial or IMEI: 5CD3281XYZ (on the warranty)'));
        expect(note, contains('Expires: 11 Oct 2028 (calculated)'));
        expect(
          note,
          contains(
            "How the end is known: Calculated from the receipt's purchase "
            'date, 12 Oct 2026, plus 2 years.',
          ),
        );
        expect(note, contains('not a statement from the shop or the maker'));
      },
    );

    test('what the owner checked says so', () async {
      final int r = await receipt();
      final CardField total =
          (await (db.select(
                db.cardFields,
              )..where(($CardFieldsTable f) => f.cardId.equals(r))).get())
              .firstWhere((CardField f) => f.fieldKey == ReceiptKeys.total);
      await cards.updateField(fieldId: total.id, value: '78,500.00');

      final PurchasePapers papers = (await reader().read(r))!;
      expect(valueOf(papers.papers.single, 'Total').source, 'you confirmed');
    });

    test('a suggestion is not a fact: the receipt stays behind', () async {
      await receipt();
      final int w = await warranty();

      final PurchasePapers papers = (await reader().read(w))!;
      expect(papers.papers, hasLength(1));
      expect(papers.linkReasons, isEmpty);
    });

    test(
      'a business card, or a paper in the bin, has nothing to share',
      () async {
        final int card = await store(
          paper(<Object>['Rahim Uddin', 'Sales Manager', '01711-223344']),
          CardType.visitingCard,
          imagePath: photo('card.jpg'),
        );
        expect(await reader().read(card), isNull);

        final int r = await receipt();
        await cards.softDelete(r);
        expect(await reader().read(r), isNull);
      },
    );

    test('the files: the note and each photograph, opened', () async {
      final int r = await receipt();
      final int w = await warranty();
      await confirmTheLink();
      final PurchasePapers papers = (await reader().read(w))!;

      final Directory out = Directory(p.join(dir.path, 'outbox'))..createSync();
      final PapersShare share = PapersShare(
        openPhoto: (String path) async =>
            Uint8List.fromList(<int>[9, ...File(path).readAsBytesSync()]),
        outbox: () async => out,
      );
      final List<File> files = await share.writeFiles(
        papers,
        DateTime(2026, 11, 8),
      );
      expect(files.map((File f) => p.basename(f.path)), <String>[
        'HP Laptop.txt',
        'Warranty - HP Laptop.jpg',
        'Receipt - STAR TECH & ENGINEERING LTD.jpg',
      ]);
      expect(files.first.readAsStringSync(), contains('RECEIPT · STAR TECH'));
      // Opened, not copied: what leaves is what openPhoto gave.
      expect(files[1].readAsBytesSync().first, 9);
      expect(r, isPositive);
    });

    test('a photograph gone from the phone is listed, not attached', () async {
      final int r = await receipt(imagePath: p.join(dir.path, 'gone.jpg'));
      final PurchasePapers papers = (await reader().read(r))!;

      expect(papers.attachments, isEmpty);
      expect(papers.papers.single.photos.single.path, isNull);
      expect(
        papers.summary(sharedOn: DateTime(2026, 11, 8)),
        contains('Not attached (no longer on the phone)'),
      );
    });
  });

  group('on the card screen', () {
    late FakePort port;
    setUp(() => port = FakePort()..allowed = true);

    Future<FakeShare> pump(
      WidgetTester tester,
      int cardId, {
      PapersShareResult result = PapersShareResult.shared,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final FakeShare share = FakeShare(result);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notificationPortProvider.overrideWithValue(port),
            papersShareProvider.overrideWithValue(share),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: CardDetailScreen(cardId: cardId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return share;
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('Share opens the preview, and Share hands it over', (
      WidgetTester tester,
    ) async {
      late int w;
      await tester.runAsync(() async {
        await receipt();
        w = await warranty();
        await confirmTheLink();
      });
      final FakeShare share = await pump(tester, w);

      await tester.tap(find.bySemanticsLabel('Share the papers'));
      await tester.pumpAndSettle();
      expect(find.text('Share these papers?'), findsOneWidget);
      expect(
        find.textContaining('leave the phone unencrypted'),
        findsOneWidget,
      );
      // Below the warranty, as a person would find it: by scrolling.
      await tester.scrollUntilVisible(
        find.textContaining('STAR TECH & ENGINEERING LTD.jpg'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('RECEIPT'), findsOneWidget);
      expect(find.text('STAR TECH & ENGINEERING LTD'), findsWidgets);
      expect(share.shared, isNull, reason: 'nothing leaves before Share');

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(share.shared?.papers, hasLength(2));
      expect(find.text('Share these papers?'), findsNothing);
      expect(find.text('Handed to the app you chose.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a failed share says so, and keeps the sheet', (
      WidgetTester tester,
    ) async {
      late int r;
      await tester.runAsync(() async => r = await receipt());
      await pump(tester, r, result: PapersShareResult.failed);

      await tester.tap(find.bySemanticsLabel('Share the papers'));
      await tester.pumpAndSettle();
      expect(find.text('Share this paper?'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(
        find.text('That did not work. Nothing was shared.'),
        findsOneWidget,
      );
      expect(find.text('Share this paper?'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a business card has no share button', (
      WidgetTester tester,
    ) async {
      late int card;
      await tester.runAsync(() async {
        card = await store(
          paper(<Object>['Rahim Uddin', 'Sales Manager', '01711-223344']),
          CardType.visitingCard,
          imagePath: photo('card.jpg'),
        );
      });
      await pump(tester, card);
      expect(find.bySemanticsLabel('Share the papers'), findsNothing);
      expect(find.bySemanticsLabel('Delete'), findsOneWidget);
      await unmount(tester);
    });
  });
}

class FakeShare extends PapersShare {
  FakeShare(this.result) : super(openPhoto: (_) async => Uint8List(0));

  final PapersShareResult result;
  PurchasePapers? shared;

  @override
  Future<PapersShareResult> share(PurchasePapers papers) async {
    shared = papers;
    return result;
  }
}
