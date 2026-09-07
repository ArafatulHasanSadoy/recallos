import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../../cards/presentation/needs_attention_screen.dart';
import '../../contacts/data/identity_repository.dart';
import '../data/app_settings.dart';

/// Frame 12.
///
/// Only rows with something behind them. The frame also proposes "Ask for a
/// note every time", "Capture the back too", "Photo quality" and "Larger
/// type"; none of those has a store or a consumer yet, and a switch that
/// remembers nothing is worse than an absent one — so they ship with their
/// features, not before.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppSettings settings = ref.watch(appSettingsProvider);
    final int deleted =
        ref.watch(deletedCardsProvider).value?.length ?? 0;
    final int duplicates =
        ref.watch(duplicateCandidatesProvider).value?.length ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'Settings', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
                children: <Widget>[
                  Text('Settings', style: AppText.title(c)),
                  const SizedBox(height: Gap.lg),

                  SettingGroup(
                    label: 'Your wallet',
                    children: <Widget>[
                      SettingRow(
                        label: 'Recently deleted',
                        description: deleted == 1
                            ? '1 card, still on the phone'
                            : '$deleted cards, still on the phone',
                        trailing: Icon(Icons.chevron_right,
                            size: 18, color: c.inkFaint),
                        onTap: () => context.push(Routes.needsAttention),
                      ),
                      SettingRow(
                        label: 'Duplicates to review',
                        description: duplicates == 1
                            ? '1 pair waiting'
                            : '$duplicates pairs waiting',
                        trailing: Icon(Icons.chevron_right,
                            size: 18, color: c.inkFaint),
                        onTap: () => context.push(Routes.duplicates),
                      ),
                      SettingRow(
                        label: 'Needs attention',
                        description: 'Cards that did not read cleanly',
                        trailing: Icon(Icons.chevron_right,
                            size: 18, color: c.inkFaint),
                        onTap: () => context.push(Routes.needsAttention),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),

                  SettingGroup(
                    label: 'Look',
                    children: <Widget>[
                      SettingRow(
                        label: 'Appearance',
                        description: switch (settings.themeMode) {
                          ThemeMode.system => 'Follow system',
                          ThemeMode.light => 'Always light',
                          ThemeMode.dark => 'Always dark',
                        },
                        trailing: Icon(Icons.chevron_right,
                            size: 18, color: c.inkFaint),
                        onTap: () => unawaited(_pickAppearance(context, ref)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),

                  // Phase 0 scaffolding, and the last thing still reachable
                  // only from a menu. It lives here until the spike screen
                  // itself goes.
                  SettingGroup(
                    label: 'Development',
                    children: <Widget>[
                      SettingRow(
                        label: 'OCR spike',
                        description: 'Scores extraction against real cards',
                        trailing: Icon(Icons.chevron_right,
                            size: 18, color: c.inkFaint),
                        onTap: () => context.push(Routes.spike),
                      ),
                    ],
                  ),

                  const SizedBox(height: Gap.xl),
                  Center(child: MicroLabel('RecallOS · offline', color: c.inkFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAppearance(BuildContext context, WidgetRef ref) async {
    final AppColors c = AppColors.of(context);
    final ThemeMode? picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Appearance', style: AppText.rowSerif(c)),
            const SizedBox(height: Gap.sm),
            for (final (ThemeMode mode, String label) in <(ThemeMode, String)>[
              (ThemeMode.system, 'Follow system'),
              (ThemeMode.light, 'Always light'),
              (ThemeMode.dark, 'Always dark'),
            ])
              SettingRow(
                label: label,
                onTap: () => Navigator.of(sheet).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(appSettingsProvider.notifier).setThemeMode(picked);
  }
}
