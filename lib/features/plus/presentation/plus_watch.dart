import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/plus_controller.dart';

/// Keeps Plus in step with Google Play while the app runs.
///
/// Starts listening once the first frame is up, and asks Play again on every
/// return to the app: a payment confirmed while RecallOS was in the
/// background (a pending purchase, paid at a shop) turns Plus on then, and a
/// refund takes it away. Above every route, like [ReminderResponder], so it
/// is listening whichever screen is open.
class PlusWatch extends ConsumerStatefulWidget {
  const PlusWatch({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PlusWatch> createState() => _PlusWatchState();
}

class _PlusWatchState extends ConsumerState<PlusWatch>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(plusProvider.notifier).start());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(plusProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
