import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../../followup/data/follow_up_repository.dart';
import '../../followup/presentation/card_follow_up_blocks.dart';
import '../../plus/data/plus_controller.dart';
import '../data/wallet_events.dart';
import 'event_widgets.dart';

/// Event Mode: name the event once, and every card scanned until it ends is
/// marked as met there, that day. When it ends, everyone met, and what is
/// next with each of them, on one screen.
///
/// Part of RecallOS Plus. The free version sees what it does — an example of
/// the summary, drawn by the same widgets — and the way to Plus, never a Start
/// button that cannot start anything.
class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({this.eventId, this.now = DateTime.now, super.key});

  /// One event's summary. Null shows the running event, or the way to start.
  final int? eventId;
  final DateTime Function() now;

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  final TextEditingController _name = TextEditingController();

  /// The event just ended here, kept on screen as its summary — the moment
  /// the summary is for.
  int? _justEnded;
  bool _nameMissing = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final EventStore store = ref.read(eventStoreProvider);
    setState(() => _busy = true);
    await store.start(name);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _justEnded = null;
      _name.clear();
    });
  }

  Future<void> _end() async {
    final EventStore store = ref.read(eventStoreProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final WalletEvent? ended = await store.end();
    if (!mounted || ended == null) return;
    setState(() => _justEnded = ended.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${ended.name} has ended'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(store.reopen(ended.id));
            if (mounted) setState(() => _justEnded = null);
          },
        ),
      ),
    );
  }

  Future<void> _forget(WalletEvent event) async {
    final EventStore store = ref.read(eventStoreProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GoRouter? router = GoRouter.maybeOf(context);
    final WalletEvent? gone = await store.forget(event.id);
    if (!mounted || gone == null) return;
    setState(() => _justEnded = null);
    // A page opened on this event has nothing left to show.
    if (widget.eventId != null && router != null && router.canPop()) {
      router.pop();
    }
    // The "has ended" note may still be up, offering an Undo for an event
    // that is no longer here.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Removed ${gone.name}. The cards still say where you met.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(store.putBack(gone)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<List<WalletEvent>> events = ref.watch(
      walletEventsProvider,
    );
    final List<WalletEvent> all = events.value ?? const <WalletEvent>[];
    final int? showId = widget.eventId ?? _justEnded;
    final WalletEvent? shown = showId == null
        ? all.where((WalletEvent e) => e.active).firstOrNull
        : all.where((WalletEvent e) => e.id == showId).firstOrNull;

    final Widget body;
    if (!events.hasValue) {
      // Rule 5: a ghost, never a spinner.
      body = const Padding(
        padding: EdgeInsets.symmetric(horizontal: Gap.lg),
        child: GhostStack(count: 1),
      );
    } else if (shown != null) {
      body = _EventView(
        event: shown,
        now: widget.now,
        onEnd: _end,
        onForget: () => unawaited(_forget(shown)),
        // Ending from a past event's own page would end a different one.
        canEnd: widget.eventId == null || shown.active,
      );
    } else if (widget.eventId != null) {
      body = EmptyState(
        label: 'Not found',
        title: 'This event is not here any more',
        body: 'The cards met there still say where you met them.',
      );
    } else {
      body = _StartView(
        name: _name,
        nameMissing: _nameMissing,
        busy: _busy,
        earlier: <WalletEvent>[
          for (final WalletEvent e in all)
            if (!e.active) e,
        ],
        now: widget.now,
        onNameChanged: () {
          if (_nameMissing) setState(() => _nameMissing = false);
        },
        onStart: _start,
      );
    }

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'Event Mode', onBack: () => context.pop()),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// How long an event ran, in words: "Started 1 PM today", "Sat, 4 Oct",
/// "Sat, 4 Oct – Mon, 6 Oct".
String eventSpanWords(WalletEvent e, DateTime now) {
  final DateTime start = e.startedAt;
  final DateTime? end = e.endedAt;
  if (end == null) {
    return daysFrom(now, start) == 0
        ? 'Started ${clock(start)} today'
        : 'Running since ${weekdayDayMonth(start, now)}';
  }
  if (dayOf(start) == dayOf(end)) return weekdayDayMonth(start, now);
  return '${weekdayDayMonth(start, now)} – ${weekdayDayMonth(end, now)}';
}

/// No event running: what Event Mode does, and the way in.
class _StartView extends ConsumerWidget {
  const _StartView({
    required this.name,
    required this.nameMissing,
    required this.busy,
    required this.earlier,
    required this.now,
    required this.onNameChanged,
    required this.onStart,
  });

  final TextEditingController name;
  final bool nameMissing;
  final bool busy;
  final List<WalletEvent> earlier;
  final DateTime Function() now;
  final VoidCallback onNameChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final PlusPhase phase = ref.watch(plusProvider).phase;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: <Widget>[
        // Rule 3: the serif italic is the app asking the user something.
        Text('Off to an event?', style: AppText.displayAsk(c)),
        const SizedBox(height: Gap.sm),
        Text(
          'Name it once. Every card you scan until you end it is marked as '
          'met there, that day — and when it is over, you see everyone you '
          'met and what you said you would do next, in one list.',
          style: AppText.body(c),
        ),
        const SizedBox(height: Gap.lg),
        switch (phase) {
          PlusPhase.checking => const GhostStack(count: 1),
          PlusPhase.owned => _StartForm(
            name: name,
            nameMissing: nameMissing,
            busy: busy,
            onChanged: onNameChanged,
            onStart: onStart,
          ),
          PlusPhase.free || PlusPhase.pending => const _PlusPreview(),
        },
        if (earlier.isNotEmpty) ...<Widget>[
          const SizedBox(height: Gap.xl),
          SettingGroup(
            label: 'Earlier events',
            children: <Widget>[
              for (final WalletEvent e in earlier)
                SettingRow(
                  label: e.name,
                  description: eventSpanWords(e, now()),
                  trailing: Icon(Icons.chevron_right, color: c.inkMuted),
                  onTap: () => context.push(Routes.eventOf(e.id)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StartForm extends StatelessWidget {
  const _StartForm({
    required this.name,
    required this.nameMissing,
    required this.busy,
    required this.onChanged,
    required this.onStart,
  });

  final TextEditingController name;
  final bool nameMissing;
  final bool busy;
  final VoidCallback onChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MicroLabel('Where are you?', color: c.inkMuted),
        const SizedBox(height: Gap.sm),
        // Rule 1: recessed, never outlined.
        Pocket(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm + 2,
          ),
          child: TextField(
            controller: name,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onStart(),
            cursorColor: c.ochre,
            cursorWidth: 2,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: AppText.rowTitle(c).copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              fontVariations: AppFonts.weight(400),
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'CSE fest at NSU',
              hintStyle: AppText.body(c).copyWith(fontSize: 15),
            ),
          ),
        ),
        if (nameMissing) ...<Widget>[
          const SizedBox(height: Gap.sm),
          Text(
            'Name the event first — it is what each card will say.',
            style: AppText.small(c).copyWith(color: c.vermilion),
          ),
        ],
        const SizedBox(height: Gap.md),
        InkPill(
          label: busy ? 'Starting…' : 'Start the event',
          height: 58,
          onTap: busy ? null : onStart,
        ),
      ],
    );
  }
}

/// The free version: what the end of an event looks like, and where Event
/// Mode comes from. An example, said to be one, in the real summary's rows.
class _PlusPreview extends StatelessWidget {
  const _PlusPreview();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Example'),
        Text(
          'What the end of an event looks like:',
          style: AppText.body(c).copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.sm),
        const EventPersonRow(
          title: 'Green Leaf Printing',
          person: 'Shafiq Rahman',
          next: 'Ask for a quote on 500 cards · Due tomorrow',
        ),
        const SizedBox(height: Gap.sm),
        const EventPersonRow(
          title: 'Bengal Event Solutions',
          person: 'Nusrat Jahan',
        ),
        const SizedBox(height: Gap.sm),
        const EventPersonRow(
          title: 'Pixel Studio BD',
          person: 'Nabila Rahman',
          next: 'Send the brand brief · Due Friday',
        ),
        const SizedBox(height: Gap.lg),
        InkPill(
          label: 'Comes with RecallOS Plus',
          height: 58,
          onTap: () => context.push(Routes.plus),
        ),
      ],
    );
  }
}

/// One event: the running one, or one that has ended — everyone met there,
/// split by whether there is a plan for them yet.
class _EventView extends ConsumerWidget {
  const _EventView({
    required this.event,
    required this.now,
    required this.onEnd,
    required this.onForget,
    required this.canEnd,
  });

  final WalletEvent event;
  final DateTime Function() now;
  final VoidCallback onEnd;
  final VoidCallback onForget;
  final bool canEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final DateTime at = now();
    final List<MetCard>? cards = ref.watch(eventCardsProvider(event)).value;
    final List<MetCard> unplanned = <MetCard>[
      for (final MetCard m in cards ?? const <MetCard>[])
        if (m.openSteps.isEmpty) m,
    ];
    final List<MetCard> planned = <MetCard>[
      for (final MetCard m in cards ?? const <MetCard>[])
        if (m.openSteps.isNotEmpty) m,
    ];
    final int met = (cards ?? const <MetCard>[]).length;

    final String summary;
    if (event.active) {
      summary =
          'Every card you scan now is marked as met here, today. End the '
          'event when you leave.';
    } else if (met == 0) {
      summary = 'No cards were scanned while it ran.';
    } else if (unplanned.length == met) {
      summary = met == 1
          ? 'You met 1 person here, with no next step yet.'
          : 'You met $met people here, none with a next step yet.';
    } else if (unplanned.isEmpty) {
      summary = met == 1
          ? 'You met 1 person here, with a next step planned.'
          : 'You met $met people here, each with a next step planned.';
    } else {
      final String people = met == 1 ? '1 person' : '$met people';
      final String still = unplanned.length == 1
          ? '1 still needs a next step'
          : '${unplanned.length} still need a next step';
      summary = 'You met $people here. $still.';
    }

    Widget row(MetCard m) {
      final ImportantDate? first = m.openSteps.firstOrNull;
      final ({String text, bool overdue})? due = first == null
          ? null
          : dueWords(first.dueOn, at);
      return Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: EventPersonRow(
          title: m.title,
          person: m.person,
          next: first == null ? null : '${first.title} · ${due!.text}',
          nextIsLate: due?.overdue ?? false,
          moreSteps: m.openSteps.isEmpty ? 0 : m.openSteps.length - 1,
          onOpen: () => unawaited(
            openCardDetail<void>(context, cardId: m.cardId, imagePath: null),
          ),
          onAddStep: () => unawaited(addNextStep(context, ref, m.cardId)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: <Widget>[
        Text(event.name, style: AppText.title(c)),
        const SizedBox(height: 2),
        Text(
          eventSpanWords(event, at),
          style: AppText.body(c).copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.md),
        Text(summary, style: AppText.body(c)),
        if (event.active && canEnd) ...<Widget>[
          const SizedBox(height: Gap.lg),
          // Stacked, not side by side: at half width "End the event" ran out
          // of room at larger text.
          InkPill(
            label: 'Scan a card',
            icon: Icons.document_scanner_outlined,
            height: 58,
            onTap: () => context.push(Routes.capture),
          ),
          const SizedBox(height: Gap.sm),
          OutlinePill(label: 'End the event', height: 58, onTap: onEnd),
        ],
        if (cards == null) ...<Widget>[
          const SizedBox(height: Gap.lg),
          const GhostStack(count: 1),
        ],
        if (unplanned.isNotEmpty) ...<Widget>[
          const SizedBox(height: Gap.lg),
          SectionHeader('No next step yet', count: unplanned.length),
          const SizedBox(height: Gap.sm),
          for (final MetCard m in unplanned) row(m),
        ],
        if (planned.isNotEmpty) ...<Widget>[
          const SizedBox(height: Gap.lg),
          SectionHeader('Next step planned', count: planned.length),
          const SizedBox(height: Gap.sm),
          for (final MetCard m in planned) row(m),
        ],
        if (!event.active) ...<Widget>[
          const SizedBox(height: Gap.lg),
          Center(
            child: TextAction(
              label: 'Remove from your events',
              tint: c.inkMuted,
              onTap: onForget,
            ),
          ),
        ],
      ],
    );
  }
}
