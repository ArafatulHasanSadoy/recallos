import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../data/my_card_qr.dart';
import '../data/profile_repository.dart';
import 'widgets/my_card_qr_code.dart';

/// Your card as a code the other person scans — the in-person half of
/// meeting somebody, where "Say hello" is the half afterwards.
///
/// Any phone camera reads it and offers to save the contact, so they need no
/// app and there is no link to a server. The lines on it are the user's
/// choice, one switch each, remembered for the next time.
class MyCardQrScreen extends ConsumerWidget {
  const MyCardQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileDetail?> profile = ref.watch(myProfileProvider);
    final AsyncValue<Set<String>?> hidden = ref.watch(myCardQrHiddenProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'Scan to save', onBack: () => context.pop()),
            Expanded(child: _body(context, profile, hidden)),
          ],
        ),
      ),
    );
  }
}

Widget _body(
  BuildContext context,
  AsyncValue<ProfileDetail?> profile,
  AsyncValue<Set<String>?> hidden,
) {
  final Object? error = profile.error ?? hidden.error;
  if (error != null) {
    return EmptyState(
      label: 'Not available',
      title: 'Could not open your card',
      body: '$error',
    );
  }
  if (!profile.hasValue || !hidden.hasValue) {
    // Rule 5: a ghost card, never a spinner.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: Gap.lg),
      child: GhostStack(count: 1),
    );
  }
  final ProfileDetail? detail = profile.value;
  if (detail == null || detail.isEmpty) {
    return EmptyState(
      label: 'No card yet',
      title: 'There is nothing to put on a code yet',
      body:
          'Say who you are and how to reach you, and any phone can scan your '
          'card.',
      actionLabel: 'Make my card',
      onAction: () => context.push(Routes.myCardEdit),
    );
  }
  // Never chosen: the default, which leaves the address off.
  return _Code(detail: detail, hidden: hidden.value ?? defaultQrHidden(detail));
}

class _Code extends ConsumerWidget {
  const _Code({required this.detail, required this.hidden});

  final ProfileDetail detail;
  final Set<String> hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final List<QrLine> lines = qrLines(detail);
    // The whole width but for the tile's padding and the gutter, up to a size
    // that still fits a short phone with the switches under it.
    final double size = math.min(
      MediaQuery.sizeOf(context).width - 2 * Gap.gutter - 2 * Gap.lg,
      280,
    );

    void toggle(QrLine line) {
      final Set<String> next = <String>{...hidden};
      if (!next.remove(line.key)) next.add(line.key);
      unawaited(ref.read(myCardQrStoreProvider).setHidden(next));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, Gap.xl),
      children: <Widget>[
        MyCardQrCode(payload: myCardQrPayload(detail, hidden), size: size),
        const SizedBox(height: Gap.md),
        Text(
          'Hold it up to their camera. Any phone reads it and offers to save '
          'you as a contact — they need no app.',
          style: AppText.body(c),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.lg),
        SettingGroup(
          label: 'On the code',
          children: <Widget>[
            for (final QrLine line in lines)
              SettingRow(
                label: line.value,
                description: line.label,
                onTap: () => toggle(line),
                trailing: AppSwitch(
                  value: !hidden.contains(line.key),
                  onChanged: (_) => toggle(line),
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Your name is always on it. To change what a line says, edit your '
          'card.',
          style: AppText.small(c),
        ),
      ],
    );
  }
}
