import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../router.dart';
import '../../capture/data/card_repository.dart';
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
    final List<SearchHit> hits =
        await ref.read(searchRepositoryProvider).search(query);
    if (!mounted || _query != query) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  /// Removes a card, with a way back.
  ///
  /// Two-stage: hide it immediately so the list responds, then destroy it only
  /// once the undo window closes untouched. Deleting something the user walked
  /// across a market to photograph should not be one mis-swipe away from
  /// permanent.
  Future<void> _delete(CardSummary card) async {
    final CardRepository repo = ref.read(cardRepositoryProvider);
    await repo.softDelete(card.id);

    // Drop it from the visible results too, or a deleted card lingers on screen
    // until the next keystroke.
    if (mounted && _hits.isNotEmpty) {
      setState(() =>
          _hits = _hits.where((SearchHit h) => h.card.id != card.id).toList());
    }
    if (!mounted) return;

    final SnackBarClosedReason reason = await ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Deleted ${card.title ?? "card"}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(repo.restore(card.id)),
            ),
            duration: const Duration(seconds: 5),
          ),
        )
        .closed;

    if (reason == SnackBarClosedReason.action) {
      if (_query.isNotEmpty) unawaited(_run(_query));
      return;
    }
    // Undo window closed untouched — now it really goes, image and index rows
    // included.
    await repo.purge(card.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AsyncValue<List<CardSummary>> saved = ref.watch(savedCardsProvider);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          // Phase 0 scaffolding — remove with the spike screen itself.
          IconButton(
            tooltip: 'OCR spike',
            onPressed: () => context.push(Routes.spike),
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: Gap.lg),
              Text(
                'What do you need?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'e.g. cheap t-shirt print, low quantity',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Expanded(
                child: _query.isNotEmpty
                    ? _SearchResults(
                        query: _query,
                        hits: _hits,
                        searching: _searching,
                        onDelete: _delete,
                      )
                    : saved.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (Object e, _) => Center(
                          child: Text(
                            'Could not open your saved cards.\n$e',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.error),
                          ),
                        ),
                        data: (List<CardSummary> cards) => cards.isEmpty
                            ? const _EmptyState()
                            : _CardList(cards: cards, onDelete: _delete),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.capture),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan'),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.hits,
    required this.searching,
    required this.onDelete,
  });

  final String query;
  final List<SearchHit> hits;
  final bool searching;
  final Future<void> Function(CardSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (searching && hits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.search_off,
                  size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: Gap.md),
              Text('Nothing matched “$query”',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: Gap.xs),
              Text(
                'Try describing what you needed them for.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: hits.length,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
      itemBuilder: (BuildContext context, int i) => _CardTile(
        card: hits[i].card,
        hit: hits[i],
        onDelete: onDelete,
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.cards, required this.onDelete});

  final List<CardSummary> cards;
  final Future<void> Function(CardSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      // Padded so the last row clears the floating action button.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: cards.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Text(
              cards.length == 1 ? '1 card saved' : '${cards.length} cards saved',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return _CardTile(card: cards[i - 1], onDelete: onDelete);
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onDelete, this.hit});

  final CardSummary card;
  final SearchHit? hit;
  final Future<void> Function(CardSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final File image = File(card.imagePath);
    final SearchHit? h = hit;

    return Dismissible(
      key: ValueKey<int>(card.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gap.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => unawaited(onDelete(card)),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: () => context.push(Routes.card(card.id)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Gap.sm,
            vertical: Gap.xs,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image.existsSync()
                ? Hero(
                    tag: 'card-${card.id}',
                    child: Image.file(
                      image,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      // Thumbnails must never decode the full-resolution
                      // bitmap; a list of them would otherwise exhaust memory
                      // on a cheap phone long before the list got long.
                      cacheWidth: 168,
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
          ),
          title: Text(
            card.title ?? 'Unread card',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                // The note is what the user will actually recognise the card by,
                // so it wins over the extracted fields when there is one.
                card.note ?? card.subtitle ?? 'No details read',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (h != null && h.reasons.isNotEmpty) ...<Widget>[
                const SizedBox(height: Gap.xs),
                Text(
                  // Derived from the signals that actually ranked this, not
                  // written after the fact by a model.
                  h.matchedOnMeaningOnly
                      ? 'Similar meaning'
                      : 'Matched ${h.reasons.join(" · ")}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
          isThreeLine: h != null && h.reasons.isNotEmpty,
          trailing: card.needsAttention
              ? Icon(
                  Icons.flag_outlined,
                  size: 20,
                  color: theme.colorScheme.error,
                )
              : null,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.style_outlined,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Nothing saved yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Scan a card and tell RecallOS why it matters.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
