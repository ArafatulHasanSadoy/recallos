import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/cards/presentation/widgets/editable_field_list.dart';

/// Layout-only tests for the field editor.
///
/// These build [CardDetail] out of plain row objects rather than a database,
/// so nothing here touches drift — whose async does not survive the fake clock
/// `testWidgets` runs under.
void main() {
  final DateTime now = DateTime(2026, 8, 15);

  CardField field(
    int id,
    String key,
    String value, {
    String? issue,
    bool verified = false,
  }) =>
      CardField(
        id: id,
        cardId: 1,
        fieldKey: key,
        value: value,
        source: FactSource.printed,
        verifiedByUser: verified,
        validationIssue: issue,
        valueKind: FieldValueKind.text,
        regionRect: '10,10,310,50',
        createdAt: now,
        updatedAt: now,
      );

  OcrBlockRow blockRow(int id, String text, {int? fieldId}) => OcrBlockRow(
        id: id,
        cardId: 1,
        blockText: text,
        rect: '10,${id * 40},310,${id * 40 + 30}',
        confidence: 0.9,
        script: 'latin',
        fieldId: fieldId,
        orderIndex: id,
      );

  /// The card from the device: a shop card with two numbers and a long email.
  CardDetail detail() => CardDetail(
        card: CardRow(
          id: 1,
          type: CardType.unknown,
          imagePath: '/tmp/cards/card_1.jpg',
          extractionStatus: ExtractionStatus.complete,
          capturedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        fields: <CardField>[
          field(1, FieldKeys.company, 'TARGET CENTER'),
          field(2, FieldKeys.phone, '01747157741', issue: 'digit_restored'),
          field(3, FieldKeys.phone, '01977826596'),
          field(4, FieldKeys.email, 'targetbrand2015@gmail.com'),
          field(5, FieldKeys.address,
              'Shop No:300, Dhaka New Market, Dhaka-1205, Bangladesh'),
        ],
        notes: const <Note>[],
        blocks: <OcrBlockRow>[
          blockRow(1, 'TARGET CENTER', fieldId: 1),
          blockRow(2, 'Shop No:300, Dhaka New Market, Dhaka-1205', fieldId: 5),
          blockRow(3, 'Cell phone: +88 01747-157741, 01977826596', fieldId: 2),
          blockRow(4, 'E-mail: targetbrand2015@gmail.com', fieldId: 4),
        ],
      );

  Future<void> pump(WidgetTester tester) async {
    // A real phone's logical size, because the bug is about running out of it.
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                EditableFieldList(
                  detail: detail(),
                  onRegionChanged: (String? _) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the collapsed list lays out without overflowing', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expanded editor lays out without overflowing', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('TARGET CENTER'));
    await tester.pumpAndSettle();

    // Everything the editor offers has to actually be on screen and separate.
    expect(find.text('What is this?'), findsOneWidget);
    expect(find.text('Or take it from the card'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the expanded editor is given the height it asks for', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('TARGET CENTER'));
    await tester.pumpAndSettle();

    // Role chips, a text field, block chips and three buttons do not fit in a
    // couple of hundred pixels. If the editor is shorter than this it has been
    // squashed and its children are painting over each other.
    final double height = tester.getSize(find.byType(TextField)).height +
        tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom -
        tester.getRect(find.text('What is this?')).top;
    expect(height, greaterThan(400));
  });

  testWidgets('Save does not swallow the whole action row', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('TARGET CENTER'));
    await tester.pumpAndSettle();

    // The theme's `Size.fromHeight(52)` is an infinite minimum width, so a
    // filled button left to itself takes the entire line and pushes Cancel and
    // Remove onto their own rows.
    final double save =
        tester.getSize(find.widgetWithText(FilledButton, 'Save')).width;
    expect(save, lessThan(200));

    // Cancel and Save belong on the same line.
    expect(
      tester.getRect(find.widgetWithText(TextButton, 'Cancel')).center.dy,
      closeTo(
        tester.getRect(find.widgetWithText(FilledButton, 'Save')).center.dy,
        4,
      ),
    );
  });
}
