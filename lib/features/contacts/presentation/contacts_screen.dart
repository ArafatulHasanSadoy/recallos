import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<PersonSummary>> people = ref.watch(peopleProvider);
    final AsyncValue<List<OrgSummary>> orgs = ref.watch(organizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: <Widget>[
          // The banner below advertises the review list when it has something
          // in it. This is how you reach it on the days it does not — without
          // a permanent way in, a feature that only appears when the app has
          // something to say is indistinguishable from one that is missing.
          IconButton(
            tooltip: 'Possible duplicates',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => context.push(Routes.duplicates),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _controller,
                onChanged: (String v) =>
                    setState(() => _filter = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Find a person or company',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filter.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _filter = '');
                          },
                        ),
                ),
              ),
              const _DuplicateBanner(),
              const SizedBox(height: Gap.md),
              Expanded(
                child: people.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object e, _) => Center(
                    child: Text(
                      'Could not open your contacts.\n$e',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
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

                    // A card with a shop name but no legible person on it
                    // still leaves a company worth keeping, so companies get
                    // their own section rather than being unreachable.
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
                      return const _EmptyState();
                    }
                    if (shownPeople.isEmpty && shownOrgs.isEmpty) {
                      return Center(
                        child: Text(
                          'Nothing matched “$_filter”',
                          style: theme.textTheme.titleMedium,
                        ),
                      );
                    }

                    return ListView(
                      children: <Widget>[
                        if (shownPeople.isNotEmpty) ...<Widget>[
                          _SectionHeader(
                            label: shownPeople.length == 1
                                ? '1 person'
                                : '${shownPeople.length} people',
                          ),
                          for (final PersonSummary p in shownPeople)
                            _PersonRow(person: p),
                        ],
                        if (shownOrgs.isNotEmpty) ...<Widget>[
                          _SectionHeader(
                            label: shownOrgs.length == 1
                                ? '1 company'
                                : '${shownOrgs.length} companies',
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
      ),
    );
  }
}

/// Offers the review list, and only when it has something in it.
class _DuplicateBanner extends ConsumerWidget {
  const _DuplicateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int waiting =
        ref.watch(duplicateCandidatesProvider).value?.length ?? 0;
    if (waiting == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(Routes.duplicates),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: Gap.sm),
            child: Row(
              children: <Widget>[
                Icon(Icons.people_alt_outlined,
                    color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    waiting == 1
                        ? '1 pair may be the same person'
                        : '$waiting pairs may be the same person',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});

  final PersonSummary person;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: Gap.xs),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          contactInitials(person.displayName),
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
      title: Text(person.displayName, maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: person.subtitle == null
          ? null
          : Text(person.subtitle!,
              maxLines: 1, overflow: TextOverflow.ellipsis),
      // Only worth saying when it is more than one — otherwise it is noise on
      // every single row.
      trailing: person.cardCount > 1
          ? Chip(
              label: Text('${person.cardCount} cards'),
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: () => context.push(Routes.person(person.id)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
      child: Text(
        label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _OrgRow extends StatelessWidget {
  const _OrgRow({required this.org});

  final OrgSummary org;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: Gap.xs),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.tertiaryContainer,
        child: Icon(
          Icons.storefront_outlined,
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
      title: Text(org.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: org.subtitle == null
          ? null
          : Text(org.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => context.push(Routes.organization(org.id)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.people_outline, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: Gap.md),
          Text('No contacts yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            'Scan a card with a name or a number on it and the person\n'
            'behind it shows up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
