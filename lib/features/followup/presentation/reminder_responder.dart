import 'dart:async';

import 'package:drift/drift.dart'
    show ResultSetImplementation, TableUpdate, TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../router.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;
import '../data/follow_up_actions.dart';
import '../data/local_notification_port.dart';
import '../data/reminder_engine.dart';

/// Answers reminder notifications, and keeps Android's copy honest.
///
/// A tap opens the card. "Done" finishes the step; "Snooze 1 hour" moves the
/// reminder. Both buttons bring the app forward, so they run here, on the
/// screen's own isolate, with the wallet already open — never in a background
/// isolate that would have to open the encrypted database by itself.
///
/// On every return to the foreground it reconciles and re-asks whether
/// notifications are allowed: the answer changes in Android's settings,
/// outside the app, and the clock may have crossed into a new day.
///
/// It also reconciles whenever cards, steps or reminders change, from
/// anywhere. Found on the phone: deleting a card from its own screen left its
/// reminders scheduled, because that delete is card code, not follow-up code,
/// and five such paths exist (the card screen, the home swipe and its undo,
/// Recently deleted, the 30-day sweep). Watching the tables covers every one
/// of them, and any added later, without each having to remember. Reconcile
/// only reads, so it cannot set itself off.
class ReminderResponder extends ConsumerStatefulWidget {
  const ReminderResponder({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderResponder> createState() => _ReminderResponderState();
}

class _ReminderResponderState extends ConsumerState<ReminderResponder>
    with WidgetsBindingObserver {
  StreamSubscription<ReminderResponse>? _taps;
  StreamSubscription<Set<TableUpdate>>? _changes;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taps = LocalNotificationPort.instance.responses.listen(
      (ReminderResponse r) => unawaited(_answer(r)),
    );
    final AppDatabase db = ref.read(databaseProvider);
    _changes = db
        .tableUpdates(
          TableUpdateQuery.onAllTables(
            <ResultSetImplementation<dynamic, dynamic>>[
              db.cards,
              db.importantDates,
              db.reminders,
            ],
          ),
        )
        .listen((_) {
          // A delete touches several tables at once; one reconcile after it
          // settles is enough.
          _settle?.cancel();
          _settle = Timer(
            const Duration(milliseconds: 400),
            () => unawaited(ref.read(reminderEngineProvider).reconcile()),
          );
        });
    // A reminder that launched the app from cold arrives once, here.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ReminderResponse? r = await LocalNotificationPort.instance
          .launchResponse();
      if (r != null && mounted) await _answer(r);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_taps?.cancel());
    unawaited(_changes?.cancel());
    _settle?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(notificationsEnabledProvider);
    unawaited(ref.read(reminderEngineProvider).reconcile());
  }

  Future<void> _answer(ReminderResponse r) async {
    final FollowUpActions actions = ref.read(followUpActionsProvider);
    final int? step = r.stepId;
    final int? reminder = r.reminderId;
    final int? card = r.cardId;
    switch (r.action) {
      case ReminderResponse.done when step != null:
        await actions.complete(step);
      case ReminderResponse.snooze when reminder != null:
        await actions.snooze(reminder, const Duration(hours: 1));
      case null when card != null:
        unawaited(ref.read(routerProvider).push<void>(Routes.card(card)));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
