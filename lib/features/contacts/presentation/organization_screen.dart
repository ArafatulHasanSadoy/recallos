import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router.dart';
import '../data/identity_repository.dart';
import 'widgets/contact_widgets.dart';

/// One company, and the people you know there.
///
/// The mirror of [PersonScreen]: a card with a company but no legible name on
/// it still creates something worth keeping, and without this screen that
/// organization exists in the database but nowhere a user can reach it.
class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({required this.orgId, super.key});

  final int orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OrgDetail?> detail =
        ref.watch(organizationDetailProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            Center(child: Text('Could not open this company.\n$e')),
        data: (OrgDetail? d) => d == null
            ? const Center(child: Text('This company is no longer here.'))
            : _Body(detail: d),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final OrgDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Organization org = detail.organization;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: <Widget>[
        Text(
          org.name,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (org.website != null) ...<Widget>[
          const SizedBox(height: Gap.xs),
          Text(
            org.website!,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
        const SizedBox(height: Gap.lg),

        if (detail.branches.isNotEmpty) ...<Widget>[
          Text('Address', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          for (final OrgBranch b in detail.branches)
            if (b.address != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Text(b.address!, style: theme.textTheme.bodyLarge),
              ),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.contacts.isNotEmpty) ...<Widget>[
          Text('Contact', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          Endpoints(contacts: detail.contacts),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.people.isNotEmpty) ...<Widget>[
          Text(
            detail.people.length == 1 ? 'Person here' : 'People here',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Gap.sm),
          for (final PersonSummary p in detail.people)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(p.displayName),
              subtitle: p.subtitle == null ? null : Text(p.subtitle!),
              onTap: () => context.push(Routes.person(p.id)),
            ),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.cardIds.isNotEmpty) ...<Widget>[
          Text(
            detail.cardIds.length == 1 ? 'From this card' : 'From these cards',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Gap.sm),
          CardStrip(cardIds: detail.cardIds),
        ],
      ],
    );
  }
}
