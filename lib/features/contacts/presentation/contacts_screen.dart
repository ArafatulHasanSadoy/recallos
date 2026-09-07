import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../data/identity_repository.dart';
import 'widgets/contact_widgets.dart';

/// The people behind the cards, rather than the cards themselves.
///
/// A card is a piece of paper; a person is who you actually want. Two cards
/// from the same person collapse to one row here, and the subtitle says how
/// many businesses they turned out to have — which is the thing the card
/// library physically cannot show.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _controller = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    // Cards saved before the identity graph existed have fields but nobody to
    // show, and without this they would never appear here at all.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(identityRepositoryProvider).backfill());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<List<PersonSummary>> people = ref.watch(peopleProvider);
    final AsyncValue<List<OrgSummary>> orgs = ref.watch(organizationsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Contacts',
              onBack: () => context.pop(),
              actions: <Widget>[
                // The banner below advertises the review list when it has
                // something in it. This is how you reach it on the days it
                // does not — a feature that only appears when it has something
                // to say is indistinguishable from one that is missing.
                RoundIconButton(
                  icon: Icons.people_alt_outlined,
                  tooltip: 'Possible duplicates',
                  onTap: () => context.push(Routes.duplicates),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Pocket(
                    height: 54,
                    padding: const EdgeInsets.only(
                      left: Gap.md,
                      right: Gap.sm,
                    ),
                    trailing: _filter.isEmpty
                        ? null
                        : PressFade(
                            onTap: () {
                              _controller.clear();
                              setState(() => _filter = '');
                            },
                            scale: 0.9,
                            semanticLabel: 'Clear the filter',
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.close,
                                  size: 18, color: c.inkMuted),
                            ),
                          ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.search, size: 19, color: c.inkMuted),
                        const SizedBox(width: Gap.sm + 2),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: (String v) => setState(
                                () => _filter = v.trim().toLowerCase()),
                            cursorColor: c.ochre,
                            cursorWidth: 2,
                            style: AppText.rowTitle(c).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              fontVariations: AppFonts.weight(400),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Find a person or company',
                              hintStyle:
                                  AppText.body(c).copyWith(fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _DuplicateBanner(),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            Expanded(
              child: people.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: GhostStack(count: 2),
                ),
                error: (Object e, _) => EmptyState(
                  label: 'Not available',
                  title: 'Could not open your contacts',
                  body: '$e',
                ),
                data: (List<PersonSummary> all) {
                  final List<PersonSummary> shownPeople = _filter.isEmpty
                      ? all
                      : all
                          .where((PersonSummary p) =>
                              p.displayName.toLowerCase().contains(_filter) ||
                              (p.subtitle ?? '')
                                  .toLowerCase()
                                  .contains(_filter))
                          .toList();

                  // A card with a shop name but no legible person on it still
                  // leaves a company worth reaching, so companies get their
                  // own section rather than being unreachable.
                  final List<OrgSummary> allOrgs =
                      orgs.value ?? const <OrgSummary>[];
                  final List<OrgSummary> shownOrgs = _filter.isEmpty
                      ? allOrgs
                      : allOrgs
                          .where((OrgSummary o) =>
                              o.name.toLowerCase().contains(_filter) ||
                              (o.subtitle ?? '')
                                  .toLowerCase()
                                  .contains(_filter))
                          .toList();

                  if (all.isEmpty && allOrgs.isEmpty) {
                    return const EmptyState(
                      label: 'No contacts yet',
                      title: 'Nobody in here yet',
                      body: 'People and companies appear as soon as a scanned '
                          'card names one.',
                    );
                  }
                  if (shownPeople.isEmpty && shownOrgs.isEmpty) {
                    return EmptyState(
                      label: 'No results',
                      title: 'Nothing matched that',
                      body: 'Try part of a name, a company, or a place.',
                      actionLabel: 'Clear the filter',
                      onAction: () {
                        _controller.clear();
                        setState(() => _filter = '');
                      },
                    );
                  }

                  // One list, two count-labelled sections. No tabs, no letter
                  // grouping, no alphabet rail — the filter above is the find
                  // mechanism and it searches both at once.
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      0,
                      Gap.lg,
                      Gap.xl,
                    ),
                    children: <Widget>[
                      if (shownPeople.isNotEmpty) ...<Widget>[
                        SectionHeader(
                          shownPeople.length == 1 ? 'person' : 'people',
                          count: shownPeople.length,
                        ),
                        for (final PersonSummary p in shownPeople)
                          _PersonRow(person: p),
                        const SizedBox(height: Gap.md),
                      ],
                      if (shownOrgs.isNotEmpty) ...<Widget>[
                        SectionHeader(
                          shownOrgs.length == 1 ? 'company' : 'companies',
                          count: shownOrgs.length,
                        ),
                        for (final OrgSummary o in shownOrgs)
                          _OrgRow(org: o),
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

/// Offers the review list, and only when it has something in it.
class _DuplicateBanner extends ConsumerWidget {
  const _DuplicateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final int pairs =
        ref.watch(duplicateCandidatesProvider).value?.length ?? 0;
    if (pairs == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: PressFade(
        onTap: () => context.push(Routes.duplicates),
        child: Container(
          height: kMinTarget,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          decoration: BoxDecoration(
            color: c.ochre.withValues(alpha: 0.12),
            borderRadius: AppRadius.pocketR,
            border: Border.all(color: c.ochre.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  pairs == 1
                      ? '1 pair may be the same'
                      : '$pairs pairs may be the same',
                  style: AppText.rowTitle(c).copyWith(fontSize: 15),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.ochreInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// A person. Initials, name, their job or best endpoint, and a card count that
/// only appears when it means something.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});

  final PersonSummary person;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return _ContactRow(
      leading: InitialsAvatar(
        initials: contactInitials(person.displayName),
        seed: person.id,
      ),
      title: person.displayName,
      subtitle: person.subtitle,
      // Above one, or it is noise on every row.
      trailing: person.cardCount > 1
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: c.pocket,
                borderRadius: AppRadius.chipR,
              ),
              child: MetaLabel('${person.cardCount} cards'),
            )
          : null,
      onTap: () => context.push(Routes.person(person.id)),
    );
  }
}

/// A company. The storefront glyph rather than initials is what keeps the two
/// row types apart at a glance in one mixed list.
class _OrgRow extends StatelessWidget {
  const _OrgRow({required this.org});

  final OrgSummary org;

  @override
  Widget build(BuildContext context) => _ContactRow(
        leading: const OrgGlyph(),
        title: org.name,
        subtitle: org.subtitle,
        onTap: () => context.push(Routes.organization(org.id)),
      );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? sub = subtitle;
    final Widget? trail = trailing;

    return PressFade(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget + 8),
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: <Widget>[
            leading,
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowTitle(c),
                  ),
                  if (sub != null && sub.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small(c),
                    ),
                  ],
                ],
              ),
            ),
            if (trail != null) ...<Widget>[const SizedBox(width: Gap.sm), trail],
            const SizedBox(width: Gap.sm),
            Icon(Icons.chevron_right, size: 18, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}
