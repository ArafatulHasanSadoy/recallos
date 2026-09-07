import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/card_face.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../../capture/data/card_repository.dart';
import '../../contacts/data/identity_repository.dart';
import '../data/rescan_service.dart';

/// Cards that did not come out right, and cards on their way out.
final needsAttentionProvider = StreamProvider<List<CardSummary>>(
  (Ref ref) => ref.watch(cardRepositoryProvider).watchNeedsAttention(),
);

final deletedCardsProvider = StreamProvider<List<CardSummary>>(
  (Ref ref) => ref.watch(cardRepositoryProvider).watchDeleted(),
);

/// The queue of cards that need a human.
///
/// A failed scan is not a lost card — the image and the note are still there,
/// and a second run on a better-lit day often reads what the first could not.
/// What was missing was anywhere to *see* the failures: they sat in the
/// library looking like every other card, and nobody goes looking for the ones
/// that went wrong.
class NeedsAttentionScreen extends ConsumerStatefulWidget {
  const NeedsAttentionScreen({super.key});

  @override
  ConsumerState<NeedsAttentionScreen> createState() =>
      _NeedsAttentionScreenState();
}

class _NeedsAttentionScreenState extends ConsumerState<NeedsAttentionScreen> {
  bool _retrying = false;
  String? _progress;

  /// Re-reads every card in the queue.
  ///
  /// Sequential rather than parallel: the recogniser is one native resource
  /// and this runs on phones with 3 GB of RAM, where four concurrent
  /// full-resolution decodes is how you get killed by the OOM reaper.
  Future<void> _retryAll(List<CardSummary> cards) async {
    setState(() {
      _retrying = true;
      _progress = null;
    });

    final RescanService rescan = ref.read(rescanServiceProvider);
    int improved = 0;
    for (int i = 0; i < cards.length; i++) {
      if (!mounted) return;
      setState(() => _progress = 'Re-reading ${i + 1} of ${cards.length}…');
      final RescanOutcome outcome = await rescan.rescan(cards[i].id);
      if (outcome == RescanOutcome.improved) improved++;
    }

    if (!mounted) return;
    setState(() {
      _retrying = false;
      _progress = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          improved == 0
              ? 'No card read any better this time.'
              : improved == 1
                  ? '1 card improved.'
                  : '$improved cards improved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<List<CardSummary>> queue =
        ref.watch(needsAttentionProvider);
    final List<CardSummary> deleted =
        ref.watch(deletedCardsProvider).value ?? const <CardSummary>[];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Needs attention',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: queue.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: GhostStack(count: 2),
                ),
                error: (Object e, _) => EmptyState(
                  label: 'Not available',
                  title: 'Could not open the queue',
                  body: '$e',
                ),
                data: (List<CardSummary> cards) {
                  if (cards.isEmpty && deleted.isEmpty) {
                    return const EmptyState(
                      label: 'All clear',
                      title: 'Every card read cleanly',
                      body: 'Cards that go wrong show up here, with a way to '
                          'read them again.',
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      0,
                      Gap.lg,
                      Gap.xl,
                    ),
                    children: <Widget>[
                      if (cards.isNotEmpty) ...<Widget>[
                        Text(
                          cards.length == 1
                              ? 'One card did not\nread cleanly'
                              : '${cards.length} cards did not\nread cleanly',
                          style: AppText.title(c),
                        ),
                        const SizedBox(height: Gap.sm),
                        Text(
                          'Open one to fix it by hand, or try reading them all '
                          'again — the same card often reads better on a '
                          'second run.',
                          style: AppText.body(c),
                        ),
                        const SizedBox(height: Gap.md),
                        // Sequential, and the label carries its own progress.
                        OutlinePill(
                          label: _progress ?? 'Try reading them again',
                          icon: Icons.refresh,
                          height: 54,
                          onTap: _retrying ? null : () => _retryAll(cards),
                        ),
                        const SizedBox(height: Gap.lg),
                        for (final CardSummary card in cards)
                          _QueueRow(card: card),
                      ],
                      if (deleted.isNotEmpty) ...<Widget>[
                        const SizedBox(height: Gap.lg),
                        SectionHeader(
                          'Recently deleted',
                          count: deleted.length,
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          'Deleted, but still on the phone. Nothing here is '
                          'gone until you say so.',
                          style: AppText.body(c),
                        ),
                        const SizedBox(height: Gap.md),
                        for (final CardSummary card in deleted)
                          _DeletedRow(card: card),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card that did not read.
///
/// Exactly two states off `card.status`, because they need different things
/// from the user: nothing read at all is vermilion, a partial read is ochre.
/// No per-field guess and no dismiss — the row pushes to card detail, where
/// the field list is the repair tool.
class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool nothing = card.status == ExtractionStatus.failed;
    final Color rail = nothing ? c.vermilion : c.ochre;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: PressFade(
        onTap: () => context.push(Routes.card(card.id)),
        semanticLabel: card.title ?? 'Unread card',
        child: Container(
          decoration: AppDecoration.card(
            c,
            isDark: isDarkTheme(context),
            lifted: false,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: <Widget>[
                // The cap rail: the state, read before any of the words.
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: rail,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.card),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.sm + 2),
                  child: CardFace(
                    imagePath: card.displayPath,
                    size: const Size(74, 46),
                    radius: 7,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        card.title ?? 'Unread card',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.rowTitle(c),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nothing
                            ? 'Nothing was read from this card'
                            : 'Only part of this card was read',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small(c).copyWith(color: rail),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: Gap.sm + 2),
                  child: Icon(Icons.chevron_right, size: 18, color: c.inkFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletedRow extends ConsumerWidget {
  const _DeletedRow({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);

    // Actions under the text rather than beside it. Two of them in a trailing
    // slot leave the title about a third of the row, and the title is how you
    // recognise the card you are trying to get back.
    //
    // The row is desaturated rather than tinted: it sits on the pocket colour
    // instead of paper, which is what says "not in the wallet" without a grey
    // filter over a photograph.
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.sm + 2, Gap.sm + 2, Gap.sm, Gap.xs),
        decoration: BoxDecoration(
          color: c.pocket.withValues(alpha: 0.55),
          borderRadius: AppRadius.cardR,
          border: Border.all(color: c.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Opacity(
                  opacity: 0.65,
                  child: CardFace(
                    imagePath: card.displayPath,
                    size: const Size(74, 46),
                    radius: 7,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        card.title ?? 'Unread card',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.rowTitle(c),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.note ?? card.subtitle ?? 'No details read',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small(c),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                // Destructive copy is vermilion text, never a filled red
                // button — and this is the one delete with no undo, so it
                // keeps its confirm.
                TextAction(
                  label: 'Delete for good',
                  tint: c.vermilion,
                  onTap: () => unawaited(_confirmPurge(context, ref)),
                ),
                const SizedBox(width: Gap.xs),
                PressFade(
                  onTap: () async {
                    await ref.read(cardRepositoryProvider).restore(card.id);
                    // Back in the library means back in the graph too.
                    await ref
                        .read(identityRepositoryProvider)
                        .promote(card.id);
                  },
                  scale: 0.94,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: Gap.sm + 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: AppRadius.chipR,
                      border: Border.all(color: c.hairline),
                    ),
                    child: Text(
                      'Restore',
                      style: AppText.button(c, on: c.ink).copyWith(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPurge(BuildContext context, WidgetRef ref) async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete for good?'),
        content: const Text(
          'The photo and everything read from it will be removed. This one '
          'cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    await ref.read(identityRepositoryProvider).detach(card.id);
    await ref.read(cardRepositoryProvider).purge(card.id);
  }
}
