import 'package:recallos/features/followup/data/follow_up_repository.dart';
import 'package:recallos/features/followup/data/reminder_engine.dart';

/// A phone that remembers what it was told to schedule.
class FakePort implements NotificationPort {
  final Map<int, PendingReminder> held = <int, PendingReminder>{};
  bool allowed = false;
  bool grantOnAsk = true;
  int asked = 0;
  int prepared = 0;

  @override
  Future<void> prepare() async => prepared++;
  @override
  Future<bool> enabled() async => allowed;
  @override
  Future<bool> requestPermission() async {
    asked++;
    allowed = grantOnAsk;
    return allowed;
  }

  @override
  Future<Set<int>> scheduledIds() async => held.keys.toSet();
  @override
  Future<void> schedule(PendingReminder r) async => held[r.id] = r;
  @override
  Future<void> cancel(int id) async => held.remove(id);

  int settingsOpened = 0;
  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
