import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../../core/extraction/receipt_extractor.dart' show formatDay;
import '../../../core/spending/spending_totals.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../../router.dart';
import '../../capture/data/card_repository.dart';
import '../../plus/data/plus_controller.dart';
import '../data/spending_repository.dart';
import '../data/spending_share.dart';

/// *Receipt totals* (B4): what the saved receipts add up to, and exactly
/// what that figure is made of.
///
/// The figure counts only receipts whose total and date the user checked.
/// Everything else is on the same screen — not added yet, a possible second
/// copy, no date — each with the one step that would count it, so nothing is
/// left out without a word and nothing is added that nobody looked at.
///
/// Everyone sees this month. Plus adds other months and years, and the
/// breakdowns by shop and category. What is held back, and why, is never
/// behind Plus.
class SpendingScreen extends ConsumerStatefulWidget {
  const SpendingScreen({this.now = DateTime.now, super.key});

  final DateTime Function() now;

  @override
  ConsumerState<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends ConsumerState<SpendingScreen> {
  /// The period chosen with Plus. Null is this month.
  SpendingPeriod? _period;
  String? _currency;
  SpendingFocus? _focus;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<List<ReceiptFacts>> facts = ref.watch(
      receiptFactsProvider,
    );
    final PlusPhase phase = ref.watch(plusProvider).phase;
    final List<ReceiptFacts>? loaded = facts.value;
    // What the screen shows is what is shared: the same summary, built once.
    final SpendingSummary? shown = loaded == null || loaded.isEmpty
        ? null
        : _summaryFor(loaded, phase);

    final Widget body = facts.when(
      // Rule 5: a ghost, never a spinner.
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: Gap.lg),
        child: GhostStack(count: 2),
      ),
      error: (Object e, _) => EmptyState(
        label: 'Could not open',
        title: 'The receipts did not open',
        body: '$e',
      ),
      data: (List<ReceiptFacts> all) => all.isEmpty
          ? EmptyState(
              label: 'No receipts',
              title: 'No receipts saved yet',
              body:
                  'Scan a receipt with the same Scan button, then check its '
                  'total and date. Only what you checked is added here.',
              actionLabel: 'Scan a receipt',
              onAction: () => context.push(Routes.capture),
            )
          : _totals(all, phase),
    );

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Receipt totals',
              onBack: () => context.pop(),
              actions: <Widget>[
                if (shown != null && !shown.isEmpty)
                  RoundIconButton(
                    icon: Icons.ios_share,
                    tooltip: 'Share this total',
                    onTap: () => unawaited(_share(shown)),
                  ),
              ],
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  SpendingSummary _summaryFor(List<ReceiptFacts> all, PlusPhase phase) {
    final bool plus = phase == PlusPhase.owned;
    final SpendingPeriod thisMonth = SpendingPeriod.monthOf(widget.now());
    // Without Plus — never bought, or refunded while another month was open
    // — this month is what there is.
    return SpendingSummary.of(
      all,
      period: plus ? (_period ?? thisMonth) : thisMonth,
      currency: _currency,
      focus: plus ? _focus : null,
    );
  }

  /// Asks first, saying what the file holds, then hands it over (B4).
  Future<void> _share(SpendingSummary s) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SpendingShare sharer = ref.read(spendingShareProvider);
    final bool? go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => ShareTotalSheet(summary: s),
    );
    if (go != true) return;
    final bool ok = await sharer.share(s);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Handed to the app you chose.'
              : 'That did not work. Nothing was shared.',
        ),
      ),
    );
  }

  Widget _totals(List<ReceiptFacts> all, PlusPhase phase) {
    final AppColors c = AppColors.of(context);
    final DateTime now = widget.now();
    final bool plus = phase == PlusPhase.owned;
    final SpendingPeriod thisMonth = SpendingPeriod.monthOf(now);
    final SpendingSummary s = _summaryFor(all, phase);
    final SpendingPeriod period = s.period;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: <Widget>[
        if (plus)
          _PeriodBar(
            period: period,
            now: now,
            onChanged: (SpendingPeriod p) => setState(() => _period = p),
          )
        else
          MicroLabel('This month · ${period.label}'),
        const SizedBox(height: Gap.md),
        if (s.currencies.length > 1) ...<Widget>[
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: <Widget>[
              for (final String code in s.currencies)
                SelectChip(
                  label: code,
                  selected: code == s.currency,
                  onTap: () => setState(() => _currency = code),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
        ],
        _Answer(
          summary: s,
          periodWords: period == thisMonth
              ? 'this month'
              : 'in ${period.label}',
          onShowAll: () => setState(() => _focus = null),
        ),
        const SizedBox(height: Gap.lg),
        // What is not in the figure comes straight after it: each of these
        // makes the figure incomplete, and each is one tap from being
        // fixed. Never buried under a long month of counted receipts.
        if (s.copies.isNotEmpty) ...<Widget>[
          SectionHeader('Possible second copies', count: s.copies.length),
          for (final PossibleCopy p in s.copies)
            _CopyBlock(
              copy: p,
              onBin: () => unawaited(_bin(p)),
              onCountBoth: () => unawaited(_countBoth(p, all)),
            ),
          const SizedBox(height: Gap.md),
        ],
        if (s.notAdded.isNotEmpty) ...<Widget>[
          _Held(label: 'Not added yet', receipts: s.notAdded),
          const SizedBox(height: Gap.lg),
        ],
        if (s.undated.isNotEmpty) ...<Widget>[
          _Held(label: 'No date', receipts: s.undated),
          const SizedBox(height: Gap.lg),
        ],
        if (phase == PlusPhase.free || phase == PlusPhase.pending) ...<Widget>[
          SettingGroup(
            label: 'With RecallOS Plus',
            children: <Widget>[
              SettingRow(
                label: 'Other months, shops and categories',
                description:
                    'Any month or year, and what went to each shop and '
                    'category.',
                trailing: Icon(Icons.chevron_right, color: c.inkMuted),
                onTap: () => context.push(Routes.plus),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
        ],
        if (plus && s.focus == null && s.counted.isNotEmpty) ...<Widget>[
          if (s.byMonth.isNotEmpty) ...<Widget>[
            _Groups(
              label: 'By month',
              groups: s.byMonth,
              onTap: (SpendingGroup g) => setState(
                () => _period = SpendingPeriod.month(
                  period.year,
                  int.parse(g.key.substring(5)),
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
          ],
          _Groups(
            label: 'By shop',
            groups: s.byShop,
            onTap: (SpendingGroup g) =>
                setState(() => _focus = SpendingFocus.shop(g.key, g.label)),
          ),
          const SizedBox(height: Gap.lg),
          _Groups(
            label: 'By category',
            groups: s.byCategory,
            onTap: (SpendingGroup g) =>
                setState(() => _focus = SpendingFocus.category(g.key, g.label)),
          ),
          const SizedBox(height: Gap.lg),
        ],
        if (s.counted.isNotEmpty) ...<Widget>[
          SettingGroup(
            label: 'Counted',
            children: <Widget>[
              for (final ReceiptFacts r in s.counted) _CountedRow(receipt: r),
            ],
          ),
          const SizedBox(height: Gap.lg),
        ],
      ],
    );
  }

  /// A copy goes to the bin, like any delete: soft, with Undo, and gone for
  /// good only from *Recently deleted*.
  Future<void> _bin(PossibleCopy p) async {
    final CardRepository cards = ref.read(cardRepositoryProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await cards.softDelete(p.receipt.cardId);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Moved the copy to the bin.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(cards.restore(p.receipt.cardId)),
        ),
      ),
    );
  }

  /// Two purchases after all. Answered for every receipt it looks like, so
  /// the next look-alike is not asked about straight after.
  Future<void> _countBoth(PossibleCopy p, List<ReceiptFacts> all) async {
    final SpendingRepository spending = ref.read(spendingRepositoryProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<int> others = lookAlikes(p.receipt, all);
    await spending.countBoth(p.receipt.cardId, others);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Both are counted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              unawaited(spending.undoCountBoth(p.receipt.cardId, others)),
        ),
      ),
    );
  }
}

/// The month or year shown, the arrows either side, and Month / Year. There
/// is no arrow past today: nothing can have been bought there yet.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.period,
    required this.now,
    required this.onChanged,
  });

  final SpendingPeriod period;
  final DateTime now;
  final ValueChanged<SpendingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool month = period.isMonth;
    final SpendingPeriod later = period.next;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            RoundIconButton(
              icon: Icons.chevron_left,
              tooltip: month ? 'Month before' : 'Year before',
              onTap: () => onChanged(period.previous),
            ),
            Expanded(
              child: Text(
                period.label,
                textAlign: TextAlign.center,
                style: AppText.rowTitle(c),
              ),
            ),
            if (later.isFuture(now))
              const SizedBox(width: kMinTarget)
            else
              RoundIconButton(
                icon: Icons.chevron_right,
                tooltip: month ? 'Month after' : 'Year after',
                onTap: () => onChanged(later),
              ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Gap.sm,
          children: <Widget>[
            SelectChip(
              label: 'Month',
              selected: month,
              onTap: () {
                if (month) return;
                // This month in this year; otherwise the year's last month,
                // the one nearest to where the user came from.
                onChanged(
                  period.year == now.year
                      ? SpendingPeriod.monthOf(now)
                      : SpendingPeriod.month(period.year, 12),
                );
              },
            ),
            SelectChip(
              label: 'Year',
              selected: !month,
              onTap: () => onChanged(period.wholeYear),
            ),
          ],
        ),
      ],
    );
  }
}

/// The figure, what it is "in", and what it covers — or, when nothing is
/// counted, why not.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.summary,
    required this.periodWords,
    required this.onShowAll,
  });

  final SpendingSummary summary;

  /// "this month", "in September 2026", "in 2026".
  final String periodWords;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final SpendingSummary s = summary;
    final SpendingFocus? focus = s.focus;
    final Money? total = s.total;
    final String where = focus == null
        ? ''
        : focus.byShop
        ? ' from ${focus.label}'
        : ' under ${focus.label}';

    final List<Widget> lines;
    if (total != null) {
      lines = <Widget>[
        // Rule 3: a standalone numeral, in the roman serif. Scaled down
        // rather than wrapped: a figure broken across lines misreads.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(total.format(), style: AppText.display(c)),
        ),
        const SizedBox(height: Gap.xs),
        // PLAN §5: what was saved, not what was spent.
        Text(
          'in saved receipts$where',
          style: AppText.body(c).copyWith(color: c.ink),
        ),
        if (s.refunded != null)
          Text(
            'After ${s.refunded!.format()} refunded on '
            '${s.refundCount == 1 ? '1 receipt' : '${s.refundCount} receipts'}',
            style: AppText.small(c),
          ),
        const SizedBox(height: 2),
        Text(s.scope, style: AppText.small(c)),
      ];
    } else {
      final int waiting = s.heldBack;
      lines = <Widget>[
        Text('Nothing counted$where $periodWords', style: AppText.title(c)),
        const SizedBox(height: Gap.sm),
        Text(
          waiting == 0
              ? 'No receipts dated in ${s.period.label}.'
              : 'A receipt is added once you check its total and date. '
                    '${waiting == 1 ? 'One is' : '$waiting are'} waiting '
                    'below.',
          style: AppText.body(c),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...lines,
        if (focus != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextAction(
              label: focus.byShop ? 'Show every shop' : 'Show every category',
              icon: Icons.close,
              onTap: onShowAll,
            ),
          ),
      ],
    );
  }
}

/// A breakdown — by shop, by category, by month — as rows with their sums.
/// A row narrows the screen to it. Long lists show their largest few first.
class _Groups extends StatefulWidget {
  const _Groups({
    required this.label,
    required this.groups,
    required this.onTap,
  });

  final String label;
  final List<SpendingGroup> groups;
  final ValueChanged<SpendingGroup> onTap;

  static const int _first = 5;

  @override
  State<_Groups> createState() => _GroupsState();
}

class _GroupsState extends State<_Groups> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final List<SpendingGroup> groups = widget.groups;
    final bool cut = !_all && groups.length > _Groups._first + 1;
    final List<SpendingGroup> shown = cut
        ? groups.take(_Groups._first).toList()
        : groups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingGroup(
          label: widget.label,
          children: <Widget>[
            for (final SpendingGroup g in shown)
              _SumRow(
                label: g.label,
                description: _groupWords(g),
                money: g.total,
                onTap: () => widget.onTap(g),
              ),
          ],
        ),
        if (cut)
          Align(
            alignment: Alignment.centerLeft,
            child: TextAction(
              label: 'Show all ${groups.length}',
              tint: c.ochreInk,
              onTap: () => setState(() => _all = true),
            ),
          ),
      ],
    );
  }

  static String _groupWords(SpendingGroup g) {
    final String n = g.receipts == 1 ? '1 receipt' : '${g.receipts} receipts';
    if (g.guessed == 0) return n;
    return g.guessed == g.receipts
        ? '$n · category guessed'
        : '$n · ${g.guessed} guessed';
  }
}

/// A counted receipt: what it is, when, and what it adds. Opens it.
class _CountedRow extends StatelessWidget {
  const _CountedRow({required this.receipt});

  final ReceiptFacts receipt;

  @override
  Widget build(BuildContext context) {
    final ReceiptFacts r = receipt;
    final String? category = r.category;
    return _SumRow(
      label: r.title ?? 'Receipt',
      description: <String>[
        if (r.isRefund) 'Refund',
        formatDay(r.date!),
        if (category != null)
          r.categoryGuessed ? '$category (guess)' : category,
      ].join(' · '),
      money: r.total!,
      onTap: () => context.push(Routes.card(r.cardId)),
    );
  }
}

/// Receipts held back, each with what it says, as read, and what to do.
class _Held extends StatelessWidget {
  const _Held({required this.label, required this.receipts});

  final String label;
  final List<ReceiptFacts> receipts;

  @override
  Widget build(BuildContext context) => SettingGroup(
    label: label,
    children: <Widget>[
      for (final ReceiptFacts r in receipts) _HeldRow(receipt: r),
    ],
  );
}

class _HeldRow extends StatelessWidget {
  const _HeldRow({required this.receipt});

  final ReceiptFacts receipt;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final ReceiptFacts r = receipt;
    final String title = r.title ?? 'Receipt';
    final String read = _asRead(r);
    final String todo = r.whatToDo ?? '';

    return PressFade(
      onTap: () => context.push(Routes.card(r.cardId)),
      semanticLabel: '$title. ${read.isEmpty ? '' : '$read. '}$todo',
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget + 6),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + 2,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppText.rowTitle(c).copyWith(fontSize: 15),
                  ),
                  if (read.isNotEmpty) Text(read, style: AppText.small(c)),
                  // The same words and ink as *check this* on the receipt,
                  // where the tap leads.
                  Text(
                    todo,
                    style: AppText.small(
                      c,
                    ).copyWith(color: c.ochreInk, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
          ],
        ),
      ),
    );
  }

  /// What was read, checked or not: "BDT 432.60 · 12 Oct 2026".
  static String _asRead(ReceiptFacts r) => <String>[
    if (r.total case final Money m) m.format(),
    if (r.date case final d?) formatDay(d),
  ].join(' · ');
}

/// *Is this a second copy?* — the receipt, why it looks like one already
/// counted, and both answers.
class _CopyBlock extends StatelessWidget {
  const _CopyBlock({
    required this.copy,
    required this.onBin,
    required this.onCountBoth,
  });

  final PossibleCopy copy;
  final VoidCallback onBin;
  final VoidCallback onCountBoth;

  /// Drawn at 44 and grown to the 52 floor, as on B3's suggestion.
  static const double _art = 44;
  static const EdgeInsets _target = EdgeInsets.symmetric(
    vertical: (kMinTarget - _art) / 2,
  );

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final ReceiptFacts r = copy.receipt;
    final String title = r.title ?? 'Receipt';

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
        decoration: AppDecoration.card(
          c,
          isDark: isDarkTheme(context),
          lifted: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Rule 3: the app asking, at the inline size B3's question uses.
            Text(
              'Is this a second copy?',
              style: AppText.displayAsk(c).copyWith(fontSize: 21, height: 1.1),
            ),
            const SizedBox(height: Gap.xs),
            PressFade(
              onTap: () => context.push(Routes.card(r.cardId)),
              semanticLabel: 'Open the receipt: $title, ${r.total!.format()}',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinTarget),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.receipt_long, size: 20, color: c.inkMuted),
                    const SizedBox(width: Gap.sm),
                    Expanded(child: Text(title, style: AppText.rowTitle(c))),
                    Icon(Icons.chevron_right, size: 20, color: c.inkFaint),
                  ],
                ),
              ),
            ),
            for (final CopyReason reason in copy.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.check, size: 14, color: c.olive),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(reason.describe(), style: AppText.small(c)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Gap.xs),
            Text(
              'The one saved first is counted; this one is not, until you '
              'say.',
              style: AppText.small(c),
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: <Widget>[
                InkPill(
                  label: 'Yes, bin this copy',
                  height: _art,
                  hitPadding: _target,
                  onTap: onBin,
                ),
                OutlinePill(
                  label: 'No, count both',
                  height: _art,
                  hitPadding: _target,
                  onTap: onCountBoth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row with a sum: a name, a line under it, and the amount — at the end
/// of the row when the name fits beside it, under the name when it does not.
///
/// A long shop name beside a long amount at 1.3× text left the name a
/// column too narrow for its longest word, and "ENGINEERING" broke as
/// "ENGINEE / RING". Words are measured, not guessed: when the longest one
/// would not fit beside the amount, the amount moves under the name.
class _SumRow extends StatelessWidget {
  const _SumRow({
    required this.label,
    required this.description,
    required this.money,
    required this.onTap,
  });

  final String label;
  final String description;
  final Money money;
  final VoidCallback onTap;

  static const double _chevron = 22;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final TextStyle name = AppText.rowTitle(c).copyWith(fontSize: 15);
    final TextStyle amount = name.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final String sum = money.format();
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    double widthOf(String text, TextStyle style) {
      final TextPainter p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double w = p.width;
      p.dispose();
      return w;
    }

    return PressFade(
      onTap: onTap,
      semanticLabel: '$label, $sum. $description',
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget + 6),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + 2,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double room =
                box.maxWidth - widthOf(sum, amount) - Gap.sm - _chevron;
            final double longest = label
                .split(RegExp(r'\s+'))
                .map((String w) => widthOf(w, name))
                .fold(0, (double a, double b) => a > b ? a : b);
            final bool stacked = longest > room;

            return Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label, style: name),
                      if (stacked) Text(sum, style: amount),
                      const SizedBox(height: 2),
                      Text(description, style: AppText.small(c)),
                    ],
                  ),
                ),
                if (!stacked) ...<Widget>[
                  const SizedBox(width: Gap.sm),
                  Text(sum, style: amount),
                ],
                SizedBox(
                  width: _chevron,
                  child: Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Home's line about the receipts this month (B4): the figure when there is
/// one, else how many are waiting, else just the way in.
String homeReceiptsWords(SpendingSummary month) {
  final Money? total = month.total;
  if (total != null) {
    final int others = month.currencies.length - 1;
    return others == 0
        ? '${total.format()} in receipts this month'
        : '${total.format()} + $others other '
              '${others == 1 ? 'currency' : 'currencies'} this month';
  }
  final int waiting = month.notAdded.length + month.copies.length;
  if (waiting > 0) {
    return waiting == 1
        ? '1 receipt this month to check'
        : '$waiting receipts this month to check';
  }
  return 'Receipt totals';
}

/// *Share this total?* — what the file holds, before it leaves (B4).
class ShareTotalSheet extends StatelessWidget {
  const ShareTotalSheet({required this.summary, super.key});

  final SpendingSummary summary;

  static String _receipts(int n) => n == 1 ? '1 receipt' : '$n receipts';

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final SpendingSummary s = summary;
    final String figure = s.total == null
        ? 'nothing counted yet'
        : '${s.total!.format()} in saved receipts';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Rule 3: the app asking the user something.
          Text(
            'Share this total?',
            style: AppText.displayAsk(c).copyWith(fontSize: 24, height: 1.1),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            '${s.period.label}: $figure. A spreadsheet with a row for each '
            'of the ${_receipts(s.counted.length)} counted'
            '${s.heldBack == 0 ? '' : ' and the ${s.heldBack} held back, each saying why'}'
            ', and a note saying what the figure covers. No photographs.',
            style: AppText.body(c),
          ),
          const SizedBox(height: Gap.md),
          InkPill(
            label: 'Share',
            icon: Icons.ios_share,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(false),
            child: SizedBox(
              height: kMinTarget,
              child: Center(
                child: Text('Cancel', style: AppText.button(c, on: c.inkMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
