import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../router.dart';
import '../data/identity_repository.dart';
import 'widgets/contact_widgets.dart';

/// The one question the graph cannot answer on its own.
///
/// Resolution links two cards automatically when they share a phone number or
/// an email, because only one person holds those. It never links on a name,
/// because two different Md. Rahmans would collapse into one contact and no
/// amount of later editing would separate them again. So the near-misses come
/// here, where a human can look at both and say.
class DuplicatesScreen extends ConsumerWidget {
  const DuplicatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<DuplicatePair>> pairs =
        ref.watch(duplicateCandidatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Possible duplicates'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: pairs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) =>
              Center(child: Text('Could not open this list.\n$e')),
          data: (List<DuplicatePair> all) {
            if (all.isEmpty) return const _NothingToReview();

            return ListView(
              padding: const EdgeInsets.all(Gap.md),
              children: <Widget>[
                Text(
                  'These may be the same person. Nothing has been combined — '
                  'RecallOS never merges two people on a name alone.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: Gap.md),
                for (final DuplicatePair pair in all) _PairCard(pair: pair),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PairCard extends ConsumerWidget {
  const _PairCard({required this.pair});

  final DuplicatePair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    // `stretch` rather than `start`, and `ListTile` rather than a hand-rolled
    // Row of Expanded: an earlier version of this card laid out to nothing —
    // the whole list painted blank, with no exception logged and the sibling
    // rows above it disappearing too. These are the constructions the other
    // list screens here already use.
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (pair.signals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
                child: Text(
                  // Says what it noticed rather than asserting a verdict.
                  'Matched on ${pair.signals.join(" · ")}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            _Side(person: pair.a),
            _Side(person: pair.b),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => ref
                        .read(identityRepositoryProvider)
                        .keepSeparate(a: pair.a.id, b: pair.b.id),
                    child: const Text('Different people'),
                  ),
                  const SizedBox(width: Gap.xs),
                  FilledButton(
                    onPressed: () => _confirmMerge(context, ref),
                    child: const Text('Same person'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks before combining, and says plainly that it can be taken back.
  ///
  /// The reassurance is not decoration: people hesitate over merges precisely
  /// because they are usually permanent, and this one genuinely is not.
  Future<void> _confirmMerge(BuildContext context, WidgetRef ref) async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Same person?'),
        content: Text(
          '${pair.a.displayName} and ${pair.b.displayName} will be shown as '
          'one contact, with both businesses and every number under them.\n\n'
          'Nothing is deleted, and you can separate them again later.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Combine'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    // The one with more cards survives: it is the row more of the library
    // already points at, so it is the less disruptive of the two to keep.
    final bool aWins = pair.a.cardCount >= pair.b.cardCount;
    await ref.read(identityRepositoryProvider).merge(
          survivor: aWins ? pair.a.id : pair.b.id,
          loser: aWins ? pair.b.id : pair.a.id,
        );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.person});

  final PersonSummary person;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          contactInitials(person.displayName),
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
      title: Text(
        person.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: person.subtitle == null
          ? null
          : Text(person.subtitle!,
              maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: person.cardCount > 0
          ? Text(
              person.cardCount == 1 ? '1 card' : '${person.cardCount} cards',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : null,
      onTap: () => context.push(Routes.person(person.id)),
    );
  }
}

class _NothingToReview extends StatelessWidget {
  const _NothingToReview();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.done_all, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: Gap.md),
            Text('Nothing to review', style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              'Cards that share a number or an email are combined on their '
              'own. This list is only for the ones that need your judgement.',
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
