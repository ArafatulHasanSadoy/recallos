import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../router.dart';
import '../data/identity_repository.dart';
import 'widgets/contact_widgets.dart';

/// The questions the graph cannot answer on its own.
///
/// Resolution links two cards automatically when they share a phone or an
/// email, because only one person holds those. It never links on a name — two
/// different Md. Rahmans would collapse into one contact — and it cannot link
/// what OCR read differently the second time. So three kinds of near-miss end
/// up here: two contacts, two companies, and the same piece of paper
/// photographed twice, which is the commonest of the three.
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
                  'Nothing here has been combined or deleted. RecallOS only '
                  'joins two records when they share a number or an email — '
                  'everything else is your call.',
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

  String get _heading => switch (pair.kind) {
        DuplicateKind.person => 'Two contacts',
        DuplicateKind.organization => 'Two companies',
        DuplicateKind.card => 'The same card, scanned twice?',
      };

  /// What combining actually does, which differs by kind and is the thing the
  /// user is really deciding.
  String get _affirmative => switch (pair.kind) {
        DuplicateKind.person => 'Same person',
        DuplicateKind.organization => 'Same company',
        DuplicateKind.card => 'Delete one',
      };

  String get _negative => switch (pair.kind) {
        DuplicateKind.person => 'Different people',
        DuplicateKind.organization => 'Different companies',
        DuplicateKind.card => 'Keep both',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_heading, style: theme.textTheme.titleMedium),
                  if (pair.signals.isNotEmpty)
                    Text(
                      // Says what it noticed rather than asserting a verdict.
                      'Matched on ${pair.signals.join(" and ")}',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                ],
              ),
            ),
            if (pair.kind == DuplicateKind.card)
              _CardSides(pair: pair)
            else ...<Widget>[
              _Side(side: pair.a, kind: pair.kind),
              _Side(side: pair.b, kind: pair.kind),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => _keepSeparate(ref),
                    child: Text(_negative),
                  ),
                  const SizedBox(width: Gap.xs),
                  FilledButton(
                    onPressed: () => _confirm(context, ref),
                    child: Text(_affirmative),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _keepSeparate(WidgetRef ref) async {
    final IdentityRepository identity = ref.read(identityRepositoryProvider);
    switch (pair.kind) {
      case DuplicateKind.person:
        await identity.keepSeparate(a: pair.a.id, b: pair.b.id);
      case DuplicateKind.organization:
        await identity.keepOrganizationsSeparate(a: pair.a.id, b: pair.b.id);
      case DuplicateKind.card:
        await identity.keepCardsSeparate(a: pair.a.id, b: pair.b.id);
    }
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final (String title, String body, String action) = switch (pair.kind) {
      DuplicateKind.person => (
          'Same person?',
          '${pair.a.title} and ${pair.b.title} will be shown as one contact, '
              'with both businesses and every number under them.\n\n'
              'Nothing is deleted, and you can separate them again later.',
          'Combine',
        ),
      DuplicateKind.organization => (
          'Same company?',
          '${pair.a.title} and ${pair.b.title} will be shown as one company, '
              'with every card and everyone you know there under it.\n\n'
              'Nothing is deleted, and you can separate them again later.',
          'Combine',
        ),
      DuplicateKind.card => (
          'Delete the newer scan?',
          'The older card is kept, along with anything you have corrected or '
              'written on it. The newer photograph is removed.\n\n'
              'It goes to Recently deleted first, so this can be undone.',
          'Delete',
        ),
    };

    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (sure != true) return;

    final IdentityRepository identity = ref.read(identityRepositoryProvider);
    switch (pair.kind) {
      case DuplicateKind.person:
      case DuplicateKind.organization:
        // The one with more cards survives: it is the row more of the library
        // already points at, so it is the less disruptive of the two to keep.
        final bool aWins = _weight(pair.a) >= _weight(pair.b);
        final int survivor = aWins ? pair.a.id : pair.b.id;
        final int loser = aWins ? pair.b.id : pair.a.id;
        if (pair.kind == DuplicateKind.person) {
          await identity.merge(survivor: survivor, loser: loser);
        } else {
          await identity.mergeOrganizations(survivor: survivor, loser: loser);
        }

      case DuplicateKind.card:
        // The *older* scan survives. It is the one that has been in the
        // library long enough to have been corrected, noted on, or found in a
        // search — all of which the second photograph has not.
        await identity.discardDuplicateCard(
          keep: pair.a.id,
          discard: pair.b.id,
        );
    }
  }

  /// How much of the library already points at a row.
  static int _weight(DuplicateSide side) =>
      int.tryParse((side.detail ?? '').split(' ').first) ?? 0;
}

/// Two contacts or two companies, side by side.
class _Side extends StatelessWidget {
  const _Side({required this.side, required this.kind});

  final DuplicateSide side;
  final DuplicateKind kind;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isPerson = kind == DuplicateKind.person;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isPerson
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.tertiaryContainer,
        child: isPerson
            ? Text(
                contactInitials(side.title),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
              )
            : Icon(
                Icons.storefront_outlined,
                color: theme.colorScheme.onTertiaryContainer,
              ),
      ),
      title: Text(side.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: side.subtitle == null
          ? null
          : Text(side.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: side.detail == null
          ? null
          : Text(
              side.detail!,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
      onTap: () => context.push(
        isPerson ? Routes.person(side.id) : Routes.organization(side.id),
      ),
    );
  }
}

/// Two scans of one card, shown as pictures.
///
/// Text cannot settle this one — both sides say the same thing, which is why
/// they were flagged. Only the photographs differ, so they are what the
/// decision is made on.
class _CardSides extends StatelessWidget {
  const _CardSides({required this.pair});

  final DuplicatePair pair;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _CardFace(side: pair.a, label: 'Kept')),
          const SizedBox(width: Gap.md),
          Expanded(child: _CardFace(side: pair.b, label: 'Newer')),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.side, required this.label});

  final DuplicateSide side;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = side.imagePath;

    return GestureDetector(
      onTap: () => context.push(Routes.card(side.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.586,
              child: path != null && File(path).existsSync()
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            '$label · ${side.detail ?? ""}',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
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
              'Records that share a number or an email are combined on their '
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
