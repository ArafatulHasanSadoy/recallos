import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/enums.dart';
import '../../../../core/extraction/phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../router.dart';
import '../../../capture/data/card_repository.dart';
import '../../../cards/presentation/widgets/wallet_card.dart';

/// The endpoints on a person or a company, each with the one action that
/// actually reaches it.
class Endpoints extends StatelessWidget {
  const Endpoints({required this.contacts, super.key});

  final List<ContactPoint> contacts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ContactPoint c in contacts) _EndpointRow(contact: c),
      ],
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.contact});

  final ContactPoint contact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String canonical = contact.normalizedValue ?? contact.value;
    final bool isPhone = contact.kind == ContactKind.phone;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: <Widget>[
          Icon(
            isPhone ? Icons.call_outlined : Icons.mail_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              contact.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (isPhone)
            IconButton(
              tooltip: 'Call',
              icon: const Icon(Icons.call),
              onPressed: () =>
                  _open(context, Uri(scheme: 'tel', path: canonical)),
            ),
          // A landline WhatsApp link opens to an error, which reads as the app
          // being broken — so it is offered only where it can work.
          if (isPhone && PhoneExtractor.isMobile(canonical))
            IconButton(
              tooltip: 'WhatsApp',
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => _open(
                context,
                Uri.parse('https://wa.me/${canonical.replaceAll("+", "")}'),
              ),
            ),
          if (!isPhone)
            IconButton(
              tooltip: 'Email',
              icon: const Icon(Icons.mail),
              onPressed: () =>
                  _open(context, Uri(scheme: 'mailto', path: canonical)),
            ),
        ],
      ),
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

/// The cards an entity was built from.
///
/// Kept visible because every fact above came off one of them, and being able
/// to go back to the paper is what makes an extracted value checkable.
class CardStrip extends ConsumerWidget {
  const CardStrip({required this.cardIds, super.key});

  final List<int> cardIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cardIds.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
        itemBuilder: (BuildContext context, int i) {
          final int id = cardIds[i];
          final AsyncValue<CardDetail?> card = ref.watch(cardDetailProvider(id));
          return card.maybeWhen(
            data: (CardDetail? d) => d == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () => context.push(Routes.card(id)),
                    child: AspectRatio(
                      aspectRatio: WalletCard.aspectRatio,
                      child: WalletCard(
                        imagePath: d.card.thumbPath ?? d.card.imagePath,
                      ),
                    ),
                  ),
            orElse: () => const SizedBox(width: 1),
          );
        },
      ),
    );
  }
}

/// Initials for an avatar, with honorifics left out.
///
/// "Md. Abul Bashar Sarker" is A.S., not M.S. — the honorific is the one part
/// of the name that identifies nobody.
String contactInitials(String name) {
  const Set<String> skip = <String>{
    'md', 'md.', 'mohammad', 'mohammed', 'mohd', 'mohd.', 'muhammad',
    'mr', 'mr.', 'mrs', 'mrs.', 'ms', 'ms.', 'miss',
    'dr', 'dr.', 'prof', 'prof.', 'engr', 'engr.', 'alhaj', 'late',
  };

  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  final List<String> real =
      parts.where((String p) => !skip.contains(p.toLowerCase())).toList();
  // If stripping left nothing, the honorific was the whole name.
  final List<String> use = real.isEmpty ? parts : real;

  if (use.isEmpty) return '?';
  if (use.length == 1) return use.first.characters.first.toUpperCase();
  return (use.first.characters.first + use.last.characters.first).toUpperCase();
}
