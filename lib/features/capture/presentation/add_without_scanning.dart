import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/storage/out_of_space.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../../contacts/data/identity_repository.dart';
import '../../search/data/search_repository.dart';
import '../data/card_repository.dart';
import '../data/paper_import.dart';
import 'kind_sheet.dart';

enum _Way { type, file }

/// The way in for what the camera cannot do: a paper that is not to hand, or
/// one that only ever existed as a file.
Future<void> addWithoutScanning(BuildContext context, WidgetRef ref) async {
  final _Way? way = await showModalBottomSheet<_Way>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _WaySheet(),
  );
  if (way == null || !context.mounted) return;
  return switch (way) {
    _Way.type => _typeItIn(context, ref),
    _Way.file => _bringInAFile(context, ref),
  };
}

Future<void> _typeItIn(BuildContext context, WidgetRef ref) async {
  final TypedStart? start = await showModalBottomSheet<TypedStart>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const TypedSheet(),
  );
  if (start == null || !context.mounted) return;

  final int id;
  try {
    id = await ref
        .read(cardRepositoryProvider)
        .createTyped(
          type: start.type,
          fieldKey: firstFieldFor(start.type),
          value: start.value,
        );
    await ref.read(searchRepositoryProvider).reindexCard(id);
    await ref.read(identityRepositoryProvider).promote(id);
  } on Object catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failureWords(e, 'That was not saved'))),
    );
    return;
  }
  if (!context.mounted) return;
  unawaited(openCardDetail<void>(context, cardId: id, imagePath: null));
}

Future<void> _bringInAFile(BuildContext context, WidgetRef ref) async {
  final Future<File?> Function() pick = ref.read(pickPaperFileProvider);
  final Future<PaperImporter> Function() importer = ref.read(
    paperImporterProvider,
  );
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  try {
    final File? picked = await pick();
    if (picked == null) return;
    final ImportOutcome outcome = await (await importer()).prepare(picked);
    if (!context.mounted) return;
    switch (outcome) {
      case ImportRefused(:final String reason):
        messenger.showSnackBar(SnackBar(content: Text(reason)));
      case ImportReady(:final ImportedPaper paper):
        unawaited(context.push<void>(Routes.capture, extra: paper));
    }
  } on Object catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(failureWords(e, 'That file could not be opened'))),
    );
  }
}

/// What a typed record is first asked for: the thing it is known by.
String firstFieldFor(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => ReceiptKeys.merchant,
  CardType.warrantyCard => WarrantyKeys.product,
  _ => FieldKeys.personName,
};

String _firstLabel(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => 'Shop',
  CardType.warrantyCard => 'What it covers',
  _ => 'Their name',
};

String _firstHint(CardType type) => switch (type) {
  CardType.receipt || CardType.invoice => 'Star Tech, Agargaon',
  CardType.warrantyCard => 'Kitchen fridge',
  _ => 'Nusrat Jahan',
};

class _WaySheet extends StatelessWidget {
  const _WaySheet();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'No paper to scan?',
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.md),
          SettingGroup(
            label: 'Add it another way',
            children: <Widget>[
              SettingRow(
                label: 'Type it in',
                description: 'A card, receipt or warranty, in your own words.',
                onTap: () => Navigator.of(context).pop(_Way.type),
              ),
              SettingRow(
                label: 'From a file',
                description:
                    'A PDF, JPG or PNG on this phone. Only the first page '
                    'of a PDF is kept.',
                onTap: () => Navigator.of(context).pop(_Way.file),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the typed sheet came back with.
class TypedStart {
  const TypedStart(this.type, this.value);
  final CardType type;
  final String value;
}

/// What it is, and the one thing it is known by. The rest is added on the
/// card's own screen, with the same editor as anything scanned.
class TypedSheet extends StatefulWidget {
  const TypedSheet({super.key});

  @override
  State<TypedSheet> createState() => _TypedSheetState();
}

class _TypedSheetState extends State<TypedSheet> {
  final TextEditingController _controller = TextEditingController();
  CardType _type = CardType.visitingCard;

  /// Set once *Add it* was tapped with nothing written, so the tap answers.
  bool _nudged = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _nudged = true);
      return;
    }
    Navigator.of(context).pop(TypedStart(_type, value));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    // Scrolls because the keyboard and 1.3x text leave it little room.
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
            'What are you adding?',
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: <Widget>[
              for (final CardType kind in kCapturableKinds)
                SelectChip(
                  label: _capital(kindNoun(kind)),
                  selected: _type == kind,
                  onTap: () => setState(() => _type = kind),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          MicroLabel(_firstLabel(_type)),
          const SizedBox(height: Gap.xs),
          Pocket(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm + 2,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              cursorColor: c.ochre,
              cursorWidth: 2,
              textCapitalization: TextCapitalization.words,
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
                hintText: _firstHint(_type),
                hintStyle: AppText.body(c).copyWith(fontSize: 15),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _finish(),
            ),
          ),
          if (_nudged && _controller.text.trim().isEmpty) ...<Widget>[
            const SizedBox(height: Gap.xs),
            Text(
              'Write this first, so it is not a blank row in the wallet.',
              style: AppText.small(c).copyWith(color: c.vermilion),
            ),
          ],
          const SizedBox(height: Gap.md),
          InkPill(label: 'Add it', height: 58, onTap: _finish),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text('Cancel', style: AppText.button(c, on: c.inkMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capital(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
}
