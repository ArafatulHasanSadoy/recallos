import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/phone.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../capture/data/card_repository.dart';
import '../../contacts/data/identity_repository.dart';
import 'widgets/card_sides_view.dart';
import 'widgets/editable_field_list.dart';

/// One saved card, and what you can do with it.
///
/// The layer the plan calls Action: finding the right contact is only half the
/// job — the point is to call them, message them, or find their shop. Every
/// fact carries where it came from, so an OCR guess never looks like something
/// printed on the card, and every fact is repairable, because mistakes get
/// noticed a week after scanning at least as often as during the scan.
class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({required this.cardId, super.key});

  final int cardId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  /// Region of the field being edited, boxed on the image above.
  String? _highlight;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CardDetail?> detail =
        ref.watch(cardDetailProvider(widget.cardId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Card',
              onBack: () => context.pop(),
              actions: <Widget>[
                RoundIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onTap: () => unawaited(_confirmDelete(context)),
                ),
              ],
            ),
            Expanded(
              child: detail.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: GhostStack(count: 1),
                ),
                error: (Object e, _) => EmptyState(
                  label: 'Not found',
                  title: 'Could not open this card',
                  body: '$e',
                ),
                data: (CardDetail? d) => d == null
                    ? const EmptyState(
                        label: 'Gone',
                        title: 'This card is no longer here',
                        body: 'It may have been deleted from another screen.',
                      )
                    : _Body(
                        detail: d,
                        highlight: _highlight,
                        onRegionChanged: (String? rect) =>
                            setState(() => _highlight = rect),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this card?'),
        content: const Text(
          'It moves to Recently deleted, on the Needs attention screen. '
          'It stays on the phone until you remove it there.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Soft, exactly like a swipe in the library. This used to purge outright —
    // photo, fields and all — the moment the dialog was confirmed, which made
    // the trash icon on this screen the one irreversible delete in an app
    // built on being able to change your mind. It also meant a card deleted
    // from here never reached Recently deleted, because there was nothing left
    // to reach it.
    await ref.read(cardRepositoryProvider).softDelete(widget.cardId);
    // The person and company come down with it, and go back up on restore.
    await ref.read(identityRepositoryProvider).detach(widget.cardId);
    if (context.mounted) context.pop();
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.highlight,
    required this.onRegionChanged,
  });

  final CardDetail detail;
  final String? highlight;
  final ValueChanged<String?> onRegionChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final File image = File(detail.card.imagePath);
    final String? note = detail.notes
        .map((Note n) => n.body)
        .whereType<String>()
        .where((String b) => b.trim().isNotEmpty)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Pinned, so a field can be checked against the printing while it is
        // corrected rather than from memory.
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
          child: CardSidesView(
            cardId: detail.card.id,
            front: image,
            backPath: detail.card.backImagePath,
            highlight: highlight,
            maxHeight: 200,
            heroTag: 'card-${detail.card.id}',
            onOpenFullImage: (File side) => _showFullImage(context, side),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            children: <Widget>[
              Text(detail.title, style: AppText.title(c)),
              const SizedBox(height: Gap.md),
              if (note != null) ...<Widget>[
                _NoteBlock(note: note, colors: c),
                const SizedBox(height: Gap.lg),
              ],
              _Actions(detail: detail),
              const SizedBox(height: Gap.lg),
              SectionHeader('On the card', count: detail.fields.length),
              const SizedBox(height: Gap.sm),
              EditableFieldList(
                detail: detail,
                onRegionChanged: onRegionChanged,
              ),
              if (detail.unassignedText.isNotEmpty) ...<Widget>[
                const SizedBox(height: Gap.lg),
                const SectionHeader('Other text'),
                const SizedBox(height: Gap.sm),
                Text(
                  detail.unassignedText.join(' · '),
                  style: AppText.body(c).copyWith(color: c.inkFaint),
                ),
              ],
              const SizedBox(height: Gap.xl),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context, File image) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
          body: Center(
            child: InteractiveViewer(maxScale: 6, child: Image.file(image)),
          ),
        ),
      ),
    );
  }
}

/// Why the card was kept. The label is the existing copy, deliberately.
class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.note, required this.colors});

  final String note;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.md),
        decoration: AppDecoration.card(
          colors,
          isDark: isDarkTheme(context),
          lifted: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MicroLabel('Why you saved this', color: colors.ochreInk),
            const SizedBox(height: Gap.sm),
            Text(
              note,
              style: AppText.rowTitle(colors).copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                fontVariations: AppFonts.weight(400),
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}

/// Call, message, mail, map.
class _Actions extends StatelessWidget {
  const _Actions({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    final List<CardField> phones = detail.allOf(FieldKeys.phone);
    final String? email = detail.valueOf(FieldKeys.email);
    final String? address = detail.valueOf(FieldKeys.address);

    final String? primaryPhone = phones.isEmpty
        ? null
        : (phones.first.normalizedValue ?? phones.first.value);

    // Derived, never four fixed buttons. A landline wa.me link opens to an
    // error, which reads as the app being broken.
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: <Widget>[
        if (primaryPhone != null)
          // Ink-filled, alone among the four. Calling is what people came to
          // this screen to do; the rest are alternatives to it.
          _ActionPill(
            label: 'Call',
            primary: true,
            onTap: () => _open(context, Uri(scheme: 'tel', path: primaryPhone)),
          ),
        if (primaryPhone != null && PhoneExtractor.isMobile(primaryPhone))
          _ActionPill(
            label: 'WhatsApp',
            onTap: () => _open(
              context,
              Uri.parse('https://wa.me/${primaryPhone.replaceAll("+", "")}'),
            ),
          ),
        if (email != null)
          _ActionPill(
            label: 'Email',
            onTap: () => _open(context, Uri(scheme: 'mailto', path: email)),
          ),
        if (address != null)
          _ActionPill(
            label: 'Map',
            onTap: () => _open(
              context,
              Uri.https('www.google.com', '/maps/search/',
                  <String, String>{'api': '1', 'query': address}),
            ),
          ),
      ],
    );
  }

  static Future<void> _open(BuildContext context, Uri uri) async {
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nothing on this phone can open $uri')),
      );
    }
  }
}

/// One derived action.
///
/// Label only, as the frames have it: at this size an icon beside a four-letter
/// word makes the pill wider than the word it is explaining, and four of them
/// wrap to two lines on a narrow phone.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final Future<void> Function() onTap;
  final bool primary;

  /// The frames draw a 44 pill. The accessibility floor wants 52 of touch, so
  /// the art stays 44 and [PressFade.hitPadding] grows the target around it,
  /// rather than the pill being inflated to meet a number nobody can see.
  static const double _art = 44;
  static const EdgeInsets _target =
      EdgeInsets.symmetric(vertical: (kMinTarget - _art) / 2);

  @override
  Widget build(BuildContext context) {
    final Widget pill = primary
        ? InkPill(
            label: label,
            height: _art,
            hitPadding: _target,
            onTap: () => unawaited(onTap()),
          )
        : OutlinePill(
            label: label,
            height: _art,
            hitPadding: _target,
            onTap: () => unawaited(onTap()),
          );

    // `Align` with a width factor, never `Center`: inside a `Wrap` a Center
    // expands to the full available width, so each pill claimed an entire row
    // and the four of them came out stacked down the middle of the screen
    // instead of flowing along it.
    return Align(widthFactor: 1, heightFactor: 1, child: pill);
  }
}
