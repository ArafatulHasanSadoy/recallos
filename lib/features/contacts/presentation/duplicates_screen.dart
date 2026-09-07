
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/card_face.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
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
    final AppColors c = AppColors.of(context);
    final AsyncValue<List<DuplicatePair>> pairs =
        ref.watch(duplicateCandidatesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Possible duplicates',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: pairs.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: GhostStack(count: 2),
                ),
                error: (Object e, _) => EmptyState(
                  label: 'Not available',
                  title: 'Could not open this list',
                  body: '$e',
                ),
                data: (List<DuplicatePair> all) {
                  if (all.isEmpty) {
                    return const EmptyState(
                      label: 'Nothing to review',
                      title: 'Nothing to review',
                      body: 'Records that share a number or an email are '
                          'combined on their own. This list is only for the '
                          'ones that need your judgement.',
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
                      Text(
                        'Possible duplicates',
                        style: AppText.title(c),
                      ),
                      const SizedBox(height: Gap.sm),
                      Text(
                        'Nothing here has been combined or deleted. RecallOS '
                        'only joins two records when they share a number or '
                        'an email — everything else is your call.',
                        style: AppText.body(c),
                      ),
                      const SizedBox(height: Gap.lg),
                      for (final DuplicatePair pair in all)
                        _PairCard(pair: pair),
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
    final AppColors c = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.md),
      decoration: AppDecoration.card(c, isDark: isDarkTheme(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_heading, style: AppText.rowSerif(c)),
          if (pair.signals.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.xs),
            // Says what it noticed, never a verdict and never an invented
            // reason.
            MicroLabel(
              'Matched on ${pair.signals.join(" and ")}',
              color: c.ochreInk,
            ),
          ],
          const SizedBox(height: Gap.md),
          if (pair.kind == DuplicateKind.card)
            _CardSides(pair: pair)
          else ...<Widget>[
            _Side(side: pair.a, kind: pair.kind),
            _Side(side: pair.b, kind: pair.kind),
          ],
          const SizedBox(height: Gap.md),
          // Every label changes with the kind — Same person / Different
          // people, Same company / Different companies, Delete one / Keep
          // both. Never a generic "Merge".
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinePill(
                  label: _negative,
                  height: 52,
                  onTap: () => unawaited(_keepSeparate(ref)),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: InkPill(
                  label: _affirmative,
                  height: 52,
                  onTap: () => unawaited(_confirm(context, ref)),
                ),
              ),
            ],
          ),
        ],
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
    final AppColors c = AppColors.of(context);
    final bool isPerson = kind == DuplicateKind.person;

    return PressFade(
      onTap: () => context.push(
        isPerson ? Routes.person(side.id) : Routes.organization(side.id),
      ),
      semanticLabel: side.title,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: <Widget>[
            if (isPerson)
              InitialsAvatar(
                initials: contactInitials(side.title),
                seed: side.id,
              )
            else
              const OrgGlyph(),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    side.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowTitle(c),
                  ),
                  if (side.subtitle != null)
                    Text(
                      side.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small(c),
                    ),
                ],
              ),
            ),
            if (side.detail != null) MetaLabel(side.detail!),
            const SizedBox(width: Gap.sm),
            Icon(Icons.chevron_right, size: 18, color: c.inkFaint),
          ],
        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: _CardPhoto(side: pair.a, label: 'Kept')),
        const SizedBox(width: Gap.md),
        Expanded(child: _CardPhoto(side: pair.b, label: 'Newer')),
      ],
    );
  }
}

class _CardPhoto extends StatelessWidget {
  const _CardPhoto({required this.side, required this.label});

  final DuplicateSide side;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? path = side.imagePath;

    return PressFade(
      onTap: () => context.push(Routes.card(side.id)),
      semanticLabel: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The real card proportion. This is the decision surface, so the
          // photographs have to be comparable at a glance.
          AspectRatio(
            aspectRatio: 1.586,
            child: CardFace(imagePath: path, radius: 10),
          ),
          const SizedBox(height: Gap.sm),
          MetaLabel(label),
          if (side.detail != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(side.detail!, style: AppText.small(c)),
          ],
        ],
      ),
    );
  }
}
