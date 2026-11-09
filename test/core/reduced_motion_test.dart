import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/theme/app_theme.dart';

/// Android's *Remove animations*: Flutter shortens every finite animation by
/// itself, but not a `repeat()`, so a loop has to be told.
void main() {
  Widget at({required bool still, required GlobalKey<_LooperState> key}) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: _Looper(key: key),
      );

  testWidgets('with animations on, the loop runs', (WidgetTester t) async {
    final GlobalKey<_LooperState> key = GlobalKey<_LooperState>();
    await t.pumpWidget(at(still: false, key: key));
    expect(key.currentState!.c.isAnimating, isTrue);
  });

  testWidgets('removed, it holds still and asks for no frames', (
    WidgetTester t,
  ) async {
    final GlobalKey<_LooperState> key = GlobalKey<_LooperState>();
    await t.pumpWidget(at(still: true, key: key));
    expect(key.currentState!.c.isAnimating, isFalse);
    expect(key.currentState!.c.value, 0.5);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('it follows the setting if that changes while open', (
    WidgetTester t,
  ) async {
    final GlobalKey<_LooperState> key = GlobalKey<_LooperState>();
    await t.pumpWidget(at(still: false, key: key));
    await t.pumpWidget(at(still: true, key: key));
    expect(key.currentState!.c.isAnimating, isFalse);
    await t.pumpWidget(at(still: false, key: key));
    expect(key.currentState!.c.isAnimating, isTrue);
  });
}

class _Looper extends StatefulWidget {
  const _Looper({super.key});

  @override
  State<_Looper> createState() => _LooperState();
}

class _LooperState extends State<_Looper> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.loop(context, c);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
