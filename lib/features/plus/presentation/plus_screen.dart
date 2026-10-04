import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../data/plus_controller.dart';

/// RecallOS Plus: what it adds, what stays free, and the one button.
///
/// Lists only what Plus does today. Event Mode and people search come to
/// buyers in a later update and are added here when they exist, not before:
/// a paywall that sells what is not built is a promise the app cannot keep.
class PlusScreen extends ConsumerStatefulWidget {
  const PlusScreen({super.key});

  @override
  ConsumerState<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends ConsumerState<PlusScreen> {
  @override
  void initState() {
    super.initState();
    // Asked fresh each time: the price is Play's, in the buyer's currency.
    // After the first frame, never during it: the answer can arrive at once
    // (a build with no licence key has nothing to ask), and a provider may
    // not change while the tree is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(plusProvider.notifier).loadOffer());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final PlusState plus = ref.watch(plusProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'RecallOS Plus', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
                children: <Widget>[
                  Text('No limit on reminders', style: AppText.title(c)),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'The free version keeps $kFreeReminders reminders waiting '
                    'at a time. Plus takes the limit away. One payment — no '
                    'subscription, no account — and like the rest of '
                    'RecallOS it works without the internet.',
                    style: AppText.body(c),
                  ),
                  const SizedBox(height: Gap.lg),
                  _Action(plus: plus),
                  if (plus.notice case final String notice) ...<Widget>[
                    const SizedBox(height: Gap.sm),
                    Text(
                      notice,
                      style: AppText.small(c).copyWith(
                        color: plus.noticeIsProblem ? c.vermilion : c.inkMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.xl),
                  const SettingGroup(
                    label: 'Always free',
                    children: <Widget>[
                      SettingRow(
                        label: 'Scanning, reading and correcting cards',
                      ),
                      SettingRow(label: 'Search, notes and next steps'),
                      SettingRow(label: 'Say hello and your QR code'),
                      SettingRow(label: 'Backup, restore and the lock'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The part that changes with the purchase: the button, or why there is
/// none. Never a button that cannot work.
class _Action extends ConsumerWidget {
  const _Action({required this.plus});

  final PlusState plus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final PlusController controller = ref.read(plusProvider.notifier);

    Widget said(String title, String body, {Color? mark}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: AppDecoration.card(
        c,
        isDark: isDarkTheme(context),
        lifted: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (mark != null) ...<Widget>[
                Icon(Icons.check_circle, size: 18, color: mark),
                const SizedBox(width: Gap.sm),
              ],
              Expanded(child: Text(title, style: AppText.rowTitle(c))),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(body, style: AppText.body(c)),
        ],
      ),
    );

    switch (plus.phase) {
      case PlusPhase.owned:
        return said(
          'Plus is on',
          'Thank you. Reminders have no limit — on this phone, and on any '
              'phone signed in to the same Google account.',
          mark: c.olive,
        );
      case PlusPhase.pending:
        return said(
          'Waiting for Google to confirm the payment',
          'Plus turns on by itself when it does. You can leave this screen.',
        );
      case PlusPhase.checking:
      case PlusPhase.free:
        break;
    }

    if (!plus.offerLoaded) {
      // Rule 5: a ghost, never a spinner.
      return const GhostStack(count: 1);
    }

    final String? price = plus.offer?.price;
    if (price == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          said(
            'Plus cannot be bought on this phone right now',
            'Google Play is not answering, or this copy of RecallOS did not '
                'come from Google Play.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextAction(
              label: 'Try again',
              icon: Icons.refresh,
              onTap: () => unawaited(controller.loadOffer()),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkPill(
          label: 'Buy for $price',
          height: 58,
          onTap: () => unawaited(controller.buy()),
        ),
        const SizedBox(height: Gap.xs),
        Center(
          child: TextAction(
            label: 'Already bought it? Restore',
            onTap: () => unawaited(controller.restore()),
          ),
        ),
      ],
    );
  }
}
