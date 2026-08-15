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
import '../../capture/data/card_repository.dart';
import 'widgets/card_image_overlay.dart';
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
      appBar: AppBar(
        title: const Text('Card'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => unawaited(_confirmDelete(context)),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            Center(child: Text('Could not open this card.\n$e')),
        data: (CardDetail? d) => d == null
            ? const Center(child: Text('This card is no longer here.'))
            : _Body(
                detail: d,
                highlight: _highlight,
                onRegionChanged: (String? rect) =>
                    setState(() => _highlight = rect),
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
          'The photo and everything read from it will be removed.',
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

    await ref.read(cardRepositoryProvider).purge(widget.cardId);
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
    final ThemeData theme = Theme.of(context);
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
        // being corrected rather than from memory.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          child: GestureDetector(
            // The original is always one tap away, at full zoom.
            onTap: () => _showFullImage(context, image),
            child: Hero(
              tag: 'card-${detail.card.id}',
              child: CardImageOverlay(
                image: image,
                highlight: highlight,
                maxHeight: 200,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            children: <Widget>[
              Text(detail.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: Gap.md),
              if (note != null) ...<Widget>[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Why you saved this',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            )),
                        const SizedBox(height: Gap.xs),
                        Text(note,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
              ],
              _Actions(detail: detail),
              const SizedBox(height: Gap.lg),
              Text('On the card', style: theme.textTheme.titleMedium),
              const SizedBox(height: Gap.sm),
              EditableFieldList(
                detail: detail,
                onRegionChanged: onRegionChanged,
              ),
              if (detail.unassignedText.isNotEmpty) ...<Widget>[
                const SizedBox(height: Gap.lg),
                Text('Other text', style: theme.textTheme.titleMedium),
                const SizedBox(height: Gap.sm),
                Text(
                  detail.unassignedText.join('\n'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
          appBar: AppBar(),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              maxScale: 6,
              child: Image.file(image),
            ),
          ),
        ),
      ),
    );
  }
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

    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: <Widget>[
        if (primaryPhone != null)
          _ActionChip(
            icon: Icons.call_outlined,
            label: 'Call',
            onTap: () => _open(context, Uri(scheme: 'tel', path: primaryPhone)),
          ),
        // WhatsApp is offered only for mobiles: a landline link opens to an
        // error, which reads as the app being broken.
        if (primaryPhone != null && PhoneExtractor.isMobile(primaryPhone))
          _ActionChip(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            onTap: () => _open(
              context,
              Uri.parse('https://wa.me/${primaryPhone.replaceAll("+", "")}'),
            ),
          ),
        if (email != null)
          _ActionChip(
            icon: Icons.mail_outlined,
            label: 'Email',
            onTap: () => _open(context, Uri(scheme: 'mailto', path: email)),
          ),
        if (address != null)
          _ActionChip(
            icon: Icons.map_outlined,
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => unawaited(onTap()),
    );
  }
}
