import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/settings/presentation/settings_screen.dart';

/// The settings pickers mark the choice in use.
///
/// Found on the phone: with the app dark, Appearance listed "Follow system",
/// "Always light" and "Always dark" with nothing to say which was doing it.
void main() {
  /// Opens the Appearance picker with [current] in use; [picked] gets what
  /// it returns.
  Future<void> open(
    WidgetTester t,
    ThemeMode current,
    void Function(ThemeMode?) picked,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => picked(
                  await showModalBottomSheet<ThemeMode>(
                    context: context,
                    builder: (_) => ChoiceSheet<ThemeMode>(
                      title: 'Appearance',
                      current: current,
                      choices: const <(ThemeMode, String, String?)>[
                        (ThemeMode.system, 'Follow system', null),
                        (ThemeMode.light, 'Always light', null),
                        (ThemeMode.dark, 'Always dark', null),
                      ],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  testWidgets('the choice in use is marked, and only that one', (
    WidgetTester t,
  ) async {
    await open(t, ThemeMode.dark, (_) {});

    expect(find.text('IN USE'), findsOneWidget);
    final Finder row = find
        .ancestor(of: find.text('IN USE'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: row, matching: find.text('Always dark')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a choice returns it', (WidgetTester t) async {
    ThemeMode? got;
    await open(t, ThemeMode.system, (ThemeMode? m) => got = m);

    await t.tap(find.text('Always light'));
    await t.pumpAndSettle();

    expect(got, ThemeMode.light);
  });
}
