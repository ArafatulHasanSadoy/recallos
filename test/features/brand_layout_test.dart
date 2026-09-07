import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/core/ui/brand.dart';
import 'package:recallos/features/settings/presentation/onboarding_screen.dart';

void main() {
  for (final bool dark in <bool>[false, true]) {
    testWidgets('branded onboarding fits compact phone, dark=$dark', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const OnboardingScreen(),
          ),
        ),
      );
      for (int page = 0; page < 3; page++) {
        expect(tester.takeException(), isNull);
        expect(find.byType(RecallBrand), findsOneWidget);
        expect(find.text('Skip').hitTestable(), findsOneWidget);
        final String next = page == 2 ? 'Scan the first card' : 'Next';
        expect(find.text(next).hitTestable(), findsOneWidget);
        if (page < 2) {
          await tester.tap(find.text(next));
          await tester.pumpAndSettle();
        }
      }
    });
  }
}
