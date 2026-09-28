import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../../contacts/data/contact_export.dart';
import '../../contacts/presentation/widgets/contact_widgets.dart';
import '../data/profile_repository.dart';
import 'widgets/typeset_card.dart';

/// The card you hand over.
///
/// The one screen in the app about its own user. Everything else here is a
/// record of somebody else; this is the record of you, and it is drawn as a
/// card rather than as a profile page because handing it over is the entire
/// point of it existing.
class MyCardScreen extends ConsumerWidget {
  const MyCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileDetail?> profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Your card',
              onBack: () => context.pop(),
              actions: <Widget>[
                if (profile.value != null)
                  RoundIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onTap: () => context.push(Routes.myCardEdit),
                  ),
              ],
            ),
            Expanded(
              child: profile.when(
                // Rule 5: a ghost card, never a spinner.
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: GhostStack(count: 1),
                ),
                error: (Object e, _) => EmptyState(
                  label: 'Not available',
                  title: 'Could not open your card',
                  body: '$e',
                ),
                data: (ProfileDetail? detail) =>
                    detail == null || detail.isEmpty
                    ? const _NoCardYet()
                    : _Card(detail: detail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Before there is a card.
///
/// Says what the app is offering rather than what is missing — "you have no
/// card" is a fact about an empty table; "hand it over without printing
/// anything" is the reason to make one.
class _NoCardYet extends StatelessWidget {
  const _NoCardYet();

  @override
  Widget build(BuildContext context) => EmptyState(
    label: 'No card yet',
    title: 'You have no card of your own',
    body:
        'Every card in here belongs to somebody else. Say who you are and '
        'how to reach you, and RecallOS will set you one you can hand over '
        'without printing anything.',
    actionLabel: 'Make my card',
    onAction: () => context.push(Routes.myCardEdit),
  );
}

class _Card extends ConsumerWidget {
  const _Card({required this.detail});

  final ProfileDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: <Widget>[
        TypesetCardFace(card: detail.toCard()),
        const SizedBox(height: Gap.lg),

        InkPill(
          label: 'Save to my contacts',
          icon: Icons.person_add_alt,
          // ACTION_VIEW, which is the only verb Contacts actually registers
          // for — see the note on `ContactExport`.
          onTap: () => unawaited(
            exportContact(
              context,
              () => ref.read(contactExportProvider).saveProfile(),
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        OutlinePill(
          label: 'Send my card',
          icon: Icons.share_outlined,
          onTap: () => unawaited(
            exportContact(
              context,
              () => ref.read(contactExportProvider).saveProfile(share: true),
            ),
          ),
        ),
      ],
    );
  }
}
