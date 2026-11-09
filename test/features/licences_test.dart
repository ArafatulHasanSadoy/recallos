import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/settings/data/licences.dart';
import 'package:recallos/features/settings/presentation/licences_screen.dart';
import 'package:recallos/features/settings/presentation/settings_screen.dart';
import 'package:recallos/router.dart';

/// Settings → About → Licences.
///
/// The two fonts and the search model are files copied into `assets/`, not
/// packages, so nothing puts their licences in front of anyone unless the app
/// registers them. Their licences require every copy to carry the notice.
void main() {
  test(
    'the fonts and the search model are registered with their notices',
    () async {
      LicenseRegistry.reset();
      addTearDown(LicenseRegistry.reset);
      registerBundledLicences();

      final List<LicencedWork> works = await collectLicences(
        LicenseRegistry.licenses,
      );
      String textOf(String name) => works
          .firstWhere((LicencedWork w) => w.name == name)
          .licences
          .expand((List<LicenseParagraph> l) => l)
          .map((LicenseParagraph p) => p.text)
          .join('\n');

      expect(
        works.map((LicencedWork w) => w.name),
        containsAll(<String>['Archivo', 'Instrument Serif', 'potion-base-8M']),
      );
      expect(textOf('Archivo'), contains('Copyright 2020 The Archivo Project'));
      expect(textOf('Archivo'), contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(
        textOf('Instrument Serif'),
        contains('Copyright 2022 The Instrument Serif Project Authors'),
      );
      expect(textOf('potion-base-8M'), contains('MIT License'));

      // Headings stand on their own, not run into the sentence below them.
      final List<String> archivo = works
          .firstWhere((LicencedWork w) => w.name == 'Archivo')
          .licences
          .single
          .map((LicenseParagraph p) => p.text)
          .toList();
      for (final String heading in <String>[
        'PREAMBLE',
        'DEFINITIONS',
        'PERMISSION & CONDITIONS',
        'TERMINATION',
        'DISCLAIMER',
      ]) {
        expect(archivo, contains(heading));
      }
    },
  );

  test('works are listed A to Z, and a shared entry under each name', () async {
    final List<LicencedWork> works = await collectLicences(
      Stream<LicenseEntry>.fromIterable(<LicenseEntry>[
        const LicenseEntryWithLineBreaks(<String>['zeta'], 'Z'),
        const LicenseEntryWithLineBreaks(<String>['Alpha', 'beta'], 'AB'),
        const LicenseEntryWithLineBreaks(<String>['Alpha'], 'A2'),
      ]),
    );
    expect(works.map((LicencedWork w) => w.name), <String>[
      'Alpha',
      'beta',
      'zeta',
    ]);
    expect(works.first.licences, hasLength(2));
  });

  testWidgets('the About row opens the list, and a row opens its licence', (
    WidgetTester tester,
  ) async {
    final List<LicencedWork> works = await collectLicences(bundledLicences());
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Column(children: <Widget>[LicencesRow()])),
        ),
        GoRoute(
          path: Routes.licences,
          builder: (_, _) => const LicencesScreen(),
        ),
        GoRoute(
          path: '/licences/:name',
          builder: (_, GoRouterState state) =>
              LicenceScreen(name: state.pathParameters['name'] ?? ''),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [licencesProvider.overrideWith((Ref ref) async => works)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.text('3 IN THIS BUILD'), findsOneWidget);
    expect(find.text('potion-base-8M'), findsOneWidget);

    // A name with a space survives the trip through the path.
    await tester.tap(find.text('Instrument Serif'));
    await tester.pumpAndSettle();
    expect(find.text('Instrument Serif'), findsOneWidget);
    expect(
      find.textContaining('The Instrument Serif Project Authors'),
      findsOneWidget,
    );
    expect(find.textContaining('could not be found'), findsNothing);
  });
}
