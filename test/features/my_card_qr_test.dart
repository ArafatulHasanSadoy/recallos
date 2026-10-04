import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/profile/data/my_card_qr.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';
import 'package:recallos/features/profile/presentation/my_card_qr_screen.dart';
import 'package:recallos/features/profile/presentation/my_card_screen.dart';
import 'package:recallos/features/profile/presentation/widgets/my_card_qr_code.dart';
import 'package:recallos/router.dart';

import '../support/qr_decode.dart';

/// A4: your card as a QR code.
///
/// The failure that matters is a code that looks right and does not scan, or
/// scans to the wrong lines — invisible to any assertion about widgets. So the
/// code is decoded from the painted pixels and compared with what was meant,
/// and the switches are tested by what the code carries afterwards.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> makeMyCard({
    String name = 'Arafat Hasan',
  }) => ProfileRepository(db).save(
    ProfileDraft(
      tagline: 'Business cards you can search',
      entries: <ProfileEntry>[
        ProfileEntry(fieldKey: FieldKeys.personName, value: name),
        const ProfileEntry(fieldKey: FieldKeys.designation, value: 'Founder'),
        const ProfileEntry(fieldKey: FieldKeys.company, value: 'RecallOS'),
        const ProfileEntry(fieldKey: FieldKeys.phone, value: '01711-363991'),
        const ProfileEntry(
          fieldKey: FieldKeys.email,
          value: 'hello@recallos.app',
        ),
        const ProfileEntry(
          fieldKey: FieldKeys.address,
          value: 'House 12, Road 5, Dhanmondi, Dhaka',
        ),
      ],
    ),
  );

  Future<ProfileDetail> mine() async =>
      (await ProfileRepository(db).watchDefault().first)!;

  group('what the code carries', () {
    test('everything but the address, until you choose', () async {
      await makeMyCard();
      final ProfileDetail d = await mine();
      final String vcard = myCardQrPayload(d, defaultQrHidden(d));

      expect(vcard, contains('FN:Arafat Hasan'));
      expect(vcard, contains('TITLE:Founder'));
      expect(vcard, contains('ORG:RecallOS'));
      expect(vcard, contains('TEL;'));
      expect(vcard, contains('EMAIL;TYPE=INTERNET:hello@recallos.app'));
      expect(vcard, contains('NOTE:Business cards you can search'));
      expect(vcard, isNot(contains('ADR')));
    });

    test('a line switched off is not on it; the name always is', () async {
      await makeMyCard();
      final ProfileDetail d = await mine();
      final Set<String> every = <String>{
        for (final QrLine l in qrLines(d)) l.key,
      };
      final String vcard = myCardQrPayload(d, every);

      expect(vcard, contains('FN:Arafat Hasan'));
      for (final String gone in <String>[
        'TEL',
        'EMAIL',
        'ORG',
        'NOTE',
        'ADR',
      ]) {
        expect(vcard, isNot(contains(gone)), reason: '$gone was switched off');
      }
    });
  });

  testWidgets('the painted code scans back to exactly that vCard', (
    WidgetTester tester,
  ) async {
    // Latin names only. The code carries UTF-8 and a Bangla card scans
    // correctly — checked with macOS's own QR detector, the iPhone camera's —
    // but zxing2 0.2.4, the only pure-Dart reader, cannot read some codes
    // that *its own encoder* makes from Bangla bytes, so it is no judge of
    // them.
    for (final String name in <String>['Arafat Hasan', 'Nusrat Jahan']) {
      final String vcard = (await tester.runAsync(() async {
        await db.delete(db.profileFields).go();
        await db.delete(db.profiles).go();
        await makeMyCard(name: name);
        final ProfileDetail d = await mine();
        return myCardQrPayload(d, defaultQrHidden(d));
      }))!;

      // Whole pixels per square, as the screen draws it (see MyCardQrCode).
      final QrCode code = myCardQrCode(vcard)!;
      final ByteData png = (await tester.runAsync<ByteData?>(
        () => myCardQrPainter(
          code,
        ).toImageData(code.moduleCount * 10.0, format: ui.ImageByteFormat.png),
      ))!;
      expect(decodeQrPng(png.buffer.asUint8List()), vcard, reason: name);
    }
  });

  test('a card too long for one code says so instead of drawing one', () {
    expect(myCardQrCode('x' * 4000), isNull);
    expect(myCardQrCode('BEGIN:VCARD'), isA<QrCode>());
  });

  group('on the screen', () {
    Future<void> pumpQr(WidgetTester tester) async {
      // Tall enough for the code and every switch at once: the list is lazy,
      // and scrolling down to a switch would dispose the code being checked.
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MyCardQrScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String shown(WidgetTester tester) =>
        tester.widget<MyCardQrCode>(find.byType(MyCardQrCode)).payload;

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('switching the address on puts it on the code, and stays', (
      WidgetTester tester,
    ) async {
      await makeMyCard();
      await pumpQr(tester);
      expect(shown(tester), isNot(contains('ADR')));

      final Finder address = find.text('House 12, Road 5, Dhanmondi, Dhaka');
      await tester.ensureVisible(address);
      await tester.pumpAndSettle();
      await tester.tap(address);
      await tester.pumpAndSettle();
      expect(shown(tester), contains('ADR;TYPE=WORK:;;House 12'));

      // Leave and come back: the choice is remembered.
      await unmount(tester);
      await pumpQr(tester);
      expect(shown(tester), contains('ADR;TYPE=WORK:;;House 12'));

      await tester.ensureVisible(find.text('01711-363991'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('01711-363991'));
      await tester.pumpAndSettle();
      expect(shown(tester), isNot(contains('TEL')));
      await unmount(tester);
    });

    testWidgets('with no card yet, it goes to where one is made', (
      WidgetTester tester,
    ) async {
      await pumpQr(tester);
      expect(find.byType(MyCardQrCode), findsNothing);
      expect(find.text('Make my card'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('My Card opens it', (WidgetTester tester) async {
      await makeMyCard();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const MyCardScreen()),
          GoRoute(
            path: Routes.myCardQr,
            builder: (_, _) => const MyCardQrScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder button = find.text('Show as a QR code');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(MyCardQrCode), findsOneWidget);
      expect(shown(tester), contains('FN:Arafat Hasan'));
      await unmount(tester);
    });
  });
}
