import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/profile/data/profile_repository.dart';
import 'package:recallos/features/profile/presentation/profile_editor_screen.dart';
import 'package:recallos/features/profile/presentation/widgets/typeset_card.dart';

/// Setting your own card.
///
/// No database anywhere here, deliberately — the same choice
/// `field_editor_layout_test.dart` documents: drift's async does not survive
/// the fake clock `testWidgets` runs under, and a widget test that waits on it
/// hangs rather than fails. The provider is overridden with a plain stream and
/// the repository with a recorder, which is also the better test: what is under
/// examination here is the form, and the storage has a suite of its own.
///
/// Two assertions are worth more than the rest.
///
/// The **live preview** is the entire justification for this being one screen
/// rather than the bottom sheets the app edits with everywhere else. If typing
/// a name does not change the card above it, the deviation bought nothing.
///
/// The **discard guard on the header chevron** is a bug that would render
/// perfectly. GoRouter's `context.pop()` calls `Navigator.pop`, which is
/// unconditional and walks straight past `PopScope` — so a screen that guards
/// the back *gesture* can still throw an edit away on the back *button*, and an
/// assertion about the gesture alone passes on the broken version.
void main() {
  late _Recorder repo;

  setUp(() => repo = _Recorder());

  Future<void> pump(WidgetTester tester, {ProfileDetail? existing}) async {
    // Phone-shaped. The default 800x600 surface is both wider and much shorter
    // than any phone, which puts a header, a card and a pinned save bar into
    // 280 logical pixels.
    tester.view.physicalSize =
        const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          myProfileProvider.overrideWith(
            (Ref ref) => Stream<ProfileDetail?>.value(existing),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfileEditorScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  /// The name as the *card* draws it, not as the field holds it. `find.text`
  /// matches an `EditableText` too, so a bare finder cannot tell the preview
  /// from the input it mirrors.
  Finder onTheCard(String text) => find.descendant(
    of: find.byType(TypesetCardFace),
    matching: find.text(text),
  );

  testWidgets('opens as a blank card, not an error', (WidgetTester t) async {
    await pump(t);

    // `ScreenHeader` sets its title in micro-caps, which upper-cases it.
    expect(find.text('MAKE YOUR CARD'), findsOneWidget);
    expect(onTheCard('Your name'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the preview follows what you type', (WidgetTester t) async {
    await pump(t);
    expect(onTheCard('Your name'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'Arafatul Hasan Sadoy');
    await t.pump();

    // On the card, not merely in the field. That the card reflects a draft
    // nobody has committed is the whole point of this being one screen.
    expect(onTheCard('Arafatul Hasan Sadoy'), findsOneWidget);
    expect(onTheCard('Your name'), findsNothing);
  });

  testWidgets('each field asks for the right keyboard', (WidgetTester t) async {
    await pump(t);

    final List<TextField> fields = t
        .widgetList<TextField>(find.byType(TextField))
        .toList();

    // Name, what you do, company, phone, email, website, address, tagline.
    expect(fields[3].keyboardType, TextInputType.phone);
    expect(fields[4].keyboardType, TextInputType.emailAddress);
    expect(fields[5].keyboardType, TextInputType.url);
    // A phone number is not a proper noun.
    expect(fields[3].textCapitalization, TextCapitalization.none);
    expect(fields[0].textCapitalization, TextCapitalization.words);
  });

  testWidgets('a bad number is flagged while typing, and Save still works', (
    WidgetTester t,
  ) async {
    await pump(t);

    await t.enterText(find.byType(TextField).at(3), '017098227');
    await t.pump();

    // The same validator the scan path uses, so a number the scanner would
    // reject is not accepted just because it arrived by hand. Shown, never
    // refused — a value the user typed is not a guess to be overruled.
    // A sentence, not the validator's machine token — showing
    // `unrecognizedFormat` under somebody's phone number would render
    // perfectly and be useless.
    expect(find.text('That does not look like a phone number.'), findsOneWidget);
    expect(find.textContaining('unrecognizedFormat'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('the header chevron asks before discarding', (
    WidgetTester t,
  ) async {
    await pump(t);
    await t.enterText(find.byType(TextField).first, 'Half a name');
    await t.pump();

    // The chevron, not the system back gesture. `context.pop()` here would
    // walk straight past the `PopScope` and lose the edit in silence.
    await t.tap(find.byIcon(Icons.chevron_left));
    await t.pumpAndSettle();

    expect(find.text('Discard these changes?'), findsOneWidget);

    await t.tap(find.text('Keep editing'));
    await t.pumpAndSettle();
    expect(onTheCard('Half a name'), findsOneWidget);
  });

  testWidgets('an untouched card leaves without a dialog', (
    WidgetTester t,
  ) async {
    await pump(t);

    // Nothing typed, nothing to lose. Asking here would be the kind of
    // confirmation people learn to dismiss without reading.
    await t.tap(find.byIcon(Icons.chevron_left));
    await t.pumpAndSettle();

    expect(find.text('Discard these changes?'), findsNothing);
  });

  testWidgets('Save hands over every filled slot and no empty one', (
    WidgetTester t,
  ) async {
    await pump(t);

    await t.enterText(find.byType(TextField).first, 'Nusrat Jahan');
    await t.enterText(find.byType(TextField).at(3), '01711363991');
    await t.pump();

    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(repo.saved, isNotNull);
    final Map<String, String> written = <String, String>{
      for (final ProfileEntry e in repo.saved!.entries)
        if (e.value.trim().isNotEmpty) e.fieldKey: e.value,
    };
    expect(written['person_name'], 'Nusrat Jahan');
    expect(written['phone'], '01711363991');
    // Blank slots travel as empty entries and are dropped by the repository,
    // which is where that rule is tested.
    expect(written.containsKey('email'), isFalse);
  });

  testWidgets("the tagline is saved as the card's own line", (
    WidgetTester t,
  ) async {
    await pump(t);

    await t.enterText(find.byType(TextField).first, 'Someone');

    // Scrolled to, not indexed. A `ListView` does not build what it cannot
    // show, so the tagline does not exist until somebody reaches it — which is
    // also exactly what the user does.
    final Finder tagline = find.byKey(const ValueKey<String>('slot-tagline'));
    await t.scrollUntilVisible(
      tagline,
      200,
      // Named explicitly: a multi-line `TextField` carries a `Scrollable` of
      // its own, so "the scrollable" is ambiguous on this screen.
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.enterText(tagline, 'cheap t-shirt printing');
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    // Not a field: it lives on the profile row, because it is one line about
    // the person rather than a way to reach them.
    expect(repo.saved!.tagline, 'cheap t-shirt printing');
  });

  testWidgets('the preview collapses when the keyboard is up', (
    WidgetTester t,
  ) async {
    t.view.physicalSize = const Size(390, 844) * t.view.devicePixelRatio;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          myProfileProvider.overrideWith(
            (Ref ref) => Stream<ProfileDetail?>.value(null),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 320)),
            child: ProfileEditorScreen(),
          ),
        ),
      ),
    );
    await t.pump();

    // The same trade the field-editor sheet makes: with the keyboard down you
    // are looking at the card, with it up you are typing into it, and a
    // clipped value field is worse than a partly covered card.
    final AnimatedAlign align = t.widget<AnimatedAlign>(
      find.byType(AnimatedAlign),
    );
    expect(align.heightFactor, isNotNull);
    expect(align.heightFactor! < 1.0, isTrue);
  });
}

/// Records the draft the editor hands over, and stores nothing.
class _Recorder implements ProfileRepository {
  ProfileDraft? saved;

  @override
  Future<int> save(ProfileDraft draft) async {
    saved = draft;
    return draft.id ?? 1;
  }

  @override
  Stream<ProfileDetail?> watchDefault() => Stream<ProfileDetail?>.value(null);

  @override
  Future<void> attachPhoto(int profileId, String path) async {}

  @override
  Future<void> removePhoto(int profileId) async {}

  @override
  Future<void> softDelete(int profileId) async {}

  @override
  Future<Directory> profileDirectory() async => Directory.systemTemp;

  final List<String> discarded = <String>[];

  @override
  Future<void> discardUnsavedPortrait(String path) async => discarded.add(path);
}
