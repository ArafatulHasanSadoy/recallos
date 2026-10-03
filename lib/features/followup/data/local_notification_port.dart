import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'follow_up_repository.dart';
import 'reminder_engine.dart';

/// What the user did with a reminder notification.
class ReminderResponse {
  const ReminderResponse({
    required this.action,
    this.stepId,
    this.cardId,
    this.reminderId,
  });

  /// `done`, `snooze`, or null for a tap on the notification itself.
  final String? action;
  final int? stepId;
  final int? cardId;
  final int? reminderId;

  static const String done = 'done';
  static const String snooze = 'snooze';

  static String payloadFor(PendingReminder r) =>
      'step=${r.stepId};card=${r.cardId};reminder=${r.id}';

  factory ReminderResponse.parse(String? action, String? payload) {
    final Map<String, int> v = <String, int>{};
    for (final String part in (payload ?? '').split(';')) {
      final List<String> kv = part.split('=');
      if (kv.length != 2) continue;
      final int? n = int.tryParse(kv[1]);
      if (n != null) v[kv[0]] = n;
    }
    return ReminderResponse(
      action: (action == null || action.isEmpty) ? null : action,
      stepId: v['step'],
      cardId: v['card'],
      reminderId: v['reminder'],
    );
  }
}

/// Reminders through `flutter_local_notifications`.
///
/// One instance for the process: the plugin keeps its own state, and the tap
/// callback it is initialised with must outlive every screen.
class LocalNotificationPort implements NotificationPort {
  LocalNotificationPort._();

  static final LocalNotificationPort instance = LocalNotificationPort._();

  static const String _channelId = 'next_steps';
  static const MethodChannel _appInfo = MethodChannel('recallos/app_info');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<ReminderResponse> _responses =
      StreamController<ReminderResponse>.broadcast();
  Future<void>? _ready;

  /// Taps and button presses while the app is running.
  Stream<ReminderResponse> get responses => _responses.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _init() => _ready ??= () async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_recallos'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse r) =>
          _responses.add(ReminderResponse.parse(r.actionId, r.payload)),
    );
  }();

  /// The reminder that opened the app from cold, if one did. Asked once, at
  /// startup; a tap while running arrives on [responses] instead.
  Future<ReminderResponse?> launchResponse() async {
    try {
      await _init();
      final NotificationAppLaunchDetails? d = await _plugin
          .getNotificationAppLaunchDetails();
      final NotificationResponse? r = d?.notificationResponse;
      if (d == null || !d.didNotificationLaunchApp || r == null) return null;
      return ReminderResponse.parse(r.actionId, r.payload);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> prepare() async {
    await _init();
    tz.setLocalLocation(await _zone());
  }

  /// The phone's zone, asked of Android each time, because a phone that
  /// travelled should remind at 9 AM where it is now.
  Future<tz.Location> _zone() async {
    try {
      final String? id = await _appInfo.invokeMethod<String>('timezone');
      if (id != null) return tz.getLocation(id);
    } on Object {
      // Fall through to the offset.
    }
    // No name to go by: any zone with the same offset schedules the same
    // instant for the next reminder, which is all that is needed of it.
    final Duration offset = DateTime.now().timeZoneOffset;
    for (final tz.Location l in tz.timeZoneDatabase.locations.values) {
      if (l.currentTimeZone.offset == offset) return l;
    }
    return tz.UTC;
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _appInfo.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> enabled() async {
    await _init();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<Set<int>> scheduledIds() async {
    await _init();
    return <int>{
      for (final PendingNotificationRequest p
          in await _plugin.pendingNotificationRequests())
        p.id,
    };
  }

  @override
  Future<void> schedule(PendingReminder r) async {
    await _init();
    await _plugin.zonedSchedule(
      id: r.id,
      title: r.stepTitle,
      body: r.cardTitle,
      scheduledDate: tz.TZDateTime.from(r.remindAt, tz.local),
      payload: ReminderResponse.payloadFor(r),
      // Inexact on purpose: exact alarms need a permission Play reserves for
      // alarm clocks and calendars, and a follow-up a few minutes late is
      // still on time.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Next steps',
          channelDescription: 'Reminders for the next steps you set on cards.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: 'ic_stat_recallos',
          // On a locked phone Android shows only that RecallOS has a
          // reminder; who it is about stays behind the unlock.
          visibility: NotificationVisibility.private,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              ReminderResponse.done,
              'Done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              ReminderResponse.snooze,
              'Snooze 1 hour',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}
