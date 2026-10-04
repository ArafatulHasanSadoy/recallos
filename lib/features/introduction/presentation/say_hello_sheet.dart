import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/day_words.dart';
import '../../../core/ui/primitives.dart';
import '../../../router.dart';
import '../data/hello.dart';
import '../data/hello_repository.dart';

/// What the sheet came back with: where to open it, and the words as the
/// user left them.
typedef HelloAnswer = ({HelloChannel channel, String text});

/// Writes a hello to the person behind [cardId] and opens it where they read
/// messages.
///
/// The message is shown whole and can be changed before anything happens.
/// Only once Android has taken the hand-off is anything recorded, and then
/// only as written: whether an app was chosen, and whether anything was sent,
/// happen out of RecallOS's sight.
Future<void> sayHello(
  BuildContext context,
  WidgetRef ref, {
  required int cardId,
  required HelloReach reach,
  required String message,
  required bool signed,
}) async {
  // Resolved before the sheet: the card screen can be gone when it closes.
  final HelloRepository repo = ref.read(helloRepositoryProvider);
  final Future<bool> Function(Uri) open = ref.read(helloOpenerProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final GoRouter? router = GoRouter.maybeOf(context);

  final HelloAnswer? a = await showModalBottomSheet<HelloAnswer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => SayHelloSheet(
      message: message,
      channels: reach.channels,
      // Unsigned only because the user has no card of their own yet; the way
      // out goes to where that is fixed.
      onSignIt: signed || router == null
          ? null
          : () => unawaited(router.push(Routes.myCardEdit)),
    ),
  );
  if (a == null) return;

  final String to = a.channel == HelloChannel.email
      ? reach.email!
      : reach.mobile!;
  final bool opened = await open(helloUri(a.channel, to: to, text: a.text));
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (a.channel) {
          HelloChannel.whatsapp => 'WhatsApp could not be opened',
          HelloChannel.sms => 'Nothing on this phone sends text messages',
          HelloChannel.email => 'Nothing on this phone sends email',
        }),
      ),
    );
    return;
  }
  await repo.recordOpened(cardId, a.channel);
}

/// The sheet. Public so a widget test can pump it directly.
class SayHelloSheet extends StatefulWidget {
  const SayHelloSheet({
    required this.message,
    required this.channels,
    this.onSignIt,
    super.key,
  });

  final String message;

  /// Never empty: with nowhere to send a hello, there is no button to open
  /// this sheet.
  final List<HelloChannel> channels;

  /// Set when the message cannot be signed because the user has no card.
  final VoidCallback? onSignIt;

  @override
  State<SayHelloSheet> createState() => _SayHelloSheetState();
}

class _SayHelloSheetState extends State<SayHelloSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.message,
  );
  late HelloChannel _channel = widget.channels.first;
  bool _empty = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _open() {
    if (_text.text.trim().isEmpty) {
      setState(() => _empty = true);
      return;
    }
    Navigator.of(
      context,
    ).pop<HelloAnswer>((channel: _channel, text: _text.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final VoidCallback? signIt = widget.onSignIt;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: Gap.lg,
        right: Gap.lg,
        top: Gap.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'What would you like to say?',
            style: AppText.displayAsk(c).copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Change anything you like. RecallOS opens it in the app you '
            'pick, and you send it from there.',
            style: AppText.body(c),
          ),
          const SizedBox(height: Gap.md),
          Pocket(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm + 2,
            ),
            child: TextField(
              controller: _text,
              // Not focused on open: the message is read first, and a
              // keyboard would cover the buttons under it.
              minLines: 4,
              maxLines: 8,
              cursorColor: c.ochre,
              cursorWidth: 2,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.rowTitle(c).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                fontVariations: AppFonts.weight(400),
                height: 1.45,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) {
                if (_empty) setState(() => _empty = false);
              },
            ),
          ),
          if (_empty) ...<Widget>[
            const SizedBox(height: Gap.xs),
            Text(
              'Write a message first.',
              style: AppText.small(c).copyWith(color: c.vermilion),
            ),
          ],
          if (signIt != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextAction(
                label: 'Sign it — make your card',
                icon: Icons.badge_outlined,
                onTap: () {
                  Navigator.of(context).pop();
                  signIt();
                },
              ),
            ),
          // A choice of one is not a choice; the button says where it goes.
          if (widget.channels.length > 1) ...<Widget>[
            const SizedBox(height: Gap.md),
            MicroLabel('Open it in', color: c.inkMuted),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: <Widget>[
                for (final HelloChannel ch in widget.channels)
                  SelectChip(
                    label: ch.label,
                    selected: ch == _channel,
                    onTap: () => setState(() => _channel = ch),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Gap.lg),
          InkPill(label: _channel.action, height: 58, onTap: _open),
          const SizedBox(height: Gap.sm),
          PressFade(
            onTap: () => Navigator.of(context).pop(),
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

/// "Hello written for WhatsApp today" — what the card remembers, in the words
/// that are true. Nothing when there has been no hello.
class HelloLine extends ConsumerWidget {
  const HelloLine({required this.cardId, this.now = DateTime.now, super.key});

  final int cardId;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HelloRecord? last = ref.watch(lastHelloProvider(cardId)).value;
    if (last == null) return const SizedBox.shrink();
    final AppColors c = AppColors.of(context);
    final DateTime at = now();
    final int days = daysFrom(at, last.openedAt);
    final String when = switch (days) {
      0 => 'today',
      -1 => 'yesterday',
      _ => 'on ${weekdayDayMonth(last.openedAt, at)}',
    };

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Row(
        children: <Widget>[
          Icon(Icons.waving_hand_outlined, size: 15, color: c.inkMuted),
          const SizedBox(width: Gap.xs + 2),
          Expanded(
            child: Text(
              'Hello written ${last.channel.written} $when',
              style: AppText.small(c),
            ),
          ),
        ],
      ),
    );
  }
}
