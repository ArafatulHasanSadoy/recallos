import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_format.dart';
import '../../../core/backup/backup_reader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../data/backup_service.dart';

/// The shortest passphrase a backup accepts. Long rather than complex: a
/// sentence is easier to remember than symbols, and harder to guess.
const int kMinPassphraseLength = 10;

/// Backs the whole wallet up to one encrypted file the user keeps somewhere
/// else.
///
/// The row the rest of the Privacy group was missing: Android backup is off,
/// the database key dies with the app, and "Take a copy" is readable but
/// cannot be restored. Uninstalling or losing the phone used to lose
/// everything.
///
/// No spinner while it runs (rule 5). The description says what is happening,
/// and the row stops taking taps.
class BackupRow extends ConsumerStatefulWidget {
  const BackupRow({super.key});

  @override
  ConsumerState<BackupRow> createState() => _BackupRowState();
}

enum _BackupState { idle, working, done, failed }

class _BackupRowState extends ConsumerState<BackupRow> {
  _BackupState _state = _BackupState.idle;
  String? _doneAt;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return SettingRow(
      label: 'Back up the wallet',
      description: switch (_state) {
        _BackupState.idle =>
          'One encrypted file with everything — cards, notes, people, photos '
              '— to keep off this phone. It restores on any phone.',
        _BackupState.working => 'Encrypting and checking your wallet…',
        _BackupState.done =>
          'Backed up at $_doneAt. Keep the file and its passphrase somewhere '
              'safe — neither can be recovered.',
        _BackupState.failed =>
          'That did not work. Nothing on the phone was changed or lost.',
      },
      trailing: Icon(
        switch (_state) {
          _BackupState.done => Icons.check,
          _BackupState.failed => Icons.error_outline,
          _ => Icons.lock_outline,
        },
        size: 18,
        color: _state == _BackupState.failed ? c.vermilion : c.inkFaint,
      ),
      onTap: _state == _BackupState.working ? null : () => unawaited(_run()),
    );
  }

  Future<void> _run() async {
    // Read before any await: the row can be disposed while the sheet is open.
    final BackupService service = ref.read(backupServiceProvider);
    final String? passphrase = await showPassphraseSheet(
      context,
      title: 'Choose a passphrase',
      explanation:
          'It locks this backup. Nobody can reset it — not even RecallOS — so '
          'without it the file cannot be opened. A short sentence works well.',
      confirm: true,
      action: 'Create backup',
    );
    if (passphrase == null || !mounted) return;

    setState(() => _state = _BackupState.working);
    try {
      final CreatedBackup backup = await service.create(passphrase);
      if (!mounted) return;
      final TimeOfDay t = TimeOfDay.now();
      setState(() {
        _state = _BackupState.done;
        _doneAt =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      });
      await service.share(backup);
    } on Object {
      if (mounted) setState(() => _state = _BackupState.failed);
    }
  }
}

/// Replaces the wallet on this phone with one from a backup file.
///
/// Nothing is replaced until the file has been fully checked, its contents
/// shown, and the replacement confirmed — and even then the old wallet is
/// kept aside until the restored one has opened.
class RestoreRow extends ConsumerStatefulWidget {
  const RestoreRow({super.key});

  @override
  ConsumerState<RestoreRow> createState() => _RestoreRowState();
}

class _RestoreRowState extends ConsumerState<RestoreRow> {
  String? _status;
  bool _busy = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return SettingRow(
      label: 'Restore from a backup',
      description:
          _status ??
          'Replaces everything on this phone with a backup you made. You see '
              'what is in it before anything changes.',
      trailing: Icon(
        _failed ? Icons.error_outline : Icons.settings_backup_restore,
        size: 18,
        color: _failed ? c.vermilion : c.inkFaint,
      ),
      onTap: _busy ? null : () => unawaited(_run()),
    );
  }

  void _show(String status, {bool failed = false, bool busy = false}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _failed = failed;
      _busy = busy;
    });
  }

  Future<void> _run() async {
    final BackupService service = ref.read(backupServiceProvider);
    final String? path = await service.pickBackup();
    if (path == null || !mounted) return;

    OpenedBackup? opened;
    String? error;
    while (opened == null) {
      if (!mounted) return;
      final String? passphrase = await showPassphraseSheet(
        context,
        title: 'Open the backup',
        explanation: 'Type the passphrase you chose when you made it.',
        confirm: false,
        action: 'Open',
        error: error,
      );
      if (passphrase == null) {
        _show('Restore cancelled. Nothing was changed.');
        return;
      }
      _show('Checking the backup…', busy: true);
      try {
        opened = await service.open(path, passphrase);
      } on BackupException catch (e) {
        if (e.problem != BackupProblem.wrongPassphraseOrDamaged) {
          _show(problemMessage(e.problem), failed: true);
          return;
        }
        // Asked again rather than sending the user back to the file picker.
        error = problemMessage(e.problem);
      } on Object {
        _show(problemMessage(BackupProblem.notABackup), failed: true);
        return;
      }
    }

    final int live = await service.liveCards();
    if (!mounted) return;
    final bool? replace = await showRestorePreview(
      context,
      preview: opened.preview,
      liveCards: live,
    );
    if (replace != true) {
      _show('Restore cancelled. Nothing was changed.');
      return;
    }

    _show('Restoring… RecallOS will restart when it is done.', busy: true);
    try {
      final bool restarted = await service.stageAndRestart(path, opened);
      if (!restarted) {
        _show(
          'Almost done. Close RecallOS and open it again to finish the restore.',
          busy: true,
        );
      }
    } on BackupException catch (e) {
      _show(problemMessage(e.problem), failed: true);
    } on Object {
      _show(
        'That did not work. Nothing on the phone was changed or lost.',
        failed: true,
      );
    }
  }
}

/// What to tell someone when a backup cannot be used. Every one of these
/// leaves the current wallet exactly as it was, and says so.
String problemMessage(BackupProblem problem) => switch (problem) {
  BackupProblem.notABackup =>
    'That file is not a RecallOS backup. Nothing was changed.',
  BackupProblem.wrongPassphraseOrDamaged =>
    'That passphrase does not open this backup — or the file was changed '
        'since it was made. Nothing was changed.',
  BackupProblem.damaged =>
    'This backup is damaged: something inside does not match what it '
        'recorded. Nothing was changed.',
  BackupProblem.tooNew =>
    'This backup was made by a newer RecallOS. Update the app, then try '
        'again. Nothing was changed.',
  BackupProblem.tooLarge =>
    'That file is larger than RecallOS will open. Nothing was changed.',
};

/// Asks for a passphrase — twice when [confirm], to catch a typo that would
/// otherwise lock the user out of their own backup for good.
///
/// The action button always responds: an invalid entry gets a sentence saying
/// what is wrong, never a greyed-out button that does nothing.
Future<String?> showPassphraseSheet(
  BuildContext context, {
  required String title,
  required String explanation,
  required bool confirm,
  required String action,
  String? error,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => PassphraseSheet(
      title: title,
      explanation: explanation,
      confirm: confirm,
      action: action,
      initialError: error,
    ),
  );
}

class PassphraseSheet extends StatefulWidget {
  const PassphraseSheet({
    required this.title,
    required this.explanation,
    required this.confirm,
    required this.action,
    this.initialError,
    super.key,
  });

  final String title;
  final String explanation;
  final bool confirm;
  final String action;
  final String? initialError;

  @override
  State<PassphraseSheet> createState() => _PassphraseSheetState();
}

class _PassphraseSheetState extends State<PassphraseSheet> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();
  late String? _error = widget.initialError;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    final String a = _first.text;
    String? problem;
    if (a.isEmpty) {
      problem = 'Type a passphrase first.';
    } else if (widget.confirm && a.length < kMinPassphraseLength) {
      problem = 'Use at least $kMinPassphraseLength characters — a short '
          'sentence is easiest.';
    } else if (widget.confirm && a != _second.text) {
      problem = 'The two do not match. Type it again in both boxes.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? error = _error;

    return Padding(
      padding: EdgeInsets.only(
        left: Gap.lg,
        right: Gap.lg,
        top: Gap.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: AppText.rowSerif(c)),
          const SizedBox(height: Gap.sm),
          Text(widget.explanation, style: AppText.body(c)),
          const SizedBox(height: Gap.md),
          _SecretField(
            controller: _first,
            hint: 'Passphrase',
            autofocus: true,
            onSubmitted: widget.confirm ? null : (_) => _submit(),
          ),
          if (widget.confirm) ...<Widget>[
            const SizedBox(height: Gap.sm),
            _SecretField(
              controller: _second,
              hint: 'The same again',
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Text(
              error,
              style: AppText.body(c).copyWith(color: c.vermilion),
            ),
          ],
          const SizedBox(height: Gap.md),
          InkPill(label: widget.action, onTap: _submit),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text(
                  'Cancel',
                  style: AppText.button(c, on: c.inkMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A recessed field (rule 1) whose contents stay hidden.
class _SecretField extends StatelessWidget {
  const _SecretField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

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
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        cursorColor: c.ochre,
        cursorWidth: 2,
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
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// What is in the backup, and what restoring it will do, before anything is
/// done. True only when the user chose to replace their wallet.
Future<bool?> showRestorePreview(
  BuildContext context, {
  required BackupPreview preview,
  required int liveCards,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) =>
        RestorePreviewSheet(preview: preview, liveCards: liveCards),
  );
}

class RestorePreviewSheet extends StatelessWidget {
  const RestorePreviewSheet({
    required this.preview,
    required this.liveCards,
    super.key,
  });

  final BackupPreview preview;
  final int liveCards;

  static String _plural(int n, String one, String many) =>
      '$n ${n == 1 ? one : many}';

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final DateTime at = preview.createdAt.toLocal();
    final String when = '${at.day} ${_months[at.month - 1]} ${at.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Replace this wallet?', style: AppText.rowSerif(c)),
          const SizedBox(height: Gap.sm),
          Text(
            'This backup was made on $when. It holds '
            '${_plural(preview.cards, 'card', 'cards')}, '
            '${_plural(preview.people, 'person', 'people')}, '
            '${_plural(preview.organizations, 'company', 'companies')} and '
            '${_plural(preview.photos, 'photograph', 'photographs')}.',
            style: AppText.body(c),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            liveCards == 0
                ? 'There is nothing on this phone yet, so nothing is lost.'
                : 'Restoring replaces everything on this phone. The '
                      '${_plural(liveCards, 'card', 'cards')} here now '
                      '(Recently deleted included) will be gone — back '
                      '${liveCards == 1 ? 'it' : 'them'} up first if you might '
                      'want ${liveCards == 1 ? 'it' : 'them'}.',
            style: AppText.body(c).copyWith(
              color: liveCards == 0 ? c.inkMuted : c.vermilion,
            ),
          ),
          const SizedBox(height: Gap.md),
          InkPill(
            label: 'Replace with this backup',
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(false),
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text(
                  'Keep this wallet',
                  style: AppText.button(c, on: c.inkMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
