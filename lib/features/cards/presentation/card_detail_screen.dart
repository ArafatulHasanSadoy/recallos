import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/phone.dart';
import '../../../core/theme/app_theme.dart';
import '../../capture/data/card_repository.dart';

final cardDetailProvider =
    StreamProvider.family<CardDetail?, int>((Ref ref, int id) {
  return ref.watch(cardRepositoryProvider).watchCard(id);
});

/// One saved card, and what you can do with it.
///
/// The layer the plan calls Action: finding the right contact is only half the
/// job — the point is to call them, message them, or find their shop. Every
/// fact carries where it came from, so an OCR guess never looks like something
/// printed on the card.
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({required this.cardId, super.key});

  final int cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CardDetail?> detail =
        ref.watch(cardDetailProvider(cardId));

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
            onPressed: () => unawaited(_confirmDelete(context, ref)),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Could not open this card.\n$e')),
        data: (CardDetail? d) => d == null
            ? const Center(child: Text('This card is no longer here.'))
            : _Body(detail: d),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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

    await ref.read(cardRepositoryProvider).purge(cardId);
    if (context.mounted) context.pop();
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final CardDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final File image = File(detail.card.imagePath);
    final String? note = detail.notes
        .map((Note n) => n.body)
        .whereType<String>()
        .where((String b) => b.trim().isNotEmpty)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: <Widget>[
        if (image.existsSync())
          GestureDetector(
            // The original is always one tap away, so the user can check any
            // field against what is actually printed.
            onTap: () => _showFullImage(context, image),
            child: Hero(
              tag: 'card-${detail.card.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  image,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheHeight: 660,
                ),
              ),
            ),
          ),
        const SizedBox(height: Gap.lg),
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
        for (final CardField f in detail.fields) _FieldRow(field: f),

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

    final String? primaryPhone =
        phones.isEmpty ? null : (phones.first.normalizedValue ?? phones.first.value);

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

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field});

  final CardField field;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        title: Text(field.value),
        subtitle: Row(
          children: <Widget>[
            Text(_label(field.fieldKey)),
            const SizedBox(width: Gap.sm),
            // Provenance on every fact. An AI guess or a repaired digit never
            // gets to look like something printed on the card.
            _SourceChip(
              source: field.source,
              issue: field.validationIssue,
              verified: field.verifiedByUser,
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy_outlined, size: 20),
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: field.normalizedValue ?? field.value),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied')),
            );
          },
        ),
      ),
    );
  }

  static String _label(String key) => switch (key) {
        FieldKeys.personName => 'Name',
        FieldKeys.company => 'Company',
        FieldKeys.designation => 'Designation',
        FieldKeys.phone => 'Phone',
        FieldKeys.email => 'Email',
        FieldKeys.website => 'Website',
        FieldKeys.address => 'Address',
        _ => key,
      };
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.source,
    required this.issue,
    required this.verified,
  });

  final FactSource source;
  final String? issue;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (String text, Color colour) = switch ((verified, issue, source)) {
      (true, _, _) => ('you confirmed', theme.colorScheme.primary),
      (_, 'digit_restored', _) =>
        ('digit restored', theme.colorScheme.tertiary),
      (_, 'ocr_repaired', _) => ('OCR repaired', theme.colorScheme.tertiary),
      (_, final String? i, _) when i != null =>
        ('needs a look', theme.colorScheme.error),
      (_, _, FactSource.printed) => ('on the card', theme.colorScheme.outline),
      (_, _, FactSource.user) => ('you typed', theme.colorScheme.primary),
      (_, _, FactSource.aiInferred) => ('guess', theme.colorScheme.tertiary),
      (_, _, FactSource.outdated) => ('may be old', theme.colorScheme.error),
      (_, _, FactSource.verified) => ('verified', theme.colorScheme.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colour),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: colour),
      ),
    );
  }
}
