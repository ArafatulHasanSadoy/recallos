import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/settings/data/app_info.dart';
import 'package:recallos/features/settings/presentation/settings_screen.dart';

/// Settings → About: what a closed tester needs to file a useful report.
///
/// Every row here is tested by its tap, not by its label. A version row that
/// copied nothing, or a feedback row that found no email app and said nothing,
/// would pass any assertion about what is on screen and still be a dead tap.
void main() {
  const AppVersion version = AppVersion(
    name: '1.0.0',
    code: 7,
    device: 'realme RMX3612',
    android: '14',
  );

  Future<void> pump(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((Ref ref) async => version),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Column(children: <Widget>[row])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the version row shows the build and copies it on tap', (
    WidgetTester tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester, const VersionRow());
    expect(find.textContaining('1.0.0 (7)'), findsOneWidget);

    await tester.tap(find.text('Version'));
    await tester.pumpAndSettle();

    expect(copied, contains('1.0.0 (7)'));
    expect(copied, contains('RMX3612'));
    expect(find.textContaining('Copied'), findsOneWidget);
  });

  testWidgets('feedback opens an email with the build already in it', (
    WidgetTester tester,
  ) async {
    Uri? opened;
    await pump(
      tester,
      FeedbackRow(
        launch: (Uri uri) async {
          opened = uri;
          return true;
        },
      ),
    );

    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(opened, isNotNull);
    expect(opened!.scheme, 'mailto');
    expect(opened!.path, kFeedbackEmail);
    final String body = Uri.decodeComponent(opened.toString());
    expect(body, contains('1.0.0 (7)'));
    expect(body, contains('Android 14'));
    // Spaces must arrive as spaces, not the "+" Uri.queryParameters writes.
    expect(opened.toString(), isNot(contains('+')));
  });

  testWidgets('with no email app, the row says where to write instead', (
    WidgetTester tester,
  ) async {
    await pump(tester, FeedbackRow(launch: (Uri _) async => false));

    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(find.textContaining(kFeedbackEmail), findsOneWidget);
  });

  testWidgets('the privacy policy opens the published page', (
    WidgetTester tester,
  ) async {
    Uri? opened;
    await pump(
      tester,
      PrivacyPolicyRow(
        launch: (Uri uri) async {
          opened = uri;
          return true;
        },
      ),
    );

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(opened, kPrivacyPolicyUrl);
  });

  testWidgets('with no browser, the row shows the address', (
    WidgetTester tester,
  ) async {
    await pump(tester, PrivacyPolicyRow(launch: (Uri _) async => false));

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('arafatulhasansadoy.github.io'), findsOneWidget);
  });
}
