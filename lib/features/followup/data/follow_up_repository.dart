import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../capture/data/card_repository.dart';
import '../../contacts/data/identity_repository.dart';

final followUpRepositoryProvider = Provider<FollowUpRepository>(
  (Ref ref) => FollowUpRepository(ref.watch(databaseProvider)),
);

/// Where the user met whoever is behind a card.
final encounterProvider = StreamProvider.family<Encounter?, int>(
  (Ref ref, int cardId) =>
      ref.watch(followUpRepositoryProvider).watchEncounter(cardId),
);

/// A card's open next steps.
final openStepsProvider = StreamProvider.family<List<NextStep>, int>(
  (Ref ref, int cardId) =>
      ref.watch(followUpRepositoryProvider).watchOpenSteps(cardId),
);

/// Steps on one card finished — done or removed — in the last 30 days.
final finishedStepsProvider = StreamProvider.family<List<ImportantDate>, int>(
  (Ref ref, int cardId) =>
      ref.watch(followUpRepositoryProvider).watchFinishedSteps(cardId),
);

/// Every open next step on a live card: what Today is made of.
final openFollowUpsProvider = StreamProvider<List<TodayEntry>>(
  (Ref ref) => ref.watch(followUpRepositoryProvider).watchOpen(),
);

/// Every warranty end still to come on a live warranty, soonest first
/// (B3's `warrantyExpiry` dates): what Today's *Ending soon* is picked from.
final warrantyEndsProvider = StreamProvider<List<TodayEntry>>(
  (Ref ref) => ref.watch(followUpRepositoryProvider).watchWarrantyEnds(),
);

/// A calendar day, as local midnight. Encounter and due dates are days, and
/// storing a time of day with them would make "today" depend on when the row
/// happened to be written. A new column holding one of these must be added
/// to [FollowUpRepository.followZone], or it reads a day out abroad.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// The moment that reads, in [to], what [at] read in [from]: the same date
/// and the same time on the clock.
DateTime sameClockIn(DateTime at, tz.Location from, tz.Location to) {
  final tz.TZDateTime was = tz.TZDateTime.from(at, from);
  final tz.TZDateTime moved = tz.TZDateTime(
    to,
    was.year,
    was.month,
    was.day,
    was.hour,
    was.minute,
    was.second,
  );
  return DateTime.fromMillisecondsSinceEpoch(moved.millisecondsSinceEpoch);
}

/// One open next step, and the reminder that is still due to fire for it.
class NextStep {
  const NextStep({required this.date, this.reminder});

  final ImportantDate date;

  /// The scheduled reminder, if any. Only one is kept active per step: a new
  /// time replaces the old one rather than adding a second alert.
  final Reminder? reminder;
}

/// A next step as Today lists it: the step, and whose card it belongs to.
class TodayEntry {
  const TodayEntry({
    required this.step,
    required this.cardId,
    required this.title,
    this.person,
    this.remindAt,
  });

  final ImportantDate step;
  final int cardId;

  /// The card's title — company, or the person, or a number — worked out the
  /// same way the wallet titles it, so the two never disagree.
  final String title;
  final String? person;
  final DateTime? remindAt;
}

/// Today's open steps, in the order they need attention.
class TodayView {
  const TodayView({
    required this.overdue,
    required this.today,
    required this.upcoming,
  });

  final List<TodayEntry> overdue;
  final List<TodayEntry> today;
  final List<TodayEntry> upcoming;

  bool get isEmpty => overdue.isEmpty && today.isEmpty && upcoming.isEmpty;

  /// Splits open steps by their due day against [now]'s day.
  ///
  /// Done at read time, not in the query: a stream does not re-run at
  /// midnight, so a split stored with the rows would still call yesterday's
  /// step "today" the next morning.
  factory TodayView.split(List<TodayEntry> open, DateTime now) {
    final DateTime today = dayOf(now);
    final List<TodayEntry> overdue = <TodayEntry>[];
    final List<TodayEntry> due = <TodayEntry>[];
    final List<TodayEntry> upcoming = <TodayEntry>[];
    for (final TodayEntry e in open) {
      final DateTime day = dayOf(e.step.dueOn);
      if (day.isBefore(today)) {
        overdue.add(e);
      } else if (day == today) {
        due.add(e);
      } else {
        upcoming.add(e);
      }
    }
    return TodayView(overdue: overdue, today: due, upcoming: upcoming);
  }
}

/// A card met at one place over some days, and what is still to do about it.
class MetCard {
  const MetCard({
    required this.cardId,
    required this.title,
    required this.openSteps,
    this.person,
  });

  final int cardId;
  final String title;
  final String? person;

  /// Soonest first.
  final List<ImportantDate> openSteps;
}

/// A reminder that Android should currently be holding.
class PendingReminder {
  const PendingReminder({
    required this.id,
    required this.stepId,
    required this.cardId,
    required this.remindAt,
    required this.stepTitle,
    required this.cardTitle,
    this.kind = DateKind.followUp,
    this.dueOn,
  });

  /// Also the Android notification id.
  final int id;
  final int stepId;
  final int cardId;
  final DateTime remindAt;
  final String stepTitle;
  final String cardTitle;

  /// What the date is: a follow-up the user set, or (from B3) an expiry.
  final DateKind kind;

  /// The day the date falls on, at local midnight — a warranty's last
  /// covered day, which its notice names.
  final DateTime? dueOn;
}

/// When and where the user met someone, and what they said they would do next.
///
/// Writes only what the user gave. Nothing here infers a meeting date, a place
/// or a deadline; the screens may *offer* the scan date as a suggestion, and it
/// arrives here only if the user takes it.
class FollowUpRepository {
  FollowUpRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  // ---------------------------------------------------------------------------
  // Encounters
  // ---------------------------------------------------------------------------

  /// The card's encounter, or null when the user has not said.
  Stream<Encounter?> watchEncounter(int cardId) =>
      (_db.select(_db.encounters)
            ..where(
              ($EncountersTable e) =>
                  e.cardId.equals(cardId) & e.deletedAt.isNull(),
            )
            ..orderBy(<OrderClauseGenerator<$EncountersTable>>[
              ($EncountersTable e) => OrderingTerm.desc(e.id),
            ])
            ..limit(1))
          .watchSingleOrNull();

  /// Records when and where the user met the person behind [cardId].
  ///
  /// One encounter per card for now; saving again corrects it. Clearing both
  /// the day and the place removes it, the same way clearing a note does.
  Future<void> setEncounter({
    required int cardId,
    DateTime? metOn,
    String? place,
  }) async {
    final String? where = _clean(place);
    final DateTime? day = metOn == null ? null : dayOf(metOn);

    await _db.transaction(() async {
      // A one-off read, not `watchEncounter(...).first`: a stream inside a
      // transaction waits on Drift's stream scheduling, which is not the
      // transaction's to wait on.
      final Encounter? existing =
          await (_db.select(_db.encounters)
                ..where(
                  ($EncountersTable e) =>
                      e.cardId.equals(cardId) & e.deletedAt.isNull(),
                )
                ..orderBy(<OrderClauseGenerator<$EncountersTable>>[
                  ($EncountersTable e) => OrderingTerm.desc(e.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      if (day == null && where == null) {
        if (existing != null) {
          await (_db.delete(
            _db.encounters,
          )..where(($EncountersTable e) => e.id.equals(existing.id))).go();
        }
        return;
      }
      if (existing == null) {
        await _db
            .into(_db.encounters)
            .insert(
              EncountersCompanion.insert(
                cardId: cardId,
                metOn: Value<DateTime?>(day),
                place: Value<String?>(where),
              ),
            );
      } else {
        await (_db.update(
          _db.encounters,
        )..where(($EncountersTable e) => e.id.equals(existing.id))).write(
          EncountersCompanion(
            metOn: Value<DateTime?>(day),
            place: Value<String?>(where),
            origin: const Value<EncounterOrigin>(EncounterOrigin.user),
            updatedAt: Value<DateTime>(_now()),
          ),
        );
      }
    });
  }

  /// Live cards met at [place] on a day from [from] up to, not including,
  /// [until] when given — everyone from one event — in the order they were
  /// scanned, each with its open steps. A running event leaves [until] null so
  /// this same stream also includes cards scanned on its later days.
  ///
  /// Matched on what the card says now, not on how it got there: a card whose
  /// place the user changed has left, and one they typed the same place and
  /// day into by hand has joined. The place is compared without case, as the
  /// user would read it; a card with no day is left out, since "not sure
  /// when" is not "at this event".
  Stream<List<MetCard>> watchMetAt({
    required String place,
    required DateTime from,
    required DateTime? until,
  }) {
    return _db
        .customSelect(
          'SELECT DISTINCT c.id AS card_id, c.captured_at AS captured_at '
          'FROM encounters e JOIN cards c ON c.id = e.card_id '
          'WHERE e.deleted_at IS NULL AND c.deleted_at IS NULL '
          'AND e.place = ? COLLATE NOCASE AND e.met_on IS NOT NULL '
          'AND e.met_on >= ? '
          '${until == null ? '' : 'AND e.met_on < ? '}'
          'ORDER BY c.captured_at, c.id',
          variables: <Variable<Object>>[
            Variable<String>(place),
            Variable<DateTime>(from),
            if (until != null) Variable<DateTime>(until),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.encounters,
            _db.cards,
            _db.cardFields,
            _db.importantDates,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          final List<MetCard> out = <MetCard>[];
          for (final QueryRow r in rows) {
            final int cardId = r.read<int>('card_id');
            final ({String title, String? person}) who = await _whoIs(cardId);
            final List<ImportantDate> steps =
                await (_db.select(_db.importantDates)
                      ..where(
                        ($ImportantDatesTable d) =>
                            d.cardId.equals(cardId) &
                            d.kind.equalsValue(DateKind.followUp) &
                            d.status.equalsValue(DateStatus.open) &
                            d.deletedAt.isNull(),
                      )
                      ..orderBy(<OrderClauseGenerator<$ImportantDatesTable>>[
                        ($ImportantDatesTable d) => OrderingTerm.asc(d.dueOn),
                        ($ImportantDatesTable d) => OrderingTerm.asc(d.id),
                      ]))
                    .get();
            out.add(
              MetCard(
                cardId: cardId,
                title: who.title,
                person: who.person,
                openSteps: steps,
              ),
            );
          }
          return out;
        });
  }

  // ---------------------------------------------------------------------------
  // Next steps
  // ---------------------------------------------------------------------------

  /// Steps on [cardId] that were finished in the last [days] days — marked
  /// done or removed — most recent first.
  ///
  /// Finishing a step only ever changes its status, so it is still here;
  /// this is what lets the card show it, and bring it back, long after the
  /// snackbar's Undo has gone. Found on the phone: two steps vanished from a
  /// card overnight and there was no way to see when, or to get them back.
  Stream<List<ImportantDate>> watchFinishedSteps(int cardId, {int days = 30}) {
    final DateTime since = _now().subtract(Duration(days: days));
    return (_db.select(_db.importantDates)
          ..where(
            ($ImportantDatesTable d) =>
                d.cardId.equals(cardId) &
                d.kind.equalsValue(DateKind.followUp) &
                d.status.equalsValue(DateStatus.open).not() &
                d.deletedAt.isNull() &
                d.updatedAt.isBiggerOrEqualValue(since),
          )
          ..orderBy(<OrderClauseGenerator<$ImportantDatesTable>>[
            ($ImportantDatesTable d) => OrderingTerm.desc(d.updatedAt),
            ($ImportantDatesTable d) => OrderingTerm.desc(d.id),
          ]))
        .watch();
  }

  /// Open next steps on one card, soonest first, each with its live reminder.
  ///
  /// Follow-ups only. `important_dates` will hold other kinds of date — a
  /// warranty's expiry (B3) — and those are not things the user said they
  /// would do next.
  Stream<List<NextStep>> watchOpenSteps(int cardId) {
    return _db
        .customSelect(
          'SELECT id FROM important_dates '
          "WHERE card_id = ? AND status = 'open' AND deleted_at IS NULL "
          'AND kind = ? '
          'ORDER BY due_on, id',
          variables: <Variable<Object>>[
            Variable<int>(cardId),
            Variable<String>(DateKind.followUp.name),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.importantDates,
            _db.reminders,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          final List<NextStep> out = <NextStep>[];
          for (final QueryRow r in rows) {
            final int id = r.read<int>('id');
            final ImportantDate? date = await _date(id);
            if (date == null) continue;
            out.add(NextStep(date: date, reminder: await _activeReminder(id)));
          }
          return out;
        });
  }

  /// Adds a next step to [cardId], due on [dueOn]'s day, with an optional
  /// reminder at [remindAt]. Returns the step's id.
  Future<int> addStep({
    required int cardId,
    required String title,
    required DateTime dueOn,
    DateTime? remindAt,
  }) async {
    final String what = _clean(title) ?? '';
    if (what.isEmpty) throw ArgumentError.value(title, 'title', 'is empty');

    return _db.transaction(() async {
      final int id = await _db
          .into(_db.importantDates)
          .insert(
            ImportantDatesCompanion.insert(
              cardId: cardId,
              kind: DateKind.followUp,
              title: what,
              dueOn: dayOf(dueOn),
            ),
          );
      if (remindAt != null) await _replaceReminder(id, remindAt);
      return id;
    });
  }

  /// Changes a step's words, day and reminder. A null [remindAt] removes the
  /// reminder; the step itself stays.
  Future<void> editStep(
    int stepId, {
    required String title,
    required DateTime dueOn,
    DateTime? remindAt,
  }) async {
    final String what = _clean(title) ?? '';
    if (what.isEmpty) throw ArgumentError.value(title, 'title', 'is empty');

    await _db.transaction(() async {
      await (_db.update(
        _db.importantDates,
      )..where(($ImportantDatesTable d) => d.id.equals(stepId))).write(
        ImportantDatesCompanion(
          title: Value<String>(what),
          dueOn: Value<DateTime>(dayOf(dueOn)),
          updatedAt: Value<DateTime>(_now()),
        ),
      );
      if (remindAt == null) {
        await _removeReminders(stepId);
      } else {
        await _replaceReminder(stepId, remindAt);
      }
    });
  }

  /// Marks a step done. Its reminders stop; [reopen] brings back the ones
  /// still in the future.
  Future<void> complete(int stepId) =>
      _setStatus(stepId, DateStatus.done, completedAt: _now());

  /// Drops a step the user is not going to do. Kept, as `dismissed`, so it is
  /// never counted as done.
  Future<void> dismiss(int stepId) => _setStatus(stepId, DateStatus.dismissed);

  /// Undoes [complete] or [dismiss].
  Future<void> reopen(int stepId) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.importantDates,
      )..where(($ImportantDatesTable d) => d.id.equals(stepId))).write(
        ImportantDatesCompanion(
          status: const Value<DateStatus>(DateStatus.open),
          completedAt: const Value<DateTime?>(null),
          updatedAt: Value<DateTime>(_now()),
        ),
      );
      // Only reminders still ahead come back; one whose moment has passed
      // would fire the instant it was rescheduled.
      await (_db.update(_db.reminders)..where(
            ($RemindersTable r) =>
                r.importantDateId.equals(stepId) &
                r.deletedAt.isNull() &
                r.remindAt.isBiggerThanValue(_now()),
          ))
          .write(
            RemindersCompanion(
              status: const Value<ReminderStatus>(ReminderStatus.scheduled),
              updatedAt: Value<DateTime>(_now()),
            ),
          );
    });
  }

  /// Moves a reminder [by] from now, leaving the step's due day alone.
  Future<void> snooze(int reminderId, Duration by) async {
    final Reminder? r = await (_db.select(
      _db.reminders,
    )..where(($RemindersTable t) => t.id.equals(reminderId))).getSingleOrNull();
    if (r == null) return;
    await (_db.update(
      _db.reminders,
    )..where(($RemindersTable t) => t.id.equals(reminderId))).write(
      RemindersCompanion(
        remindAt: Value<DateTime>(_now().add(by)),
        status: const Value<ReminderStatus>(ReminderStatus.scheduled),
        snoozeCount: Value<int>(r.snoozeCount + 1),
        updatedAt: Value<DateTime>(_now()),
      ),
    );
  }

  /// Whether the user has ever asked for a reminder. The notification
  /// permission is asked for at that moment, not at onboarding.
  Future<bool> hasAnyReminder() async =>
      (await (_db.select(_db.reminders)..limit(1)).get()).isNotEmpty;

  // ---------------------------------------------------------------------------
  // Today and the reminder engine
  // ---------------------------------------------------------------------------

  /// Every open step on a card that is not deleted, soonest first.
  ///
  /// A deleted card's steps drop out without being touched, and come back
  /// with it on restore — the same soft delete everything else follows.
  /// Follow-ups only, as on the card: a warranty's expiry is not a next step.
  Stream<List<TodayEntry>> watchOpen() {
    return _db
        .customSelect(
          'SELECT d.id AS id, d.card_id AS card_id FROM important_dates d '
          'JOIN cards c ON c.id = d.card_id '
          "WHERE d.status = 'open' AND d.deleted_at IS NULL "
          'AND c.deleted_at IS NULL '
          "AND d.kind = 'followUp' "
          'ORDER BY d.due_on, d.id',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.importantDates,
            _db.reminders,
            _db.cards,
            _db.cardFields,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          final List<TodayEntry> out = <TodayEntry>[];
          for (final QueryRow r in rows) {
            final ImportantDate? step = await _date(r.read<int>('id'));
            if (step == null) continue;
            final ({String title, String? person}) who = await _whoIs(
              r.read<int>('card_id'),
            );
            out.add(
              TodayEntry(
                step: step,
                cardId: step.cardId,
                title: who.title,
                person: who.person,
                remindAt: (await _activeReminder(step.id))?.remindAt,
              ),
            );
          }
          return out;
        });
  }

  /// Every open warranty end on a warranty that is not in the bin, soonest
  /// first, titled by the warranty (M7½: Today's *Ending soon*). Which of
  /// them are "soon" is the screen's to say, against the clock, as with the
  /// steps.
  Stream<List<TodayEntry>> watchWarrantyEnds() {
    return _db
        .customSelect(
          'SELECT d.id AS id, d.card_id AS card_id FROM important_dates d '
          'JOIN cards c ON c.id = d.card_id '
          "WHERE d.status = 'open' AND d.deleted_at IS NULL "
          "AND c.deleted_at IS NULL AND c.type = 'warrantyCard' "
          "AND d.kind = 'warrantyExpiry' "
          'ORDER BY d.due_on, d.id',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.importantDates,
            _db.cards,
            _db.cardFields,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          final List<TodayEntry> out = <TodayEntry>[];
          for (final QueryRow r in rows) {
            final ImportantDate? date = await _date(r.read<int>('id'));
            if (date == null) continue;
            out.add(
              TodayEntry(
                step: date,
                cardId: date.cardId,
                title: (await _whoIs(date.cardId)).title,
              ),
            );
          }
          return out;
        });
  }

  /// How many follow-up reminders are waiting — of the ones Android should
  /// hold, so the free limit counts what the user can see coming and nothing
  /// else. A reminder already sent, a finished step or a deleted card frees
  /// its place.
  ///
  /// Only follow-ups count. A warranty's expiry reminder (B3) is held by
  /// Android like any other but is not one of the free five (decided 15
  /// Oct): the user never asked for it — it comes with the warranty — and
  /// one should never be refused because of follow-ups.
  Future<int> activeReminderCount() async => (await pendingReminders())
      .where((PendingReminder r) => r.kind == DateKind.followUp)
      .length;

  /// Keeps stored days and reminder times meaning what they meant, on a
  /// phone that is now in [zone].
  ///
  /// A day is stored as local midnight, which is an instant, so a zone change
  /// moves what it reads as. Midnight on 12 Nov in Dhaka is 10 PM on 11 Nov in
  /// Dubai: every next step and "met on" read a day early there, and a
  /// warranty's end stopped matching its own last day and got a fresh
  /// reminder. So the zone in use is kept beside the data, and when it
  /// changes the rows are carried across, in one transaction, because two
  /// reconciles can overlap and moving a row twice would corrupt it. Kept in
  /// the database so a backup restored in another country is corrected too.
  ///
  /// A snooze is "an hour from now", not a time on the clock, so it stays
  /// put. A reminder only moves while it is still ahead and would stay ahead:
  /// one already shown must not come round again, and one about to fire
  /// should not be lost.
  Future<void> followZone(String zone) => _db.transaction(() async {
    final Setting? kept = await (_db.select(
      _db.settings,
    )..where(($SettingsTable s) => s.key.equals(_zoneKey))).getSingleOrNull();
    if (kept?.value == zone) return;
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: _zoneKey, value: zone),
        );

    final tz.Location? from = tz.timeZoneDatabase.locations[kept?.value];
    final tz.Location? to = tz.timeZoneDatabase.locations[zone];
    if (from == null || to == null) return;

    for (final ImportantDate d in await _db.select(_db.importantDates).get()) {
      await (_db.update(
        _db.importantDates,
      )..where(($ImportantDatesTable t) => t.id.equals(d.id))).write(
        ImportantDatesCompanion(
          dueOn: Value<DateTime>(sameClockIn(d.dueOn, from, to)),
        ),
      );
    }
    for (final Encounter e in await _db.select(_db.encounters).get()) {
      final DateTime? metOn = e.metOn;
      if (metOn == null) continue;
      await (_db.update(
        _db.encounters,
      )..where(($EncountersTable t) => t.id.equals(e.id))).write(
        EncountersCompanion(
          metOn: Value<DateTime?>(sameClockIn(metOn, from, to)),
        ),
      );
    }

    final DateTime now = _now();
    final List<Reminder> ahead =
        await (_db.select(_db.reminders)..where(
              ($RemindersTable r) =>
                  r.remindAt.isBiggerThanValue(now) & r.snoozeCount.equals(0),
            ))
            .get();
    for (final Reminder r in ahead) {
      final DateTime moved = sameClockIn(r.remindAt, from, to);
      if (!moved.isAfter(now)) continue;
      await (_db.update(_db.reminders)
            ..where(($RemindersTable t) => t.id.equals(r.id)))
          .write(RemindersCompanion(remindAt: Value<DateTime>(moved)));
    }
  });

  static const String _zoneKey = 'reminders.zone';

  /// The reminders Android should be holding right now: scheduled, still
  /// ahead, for an open step on a live card.
  Future<List<PendingReminder>> pendingReminders() async {
    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT r.id AS id, r.remind_at AS remind_at, d.id AS step_id, '
          'd.title AS title, d.card_id AS card_id, d.kind AS kind, '
          'd.due_on AS due_on '
          'FROM reminders r '
          'JOIN important_dates d ON d.id = r.important_date_id '
          'JOIN cards c ON c.id = d.card_id '
          "WHERE r.status = 'scheduled' AND r.deleted_at IS NULL "
          "AND d.status = 'open' AND d.deleted_at IS NULL "
          'AND c.deleted_at IS NULL AND r.remind_at > ? '
          'ORDER BY r.remind_at',
          variables: <Variable<Object>>[Variable<DateTime>(_now())],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.reminders,
            _db.importantDates,
            _db.cards,
          },
        )
        .get();

    final List<PendingReminder> out = <PendingReminder>[];
    for (final QueryRow r in rows) {
      final int cardId = r.read<int>('card_id');
      out.add(
        PendingReminder(
          id: r.read<int>('id'),
          stepId: r.read<int>('step_id'),
          cardId: cardId,
          remindAt: r.read<DateTime>('remind_at'),
          stepTitle: r.read<String>('title'),
          cardTitle: (await _whoIs(cardId)).title,
          // Read by name, so a kind this build does not know is held and
          // shown like a follow-up rather than failing the whole schedule.
          kind:
              DateKind.values
                  .where((DateKind k) => k.name == r.read<String>('kind'))
                  .firstOrNull ??
              DateKind.followUp,
          dueOn: r.read<DateTime>('due_on'),
        ),
      );
    }
    return out;
  }

  // ---------------------------------------------------------------------------

  Future<ImportantDate?> _date(int id) => (_db.select(
    _db.importantDates,
  )..where(($ImportantDatesTable d) => d.id.equals(id))).getSingleOrNull();

  Future<Reminder?> _activeReminder(int stepId) =>
      (_db.select(_db.reminders)
            ..where(
              ($RemindersTable r) =>
                  r.importantDateId.equals(stepId) &
                  r.status.equalsValue(ReminderStatus.scheduled) &
                  r.deletedAt.isNull(),
            )
            ..orderBy(<OrderClauseGenerator<$RemindersTable>>[
              ($RemindersTable r) => OrderingTerm.desc(r.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// One active reminder per step: the new time replaces any other.
  Future<void> _replaceReminder(int stepId, DateTime remindAt) async {
    final Reminder? current = await _activeReminder(stepId);
    if (current != null) {
      await (_db.update(
        _db.reminders,
      )..where(($RemindersTable r) => r.id.equals(current.id))).write(
        RemindersCompanion(
          remindAt: Value<DateTime>(remindAt),
          updatedAt: Value<DateTime>(_now()),
        ),
      );
      return;
    }
    // A previously cancelled reminder is no longer this step's chosen time.
    // Retire it before adding its replacement so reopening cannot revive it.
    await _removeReminders(stepId);
    await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            importantDateId: stepId,
            remindAt: remindAt,
          ),
        );
  }

  /// Removing a reminder is a lasting choice; finishing a step only pauses it
  /// so Undo can bring it back. Keep a tombstone to distinguish the two.
  Future<void> _removeReminders(int stepId) async {
    final DateTime removedAt = _now();
    await (_db.update(_db.reminders)..where(
          ($RemindersTable r) =>
              r.importantDateId.equals(stepId) & r.deletedAt.isNull(),
        ))
        .write(
          RemindersCompanion(
            status: const Value<ReminderStatus>(ReminderStatus.cancelled),
            deletedAt: Value<DateTime?>(removedAt),
            updatedAt: Value<DateTime>(removedAt),
          ),
        );
  }

  Future<void> _cancelReminders(int stepId) async {
    await (_db.update(_db.reminders)..where(
          ($RemindersTable r) =>
              r.importantDateId.equals(stepId) &
              r.status.equalsValue(ReminderStatus.scheduled),
        ))
        .write(
          RemindersCompanion(
            status: const Value<ReminderStatus>(ReminderStatus.cancelled),
            updatedAt: Value<DateTime>(_now()),
          ),
        );
  }

  Future<void> _setStatus(
    int stepId,
    DateStatus status, {
    DateTime? completedAt,
  }) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.importantDates,
      )..where(($ImportantDatesTable d) => d.id.equals(stepId))).write(
        ImportantDatesCompanion(
          status: Value<DateStatus>(status),
          completedAt: Value<DateTime?>(completedAt),
          updatedAt: Value<DateTime>(_now()),
        ),
      );
      await _cancelReminders(stepId);
    });
  }

  /// A card's title and person, by the wallet's own rule (`describeCard`):
  /// a business card's company, else the person, else a number; a
  /// warranty's product; a receipt's shop. A warranty's reminder used to be
  /// titled "A card" because only a business card's fields were looked for.
  Future<({String title, String? person})> _whoIs(int cardId) async {
    final CardRow? card = await (_db.select(
      _db.cards,
    )..where(($CardsTable c) => c.id.equals(cardId))).getSingleOrNull();
    final List<CardField> fields = await (_db.select(
      _db.cardFields,
    )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();

    final String? person = card == null || !_isPeopleCard(card.type)
        ? null
        : fields
              .where((CardField f) => f.fieldKey == FieldKeys.personName)
              .firstOrNull
              ?.value;
    return (
      title:
          (card == null ? null : describeCard(card, fields).title) ?? 'A card',
      person: person,
    );
  }

  static bool _isPeopleCard(CardType t) =>
      IdentityRepository.peopleCardTypes.contains(t);

  static String? _clean(String? raw) {
    final String t = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.isEmpty ? null : t;
  }
}
