import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../data/contact_export.dart';
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
    final AsyncValue<PersonDetail?> detail = ref.watch(
      personDetailProvider(personId),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Contact',
              onBack: () => context.pop(),
              actions: <Widget>[
                RoundIconButton(
                  icon: Icons.person_add_alt,
                  tooltip: 'Save to contacts',
                  onTap: () => exportContact(
                    context,
                    () => ref.read(contactExportProvider).savePerson(personId),
                  ),
                ),
                RoundIconButton(
                  icon: Icons.share_outlined,
                  tooltip: 'Share',
                  onTap: () => exportContact(
                    context,
                    () => ref
                        .read(contactExportProvider)
                        .savePerson(personId, share: true),
                  ),
                ),
              ],
            ),
            Expanded(
              child: detail.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: GhostStack(count: 1),
                ),
                error: (Object e, _) => EmptyState(
                  label: 'Not available',
                  title: 'Could not open this contact',
                  body: '$e',
                ),
                data: (PersonDetail? d) => d == null
                    ? const EmptyState(
                        label: 'Gone',
                        title: 'This contact is no longer here',
                        body: 'The cards behind it may have been deleted.',
                      )
                    : _Body(detail: d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final PersonDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: <Widget>[
        Row(
          children: <Widget>[
            InitialsAvatar(
              initials: contactInitials(detail.person.displayName),
              seed: detail.person.id,
              radius: 22,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(detail.person.displayName, style: AppText.title(c)),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),

        // One block per job, never one flat contact list. The grouping is the
        // feature: the motivating case is a man whose watch shop and bank
        // office have different numbers, and "which number do I use for this"
        // is the actual question.
        if (detail.roles.isNotEmpty) ...<Widget>[
          SectionHeader(
            detail.roles.length == 1 ? 'business' : 'businesses',
            count: detail.roles.length,
          ),
          const SizedBox(height: Gap.sm),
          for (final RoleDetail role in detail.roles) ...<Widget>[
            _RoleBlock(role: role),
            const SizedBox(height: Gap.sm + 2),
          ],
          const SizedBox(height: Gap.md),
        ],

        if (detail.looseContacts.isNotEmpty) ...<Widget>[
          const SectionHeader('Other'),
          const SizedBox(height: Gap.sm),
          Endpoints(contacts: detail.looseContacts),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.cardIds.isNotEmpty) ...<Widget>[
          SectionHeader(
            detail.cardIds.length == 1 ? 'From this card' : 'From these cards',
          ),
          const SizedBox(height: Gap.sm),
          CardStrip(cardIds: detail.cardIds),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.mergedFrom.isNotEmpty) _Combined(detail: detail),
      ],
    );
  }
}

/// The rows the user combined into this one, and the way back out.
///
/// The prompt that offers to combine two contacts says they can be separated
/// again later. This is where "later" happens; without it that sentence would
/// be false, and a merge nobody could undo is exactly what the graph refuses
/// to do on its own.
class _Combined extends ConsumerWidget {
  const _Combined({required this.detail});

  final PersonDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          detail.mergedFrom.length == 1
              ? 'Combined with 1 other contact'
              : 'Combined with ${detail.mergedFrom.length} others',
        ),
        const SizedBox(height: Gap.sm),
        for (final PersonSummary other in detail.mergedFrom)
          Container(
            margin: const EdgeInsets.only(bottom: Gap.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            decoration: AppDecoration.card(
              c,
              isDark: isDarkTheme(context),
              lifted: false,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        other.displayName,
                        style: AppText.rowTitle(c).copyWith(fontSize: 15),
                      ),
                      if (other.subtitle != null)
                        Text(other.subtitle!, style: AppText.small(c)),
                    ],
                  ),
                ),
                TextAction(
                  label: 'Separate',
                  onTap: () =>
                      ref.read(identityRepositoryProvider).unmerge(other.id),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One job: who they are there, and the numbers that reach them there.
class _RoleBlock extends StatelessWidget {
  const _RoleBlock({required this.role});

  final RoleDetail role;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
      decoration: AppDecoration.card(
        c,
        isDark: isDarkTheme(context),
        lifted: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(role.orgName, style: AppText.rowSerif(c)),
          if (role.title != null) Text(role.title!, style: AppText.small(c)),
          if (role.contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
              child: Text(
                'No number read for this one',
                style: AppText.small(c).copyWith(color: c.inkFaint),
              ),
            )
          else ...<Widget>[
            const SizedBox(height: Gap.sm),
            Endpoints(contacts: role.contacts),
          ],
        ],
      ),
    );
  }
}
