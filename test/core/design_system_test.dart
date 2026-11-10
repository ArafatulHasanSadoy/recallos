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
      // URI paths use forward slashes on Windows as well as Unix.
      .where((File f) => !f.uri.path.endsWith('core/theme/app_theme.dart'))
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

  test('an Undo bar goes away by itself', () {
    // Flutter now keeps any SnackBar with a button until it is tapped, so an
    // Undo bar sat over every screen after it, for good. Found on a device.
    final RegExp bar = RegExp(r'\bSnackBar\(');
    final List<String> stuck = <String>[];
    for (final File f in sources) {
      final String text = f.readAsStringSync();
      for (final Match m in bar.allMatches(text)) {
        // To the bracket that closes this call.
        int depth = 1;
        int at = m.end;
        while (depth > 0 && at < text.length) {
          final String c = text[at++];
          if ('([{'.contains(c)) depth++;
          if (')]}'.contains(c)) depth--;
        }
        final String body = text.substring(m.end, at);
        if (body.contains('SnackBarAction(') &&
            !body.contains('persist: false')) {
          stuck.add('${f.path}@${m.start}');
        }
      }
    }
    expect(stuck, isEmpty);
  });

  test('a loop goes through AppMotion, so it can hold still', () {
    // `repeat()` is the one animation Flutter does not shorten for Android's
    // *Remove animations*. The theme, which holds `AppMotion.loop`, is the
    // one file these sources leave out.
    expect(hits(r'\.repeat\('), isEmpty);
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
        .where(
          (String h) =>
              !h.contains('Colors.transparent') && !h.contains('Colors.black'),
        )
        .toList();
    expect(named, isEmpty);
  });
}
