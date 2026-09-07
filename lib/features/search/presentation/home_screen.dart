import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../../capture/data/card_repository.dart';
import '../../cards/presentation/needs_attention_screen.dart';
import '../../contacts/data/identity_repository.dart';
import '../data/search_repository.dart';

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
  List<SearchHit> _hits = const <SearchHit>[];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Cards saved before search existed have no index rows, and without this
    // they stay permanently invisible — which looks exactly like search being
    // broken.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(searchRepositoryProvider).backfill());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final String trimmed = raw.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _hits = const <SearchHit>[];
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
    final List<SearchHit> hits = await ref
        .read(searchRepositoryProvider)
        .search(query);
    if (!mounted || _query != query) return;
    setState(() {
      _hits = hits;
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
    if (mounted && _hits.isNotEmpty) {
      setState(
        () =>
            _hits = _hits.where((SearchHit h) => h.card.id != card.id).toList(),
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
    final AsyncValue<List<CardSummary>> saved = ref.watch(savedCardsProvider);
    final bool searchingNow = _query.isNotEmpty;

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
                      const SizedBox(height: Gap.lg),
                      // Rule 3: the serif italic is the app asking, and this is
                      // the question the whole product is built around.
                      Text('What do you\nneed?', style: AppText.displayAsk(c)),
                      const SizedBox(height: Gap.lg),
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
                    ],
                  ),
                ),
                const SizedBox(height: Gap.md),
                Expanded(
                  child: searchingNow
                      ? _SearchResults(
                          query: _query,
                          hits: _hits,
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
                                  onAction: () => context.push(Routes.capture),
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
            // curve, its own shape and a ripple.
            Positioned(
              left: Gap.lg,
              right: Gap.lg,
              bottom: 34,
              child: InkPill(
                label: 'Scan a card',
                icon: Icons.document_scanner_outlined,
                height: 58,
                onTap: () => context.push(Routes.capture),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wordmark, and the two ways out of this screen.
///
/// Replaces the `AppBar` and its `PopupMenuButton`. The mark is the logo's
/// folded card at 22px; the wordmark is Archivo bold, uppercase, wide-tracked,
/// and never set in the serif.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, 0),
      child: Row(
        children: <Widget>[
          _Mark(colors: c),
          const SizedBox(width: Gap.sm + 2),
          Text(
            'RECALLOS',
            style: AppText.micro(
              c,
            ).copyWith(fontSize: 12, letterSpacing: 2.6, color: c.inkMuted),
          ),
          const Spacer(),
          _RoundButton(
            icon: Icons.people_outline,
            tooltip: 'Contacts',
            onTap: () => context.push(Routes.contacts),
          ),
          const SizedBox(width: Gap.sm),
          _RoundButton(
            icon: Icons.tune,
            tooltip: 'Settings',
            onTap: () => context.push(Routes.settings),
          ),
        ],
      ),
    );
  }
}

/// The logo mark: a card with its corner turned back.
///
/// Drawn rather than loaded. At 22px an SVG or a PNG would cost a decode and a
/// cache entry to produce eleven pixels of ochre.
class _Mark extends StatelessWidget {
  const _Mark({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 18,
    child: CustomPaint(painter: _MarkPainter(colors)),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.colors);

  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    const double fold = 7;
    final Path body = Path()
      ..moveTo(0, 3)
      ..lineTo(size.width - fold, 3)
      ..lineTo(size.width, 3 + fold)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(body, Paint()..color = colors.ink);
    canvas.drawPath(
      Path()
        ..moveTo(size.width - fold, 3)
        ..lineTo(size.width, 3 + fold)
        ..lineTo(size.width - fold, 3 + fold)
        ..close(),
      Paint()..color = colors.ochre,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.colors.ink != colors.ink;
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
class _SearchPocket extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Pocket(
      height: 54,
      padding: const EdgeInsets.only(left: Gap.md, right: Gap.sm),
      trailing: hasQuery
          ? PressFade(
              onTap: onClear,
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
              controller: controller,
              onChanged: onChanged,
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
            subtitle: card.note ?? card.subtitle ?? 'No details read',
            imagePath: card.displayPath,
            hasNote: card.note != null && card.note!.trim().isNotEmpty,
            heroTag: 'card-${card.id}',
            meta: card.needsAttention
                ? MetaLabel(
                    'Needs attention',
                    color: AppColors.of(context).vermilion,
                  )
                : MetaLabel(_age(card.capturedAt)),
            onTap: () => context.push(Routes.card(card.id)),
          ),
        ),
      ],
    );
  }

  /// "3D", "1W", "2MO" — the frames use an age, not a date. A date on every
  /// row is precision nobody asked for; how long ago is what places a card in
  /// memory.
  static String _age(DateTime at) {
    final Duration since = DateTime.now().difference(at);
    if (since.inDays >= 365) return '${since.inDays ~/ 365}Y';
    if (since.inDays >= 30) return '${since.inDays ~/ 30}MO';
    if (since.inDays >= 7) return '${since.inDays ~/ 7}W';
    if (since.inDays >= 1) return '${since.inDays}D';
    if (since.inHours >= 1) return '${since.inHours}H';
    return 'JUST NOW';
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
    required this.hits,
    required this.searching,
    required this.onClear,
  });

  final String query;
  final List<SearchHit> hits;
  final bool searching;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    if (searching && hits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22),
        child: GhostStack(count: 2),
      );
    }
    if (hits.isEmpty) {
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
      itemCount: hits.length + 2,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            child: SectionHeader(
              hits.length == 1 ? '1 answer' : '${hits.length} answers',
              trailing: MicroLabel('By relevance'),
            ),
          );
        }
        if (i == hits.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(
              'Ranked on your notes first, then the printed fields.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        WalletCardTile(
          flat: true,
          title: card.title ?? 'Unread card',
          subtitle: card.note ?? card.subtitle ?? 'No details read',
          imagePath: card.displayPath,
          hasNote: card.note != null && card.note!.trim().isNotEmpty,
          heroTag: 'card-${card.id}',
          meta: MetaLabel(
            // Straight from the signals that actually ranked this. Never
            // prose, never written after the fact.
            hit.matchedOnMeaningOnly
                ? 'Similar meaning'
                : hit.reasons.join(' · '),
            color: c.ochreInk,
          ),
          onTap: () => context.push(Routes.card(card.id)),
        ),
        const SizedBox(height: Gap.sm),
        // The bar is honest: its width is the real rank, not a decoration.
        _ScoreBar(score: hit.score),
      ],
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
        onTap: () => context.push(Routes.needsAttention),
        child: Container(
          height: kMinTarget,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
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
