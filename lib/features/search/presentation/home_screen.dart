import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backup/restore_swap.dart';
import '../../../core/db/enums.dart';
import '../../../core/search/match_evidence.dart';
import '../../../core/search/query_plan.dart';
import '../../../core/spending/spending_totals.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/brand.dart';
import '../../../core/ui/card_face.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../../ask/presentation/ask_answers.dart';
import '../../capture/data/back_capture_service.dart';
import '../../capture/data/card_repository.dart';
import '../../capture/presentation/add_without_scanning.dart';
import '../../cards/data/retention_sweep.dart';
import '../../cards/presentation/needs_attention_screen.dart';
import '../../contacts/data/identity_repository.dart';
import '../../events/data/wallet_events.dart';
import '../../followup/data/follow_up_repository.dart';
import '../../followup/data/reminder_engine.dart';
import '../../plus/data/plus_controller.dart' show PlusState, plusProvider;
import '../../settings/data/backup_service.dart';
import '../../settings/data/photo_protection.dart';
import '../../spending/data/spending_repository.dart';
import '../../spending/presentation/spending_screen.dart'
    show homeReceiptsWords;
import '../data/search_repository.dart';
import 'lookup_answers.dart';
import 'people_answers.dart';

/// Live list of saved cards, newest first.
final savedCardsProvider = StreamProvider<List<CardSummary>>(
  (Ref ref) => ref.watch(cardRepositoryProvider).watchCards(),
);

/// The home screen leads with a single question rather than a card grid.
///
/// This is the product thesis made visible: people remember the *need*, not the
/// name, so the need is what we ask for first. Typing turns the list below into
/// results; clearing it turns them back into the library.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = '';
  SearchAnswer _answer = SearchAnswer.empty;
  bool _searching = false;

  /// Keeps open results true to the data. See [SearchRepository.watchChanges]:
  /// without it a card deleted from its own screen, or restored, or re-noted,
  /// stayed in the results as it was until the next keystroke.
  StreamSubscription<void>? _changes;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _changes = ref.read(searchRepositoryProvider).watchChanges().listen((_) {
      if (_query.isEmpty) return;
      // Coalesced: one edit touches several tables in a burst (the note, the
      // interaction, the card's timestamp, then the index), and the results
      // only need recomputing once it has settled.
      _refresh?.cancel();
      _refresh = Timer(const Duration(milliseconds: 150), () {
        if (mounted && _query.isNotEmpty) unawaited(_run(_query));
      });
    });
    // Cards saved before search existed have no index rows, and without this
    // they stay permanently invisible — which looks exactly like search being
    // broken.
    //
    // The backs are the same shape of problem: they have been storable for
    // longer than they have been readable, so the ones already on the phone
    // hold text nothing has ever looked at. Read first, indexed second, so a
    // back read on this launch is findable on this launch.
    //
    // The retention sweep goes first: it finishes deletes the user already
    // asked for (Recently deleted keeps a card for 30 days), and there is no
    // point reading or indexing a card that is about to be purged.
    //
    // Labels and names stored under an older rule go ahead of the backs and
    // the index: that is a handful of rows re-read from stored text, where
    // reading backs is OCR.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reportRestore());
      unawaited(() async {
        await ref.read(retentionSweepProvider).run();
        if (!ref.context.mounted) return;
        // After the sweep, which may have purged cards and their reminders
        // with them. This is also what re-arms reminders after an app update,
        // a restore or a change of time zone.
        await ref.read(reminderEngineProvider).reconcile();
        if (!ref.context.mounted) return;
        await ref.read(cardRepositoryProvider).repairDigitRestoredLabels();
        if (!ref.context.mounted) return;
        await ref
            .read(cardRepositoryProvider)
            .repairInventedPeople(ref.read(identityRepositoryProvider));
        if (!ref.context.mounted) return;
        // Photographs from before photo encryption are sealed in place, once.
        await ref.read(photoProtectionProvider.future);
        if (!ref.context.mounted) return;
        await ref.read(backCaptureServiceProvider).backfill();
        if (!ref.context.mounted) return;
        await ref.read(searchRepositoryProvider).backfill();
      }());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refresh?.cancel();
    unawaited(_changes?.cancel());
    _controller.dispose();
    super.dispose();
  }

  /// Says once, on the first screen after a restart, what a restore did.
  /// The restore itself finished before this screen existed — see
  /// `restore_swap.dart` — so this is the only place the user can be told.
  Future<void> _reportRestore() async {
    final RestoreOutcome? outcome = await ref.read(
      restoreOutcomeProvider.future,
    );
    if (outcome == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.ok
              ? 'Restored ${outcome.cards} '
                    '${outcome.cards == 1 ? 'card' : 'cards'} from your backup.'
              : 'That restore could not finish, so your wallet was left as it '
                    'was.',
        ),
        persist: false,
      ),
    );
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final String trimmed = raw.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _answer = SearchAnswer.empty;
        _searching = false;
      });
      return;
    }

    setState(() {
      _query = trimmed;
      _searching = true;
    });
    // An embedding costs ~25 µs, but FTS5 and ranking over a growing library do
    // not, so searching is held until typing pauses.
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(trimmed));
  }

  Future<void> _run(String query) async {
    final SearchAnswer answer = await ref
        .read(searchRepositoryProvider)
        .ask(query, plus: ref.read(plusProvider).owned);
    if (!mounted || _query != query) return;
    setState(() {
      _answer = answer;
      _searching = false;
    });
  }

  /// Removes a card, with a way back.
  ///
  /// Two-stage, and neither stage destroys anything. The swipe hides it and
  /// offers an immediate undo; letting that window close leaves it in Recently
  /// deleted rather than purging it. Deleting something the user walked across
  /// a market to photograph should not be one mis-swipe and five seconds away
  /// from permanent — only an explicit "Delete for good" does that.
  Future<void> _delete(CardSummary card) async {
    final CardRepository repo = ref.read(cardRepositoryProvider);
    await repo.softDelete(card.id);
    // Straight away, not once the undo window closes. A card deleted and
    // never purged — because the app closed inside those five seconds — used
    // to leave its contacts and its company behind permanently.
    await ref.read(identityRepositoryProvider).detach(card.id);

    // Drop it from the visible results too, or a deleted card lingers on screen
    // until the next keystroke.
    if (mounted && !_answer.isEmpty) {
      setState(
        () => _answer = SearchAnswer(
          plan: _answer.plan,
          lookups: <LookupAnswer>[
            for (final LookupAnswer l in _answer.lookups)
              if (l.card.id != card.id) l,
          ],
          hits: <SearchHit>[
            for (final SearchHit h in _answer.hits)
              if (h.card.id != card.id) h,
          ],
        ),
      );
    }
    if (!mounted) return;

    Future<void>? restoring;
    final SnackBarClosedReason reason = await ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Deleted ${card.title ?? "card"}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => restoring = _restore(repo, card.id),
            ),
            duration: const Duration(seconds: 5),
            // Without this the bar carrying an action outlives its own
            // duration and sits over the library until it is swiped away by
            // hand, which reads as the app being stuck.
            persist: false,
          ),
        )
        .closed;

    if (reason == SnackBarClosedReason.action) {
      // The row has to be back before results are recomputed, or undo appears
      // to do nothing while a search is open.
      await restoring;
      if (_query.isNotEmpty) unawaited(_run(_query));
      return;
    }
    // Undo window closed untouched. The card stays soft-deleted and shows up
    // under Recently deleted, where it can be restored or destroyed on
    // purpose.
    //
    // It used to be purged right here. Five seconds is long enough to catch a
    // mis-swipe and nowhere near long enough to notice you deleted the wrong
    // card — and the destruction was total: photo, fields, index rows. The bin
    // already had the screen, the Restore button and the "Delete for good"
    // confirm; all that was missing was anything ever reaching it.
  }

  /// Puts a card back, and the person and company behind it with it.
  Future<void> _restore(CardRepository repo, int cardId) async {
    await repo.restore(cardId);
    await ref.read(identityRepositoryProvider).promote(cardId);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    // Plus is read from the kept receipt a moment after launch, and can be
    // bought or refunded while results are open: a people filter answered
    // as words a second ago is answered as a list now, and the other way.
    ref.listen<bool>(plusProvider.select((PlusState s) => s.owned), (
      bool? before,
      bool now,
    ) {
      if (before != now && _query.isNotEmpty) unawaited(_run(_query));
    });
    final AsyncValue<List<CardSummary>> saved = ref.watch(savedCardsProvider);
    final bool searchingNow = _query.isNotEmpty;
    // While the keyboard is up the body shrinks to the space above it, and a
    // pill pinned to the bottom lands on the answers being typed for.
    final bool keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      // No AppBar. Frame 01 puts the wordmark and two round buttons in the
      // page itself, so the display line can start high enough to breathe.
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _HomeHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Folded away while there is a question (M7½). With
                      // the keyboard up, the heading kept a quarter of the
                      // screen and left one answer showing; the answers need
                      // the room more than the question needs repeating.
                      // Clearing the field brings it back. `AnimatedAlign`
                      // over `AnimatedSize`, as in the profile editor: it
                      // animates a factor rather than re-measuring a child.
                      ExcludeSemantics(
                        excluding: searchingNow,
                        child: ClipRect(
                          child: AnimatedAlign(
                            duration: AppMotion.normal,
                            curve: AppMotion.curve,
                            alignment: Alignment.topCenter,
                            heightFactor: searchingNow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                const SizedBox(height: Gap.lg),
                                // Rule 3: the serif italic is the app asking,
                                // and this is the question the whole product
                                // is built around.
                                Text(
                                  'What do you\nneed?',
                                  style: AppText.displayAsk(c),
                                ),
                                const SizedBox(height: Gap.lg),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Always here, only its height changes. Found on the
                      // phone: an `if` here put a new widget in front of the
                      // field the moment the first letter folded the heading,
                      // Flutter built the field again, and the keyboard lost
                      // it — "When does…" arrived as "Wh". The children
                      // around the field must keep their places.
                      SizedBox(height: searchingNow ? Gap.sm : 0),
                      _SearchPocket(
                        controller: _controller,
                        onChanged: _onQueryChanged,
                        onClear: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                        hasQuery: searchingNow,
                      ),
                      // Only while browsing. During a search the user is
                      // answering a question, and a queue of unrelated repairs
                      // is an interruption rather than a prompt.
                      if (!searchingNow) const _AttentionRow(),
                      if (!searchingNow) const _EventRow(),
                      if (!searchingNow) const _TodayRow(),
                      if (!searchingNow) const _ReceiptsRow(),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.md),
                Expanded(
                  child: searchingNow
                      ? _SearchResults(
                          query: _query,
                          answer: _answer,
                          searching: _searching,
                          onClear: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        )
                      : saved.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 22),
                            child: GhostStack(),
                          ),
                          error: (Object e, _) => EmptyState(
                            label: 'Could not open',
                            title: 'The wallet did not open',
                            body: '$e',
                          ),
                          data: (List<CardSummary> cards) => cards.isEmpty
                              ? EmptyState(
                                  label: 'Wallet empty',
                                  title: 'Nothing in the wallet yet',
                                  body:
                                      'Scan the first card and say one line '
                                      'about why it mattered.',
                                  actionLabel: 'Scan a card',
                                  onAction: () => _leaveHomeFor<void>(
                                    context,
                                    Routes.capture,
                                  ),
                                )
                              : _Library(cards: cards, onDelete: _delete),
                        ),
                ),
              ],
            ),
            // The stack runs off the bottom of the screen rather than stopping
            // at a hard edge, so the wallet reads as deeper than the viewport.
            const Positioned(left: 0, right: 0, bottom: 0, child: StackFade()),
            // Rule: this is a Positioned child of the body, never a
            // floatingActionButton — a Material FAB brings its own elevation
            // curve, its own shape and a ripple. Stood down while somebody is
            // typing a search: scanning is not what they are doing, and it
            // would sit on top of the answers.
            if (!keyboardUp)
              Positioned(
                left: Gap.lg,
                right: Gap.lg,
                bottom: 34,
                child: Row(
                  children: <Widget>[
                    const _EventButton(),
                    const SizedBox(width: Gap.sm + 2),
                    // Started from here and not from the button: the row
                    // leaves the tree as soon as a sheet raises the keyboard,
                    // and a flow holding the button's context would stop
                    // dead at its next `mounted` check, saving nothing.
                    _AddButton(
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        unawaited(addWithoutScanning(context, ref));
                      },
                    ),
                    const SizedBox(width: Gap.sm + 2),
                    Expanded(
                      // "Scan", not "Scan a card": since B2 the same button
                      // saves a receipt or a warranty, read and typed as one.
                      child: InkPill(
                        label: 'Scan',
                        icon: Icons.document_scanner_outlined,
                        height: 58,
                        onTap: () =>
                            _leaveHomeFor<void>(context, Routes.capture),
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

/// Leaves home for [route], letting go of the search field's focus first,
/// as opening a card already does (`openCardDetail`). Found on the phone:
/// back from a scan, the field still held focus and raised the keyboard by
/// itself over the wallet.
Future<T?> _leaveHomeFor<T>(BuildContext context, String route) {
  FocusManager.instance.primaryFocus?.unfocus();
  return context.push<T>(route);
}

/// The wordmark, and the three ways out of this screen.
///
/// Replaces the `AppBar` and its `PopupMenuButton`. The mark is the logo's
/// folded-card R at 32px; the wordmark is Archivo bold, uppercase, wide-tracked,
/// and never set in the serif.
///
/// Three round buttons plus the lockup is tight on a narrow phone — the
/// `FittedBox` around `RecallBrand` is what absorbs it, shrinking the wordmark
/// rather than overflowing. Your own card earns the space: it is the one thing
/// here that is about the person holding the phone, and the demo opens on it.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, 0),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: RecallBrand()),
            ),
          ),
          _RoundButton(
            icon: Icons.badge_outlined,
            tooltip: 'Your card',
            onTap: () => _leaveHomeFor<void>(context, Routes.myCard),
          ),
          const SizedBox(width: Gap.sm),
          _RoundButton(
            icon: Icons.people_outline,
            tooltip: 'People',
            onTap: () => _leaveHomeFor<void>(context, Routes.contacts),
          ),
          const SizedBox(width: Gap.sm),
          _RoundButton(
            icon: Icons.tune,
            tooltip: 'Settings',
            onTap: () => _leaveHomeFor<void>(context, Routes.settings),
          ),
        ],
      ),
    );
  }
}

/// A 36px round icon button with a 52px tap target.
///
/// The visible circle is smaller than the target on purpose: the accessibility
/// floor is 52, and shrinking the target to match the art is how icon buttons
/// become the thing people blame when they miss.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return PressFade(
      onTap: onTap,
      scale: 0.92,
      semanticLabel: tooltip,
      child: SizedBox(
        width: kMinTarget,
        height: kMinTarget,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline),
            ),
            child: Icon(icon, size: 18, color: c.ink),
          ),
        ),
      ),
    );
  }
}

/// The search field, recessed.
///
/// Rule 1. This is a [Pocket] rather than a `TextField` with a border, and the
/// caret is the one place ochre appears on this screen at rest.
class _SearchPocket extends StatefulWidget {
  const _SearchPocket({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  @override
  State<_SearchPocket> createState() => _SearchPocketState();
}

class _SearchPocketState extends State<_SearchPocket> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focused != _focus.hasFocus) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool dark = isDarkTheme(context);

    // The top shadow still says "recess"; the lower shadow gives that recess
    // a visible wall so its rounded bottom no longer dissolves into the page,
    // and it deepens on focus — which is the whole of the focus signal now.
    //
    // There was a 4px ochre rail down the left-hand edge here as well, as an
    // "index marker". It read as a stray orange sliver beside the field: rule
    // 2 allows a rail, but the ones that work are *attached* to the thing they
    // mark and carry a state — the repair queue's cap rail is flush inside the
    // row's own rounded edge and says failed-versus-partial. This one was
    // floating over a recess it did not belong to and meant nothing. The ochre
    // caret is the accent on this field.
    return AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        borderRadius: AppRadius.pocketR,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.72)
                : c.ink.withValues(alpha: _focused ? 0.18 : 0.12),
            blurRadius: _focused ? 5 : 3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Pocket(
        height: 58,
        padding: const EdgeInsets.only(left: Gap.lg, right: Gap.sm),
        trailing: widget.hasQuery
            ? PressFade(
                onTap: widget.onClear,
                scale: 0.9,
                semanticLabel: 'Clear the search',
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.close, size: 18, color: c.inkMuted),
                ),
              )
            : null,
        child: Row(
          children: <Widget>[
            Icon(Icons.search, size: 19, color: c.inkMuted),
            const SizedBox(width: Gap.sm + 2),
            Expanded(
              child: TextField(
                focusNode: _focus,
                controller: widget.controller,
                onChanged: widget.onChanged,
                textInputAction: TextInputAction.search,
                cursorColor: c.ochre,
                cursorWidth: 2,
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
                  hintText: 'cheap t-shirt print, low qty',
                  hintStyle: AppText.body(c).copyWith(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The library: a section header, then the stack.
class _Library extends StatelessWidget {
  const _Library({required this.cards, required this.onDelete});

  final List<CardSummary> cards;
  final Future<void> Function(CardSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Clears the scan pill and the fade under it.
      padding: const EdgeInsets.only(bottom: 132),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: SectionHeader('In your wallet', count: cards.length),
          ),
          const SizedBox(height: Gap.md),
          CardStack(
            count: cards.length,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            builder: (BuildContext context, int i) =>
                _SwipeableTile(card: cards[i], onDelete: onDelete),
          ),
        ],
      ),
    );
  }
}

/// One tile, with the swipe-to-delete behind it.
///
/// The `Dismissible` and the reveal underneath are unchanged from before the
/// redesign — that logic is right, and the reveal being the exact shape of the
/// tile leaving it is what makes the gesture read as the card sliding off
/// rather than a red rectangle appearing.
class _SwipeableTile extends StatelessWidget {
  const _SwipeableTile({required this.card, required this.onDelete});

  final CardSummary card;
  final Future<void> Function(CardSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          left: 1,
          top: 1,
          right: 1,
          bottom: 1,
          child: _DeleteReveal(),
        ),
        Dismissible(
          key: ValueKey<int>(card.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => unawaited(onDelete(card)),
          child: WalletCardTile(
            title: card.title ?? 'Unread card',
            subtitle: card.note ?? card.subtitle ?? _noDetails(card),
            imagePath: card.displayPath,
            hasNote: card.note != null && card.note!.trim().isNotEmpty,
            heroTag: cardHeroTag(card.id),
            meta: card.needsAttention
                ? MetaLabel(
                    'Needs attention',
                    color: AppColors.of(context).vermilion,
                  )
                : MetaLabel(compactAge(card.capturedAt)),
            onTap: () => openCardDetail(
              context,
              cardId: card.id,
              imagePath: card.displayPath,
            ),
          ),
        ),
      ],
    );
  }
}

/// Answers, not possessions.
///
/// Rule 4: results un-stack. Physical overlap means "my wallet"; flat,
/// separated cards mean "a computed answer", and the difference is the only
/// thing telling the user which of the two they are looking at.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.answer,
    required this.searching,
    required this.onClear,
  });

  final String query;
  final SearchAnswer answer;
  final bool searching;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final List<SearchHit> hits = answer.hits;
    final QueryPlan plan = answer.plan;
    // A lookup's direct answers go first, then the other cards.
    // People filters (Plus) put their exact list here instead; without
    // Plus, one line saying so sits above the words' results.
    final Widget? lookups = switch (plan) {
      LookupPlan() when answer.lookups.isNotEmpty => LookupAnswers(
        plan: plan,
        answers: answer.lookups,
      ),
      PeopleFilterPlan() when answer.plusNeeded => const PlusFilterLine(),
      PeopleFilterPlan() => PeopleAnswers(plan: plan, people: answer.people),
      // Purchases (B5). A question understood but not answerable is a
      // sentence in the answer's place, with the words still searched below.
      WarrantyPlan() when answer.cannot != null => CannotLine(answer.cannot!),
      WarrantyPlan() => WarrantyAnswers(plan: plan, answers: answer.warranties),
      ExpiringPlan() when answer.plusNeeded => const PlusFilterLine(
        text: 'Questions about dates come with RecallOS Plus',
      ),
      ExpiringPlan() => ExpiringAnswers(plan: plan, answers: answer.expiring),
      SpendingPlan() when answer.plusNeeded => const PlusFilterLine(
        text:
            'Totals by category, shop and other months come with '
            'RecallOS Plus',
      ),
      SpendingPlan() when answer.spending != null => SpendingAnswerBlock(
        plan: plan,
        answer: answer.spending!,
      ),
      _ => null,
    };

    if (searching && answer.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22),
        child: GhostStack(count: 2),
      );
    }
    if (answer.isEmpty) {
      return EmptyState(
        label: 'No results',
        title: 'Nothing matched that',
        body:
            'Try what you needed them for, not their name. '
            '“cheap printing, small run”.',
        actionLabel: 'Clear the search',
        onAction: onClear,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 132),
      itemCount: (lookups == null ? 0 : 1) + hits.length + 2,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (BuildContext context, int i) {
        if (lookups != null) {
          if (i == 0) return lookups;
          i -= 1;
        }
        if (i == 0) {
          if (lookups != null && hits.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            child: SectionHeader(
              lookups != null && !answer.plusNeeded
                  ? 'Other cards'
                  : hits.length == 1
                  ? '1 answer'
                  : '${hits.length} answers',
              trailing: MicroLabel('By relevance'),
            ),
          );
        }
        if (i == hits.length + 1) {
          if (hits.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(
              'Ranked on your notes and where you met first, then the '
              'printed fields.',
              textAlign: TextAlign.center,
              style: AppText.small(c).copyWith(color: c.inkFaint),
            ),
          );
        }
        return _SearchHitCard(hit: hits[i - 1]);
      },
    );
  }
}

/// One answer, with the arithmetic that produced it shown honestly.
class _SearchHitCard extends StatelessWidget {
  const _SearchHitCard({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final CardSummary card = hit.card;
    // One answer, one "why". When the words were found in the note, the
    // block under the tile carries the note — whole, matched words marked —
    // and the tile's second line says who it is instead of repeating it cut
    // off. Otherwise the tile shows the note as the library does. A card
    // with no name or number read has nothing else for that line, so its
    // note stays on the tile and is not said twice.
    final MatchEvidence? e = _Evidence.adds(hit) ? hit.evidence : null;
    final bool fromNote =
        e != null &&
        (e.source == EvidenceSource.note ||
            e.source == EvidenceSource.noteMeaning);
    final MatchEvidence? why = fromNote && card.subtitle == null ? null : e;
    final bool noteBelow = why != null && fromNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        WalletCardTile(
          flat: true,
          title: card.title ?? 'Unread card',
          subtitle: noteBelow
              ? card.subtitle!
              : card.note ?? card.subtitle ?? _noDetails(card),
          imagePath: card.displayPath,
          hasNote: card.note != null && card.note!.trim().isNotEmpty,
          heroTag: cardHeroTag(card.id),
          meta: why != null
              // The why is said in full below; the caps line places the card
              // in time, as a library tile's does.
              ? MetaLabel(compactAge(card.capturedAt))
              : MetaLabel(
                  // Straight from the signals that actually ranked this.
                  // Never prose, never written after the fact.
                  hit.matchedOnMeaningOnly
                      ? 'Similar meaning'
                      : hit.reasons.join(' · '),
                  color: c.ochreInk,
                ),
          onTap: () => openCardDetail(
            context,
            cardId: card.id,
            imagePath: card.displayPath,
          ),
        ),
        if (why != null) ...<Widget>[
          const SizedBox(height: Gap.sm),
          _Evidence(evidence: why),
        ],
        const SizedBox(height: Gap.sm),
        // The bar is honest: its width is the real rank, not a decoration.
        _ScoreBar(score: hit.score),
      ],
    );
  }
}

/// The words that matched, where they were found, under the result.
///
/// Every answer that matched on words gets one: the note, where they met, a
/// field or the printed text. Whether a note fits on the tile's one line
/// depends on the phone's width and text size — guessing it left one note
/// cut off with no excerpt beside another that had one (seen on the phone,
/// 7 Oct) — so the rule does not guess.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.evidence});

  final MatchEvidence evidence;

  static bool adds(SearchHit hit) => hit.evidence?.excerpt != null;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String text = evidence.excerpt!;
    final TextStyle marked = TextStyle(
      color: c.ink,
      fontWeight: FontWeight.w600,
      fontVariations: AppFonts.weight(600),
    );

    final List<InlineSpan> spans = <InlineSpan>[];
    int at = 0;
    for (final (int start, int end) in evidence.spans) {
      if (start < at || end > text.length) continue;
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: marked));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MicroLabel(evidence.label),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: spans),
            style: AppText.body(c),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => Stack(
          children: <Widget>[
            Container(height: 2, color: c.hairline),
            Container(
              height: 2,
              width: box.maxWidth * score.clamp(0.06, 1),
              color: c.ochre,
            ),
          ],
        ),
      ),
    );
  }
}

/// What a swipe uncovers: a panel the exact shape of the tile leaving it.
class _DeleteReveal extends StatelessWidget {
  const _DeleteReveal();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return ExcludeSemantics(
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        decoration: BoxDecoration(
          color: c.vermilion,
          borderRadius: AppRadius.cardR,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.delete_outline, color: c.onInk, size: 19),
            const SizedBox(width: Gap.sm),
            Text('Delete', style: AppText.button(c, on: c.onInk)),
          ],
        ),
      ),
    );
  }
}

/// The way into Today, shown only when there is a next step to go to.
///
/// It says the thing itself rather than "Today": what is overdue or due now,
/// or else what comes next. A row that read "nothing due" on most days would
/// teach people to stop reading it — the reason the repair row below is quiet
/// when empty too.
class _TodayRow extends ConsumerWidget {
  const _TodayRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final List<TodayEntry> open =
        ref.watch(openFollowUpsProvider).value ?? const <TodayEntry>[];
    if (open.isEmpty) return const SizedBox.shrink();

    final DateTime now = DateTime.now();
    final TodayView view = TodayView.split(open, now);
    final int late = view.overdue.length;
    final int due = view.today.length;
    final String text;
    if (late > 0 && due > 0) {
      text = '$late overdue · $due due today';
    } else if (late > 0) {
      text = late == 1 ? '1 step overdue' : '$late steps overdue';
    } else if (due > 0) {
      text = due == 1 ? '1 step due today' : '$due steps due today';
    } else {
      final TodayEntry next = view.upcoming.first;
      text =
          'Next: ${next.step.title} · '
          '${weekdayDayMonth(next.step.dueOn, now)}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: PressFade(
        onTap: () => _leaveHomeFor<void>(context, Routes.today),
        semanticLabel: '$text. Open Today',
        child: Container(
          // At least a thumb high, and two lines when the words need them
          // (found on the phone: "BDT 78,500.00 in receipts this m…").
          constraints: const BoxConstraints(minHeight: kMinTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.xs,
          ),
          decoration: BoxDecoration(
            color: c.ochre.withValues(alpha: 0.12),
            borderRadius: AppRadius.pocketR,
            border: Border.all(color: c.ochre.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.event_note_outlined, size: 18, color: c.ochreInk),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowTitle(c).copyWith(fontSize: 15),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.ochreInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// This month's receipts, and the way into their totals (B4).
///
/// Only while the wallet holds a receipt: in a wallet of business cards a
/// row about receipts is noise. Quiet chrome — the card's own fill, no
/// marker colour — because it is a figure to glance at, not something to do.
class _ReceiptsRow extends ConsumerWidget {
  const _ReceiptsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final List<ReceiptFacts> all =
        ref.watch(receiptFactsProvider).value ?? const <ReceiptFacts>[];
    if (all.isEmpty) return const SizedBox.shrink();
    final String text = homeReceiptsWords(
      SpendingSummary.of(all, period: SpendingPeriod.monthOf(DateTime.now())),
    );

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: PressFade(
        onTap: () => _leaveHomeFor<void>(context, Routes.receiptTotals),
        semanticLabel: '$text. Open receipt totals',
        child: Container(
          // At least a thumb high, and two lines when the words need them
          // (found on the phone: "BDT 78,500.00 in receipts this m…").
          constraints: const BoxConstraints(minHeight: kMinTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.xs,
          ),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: AppRadius.pocketR,
            border: Border.all(color: c.hairlineOnCard),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.receipt_long, size: 18, color: c.inkMuted),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowTitle(c).copyWith(fontSize: 15),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surfaces the repair queue, and only when there is something in it.
///
/// A failed scan looks exactly like a good one in the library — same tile,
/// same size — so without this the cards that went wrong are invisible unless
/// somebody thinks to go looking. Permanent chrome would be worse: a row that
/// says "nothing is wrong" on most days trains people to ignore it. The header
/// button is the way in on those days.
class _AttentionRow extends ConsumerWidget {
  const _AttentionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final int waiting = ref.watch(needsAttentionProvider).value?.length ?? 0;
    if (waiting == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: PressFade(
        onTap: () => _leaveHomeFor<void>(context, Routes.needsAttention),
        child: Container(
          // At least a thumb high, and two lines when the words need them
          // (found on the phone: "BDT 78,500.00 in receipts this m…").
          constraints: const BoxConstraints(minHeight: kMinTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.xs,
          ),
          decoration: BoxDecoration(
            color: c.vermilion.withValues(alpha: 0.10),
            borderRadius: AppRadius.pocketR,
            border: Border.all(color: c.vermilion.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: <Widget>[
              // The dot with a soft ring, not a warning triangle: this is a
              // count of things to look at, not an error.
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.vermilion,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: c.vermilion.withValues(alpha: 0.35),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  waiting == 1
                      ? '1 card needs attention'
                      : '$waiting cards need attention',
                  style: AppText.rowTitle(c).copyWith(fontSize: 15),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Event Mode's way in, beside the scan button — where somebody standing at
/// an event is about to tap anyway.
///
/// Filled with the page, not hollow: it sits over the bottom of the card
/// stack, and an outline alone would show the cards through it. While an
/// event runs, its ring turns ochre — a marker, rule 2.
/// The line under a tile with nothing else to say. A record that was typed
/// in was never read, so it cannot have failed to be.
String _noDetails(CardSummary card) =>
    card.status == ExtractionStatus.manual ? 'Typed in' : 'No details read';

/// Adds something without the camera: typed in, or from a file.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  static const double _size = 58;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return PressFade(
      onTap: onTap,
      scale: 0.92,
      semanticLabel: 'Add without scanning',
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: c.page,
          shape: BoxShape.circle,
          border: Border.all(color: c.hairline, width: 1.5),
        ),
        child: Icon(Icons.edit_note, size: 24, color: c.ink),
      ),
    );
  }
}

class _EventButton extends ConsumerWidget {
  const _EventButton();

  static const double _size = 58;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final bool running = ref.watch(activeEventProvider) != null;

    return PressFade(
      onTap: () => _leaveHomeFor<void>(context, Routes.event),
      scale: 0.92,
      semanticLabel: running ? 'Event Mode, running' : 'Event Mode',
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: c.page,
          shape: BoxShape.circle,
          border: Border.all(
            color: running ? c.ochre : c.hairline,
            width: running ? 2 : 1.5,
          ),
        ),
        child: Icon(
          Icons.festival_outlined,
          size: 22,
          color: running ? c.ochreInk : c.ink,
        ),
      ),
    );
  }
}

/// The running event, while it runs: its name and how many cards so far.
///
/// Says nothing when no event is running, like the rows around it.
class _EventRow extends ConsumerWidget {
  const _EventRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final WalletEvent? event = ref.watch(activeEventProvider);
    if (event == null) return const SizedBox.shrink();
    final int met = ref.watch(eventCardsProvider(event)).value?.length ?? 0;
    final String text =
        'At ${event.name} · ${met == 1 ? '1 card' : '$met cards'}';

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: PressFade(
        onTap: () => _leaveHomeFor<void>(context, Routes.event),
        semanticLabel: '$text. Open Event Mode',
        child: Container(
          // At least a thumb high, and two lines when the words need them
          // (found on the phone: "BDT 78,500.00 in receipts this m…").
          constraints: const BoxConstraints(minHeight: kMinTarget),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: AppRadius.pocketR,
            border: Border.all(color: c.hairlineOnCard),
          ),
          clipBehavior: Clip.antiAlias,
          // The rail runs the row's full height, whatever the words need.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 4, color: c.ochre),
                const SizedBox(width: Gap.md - 4),
                Icon(Icons.festival_outlined, size: 18, color: c.ochreInk),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowTitle(c).copyWith(fontSize: 15),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
                const SizedBox(width: Gap.md - 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
