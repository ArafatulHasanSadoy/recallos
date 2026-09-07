import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../data/contact_export.dart';
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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Company',
              onBack: () => context.pop(),
              actions: <Widget>[
                RoundIconButton(
                  icon: Icons.person_add_alt,
                  tooltip: 'Save to contacts',
                  onTap: () => exportContact(
                    context,
                    () =>
                        ref.read(contactExportProvider).saveOrganization(orgId),
                  ),
                ),
                RoundIconButton(
                  icon: Icons.share_outlined,
                  tooltip: 'Share',
                  onTap: () => exportContact(
                    context,
                    () => ref
                        .read(contactExportProvider)
                        .saveOrganization(orgId, share: true),
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
                  title: 'Could not open this company',
                  body: '$e',
                ),
                data: (OrgDetail? d) => d == null
                    ? const EmptyState(
                        label: 'Gone',
                        title: 'This company is no longer here',
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

/// The mirror of Person. Every section is conditional on its own list, and
/// there is deliberately no stat strip and no note aggregation — the graph
/// does not model org→notes, so anything of that shape would be invented.
class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final OrgDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Organization org = detail.organization;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: <Widget>[
        Row(
          children: <Widget>[
            const OrgGlyph(radius: 22),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(org.name, style: AppText.title(c)),
                  if (org.website != null)
                    Text(
                      org.website!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small(c).copyWith(color: c.ochreInk),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),

        // A list, not a line: a company can have branches.
        if (detail.branches.isNotEmpty) ...<Widget>[
          SectionHeader(
            'Address',
            count: detail.branches.length > 1 ? detail.branches.length : null,
          ),
          const SizedBox(height: Gap.sm),
          for (final OrgBranch b in detail.branches)
            if (b.address != null) _Branch(address: b.address!),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.contacts.isNotEmpty) ...<Widget>[
          const SectionHeader('Contact'),
          const SizedBox(height: Gap.sm),
          Endpoints(contacts: detail.contacts),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.people.isNotEmpty) ...<Widget>[
          SectionHeader(
            detail.people.length == 1 ? 'Person here' : 'People here',
            count: detail.people.length > 1 ? detail.people.length : null,
          ),
          const SizedBox(height: Gap.sm),
          for (final PersonSummary p in detail.people)
            PressFade(
              onTap: () => context.push(Routes.person(p.id)),
              semanticLabel: p.displayName,
              child: Container(
                constraints: const BoxConstraints(minHeight: kMinTarget),
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                child: Row(
                  children: <Widget>[
                    InitialsAvatar(
                      initials: contactInitials(p.displayName),
                      seed: p.id,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            p.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.rowTitle(c),
                          ),
                          if (p.subtitle != null)
                            Text(p.subtitle!, style: AppText.small(c)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: c.inkFaint),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Gap.lg),
        ],

        if (detail.cardIds.isNotEmpty) ...<Widget>[
          SectionHeader(
            detail.cardIds.length == 1 ? 'From this card' : 'From these cards',
          ),
          const SizedBox(height: Gap.sm),
          CardStrip(cardIds: detail.cardIds),
        ],
      ],
    );
  }
}

/// One branch address, with the map action that reaches it.
class _Branch extends StatelessWidget {
  const _Branch({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return PressFade(
      onTap: () => unawaited(
        launchUrl(
          Uri.https('www.google.com', '/maps/search/',
              <String, String>{'api': '1', 'query': address}),
          mode: LaunchMode.externalApplication,
        ),
      ),
      semanticLabel: '$address, open in maps',
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(address, style: AppText.rowTitle(c).copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  MetaLabel('Map', color: c.ochreInk),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Icon(Icons.map_outlined, size: 19, color: c.inkMuted),
          ],
        ),
      ),
    );
  }
}
