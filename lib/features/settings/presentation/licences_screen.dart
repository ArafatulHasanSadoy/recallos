import 'package:flutter/foundation.dart' show LicenseParagraph;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../data/licences.dart';

/// Settings → About → Licences: every piece of open-source work in the app,
/// A to Z, each opening its licence text.
///
/// Built on the design system rather than Flutter's `LicensePage`, which is
/// Material through and through and would arrive looking like another app.
class LicencesScreen extends ConsumerWidget {
  const LicencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<List<LicencedWork>> works = ref.watch(licencesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'Licences', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
                children: <Widget>[
                  Text('Licences', style: AppText.title(c)),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'RecallOS is built on other people’s open-source work: '
                    'the fonts, the meaning-based search, and the code '
                    'libraries below. Each is listed with the licence it '
                    'came under.',
                    style: AppText.body(c),
                  ),
                  const SizedBox(height: Gap.lg),
                  ...switch (works) {
                    AsyncData(value: final List<LicencedWork> list) => <Widget>[
                      SettingGroup(
                        label: '${list.length} in this build',
                        children: <Widget>[
                          for (final LicencedWork w in list)
                            SettingRow(
                              label: w.name,
                              description: w.licences.length == 1
                                  ? null
                                  : '${w.licences.length} licences',
                              trailing: Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: c.inkFaint,
                              ),
                              onTap: () =>
                                  context.push(Routes.licenceOf(w.name)),
                            ),
                        ],
                      ),
                    ],
                    AsyncError() => <Widget>[
                      Text(
                        'The licences could not be read on this phone. '
                        'Nothing else is affected.',
                        style: AppText.body(c).copyWith(color: c.vermilion),
                      ),
                    ],
                    _ => const <Widget>[_GhostRows()],
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One work's licence text, in full.
class LicenceScreen extends ConsumerWidget {
  const LicenceScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final LicencedWork? work = ref
        .watch(licencesProvider)
        .value
        ?.where((LicencedWork w) => w.name == name)
        .firstOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'Licence', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
                children: <Widget>[
                  Text(name, style: AppText.title(c)),
                  const SizedBox(height: Gap.md),
                  if (work == null)
                    Text(
                      'This licence could not be found.',
                      style: AppText.body(c),
                    )
                  else
                    for (int i = 0; i < work.licences.length; i++) ...<Widget>[
                      if (i > 0) ...<Widget>[
                        const SizedBox(height: Gap.md),
                        Container(height: 1, color: c.hairline),
                        const SizedBox(height: Gap.md),
                      ],
                      for (final LicenseParagraph p in work.licences[i])
                        _Paragraph(p),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.p);

  final LicenseParagraph p;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool centred = p.indent == LicenseParagraph.centeredIndent;
    return Padding(
      padding: EdgeInsets.only(
        left: centred ? 0 : Gap.md * p.indent,
        bottom: Gap.sm,
      ),
      child: Text(
        p.text,
        textAlign: centred ? TextAlign.center : TextAlign.start,
        style: AppText.small(c),
      ),
    );
  }
}

/// Loading, as everywhere in the app: the shape of what is coming, at 40%.
class _GhostRows extends StatelessWidget {
  const _GhostRows();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Opacity(
        opacity: 0.4,
        child: SettingGroup(
          label: 'Reading',
          children: <Widget>[
            SettingRow(label: ''),
            SettingRow(label: ''),
            SettingRow(label: ''),
          ],
        ),
      ),
    );
  }
}
