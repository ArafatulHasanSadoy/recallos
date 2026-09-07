import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the design system against Material creeping back in.
///
/// Three widgets were converted late — the card photo overlay, the field list
/// and the sides view — and every one of them carried the same faults the
/// system exists to remove: a near-white `surfaceContainerHighest` frame
/// around each scan, an `OutlineInputBorder`, Material chips with their own
/// outlines, and spinners. None of that is visible to a widget test, because
/// it all renders perfectly well. It is only wrong.
///
/// So this checks the source instead. It is a blunt instrument and that is the
/// point: a screen that reaches for `colorScheme` is a screen that has stopped
/// using the palette, and it will drift.
void main() {
  final List<File> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where((File f) => !f.path.endsWith('.g.dart'))
      // The theme is where Material is configured, so it is the one place
      // allowed to name Material's own colours.
      .where((File f) => !f.path.endsWith('core/theme/app_theme.dart'))
      .toList();

  /// Lines matching [pattern], ignoring comments — the rules are discussed in
  /// prose all over this codebase, and a doc comment naming `ChoiceChip` is
  /// not a use of it.
  List<String> hits(String pattern) {
    final RegExp re = RegExp(pattern);
    final List<String> found = <String>[];
    for (final File f in sources) {
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        if (re.hasMatch(line)) found.add('${f.path}:${i + 1}  $line');
      }
    }
    return found;
  }

  test('nothing reads colours off the Material scheme', () {
    // `AppColors.of(context)` is what makes dark mode work; a raw
    // `colorScheme` lookup silently opts out of the palette.
    expect(hits(r'colorScheme\.'), isEmpty);
  });

  test('nothing sets type off the Material text theme', () {
    expect(hits(r'textTheme\.'), isEmpty);
  });

  test('rule 1: there is no OutlineInputBorder in the app', () {
    expect(hits('OutlineInputBorder'), isEmpty);
  });

  test('rule 5: there are no spinners and no ink ripples', () {
    expect(hits('CircularProgressIndicator'), isEmpty);
    expect(hits('LinearProgressIndicator'), isEmpty);
    expect(hits(r'InkWell\('), isEmpty);
  });

  test('Material chips are replaced by SelectChip', () {
    expect(hits(r'ChoiceChip\('), isEmpty);
    expect(hits(r'FilterChip\('), isEmpty);
    expect(hits(r'ActionChip\('), isEmpty);
  });

  test('no widget paints a raw Colors.* value', () {
    // Colors.transparent and Colors.black are legitimate for scrims and
    // barriers; a named hue is somebody bypassing the palette.
    final List<String> named = hits(r'(?<![A-Za-z])Colors\.')
        .where((String h) =>
            !h.contains('Colors.transparent') && !h.contains('Colors.black'))
        .toList();
    expect(named, isEmpty);
  });
}
