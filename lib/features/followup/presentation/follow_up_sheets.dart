import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../plus/data/plus_controller.dart' show kFreeReminders;
import '../data/follow_up_answers.dart';
import '../data/follow_up_repository.dart' show dayOf;

/// Asks when and where the user met whoever is behind a card.
///
/// [scannedOn] is offered as one tap — it is often the answer — but it is only
/// a suggestion: nothing is stored unless the user saves, and "Not sure" is
/// always there. Returns null when the sheet is closed without saving.
Future<EncounterAnswer?> showEncounterSheet(
  BuildContext context, {
  required DateTime scannedOn,
  DateTime? metOn,
  String? place,
  DateTime Function() now = DateTime.now,
}) {
  return showModalBottomSheet<EncounterAnswer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => EncounterSheet(
      scannedOn: scannedOn,
      metOn: metOn,
      place: place,
      now: now,
    ),
  );
}

/// Asks for the next step on a card, its day and whether to be reminded.
///
/// With [editing], the sheet is prefilled and also offers to remove the step.
Future<StepAnswer?> showNextStepSheet(
  BuildContext context, {
  String title = '',
  DateTime? dueOn,
  bool remind = true,
  DateTime? remindAt,
  bool remindersFull = false,
  VoidCallback? onSeePlus,
  bool editing = false,
  DateTime Function() now = DateTime.now,
}) {
  return showModalBottomSheet<StepAnswer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => NextStepSheet(
      title: title,
      dueOn: dueOn,
      remind: remind,
      remindAt: remindAt,
      remindersFull: remindersFull,
      onSeePlus: onSeePlus,
      editing: editing,
      now: now,
    ),
  );
}

/// The encounter sheet. Public so a widget test can pump it directly.
class EncounterSheet extends StatefulWidget {
  const EncounterSheet({
    required this.scannedOn,
    this.metOn,
    this.place,
    this.now = DateTime.now,
    super.key,
  });

  final DateTime scannedOn;
  final DateTime? metOn;
  final String? place;
  final DateTime Function() now;

  @override
  State<EncounterSheet> createState() => _EncounterSheetState();
}

class _EncounterSheetState extends State<EncounterSheet> {
  late final TextEditingController _place = TextEditingController(
    text: widget.place ?? '',
  );
  late DateTime? _metOn = widget.metOn == null ? null : dayOf(widget.metOn!);

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final DateTime today = dayOf(widget.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _metOn ?? dayOf(widget.scannedOn),
      firstDate: DateTime(today.year - 30),
      // Nobody has met someone tomorrow.
      lastDate: today,
      helpText: 'When did you meet?',
    );
    if (picked != null && mounted) setState(() => _metOn = dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final DateTime now = widget.now();
    final DateTime scanned = dayOf(widget.scannedOn);
    final DateTime? chosen = _metOn;
    final bool custom = chosen != null && chosen != scanned;

    return _SheetFrame(
      question: 'Where did you meet?',
      explanation: 'Only what you enter here is saved.',
      form: <Widget>[
        _Field(
          controller: _place,
          hint: 'CSE fest at NSU',
          autofocus: widget.place == null,
        ),
        const SizedBox(height: Gap.md),
        MicroLabel('When', color: c.inkMuted),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: <Widget>[
            SelectChip(
              label: 'Day I scanned it · ${dayMonth(scanned, now)}',
              selected: chosen == scanned,
              onTap: () => setState(() => _metOn = scanned),
            ),
            if (custom)
              SelectChip(
                label: weekdayDayMonth(chosen, now),
                selected: true,
                onTap: _pick,
              ),
            SelectChip(
              label: custom ? 'Another date' : 'Pick a date',
              selected: false,
              onTap: _pick,
            ),
            SelectChip(
              label: 'Not sure',
              selected: chosen == null,
              onTap: () => setState(() => _metOn = null),
            ),
          ],
        ),
      ],
      primaryLabel: 'Save',
      onPrimary: () => Navigator.of(
        context,
      ).pop<EncounterAnswer>((metOn: _metOn, place: _place.text)),
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
    );
  }
}

/// The next-step sheet. Public so a widget test can pump it directly.
class NextStepSheet extends StatefulWidget {
  const NextStepSheet({
    this.title = '',
    this.dueOn,
    this.remind = true,
    this.remindAt,
    this.remindersFull = false,
    this.onSeePlus,
    this.editing = false,
    this.now = DateTime.now,
    super.key,
  });

  final String title;
  final DateTime? dueOn;
  final bool remind;

  /// The step's current reminder, when editing one that has it.
  final DateTime? remindAt;

  /// The free version's reminders are all in use, and this step does not
  /// already hold one. The switch is not offered — it could not work — and
  /// the sheet says why, with the way out.
  final bool remindersFull;

  /// Opens RecallOS Plus. Null where there is no router to open it with.
  final VoidCallback? onSeePlus;
  final bool editing;
  final DateTime Function() now;

  @override
  State<NextStepSheet> createState() => _NextStepSheetState();
}

class _NextStepSheetState extends State<NextStepSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.title,
  );
  // Every time on the sheet is worked out from this one moment, so what it
  // shows cannot drift from what it saves while it stands open.
  late final DateTime _opened = widget.now();
  late DateTime _due = dayOf(
    widget.dueOn ?? _opened.add(const Duration(days: 1)),
  );
  late bool _remind = widget.remind && !widget.remindersFull;
  bool _emptyTitle = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// The reminder this sheet shows, and the one it saves. Editing keeps the
  /// step's own reminder — a snoozed one included — while its day is
  /// unchanged, so correcting the words does not move it; a new day gets that
  /// day's usual time.
  DateTime get _remindAt {
    final DateTime? kept = widget.remindAt;
    final DateTime? keptDay = widget.dueOn;
    if (kept != null &&
        keptDay != null &&
        _due == dayOf(keptDay) &&
        kept.isAfter(_opened)) {
      return kept;
    }
    return reminderTimeFor(_due, _opened);
  }

  Future<void> _pick() async {
    final DateTime today = dayOf(_opened);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _due.isBefore(today) ? today : _due,
      firstDate: today.isAfter(_due) ? _due : today,
      lastDate: DateTime(today.year + 5, 12, 31),
      helpText: 'When is it due?',
    );
    if (picked != null && mounted) setState(() => _due = dayOf(picked));
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _emptyTitle = true);
      return;
    }
    Navigator.of(context).pop<StepAnswer>((
      title: _title.text,
      dueOn: _due,
      remindAt: _remind ? _remindAt : null,
      remove: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final DateTime now = _opened;
    final DateTime today = dayOf(now);
    final Map<String, DateTime> quick = <String, DateTime>{
      'Today': today,
      'Tomorrow': today.add(const Duration(days: 1)),
      'In 3 days': today.add(const Duration(days: 3)),
      'Next week': today.add(const Duration(days: 7)),
    };
    final bool custom = !quick.containsValue(_due);
    final DateTime remindAt = _remindAt;

    return _SheetFrame(
      question: "What's the next step?",
      explanation: "Say what you'll do, and by when. It shows up on Today.",
      form: <Widget>[
        _Field(
          controller: _title,
          hint: 'Send the sponsorship proposal',
          autofocus: widget.title.isEmpty,
          onChanged: (_) {
            if (_emptyTitle) setState(() => _emptyTitle = false);
          },
        ),
        if (_emptyTitle) ...<Widget>[
          const SizedBox(height: Gap.xs),
          Text(
            'Write what the step is first.',
            style: AppText.small(c).copyWith(color: c.vermilion),
          ),
        ],
        const SizedBox(height: Gap.md),
        MicroLabel('Due', color: c.inkMuted),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: <Widget>[
            for (final MapEntry<String, DateTime> q in quick.entries)
              SelectChip(
                label: q.key,
                selected: _due == q.value,
                onTap: () => setState(() => _due = q.value),
              ),
            if (custom)
              SelectChip(
                label: weekdayDayMonth(_due, now),
                selected: true,
                onTap: _pick,
              ),
            SelectChip(
              label: custom ? 'Another date' : 'Pick a date',
              selected: false,
              onTap: _pick,
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        if (widget.remindersFull)
          _RemindersFull(onSeePlus: widget.onSeePlus)
        else
          PressFade(
            onTap: () => setState(() => _remind = !_remind),
            semanticLabel: _remind
                ? 'Remind me, on, ${reminderWords(remindAt, now)}'
                : 'Remind me, off',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Remind me', style: AppText.rowTitle(c)),
                      const SizedBox(height: 2),
                      Text(
                        _remind
                            ? 'A notification at ${reminderWords(remindAt, now)}'
                            : 'No notification; it still shows on Today',
                        style: AppText.small(c),
                      ),
                    ],
                  ),
                ),
                AppSwitch(
                  value: _remind,
                  onChanged: (bool v) => setState(() => _remind = v),
                ),
              ],
            ),
          ),
      ],
      primaryLabel: widget.editing ? 'Save' : 'Add step',
      onPrimary: _save,
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      extra: widget.editing
          ? TextAction(
              label: 'Remove this step',
              icon: Icons.delete_outline,
              tint: c.vermilion,
              onTap: () => Navigator.of(context).pop<StepAnswer>((
                title: widget.title,
                dueOn: _due,
                remindAt: null,
                remove: true,
              )),
            )
          : null,
    );
  }
}

/// The frame both sheets share with the note sheet: the app's question in
/// serif italic, a line of explanation, the form, one ink button and a quiet
/// way out.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.question,
    required this.explanation,
    required this.form,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.extra,
  });

  final String question;
  final String explanation;
  final List<Widget> form;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Widget? more = extra;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: Gap.lg,
        right: Gap.lg,
        top: Gap.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            question,
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.sm),
          Text(explanation, style: AppText.body(c)),
          const SizedBox(height: Gap.md),
          ...form,
          const SizedBox(height: Gap.lg),
          InkPill(label: primaryLabel, height: 58, onTap: onPrimary),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: onSecondary,
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text(
                  secondaryLabel,
                  style: AppText.button(c, on: c.inkMuted),
                ),
              ),
            ),
          ),
          if (more != null) Center(child: more),
        ],
      ),
    );
  }
}

/// A recessed one-line field, as every input in the app is.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Pocket(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.sm + 2,
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        cursorColor: c.ochre,
        cursorWidth: 2,
        textCapitalization: TextCapitalization.sentences,
        style: AppText.rowTitle(c).copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          fontVariations: AppFonts.weight(400),
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: AppText.body(c).copyWith(fontSize: 15),
        ),
      ),
    );
  }
}

/// In place of the switch when the free reminders are all in use: how many,
/// what frees one, and where the limit goes away.
class _RemindersFull extends StatelessWidget {
  const _RemindersFull({required this.onSeePlus});

  final VoidCallback? onSeePlus;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final VoidCallback? seePlus = onSeePlus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Remind me', style: AppText.rowTitle(c)),
        const SizedBox(height: 2),
        Text(
          'All $kFreeReminders free reminders are waiting. The step is saved '
          'and shows on Today; finishing a step frees a reminder.',
          style: AppText.small(c),
        ),
        if (seePlus != null)
          TextAction(
            label: 'No limit with RecallOS Plus',
            icon: Icons.all_inclusive,
            onTap: () {
              Navigator.of(context).pop();
              seePlus();
            },
          ),
      ],
    );
  }
}
