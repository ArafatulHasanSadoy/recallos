import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/extraction/receipt_extractor.dart' show formatDay;
import '../../../core/linking/purchase_link_rules.dart';
import '../../../core/linking/warranty_expiry.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../../capture/data/card_repository.dart' show describeCard;
import '../../followup/data/reminder_engine.dart';
import '../data/purchase_link_providers.dart';
import '../data/purchase_links.dart';

/// What B3 adds to a receipt's or a warranty's screen: when the cover ends,
/// and which paper it belongs with. Nothing for any other kind of card.
///
/// Used on the card screen and on the capture review alike, because the
/// moment a suggestion is worth most is straight after the second scan.
/// Each block brings its own space below it, so one that has nothing to
/// show leaves no gap.
class PurchaseBlocks extends StatelessWidget {
  const PurchaseBlocks({
    required this.cardId,
    required this.type,
    this.now = DateTime.now,
    super.key,
  });

  final int cardId;
  final CardType type;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final bool warranty = kWarrantyTypes.contains(type);
    if (!warranty && !kReceiptTypes.contains(type)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (warranty) CoverBlock(cardId: cardId, now: now),
        LinkBlock(cardId: cardId, isWarranty: warranty),
      ],
    );
  }
}

/// *Covered until*: a warranty's last day, how that is known, and when the
/// reminder comes.
class CoverBlock extends ConsumerStatefulWidget {
  const CoverBlock({required this.cardId, this.now = DateTime.now, super.key});

  final int cardId;
  final DateTime Function() now;

  @override
  ConsumerState<CoverBlock> createState() => _CoverBlockState();
}

class _CoverBlockState extends ConsumerState<CoverBlock> {
  /// Asks for the permission where Android still will, and opens the app's
  /// notification settings where it will not. Checked again on resume
  /// (`ReminderResponder`), since the answer is given outside the app.
  Future<void> _turnOn() async {
    final ReminderEngine engine = ref.read(reminderEngineProvider);
    final NotificationPort port = ref.read(notificationPortProvider);
    if (!await engine.ensurePermission()) await port.openSettings();
    if (mounted) ref.invalidate(notificationsEnabledProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final ExpiryView? view = ref
        .watch(warrantyExpiryProvider(widget.cardId))
        .value;
    final bool notificationsOff =
        ref.watch(notificationsEnabledProvider).value == false;
    final DateTime now = widget.now();

    final List<Widget> lines;
    if (view == null) {
      lines = <Widget>[
        Text(
          'Not known yet. Link its receipt, or add the purchase date and the '
          'cover below.',
          style: AppText.body(c).copyWith(color: c.inkMuted),
        ),
      ];
    } else {
      final WarrantyExpiry e = view.expiry;
      final bool ended = e.day.isBefore(LocalDate.fromDateTime(now));
      final DateTime? remindAt = ended ? null : view.remindAt;
      final String? caveat = e.caveat;
      lines = <Widget>[
        Text(formatDay(e.day), style: AppText.rowSerif(c)),
        if (ended) ...<Widget>[
          const SizedBox(height: 2),
          // Said in words, not only in colour.
          Text(
            'This cover has ended.',
            style: AppText.small(c).copyWith(color: c.vermilion),
          ),
        ],
        const SizedBox(height: Gap.xs),
        Text(e.explain(), style: AppText.small(c).copyWith(color: c.inkMuted)),
        if (caveat != null)
          Text(caveat, style: AppText.small(c).copyWith(color: c.inkMuted)),
        if (remindAt != null) ...<Widget>[
          const SizedBox(height: Gap.xs),
          Row(
            // On the first line, not between two, when large text wraps it.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.notifications_none,
                  size: 14,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Reminder ${reminderWords(remindAt, now)}',
                  style: AppText.small(c),
                ),
              ),
            ],
          ),
          // The reminder exists either way; this is the way out of the
          // state where it cannot be shown, rather than a note about it.
          if (notificationsOff) ...<Widget>[
            const SizedBox(height: Gap.xs),
            Text(
              'Notifications are off for RecallOS, so this reminder cannot '
              'reach you.',
              style: AppText.small(c),
            ),
            TextAction(
              label: 'Turn on notifications',
              icon: Icons.notifications_active_outlined,
              onTap: () => unawaited(_turnOn()),
            ),
          ],
        ],
      ];
    }

    return _Block(
      label: 'Covered until',
      bottomPad: view?.remindAt != null && notificationsOff ? 0 : Gap.md,
      children: <Widget>[
        const SizedBox(height: Gap.sm),
        ...lines,
      ],
    );
  }
}

/// *Its receipt* on a warranty, *Its warranty* on a receipt: the paper it is
/// linked to, or the one it may belong with and why.
///
/// On a receipt it shows only when there is something to show. Most
/// receipts have no warranty, and linking by hand starts from the warranty,
/// which is the paper that needs the purchase date.
class LinkBlock extends ConsumerWidget {
  const LinkBlock({required this.cardId, required this.isWarranty, super.key});

  final int cardId;
  final bool isWarranty;

  String get _otherNoun => isWarranty ? 'receipt' : 'warranty';

  Future<void> _confirm(WidgetRef ref, PurchaseLink link) =>
      ref.read(purchaseLinksProvider).confirm(link.id);

  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref,
    PurchaseLink link,
  ) async {
    // Resolved before the await: the block may be gone by the time it ends.
    final PurchaseLinks links = ref.read(purchaseLinksProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await links.dismiss(link.id);
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        content: Text('Not linked. It will not be suggested again.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(links.reopen(link.id)),
        ),
      ),
    );
  }

  Future<void> _unlink(
    BuildContext context,
    WidgetRef ref,
    PurchaseLink link,
  ) async {
    final PurchaseLinks links = ref.read(purchaseLinksProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await links.unlink(link.id);
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        content: Text('Unlinked from the $_otherNoun.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(
            links.link(warrantyId: link.warrantyId, receiptId: link.receiptId),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final List<PurchaseLink> links =
        ref.watch(cardLinksProvider(cardId)).value ?? const <PurchaseLink>[];
    final List<PurchaseLink> confirmed = links
        .where((PurchaseLink l) => l.isConfirmed)
        .toList();
    final PurchaseLink? suggestion = links
        .where((PurchaseLink l) => !l.isConfirmed)
        .firstOrNull;

    if (!isWarranty && links.isEmpty) return const SizedBox.shrink();

    return _Block(
      label: isWarranty
          ? 'Its receipt'
          : confirmed.length > 1
          ? 'Its warranties'
          : 'Its warranty',
      bottomPad: 0,
      children: <Widget>[
        for (final PurchaseLink l in confirmed) ...<Widget>[
          PaperRow(card: l.other, fields: l.otherFields),
          Align(
            alignment: Alignment.centerLeft,
            child: TextAction(
              label: 'Unlink',
              icon: Icons.link_off,
              tint: c.inkMuted,
              onTap: () => unawaited(_unlink(context, ref, l)),
            ),
          ),
        ],
        if (suggestion != null)
          _Suggestion(
            link: suggestion,
            question: 'Is this its $_otherNoun?',
            onYes: () => unawaited(_confirm(ref, suggestion)),
            onNo: () => unawaited(_dismiss(context, ref, suggestion)),
          )
        else if (isWarranty && confirmed.isEmpty) ...<Widget>[
          const SizedBox(height: Gap.sm),
          Text(
            'Not linked yet. Its receipt gives the purchase date the cover '
            'counts from.',
            style: AppText.body(c).copyWith(color: c.inkMuted),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextAction(
              label: 'Link its receipt',
              icon: Icons.link,
              onTap: () => unawaited(showLinkPicker(context, ref, cardId)),
            ),
          ),
        ],
      ],
    );
  }
}

/// A suggestion, asked once: the other paper, the evidence, and both answers.
class _Suggestion extends StatelessWidget {
  const _Suggestion({
    required this.link,
    required this.question,
    required this.onYes,
    required this.onNo,
  });

  final PurchaseLink link;
  final String question;
  final VoidCallback onYes;
  final VoidCallback onNo;

  /// The pills are drawn at 44 and grow their touch target to 52, as on the
  /// card's own actions.
  static const double _art = 44;
  static const EdgeInsets _target = EdgeInsets.symmetric(
    vertical: (kMinTarget - _art) / 2,
  );

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Gap.sm),
        // Rule 3: the app asking the user something, at the inline size the
        // field editor's "What is this?" uses.
        Text(
          question,
          style: AppText.displayAsk(c).copyWith(fontSize: 21, height: 1.1),
        ),
        const SizedBox(height: Gap.xs),
        PaperRow(card: link.other, fields: link.otherFields),
        for (final LinkReason r in link.reasons)
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
                Expanded(child: Text(r.describe(), style: AppText.small(c))),
              ],
            ),
          ),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.xs,
          children: <Widget>[
            InkPill(
              label: 'Yes, link them',
              height: _art,
              hitPadding: _target,
              onTap: onYes,
            ),
            OutlinePill(
              label: 'Not this one',
              height: _art,
              hitPadding: _target,
              onTap: onNo,
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
      ],
    );
  }
}

/// Another paper, as a row that opens it — to check a suggestion against
/// the receipt itself, or to get from a warranty to what it was bought with.
class PaperRow extends StatelessWidget {
  const PaperRow({required this.card, required this.fields, super.key});

  final CardRow card;
  final List<CardField> fields;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final ({String? title, String? subtitle}) named = describeCard(
      card,
      fields,
    );
    final String title = named.title ?? 'Untitled';
    final String? subtitle = named.subtitle;
    final bool warranty = kWarrantyTypes.contains(card.type);

    return PressFade(
      onTap: () => unawaited(context.push<void>(Routes.card(card.id))),
      semanticLabel:
          'Open ${warranty ? 'the warranty' : 'the receipt'}: $title'
          '${subtitle == null ? '' : ', $subtitle'}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Row(
            children: <Widget>[
              Icon(
                warranty ? Icons.verified_user_outlined : Icons.receipt_long,
                size: 20,
                color: c.inkMuted,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppText.rowTitle(c)),
                    if (subtitle != null)
                      Text(subtitle, style: AppText.small(c)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of this screen's blocks: a paper card with a micro-caps label.
class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.children,
    this.bottomPad = Gap.md,
  });

  final String label;
  final List<Widget> children;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, bottomPad),
        decoration: AppDecoration.card(
          c,
          isDark: isDarkTheme(context),
          lifted: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MicroLabel(label, color: c.ochreInk),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Links a warranty to a receipt the user picks, when nothing printed on
/// the two matched (step 6). Receipts from the same day come first.
Future<void> showLinkPicker(
  BuildContext context,
  WidgetRef ref,
  int warrantyId,
) async {
  final PurchaseLinks links = ref.read(purchaseLinksProvider);
  final List<({CardRow card, List<CardField> fields})> candidates = await links
      .linkCandidates(warrantyId);
  if (!context.mounted) return;
  final int? receiptId = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => LinkPickerSheet(candidates: candidates),
  );
  if (receiptId == null) return;
  await links.link(warrantyId: warrantyId, receiptId: receiptId);
}

/// The picker. Public so a widget test can pump it directly.
class LinkPickerSheet extends StatelessWidget {
  const LinkPickerSheet({required this.candidates, super.key});

  final List<({CardRow card, List<CardField> fields})> candidates;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Which receipt is it?',
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.sm),
          if (candidates.isEmpty)
            // Not a dead end: it says what to do, and closing is the answer.
            Text(
              'No receipts saved yet. Scan the receipt with the same Scan '
              'button, and it can be linked from here.',
              style: AppText.body(c),
            )
          else ...<Widget>[
            Text(
              'Its date is what the cover counts from.',
              style: AppText.body(c),
            ),
            const SizedBox(height: Gap.md),
            SettingGroup(
              label: 'Saved receipts',
              children: <Widget>[
                for (final ({CardRow card, List<CardField> fields}) r
                    in candidates)
                  _candidate(r.card, r.fields, context),
              ],
            ),
          ],
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(),
            semanticLabel: 'Cancel',
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

  static Widget _candidate(
    CardRow card,
    List<CardField> fields,
    BuildContext context,
  ) {
    final ({String? title, String? subtitle}) named = describeCard(
      card,
      fields,
    );
    return SettingRow(
      label: named.title ?? 'Receipt',
      description: named.subtitle,
      onTap: () => Navigator.of(context).pop(card.id),
    );
  }
}
