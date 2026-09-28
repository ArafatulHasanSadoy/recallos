import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/field_validator.dart';
import '../../../core/imaging/photo_keyring.dart';
import '../../../core/imaging/portrait_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../data/profile_repository.dart';
import 'widgets/typeset_card.dart';

/// Setting your own card.
///
/// **One screen, not the bottom sheets the rest of the app edits with, and that
/// is deliberate.** The sheet exists because a card field is a *correction
/// against a photograph*: the value has to be checked against the printing
/// while it is changed, and an inline editor once put two Save buttons on
/// screen where the wrong one silently dropped the edit. Neither condition
/// holds here. There is one Save, there is no photograph to check against, and
/// the source is the user's own knowledge — so eight sheets in a row would be
/// copying the shape of a fix without its cause.
///
/// What replaces the photograph is the card itself: the preview at the top is
/// live, so this is not a form being filled in but a card being set. It is also
/// why the preview collapses rather than disappears when the keyboard comes up
/// — the same trade `_EditorSheet` makes, for the same reason. With the
/// keyboard down you are looking; with it up you are typing.
class ProfileEditorScreen extends ConsumerWidget {
  const ProfileEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileDetail?> profile = ref.watch(myProfileProvider);

    return profile.when(
      loading: () => const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Gap.lg),
            child: GhostStack(count: 1),
          ),
        ),
      ),
      error: (Object e, _) => Scaffold(
        body: SafeArea(
          child: EmptyState(
            label: 'Not available',
            title: 'Could not open your card',
            body: '$e',
          ),
        ),
      ),
      // Keyed on the row id so that arriving with no card and arriving to edit
      // one do not share form state.
      data: (ProfileDetail? detail) =>
          _Editor(key: ValueKey<int?>(detail?.profile.id), existing: detail),
    );
  }
}

/// One editable line of the card.
class _Slot {
  _Slot({
    required this.label,
    required this.fieldKey,
    required String initial,
    this.hint,
    this.maxLines = 1,
  }) : controller = TextEditingController(text: initial),
       initial = initial;

  final String label;

  /// Null for the tagline, which lives on the profile row rather than as a
  /// field — it is one line about the person, not a way to reach them.
  final String? fieldKey;

  final String? hint;
  final int maxLines;
  final TextEditingController controller;
  final String initial;

  String get text => controller.text.trim();
  bool get changed => text != initial.trim();

  void dispose() => controller.dispose();
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.existing, super.key});

  final ProfileDetail? existing;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final List<_Slot> _slots;
  late final _Slot _tagline;
  bool _saving = false;

  /// The portrait as the draft has it, which is not necessarily what is stored.
  /// Picking one has to show on the card immediately or the preview is lying.
  String? _photoPath;
  bool _photoChanged = false;

  /// A portrait this editor wrote to disk that no saved card points at yet.
  ///
  /// It is deleted when it stops being the draft's photo — another pick, a
  /// removal, or leaving without saving — and handed over to the database on
  /// Save. Without this every abandoned pick stayed on the phone for good.
  String? _unsavedPick;

  /// Resolved once, because [dispose] must still be able to reach it and a
  /// `ref` is not usable there.
  late final ProfileRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(profileRepositoryProvider);
    final ProfileDetail? e = widget.existing;
    _photoPath = e?.profile.photoPath;

    _slots = <_Slot>[
      _Slot(
        label: 'Name',
        fieldKey: FieldKeys.personName,
        initial: e?.valueOf(FieldKeys.personName) ?? '',
        hint: 'Arafatul Hasan Sadoy',
      ),
      _Slot(
        label: 'What you do',
        fieldKey: FieldKeys.designation,
        initial: e?.valueOf(FieldKeys.designation) ?? '',
        hint: 'Founder',
      ),
      _Slot(
        label: 'Company',
        fieldKey: FieldKeys.company,
        initial: e?.valueOf(FieldKeys.company) ?? '',
        hint: 'EnationX',
      ),
      _Slot(
        label: 'Phone',
        fieldKey: FieldKeys.phone,
        initial: e?.valueOf(FieldKeys.phone) ?? '',
        hint: '01711 363991',
      ),
      _Slot(
        label: 'Email',
        fieldKey: FieldKeys.email,
        initial: e?.valueOf(FieldKeys.email) ?? '',
        hint: 'you@company.com',
      ),
      _Slot(
        label: 'Website',
        fieldKey: FieldKeys.website,
        initial: e?.valueOf(FieldKeys.website) ?? '',
        hint: 'company.com',
      ),
      _Slot(
        label: 'Address',
        fieldKey: FieldKeys.address,
        initial: e?.valueOf(FieldKeys.address) ?? '',
        maxLines: 3,
      ),
    ];

    _tagline = _Slot(
      label: 'One line',
      fieldKey: null,
      initial: e?.profile.tagline ?? '',
      hint: 'cheap t-shirt printing, low quantity',
      maxLines: 2,
    );

    for (final _Slot s in <_Slot>[..._slots, _tagline]) {
      s.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final _Slot s in <_Slot>[..._slots, _tagline]) {
      s.controller
        ..removeListener(_onChanged)
        ..dispose();
    }
    _discardUnsavedPick();
    super.dispose();
  }

  void _discardUnsavedPick() {
    final String? path = _unsavedPick;
    _unsavedPick = null;
    if (path != null) unawaited(_repo.discardUnsavedPortrait(path));
  }

  /// Repaints the preview on every keystroke. That is the feature.
  void _onChanged() => setState(() {});

  bool get _dirty =>
      _slots.any((_Slot s) => s.changed) || _tagline.changed || _photoChanged;

  /// What the preview draws, and what Save would write.
  ProfileCard get _card => ProfileCard(
    name: _valueOf(FieldKeys.personName),
    designation: _valueOf(FieldKeys.designation),
    company: _valueOf(FieldKeys.company),
    tagline: _tagline.text,
    photoPath: _photoPath,
    seed: widget.existing?.profile.id ?? 1,
    lines: <ProfileLine>[
      for (final _Slot s in _slots)
        if (s.text.isNotEmpty && s.fieldKey != null)
          if (_lineLabel(s.fieldKey!) case final String label)
            ProfileLine(label: label, value: s.text),
    ],
  );

  String _valueOf(String key) =>
      _slots.firstWhere((_Slot s) => s.fieldKey == key).text;

  static String? _lineLabel(String key) => switch (key) {
    FieldKeys.phone => 'Phone',
    FieldKeys.email => 'Email',
    FieldKeys.website => 'Web',
    FieldKeys.address => 'Address',
    _ => null,
  };

  Future<void> _save() async {
    setState(() => _saving = true);

    await _repo.save(
      ProfileDraft(
        id: widget.existing?.profile.id,
        tagline: _tagline.text.isEmpty ? null : _tagline.text,
        photoPath: _photoPath,
        entries: <ProfileEntry>[
          for (final _Slot s in _slots)
            if (s.fieldKey != null)
              ProfileEntry(fieldKey: s.fieldKey!, value: s.text),
        ],
      ),
    );
    // The saved card owns it now; leaving must not delete it.
    _unsavedPick = null;

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  /// Picks a portrait, resizes it off the UI thread, and keeps it.
  ///
  /// Copied into the app's own storage rather than referenced where the picker
  /// found it: a gallery URI is not ours to rely on, and the file behind it can
  /// be deleted, moved or revoked. The stored portrait is replaced only on
  /// Save, so cancelling out of the editor leaves what was already there — and
  /// deletes the copy this pick made.
  Future<void> _pickPhoto() async {
    final ProfileRepository repo = _repo;

    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // The picker itself downsamples first, so a 12-megapixel photo never
      // reaches the decoder.
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null || !mounted) return;

    try {
      final Directory dir = await repo.profileDirectory();
      final String targetDir = dir.path;
      final String baseName =
          'portrait_${DateTime.now().microsecondsSinceEpoch}';
      final String source = picked.path;
      final Uint8List? photoKey = await PhotoKeyring.instance.key;

      final String stored = await Isolate.run(
        () => preparePortrait(
          PortraitRequest(
            sourcePath: source,
            targetDir: targetDir,
            baseName: baseName,
            photoKey: photoKey,
          ),
        ),
      );
      if (!mounted) {
        // The editor closed while the resize ran; nothing will ever save this.
        unawaited(repo.discardUnsavedPortrait(stored));
        return;
      }
      _discardUnsavedPick();
      setState(() {
        _photoPath = stored;
        _photoChanged = true;
        _unsavedPick = stored;
      });
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That picture could not be used.')),
      );
    }
  }

  void _removePhoto() {
    _discardUnsavedPick();
    setState(() {
      _photoPath = null;
      _photoChanged = true;
    });
  }

  /// The same guard the field editor uses, worded for a whole card.
  Future<void> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Discard these changes?'),
        content: const Text('Your card will stay as it was.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (!didPop) unawaited(_confirmDiscard());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ScreenHeader(
                title: widget.existing == null ? 'Make your card' : 'Your card',
                // `maybePop`, not `context.pop()`. GoRouter's pop calls
                // `Navigator.pop`, which is unconditional and walks straight
                // past the `PopScope` above — so the back chevron would discard
                // an edit in silence while the back *gesture* asked first.
                onBack: () => unawaited(Navigator.of(context).maybePop()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                // `AnimatedAlign`, not `AnimatedSize`. `AnimatedSize` measures
                // its child every frame, and this child is a `LayoutBuilder`
                // whose own width depends on the constraint it is handed —
                // which is a measuring loop that hangs rather than settles.
                // Animating the factor instead never asks the card how big it
                // would like to be.
                child: ClipRect(
                  child: AnimatedAlign(
                    duration: AppMotion.quick,
                    curve: AppMotion.curve,
                    alignment: Alignment.topCenter,
                    // Collapsed rather than shrunk: the type stays full size
                    // and the top of the card — the part that changes as you
                    // type — stays readable. A card scaled to fit above a
                    // keyboard is a card nobody can read.
                    heightFactor: keyboardUp ? 0.42 : 1.0,
                    child: TypesetCardFace(card: _card),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
                  children: <Widget>[
                    const SectionHeader('who you are'),
                    for (final _Slot s in _slots.take(3)) _SlotField(slot: s),
                    const SizedBox(height: Gap.md),

                    const SectionHeader('how to reach you'),
                    for (final _Slot s in _slots.skip(3)) _SlotField(slot: s),
                    const SizedBox(height: Gap.md),

                    // Rule 3: the serif italic is the app asking a question.
                    Text(
                      'What should they remember you for?',
                      style: AppText.displayAsk(
                        c,
                      ).copyWith(fontSize: 21, height: 1.15),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'One line, in your words. It travels with the card into '
                      'their phone.',
                      style: AppText.small(c),
                    ),
                    const SizedBox(height: Gap.sm),
                    _SlotField(slot: _tagline, showLabel: false),
                    const SizedBox(height: Gap.md),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextAction(
                        label: _photoPath == null
                            ? 'Add a photo'
                            : 'Change photo',
                        icon: Icons.person_outline,
                        onTap: () => unawaited(_pickPhoto()),
                      ),
                    ),
                    if (_photoPath != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextAction(
                          label: 'Remove photo',
                          icon: Icons.delete_outline,
                          tint: c.vermilion,
                          onTap: _removePhoto,
                        ),
                      ),
                  ],
                ),
              ),
              _SaveBar(
                saving: _saving,
                onCancel: () => unawaited(Navigator.of(context).maybePop()),
                onSave: _saving ? null : () => unawaited(_save()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled recessed field. Rule 1: inputs are recessed, never outlined.
class _SlotField extends StatelessWidget {
  const _SlotField({required this.slot, this.showLabel = true});

  final _Slot slot;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? key = slot.fieldKey;

    // Shown while typing, never blocking. A value the user typed is not a
    // guess the app is passing off as fact, so there is nothing to refuse —
    // but a number that will not dial is worth saying so about.
    final String? issue = (key == null || slot.text.isEmpty)
        ? null
        : describeFieldIssue(validateField(key, slot.text).issue);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showLabel) ...<Widget>[
            MicroLabel(slot.label),
            const SizedBox(height: Gap.xs),
          ],
          Pocket(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm + 2,
            ),
            child: TextField(
              key: ValueKey<String>('slot-${slot.fieldKey ?? "tagline"}'),
              controller: slot.controller,
              maxLines: slot.maxLines,
              keyboardType: _keyboardFor(key, slot.maxLines),
              textCapitalization: _capitalizationFor(key),
              autocorrect: _capitalizationFor(key) == TextCapitalization.words,
              // Rule 2: ochre as a caret is one of the five things it may be.
              cursorColor: c.ochre,
              cursorWidth: 2,
              style: AppText.rowTitle(c).copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontVariations: AppFonts.weight(400),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: slot.hint,
                hintStyle: AppText.body(c).copyWith(fontSize: 16),
              ),
            ),
          ),
          if (issue != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs, left: Gap.sm),
              child: Text(
                issue,
                style: AppText.small(c).copyWith(color: c.vermilion),
              ),
            ),
        ],
      ),
    );
  }

  static TextInputType _keyboardFor(String? key, int maxLines) => switch (key) {
    FieldKeys.phone => TextInputType.phone,
    FieldKeys.email => TextInputType.emailAddress,
    FieldKeys.website => TextInputType.url,
    _ => maxLines > 1 ? TextInputType.multiline : TextInputType.text,
  };

  static TextCapitalization _capitalizationFor(String? key) => switch (key) {
    FieldKeys.phone ||
    FieldKeys.email ||
    FieldKeys.website => TextCapitalization.none,
    _ => TextCapitalization.words,
  };
}

/// Pinned below the scroller, the same shape the field editor's row has — so
/// Save never scrolls away from a long card.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return DecoratedBox(
      // Opaque, so the list scrolls under it rather than through it.
      decoration: BoxDecoration(color: c.page),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinePill(label: 'Cancel', onTap: onCancel),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                // Rule 5: no spinner. The label carries the state.
                child: InkPill(
                  label: saving ? 'Saving…' : 'Save',
                  onTap: onSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
