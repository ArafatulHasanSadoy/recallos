import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/enums.dart';
import '../../../core/theme/app_theme.dart';
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
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<CardSummary>> queue =
        ref.watch(needsAttentionProvider);
    final List<CardSummary> deleted =
        ref.watch(deletedCardsProvider).value ?? const <CardSummary>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Needs attention'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: queue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('Could not open the queue.\n$e')),
          data: (List<CardSummary> cards) {
            if (cards.isEmpty && deleted.isEmpty) return const _AllClear();

            return ListView(
              padding: const EdgeInsets.all(Gap.md),
              children: <Widget>[
                if (cards.isNotEmpty) ...<Widget>[
                  Text(
                    cards.length == 1
                        ? '1 card did not read cleanly'
                        : '${cards.length} cards did not read cleanly',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Open one to fix it by hand, or try reading them all again '
                    '— the same card often reads better on a second run.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Gap.md),
                  FilledButton.icon(
                    onPressed: _retrying ? null : () => _retryAll(cards),
                    icon: _retrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_progress ?? 'Try reading them again'),
                  ),
                  const SizedBox(height: Gap.md),
                  for (final CardSummary c in cards) _QueueRow(card: c),
                ],
                if (deleted.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Gap.lg),
                  Text('Recently deleted', style: theme.textTheme.titleMedium),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Deleted, but still on the phone. These are cards whose '
                    'undo window was interrupted.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Gap.sm),
                  for (final CardSummary c in deleted) _DeletedRow(card: c),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool nothing = card.status == ExtractionStatus.failed;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        leading: Icon(
          nothing ? Icons.error_outline : Icons.help_outline,
          color: nothing ? theme.colorScheme.error : theme.colorScheme.tertiary,
        ),
        title: Text(
          card.title ?? 'Unread card',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          // Says which of the two problems this is, because they need
          // different things from the user.
          nothing
              ? 'Nothing was read from this card'
              : 'Only part of this card was read',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.card(card.id)),
      ),
    );
  }
}

class _DeletedRow extends ConsumerWidget {
  const _DeletedRow({required this.card});

  final CardSummary card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    // Actions under the text rather than beside it. Two of them in a trailing
    // slot leave the title about a third of the row, and the title is how you
    // recognise the card you are trying to get back.
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.sm, Gap.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.delete_outline,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        card.title ?? 'Unread card',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        card.note ?? card.subtitle ?? 'No details read',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => _confirmPurge(context, ref),
                  child: Text(
                    'Delete for good',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(width: Gap.xs),
                FilledButton.tonal(
                  onPressed: () async {
                    await ref.read(cardRepositoryProvider).restore(card.id);
                    // Back in the library means back in the graph too.
                    await ref
                        .read(identityRepositoryProvider)
                        .promote(card.id);
                  },
                  child: const Text('Restore'),
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

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.check_circle_outline,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: Gap.md),
            Text('Nothing needs attention', style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              'Every saved card read cleanly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
