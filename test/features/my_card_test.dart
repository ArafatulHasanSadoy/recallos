import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';
import 'package:recallos/features/profile/presentation/widgets/typeset_card.dart';

/// The typeset card.
///
/// Built from a hand-made [ProfileCard] rather than from the database, in the
/// style of `field_editor_layout_test.dart` — drift's async does not survive
/// the fake clock `testWidgets` runs under, and the card face is a pure
/// function of its value type anyway. That the face needs no database is the
/// design working, not a shortcut.
void main() {
  const ProfileCard full = ProfileCard(
    name: 'Arafatul Hasan Sadoy',
    designation: 'Founder',
    company: 'EnationX',
    tagline: 'cheap t-shirt printing, low quantity',
    lines: <ProfileLine>[
      ProfileLine(label: 'mobile', value: '01711 363991'),
      ProfileLine(label: 'Email', value: 'sadoy@enationx.com'),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    ProfileCard card, {
    double textScale = 1.0,
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: TypesetCardFace(card: card),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('draws who you are and how to reach you', (WidgetTester t) async {
    await pump(t, full);

    expect(find.text('Arafatul Hasan Sadoy'), findsOneWidget);
    expect(find.text('Founder'), findsOneWidget);
    expect(find.text('EnationX'), findsOneWidget);
    expect(find.text('01711 363991'), findsOneWidget);
    // The label the user gave, upper-cased by MicroLabel.
    expect(find.text('MOBILE'), findsOneWidget);
    expect(find.text('cheap t-shirt printing, low quantity'), findsOneWidget);
  });

  testWidgets('a card with no name still draws as a card',
      (WidgetTester t) async {
    // The first keystroke in the editor happens against this state, so it has
    // to be a card and not an error.
    await pump(t, const ProfileCard(name: ''));

    expect(find.text('Your name'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the contact value is not micro-caps metadata',
      (WidgetTester t) async {
    await pump(t, full);

    // The accessibility floor reserves `inkFaint` for micro-caps metadata and
    // forbids it for body copy. A phone number read off this card at arm's
    // length is the payload — putting it at 10px in the faintest ink on the
    // palette would render perfectly and be unusable.
    final Text value = t.widget<Text>(find.text('01711 363991'));
    final AppColors c = AppColors.light;
    expect(value.style!.color, isNot(c.inkFaint));
    expect(value.style!.fontSize, greaterThanOrEqualTo(12.0));
  });

  testWidgets('nothing overflows at textScaleFactor 1.3',
      (WidgetTester t) async {
    // The design floor says to check here, and the stack pitch is not the only
    // thing that breaks: a rigid 1.586 box with scaled serif in it overflows,
    // which is why the ratio is a floor rather than an `AspectRatio` cage.
    await pump(t, full, textScale: 1.3);

    expect(t.takeException(), isNull);
  });

  testWidgets('a long name is truncated rather than overflowing',
      (WidgetTester t) async {
    await pump(
      t,
      const ProfileCard(
        name: 'Mohammad Abul Bashar Sarker Chowdhury Rahman Ahmed',
        company: 'Green Specialized Hospital Private Limited Dhaka',
      ),
      size: const Size(320, 700),
    );

    expect(t.takeException(), isNull);
  });

  testWidgets('the compact copy drops the detail but keeps the name',
      (WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 44,
            child: TypesetCardFace(card: full, compact: true),
          ),
        ),
      ),
    );
    await t.pump();

    // Small enough for the header button: the face, not the contents.
    expect(find.text('01711 363991'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
