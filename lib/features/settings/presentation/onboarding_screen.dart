import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/brand.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../data/app_settings.dart';

/// Frame 13. Three panels, shown once.
///
/// The fanned stack is the entire illustration budget: three rotated
/// containers, no assets and no Lottie. Panel two asks for the camera in plain
/// words *before* the OS dialog fires, so the system prompt arrives as an
/// expected consequence rather than an ambush; panel three scans a real card,
/// so the first thing in the wallet is not a sample.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({bool scan = false}) async {
    await ref.read(appSettingsProvider.notifier).markOnboarded();
    if (!mounted) return;
    context.go(Routes.home);
    if (scan) unawaited(context.push(Routes.capture));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool last = _index == 2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RecallBrand(),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (int i) => setState(() => _index = i),
                children: const <Widget>[
                  _Panel(
                    title: 'You remember\nthe need,\nnot the name.',
                    body:
                        'So scan the card, then say in your own words why it '
                        'mattered. That sentence is how you will find it '
                        'again.',
                  ),
                  _Panel(
                    title: 'The camera,\nand nothing\nelse.',
                    body:
                        'RecallOS needs the camera to read a card. It asks '
                        'for nothing else — the release build ships without '
                        'permission to reach the internet at all.',
                  ),
                  _Panel(
                    title: 'Start with\na real card.',
                    body:
                        'Not a sample. Scan something from your own pocket, '
                        'so the first thing in the wallet is worth keeping.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        AnimatedContainer(
                          duration: AppMotion.quick,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _index ? c.ochre : c.hairline,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  InkPill(
                    label: last ? 'Scan the first card' : 'Next',
                    height: 58,
                    onTap: () {
                      if (last) {
                        unawaited(_finish(scan: true));
                      } else {
                        unawaited(
                          _pages.nextPage(
                            duration: AppMotion.normal,
                            curve: AppMotion.curve,
                          ),
                        );
                      }
                    },
                  ),
                  PressFade(
                    onTap: () => unawaited(_finish()),
                    child: SizedBox(
                      height: kMinTarget,
                      child: Center(
                        child: Text(
                          'Skip',
                          style: AppText.button(c, on: c.inkMuted),
                        ),
                      ),
                    ),
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

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    // Keep the navigation reachable when the brand header and larger type
    // leave less room for the illustration on a compact phone.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _FannedCards(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: AppText.display(c).copyWith(fontSize: 38),
                          ),
                          const SizedBox(height: Gap.md),
                          Text(
                            body,
                            style: AppText.body(c).copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

/// Three cards, fanned. The whole illustration.
class _FannedCards extends StatelessWidget {
  const _FannedCards();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool dark = isDarkTheme(context);

    return SizedBox(
      height: 190,
      child: Center(
        child: SizedBox(
          width: 250,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (final (int i, double turn) in <(int, double)>[
                (0, -0.13),
                (1, 0.04),
                (2, 0.19),
              ])
                Transform.rotate(
                  angle: turn * math.pi,
                  child: Transform.translate(
                    offset: Offset((i - 1) * 16, (i - 1) * 6),
                    child: Container(
                      width: 176,
                      height: 111,
                      decoration: AppDecoration.card(c, isDark: dark),
                      child: Stack(
                        children: <Widget>[
                          if (i == 2) const Center(child: RecallMark(size: 64)),
                          Align(
                            alignment: Alignment.topRight,
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CustomPaint(painter: _FoldCorner(c)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoldCorner extends CustomPainter {
  const _FoldCorner(this.colors);

  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, 0)
        ..close(),
      Paint()..color = colors.ochre,
    );
  }

  @override
  bool shouldRepaint(_FoldCorner old) => old.colors.ochre != colors.ochre;
}
