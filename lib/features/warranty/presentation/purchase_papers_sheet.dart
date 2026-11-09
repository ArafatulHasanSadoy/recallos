import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/imaging/photo_keyring.dart';
import '../../../core/imaging/photo_vault.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;
import '../../cards/presentation/widgets/editable_field_list.dart'
    show fieldKeysFor, fieldLabel;
import '../data/purchase_link_providers.dart';
import '../data/purchase_papers.dart';

/// A receipt or warranty with its confirmed partners, as it would be shared.
final purchasePapersProvider = FutureProvider.autoDispose
    .family<PurchasePapers?, int>(
      (Ref ref, int cardId) => PurchasePapersReader(
        ref.watch(databaseProvider),
        ref.watch(purchaseLinksProvider),
        label: fieldLabel,
      ).read(cardId, order: fieldKeysFor),
    );

/// Opens photographs from their sealed copies and hands them over.
final papersShareProvider = Provider<PapersShare>(
  (Ref ref) => PapersShare(
    openPhoto: (String path) async {
      final Uint8List? key = await PhotoKeyring.instance.key;
      return openPhoto(key, await File(path).readAsBytes());
    },
  ),
);

/// *Share these papers?* — everything that will leave the phone, before it
/// does (B3). Returns what happened, or null when closed.
Future<PapersShareResult?> showPurchasePapersSheet(
  BuildContext context, {
  required int cardId,
}) {
  return showModalBottomSheet<PapersShareResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => PurchasePapersSheet(cardId: cardId),
  );
}

/// The preview. Every value with where it came from, every photograph, and
/// the one sentence about where it goes. Public so a test can pump it.
class PurchasePapersSheet extends ConsumerStatefulWidget {
  const PurchasePapersSheet({required this.cardId, super.key});

  final int cardId;

  @override
  ConsumerState<PurchasePapersSheet> createState() =>
      _PurchasePapersSheetState();
}

class _PurchasePapersSheetState extends ConsumerState<PurchasePapersSheet> {
  bool _sharing = false;
  bool _failed = false;

  Future<void> _share(PurchasePapers papers) async {
    setState(() {
      _sharing = true;
      _failed = false;
    });
    final PapersShareResult result = await ref
        .read(papersShareProvider)
        .share(papers);
    if (!mounted) return;
    if (result == PapersShareResult.shared) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _sharing = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<PurchasePapers?> value = ref.watch(
      purchasePapersProvider(widget.cardId),
    );
    final PurchasePapers? papers = value.value;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
            // Rule 3: the app asking the user something.
            child: Text(
              papers != null && papers.papers.length > 1
                  ? 'Share these papers?'
                  : 'Share this paper?',
              style: AppText.displayAsk(c).copyWith(fontSize: 24, height: 1.1),
            ),
          ),
          Flexible(
            child: switch (value) {
              AsyncData(value: final PurchasePapers? p) when p != null =>
                _Preview(papers: p),
              AsyncData() || AsyncError() => Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: Text(
                  'This paper cannot be shared any more. It may have been '
                  'deleted.',
                  style: AppText.body(c),
                ),
              ),
              _ => const ExcludeSemantics(
                child: Opacity(opacity: 0.4, child: SizedBox(height: 160)),
              ),
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_failed) ...<Widget>[
                  Text(
                    'That did not work. Nothing was shared.',
                    style: AppText.body(c).copyWith(color: c.vermilion),
                  ),
                  const SizedBox(height: Gap.sm),
                ],
                if (papers != null)
                  Opacity(
                    opacity: _sharing ? 0.4 : 1,
                    child: InkPill(
                      label: _sharing ? 'Opening the share sheet…' : 'Share',
                      icon: Icons.ios_share,
                      onTap: _sharing ? null : () => unawaited(_share(papers)),
                    ),
                  ),
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
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.papers});

  final PurchasePapers papers;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final int photos = papers.attachments.length;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      children: <Widget>[
        Text(
          'A note listing every value below, '
          '${photos == 0
              ? 'and no photographs'
              : photos == 1
              ? 'and the photograph'
              : 'and $photos photographs'}'
          ', to the app you choose. The photographs leave the phone '
          'unencrypted.',
          style: AppText.body(c),
        ),
        for (final SharedPaper paper in papers.papers) ...<Widget>[
          const SizedBox(height: Gap.md),
          // The kind as the header and the title under it: a long shop
          // name in the spaced capitals of a header wrapped and squeezed its
          // rule to a stub on the phone.
          SectionHeader(paper.kind),
          const SizedBox(height: Gap.xs),
          Text(paper.title, style: AppText.rowTitle(c)),
          const SizedBox(height: Gap.xs),
          for (final SharedValue v in paper.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '${v.label}  ',
                      style: AppText.small(c).copyWith(color: c.inkMuted),
                    ),
                    TextSpan(text: v.value, style: AppText.body(c)),
                    TextSpan(
                      text: '  ${v.source}',
                      style: AppText.small(c).copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          if (paper.working != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Text(
                paper.working!,
                style: AppText.small(c).copyWith(color: c.inkMuted),
              ),
            ),
          for (final SharedPhoto ph in paper.photos)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      ph.path == null
                          ? Icons.image_not_supported_outlined
                          : Icons.image_outlined,
                      size: 16,
                      color: ph.path == null ? c.vermilion : c.inkMuted,
                    ),
                  ),
                  const SizedBox(width: Gap.xs),
                  Flexible(
                    child: Text(
                      ph.path == null
                          ? '${ph.name} — no longer on this phone, not '
                                'attached'
                          : ph.name,
                      style: AppText.small(
                        c,
                      ).copyWith(color: ph.path == null ? c.vermilion : null),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (papers.linkReasons.isNotEmpty) ...<Widget>[
          const SizedBox(height: Gap.md),
          Text(
            'Kept together because: ${papers.linkReasons.join('; ')}.',
            style: AppText.small(c).copyWith(color: c.inkMuted),
          ),
        ],
      ],
    );
  }
}
