import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../capture/data/card_repository.dart' show databaseProvider;
import '../../followup/data/follow_up_repository.dart';

final eventStoreProvider = Provider<EventStore>(
  (Ref ref) => EventStore(ref.watch(databaseProvider)),
);

/// Every event the user has named, the running one included, newest first.
final walletEventsProvider = StreamProvider<List<WalletEvent>>(
  (Ref ref) => ref.watch(eventStoreProvider).watchAll(),
);

/// The event running now, or null.
final activeEventProvider = Provider<WalletEvent?>(
  (Ref ref) => ref
      .watch(walletEventsProvider)
      .value
      ?.where((WalletEvent e) => e.active)
      .firstOrNull,
);

/// Everyone met at [WalletEvent], in the order they were scanned.
final eventCardsProvider = StreamProvider.family<List<MetCard>, WalletEvent>((
  Ref ref,
  WalletEvent event,
) {
  // A running event's stream can stay alive across midnight. Its upper bound
  // must stay open until the event ends, rather than freeze on the day this
  // provider was first read and silently exclude the next day's scans.
  return ref
      .watch(followUpRepositoryProvider)
      .watchMetAt(
        place: event.name,
        from: dayOf(event.startedAt),
        until: event.active ? null : event.days(event.endedAt!).until,
      );
});

/// Something the user went to and named in Event Mode: "CSE fest at NSU".
///
/// Not a table. An event owns nothing — the cards met there carry it, as an
/// encounter with its name and day — so what is stored here is only the name
/// and when it ran, which is what tells the summary which encounters belong.
class WalletEvent {
  const WalletEvent({
    required this.id,
    required this.name,
    required this.startedAt,
    this.endedAt,
  });

  final int id;
  final String name;
  final DateTime startedAt;

  /// Null while it is running. Only one runs at a time.
  final DateTime? endedAt;

  bool get active => endedAt == null;

  @override
  bool operator ==(Object other) =>
      other is WalletEvent &&
      other.id == id &&
      other.name == name &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(id, name, startedAt, endedAt);

  /// The first day it covers, and the day after the last — a running event
  /// covers up to today.
  ({DateTime from, DateTime until}) days(DateTime now) {
    final DateTime last = dayOf(endedAt ?? now);
    return (
      from: dayOf(startedAt),
      until: DateTime(last.year, last.month, last.day + 1),
    );
  }

  WalletEvent _ended(DateTime at) =>
      WalletEvent(id: id, name: name, startedAt: startedAt, endedAt: at);

  WalletEvent _reopened() =>
      WalletEvent(id: id, name: name, startedAt: startedAt);

  Map<String, Object?> _toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'startedAt': startedAt.toIso8601String(),
    if (endedAt case final DateTime ended) 'endedAt': ended.toIso8601String(),
  };

  static WalletEvent? _fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'];
    final Object? name = raw['name'];
    final DateTime? started = DateTime.tryParse('${raw['startedAt']}');
    if (id is! int || name is! String || name.isEmpty || started == null) {
      return null;
    }
    final Object? ended = raw['endedAt'];
    return WalletEvent(
      id: id,
      name: name,
      startedAt: started,
      endedAt: ended == null ? null : DateTime.tryParse('$ended'),
    );
  }
}

/// The events, kept as one JSON list in `settings`.
///
/// A list a person adds to a few times a year, read whole every time; a table
/// would be a migration for that. It lives in the database file, so a backup
/// carries it and a restore brings it back.
class EventStore {
  EventStore(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  static const String key = 'events_v1';

  Stream<List<WalletEvent>> watchAll() =>
      (_db.select(_db.settings)..where(($SettingsTable s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map(_parse);

  Future<List<WalletEvent>> all() async => _parse(
    await (_db.select(
      _db.settings,
    )..where(($SettingsTable s) => s.key.equals(key))).getSingleOrNull(),
  );

  Future<WalletEvent?> active() async =>
      (await all()).where((WalletEvent e) => e.active).firstOrNull;

  /// Starts [name] now, ending whatever was running: one event at a time.
  Future<WalletEvent> start(String name) async {
    final String what = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (what.isEmpty) throw ArgumentError.value(name, 'name', 'is empty');

    return _db.transaction(() async {
      final DateTime now = _now();
      final List<WalletEvent> events = <WalletEvent>[
        for (final WalletEvent e in await all()) e.active ? e._ended(now) : e,
      ];
      final int id = events.fold<int>(
        0,
        (int top, WalletEvent e) => e.id > top ? e.id : top,
      );
      final WalletEvent started = WalletEvent(
        id: id + 1,
        name: what,
        startedAt: now,
      );
      await _write(<WalletEvent>[started, ...events]);
      return started;
    });
  }

  /// Ends the running event. Returns it, ended, or null when none was running.
  Future<WalletEvent?> end() => _db.transaction(() async {
    final List<WalletEvent> events = await all();
    final WalletEvent? running = events
        .where((WalletEvent e) => e.active)
        .firstOrNull;
    if (running == null) return null;
    final WalletEvent ended = running._ended(_now());
    await _write(<WalletEvent>[
      for (final WalletEvent e in events) e.id == running.id ? ended : e,
    ]);
    return ended;
  });

  /// Undoes [end] — the snackbar's Undo — unless another event has started
  /// since, which would make two run at once.
  Future<void> reopen(int id) => _db.transaction(() async {
    final List<WalletEvent> events = await all();
    if (events.any((WalletEvent e) => e.active)) return;
    await _write(<WalletEvent>[
      for (final WalletEvent e in events) e.id == id ? e._reopened() : e,
    ]);
  });

  /// Takes an ended event off the list — a mistyped one, or one not worth
  /// keeping. The cards met there keep where they were met: that is theirs,
  /// not the event's. Returns what was removed, for Undo; a running event is
  /// ended first, never removed out from under the scans.
  Future<WalletEvent?> forget(int id) => _db.transaction(() async {
    final List<WalletEvent> events = await all();
    final WalletEvent? gone = events
        .where((WalletEvent e) => e.id == id && !e.active)
        .firstOrNull;
    if (gone == null) return null;
    await _write(<WalletEvent>[
      for (final WalletEvent e in events)
        if (e.id != id) e,
    ]);
    return gone;
  });

  /// Undoes [forget].
  Future<void> putBack(WalletEvent event) => _db.transaction(() async {
    final List<WalletEvent> events = await all();
    if (events.any((WalletEvent e) => e.id == event.id)) return;
    await _write(<WalletEvent>[event, ...events]);
  });

  Future<void> _write(List<WalletEvent> events) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: key,
          value: jsonEncode(<Object?>[
            for (final WalletEvent e in events) e._toJson(),
          ]),
        ),
      );

  static List<WalletEvent> _parse(Setting? row) {
    if (row == null) return const <WalletEvent>[];
    try {
      final List<WalletEvent> events = <WalletEvent>[
        for (final Object? raw in jsonDecode(row.value) as List<Object?>)
          ?WalletEvent._fromJson(raw),
      ];
      return events..sort(
        (WalletEvent a, WalletEvent b) => b.startedAt.compareTo(a.startedAt),
      );
    } on Object {
      // Unreadable is treated as empty: the cards keep where they were met
      // either way, and starting a new event writes the list afresh.
      return const <WalletEvent>[];
    }
  }
}

/// The event an encounter places a card at, if it is one the user ran:
/// the same name, on one of its days.
WalletEvent? eventMetAt(
  List<WalletEvent> events,
  Encounter? met,
  DateTime now,
) {
  final String? place = met?.place;
  final DateTime? day = met?.metOn;
  if (place == null || day == null) return null;
  for (final WalletEvent e in events) {
    if (e.name.toLowerCase() != place.toLowerCase()) continue;
    final ({DateTime from, DateTime until}) span = e.days(now);
    if (!day.isBefore(span.from) && day.isBefore(span.until)) return e;
  }
  return null;
}
