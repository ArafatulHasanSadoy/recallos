import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/identity_repository.dart';
import 'widgets/contact_widgets.dart';

/// One person, and every way you have of reaching them.
///
/// Grouped by job rather than flattened into a contact list, because the
/// motivating case is a man whose watch shop and bank office have different
/// numbers, and "which number do I use for this" is the actual question.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({required this.personId, super.key});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PersonDetail?> detail =
        ref.watch(personDetailProvider(personId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            Center(child: Text('Could not open this contact.\n$e')),
        data: (PersonDetail? d) => d == null
            ? const Center(child: Text('This contact is no longer here.'))
            : _Body(detail: d),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final PersonDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: <Widget>[
        Text(
          detail.person.displayName,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (detail.roles.length > 1) ...<Widget>[
          const SizedBox(height: Gap.xs),
          Text(
            '${detail.roles.length} businesses',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
        const SizedBox(height: Gap.lg),

        for (final RoleDetail role in detail.roles) ...<Widget>[
          _RoleSection(role: role),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.looseContacts.isNotEmpty) ...<Widget>[
          Text('Other', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          Endpoints(contacts: detail.looseContacts),
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

/// One job: who they are there, and the numbers that reach them there.
class _RoleSection extends StatelessWidget {
  const _RoleSection({required this.role});

  final RoleDetail role;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(role.orgName, style: theme.textTheme.titleMedium),
          if (role.title != null)
            Text(
              role.title!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (role.contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: Text(
                'No number read for this one',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else ...<Widget>[
            const SizedBox(height: Gap.md),
            Endpoints(contacts: role.contacts),
          ],
        ],
      ),
    );
  }
}
