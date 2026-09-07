import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/enums.dart';
import '../../../../core/extraction/phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/card_face.dart';
import '../../../../core/ui/primitives.dart';
import '../../../../router.dart';
import '../../../capture/data/card_repository.dart';
import '../../data/contact_export.dart';

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
    final AppColors c = AppColors.of(context);
    final String canonical = contact.normalizedValue ?? contact.value;
    final bool isPhone = contact.kind == ContactKind.phone;
    // A landline WhatsApp link opens to an error, which reads as the app being
    // broken — so the caps line says what can actually be done with this
    // endpoint, and nothing more.
    final bool mobile = isPhone && PhoneExtractor.isMobile(canonical);
    final List<String> actions = isPhone
        ? <String>['Call', if (mobile) 'WhatsApp']
        : <String>['Email'];

    return PressFade(
      onTap: () => unawaited(
        _open(
          context,
          isPhone
              ? Uri(scheme: 'tel', path: canonical)
              : Uri(scheme: 'mailto', path: canonical),
        ),
      ),
      onLongPress: mobile
          ? () => unawaited(
              _open(
                context,
                Uri.parse('https://wa.me/${canonical.replaceAll("+", "")}'),
              ),
            )
          : null,
      semanticLabel: '${contact.value}, ${actions.join(" or ")}',
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTarget),
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    contact.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowTitle(c).copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  MetaLabel(actions.join(' · '), color: c.ochreInk),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Icon(
              isPhone ? Icons.call_outlined : Icons.mail_outlined,
              size: 19,
              color: c.inkMuted,
            ),
          ],
        ),
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
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cardIds.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm + 2),
        itemBuilder: (BuildContext context, int i) {
          final int id = cardIds[i];
          final AsyncValue<CardDetail?> card = ref.watch(
            cardDetailProvider(id),
          );
          return card.maybeWhen(
            data: (CardDetail? d) => d == null
                ? const SizedBox.shrink()
                : PressFade(
                    onTap: () => openCardDetail(
                      context,
                      cardId: id,
                      imagePath: d.card.thumbPath ?? d.card.imagePath,
                    ),
                    child: CardFace(
                      imagePath: d.card.thumbPath ?? d.card.imagePath,
                      heroTag: cardHeroTag(id),
                      // The real card proportion, so the strip reads as paper.
                      size: const Size(148, 93),
                      radius: 10,
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
    'md',
    'md.',
    'mohammad',
    'mohammed',
    'mohd',
    'mohd.',
    'muhammad',
    'mr',
    'mr.',
    'mrs',
    'mrs.',
    'ms',
    'ms.',
    'miss',
    'dr',
    'dr.',
    'prof',
    'prof.',
    'engr',
    'engr.',
    'alhaj',
    'late',
  };

  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  final List<String> real = parts
      .where((String p) => !skip.contains(p.toLowerCase()))
      .toList();
  // If stripping left nothing, the honorific was the whole name.
  final List<String> use = real.isEmpty ? parts : real;

  if (use.isEmpty) return '?';
  if (use.length == 1) return use.first.characters.first.toUpperCase();
  return (use.first.characters.first + use.last.characters.first).toUpperCase();
}

/// Runs an export and says what happened.
///
/// The failure worth reporting is a phone with nothing that imports vCards —
/// rare, but silent otherwise: the file is written, no app opens, and the user
/// is left looking at a screen that did nothing.
Future<void> exportContact(
  BuildContext context,
  Future<ContactExportResult> Function() run,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ContactExportResult result = await run();

  final String? message = switch (result) {
    ContactExportResult.opened => null,
    ContactExportResult.shared => null,
    ContactExportResult.noHandler =>
      'No app on this phone can import a contact file.',
    ContactExportResult.gone => 'This contact is no longer here.',
  };
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
