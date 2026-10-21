import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/extraction/phone.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/card_face.dart';
import '../../../core/ui/primitives.dart';
import '../../../core/ui/wallet_stack.dart';
import '../../capture/data/card_repository.dart';
import '../../capture/presentation/kind_sheet.dart' show noteHintFor, paperNoun;
import '../../contacts/data/identity_repository.dart';
import '../../followup/data/follow_up_repository.dart' show encounterProvider;
import '../../followup/presentation/card_follow_up_blocks.dart';
import '../../introduction/data/hello.dart';
import '../../introduction/presentation/say_hello_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../search/data/search_repository.dart';
import '../../warranty/presentation/purchase_blocks.dart';
import 'reach_out.dart';
import 'widgets/card_sides_view.dart';
import 'widgets/editable_field_list.dart';
import 'widgets/full_image_view.dart';
import 'widgets/note_sheet.dart';

/// One saved card, and what you can do with it.
///
/// The layer the plan calls Action: finding the right contact is only half the
/// job — the point is to call them, message them, or find their shop. Every
/// fact carries where it came from, so an OCR guess never looks like something
/// printed on the card, and every fact is repairable, because mistakes get
/// noticed a week after scanning at least as often as during the scan.
class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({
    required this.cardId,
    this.previewImagePath,
    super.key,
  });

  final int cardId;
  final String? previewImagePath;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  /// Region of the field being edited, boxed on the side it was read from.
  FieldHighlight? _highlight;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CardDetail?> detail = ref.watch(
      cardDetailProvider(widget.cardId),
    );
    final CardDetail? d = detail.value;

    // The photograph lives here rather than inside `detail.when`, and that is
    // load-bearing rather than tidying.
    //
    // A card is opened by a hero flight out of its own thumbnail, and the
    // flight needs a destination that exists on the route's *first* frame —
    // before Drift has emitted anything. There used to be a second widget for
    // that first frame, and swapping it for the real one when the data landed
    // rebuilt the photograph from scratch: new element, new decode, a blank
    // rectangle for a frame or two, and a box of a slightly different height,
    // all arriving in the last moments of the transition. One widget for the
    // life of the screen has none of that — the preview is replaced by the
    // full capture in place, and `gaplessPlayback` holds the old frame until
    // the new one is ready.
    final String? front = d?.card.imagePath ?? widget.previewImagePath;
    final String? preview = d?.card.thumbPath ?? widget.previewImagePath;
    // Nothing to pin once the card is gone; the flight has nowhere to land
    // either, which is the honest thing to show.
    final bool gone = detail.hasValue && d == null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              // Named for what it is: a receipt is not a card (B3).
              title: d == null ? 'Card' : _heading(d.card.type),
              onBack: () => context.pop(),
              actions: <Widget>[
                RoundIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onTap: () => unawaited(_confirmDelete(context)),
                ),
              ],
            ),
            if (front != null && !gone)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                child: CardSidesView(
                  cardId: d?.card.id,
                  front: File(front),
                  frontPreview: preview == null ? null : File(preview),
                  backPath: d?.card.backImagePath,
                  highlight: _highlight,
                  maxHeight: 200,
                  heroTag: cardHeroTag(widget.cardId),
                  onOpenFullImage: (File side) => _showFullImage(context, side),
                ),
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
                data: (CardDetail? card) => card == null
                    ? const EmptyState(
                        label: 'Gone',
                        title: 'This card is no longer here',
                        body: 'It may have been deleted from another screen.',
                      )
                    : _Body(
                        detail: card,
                        onRegionChanged: (FieldHighlight? h) =>
                            setState(() => _highlight = h),
                        onEditNote: (String? current) =>
                            unawaited(_editNote(context, current)),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, File image) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FullImageView(image: image),
      ),
    );
  }

  /// Adds, corrects or clears the note — the one piece of a card that makes it
  /// findable by need. Until this existed it could only be written once, in
  /// the save sheet, so "Skip for now" was permanent.
  Future<void> _editNote(BuildContext context, String? current) async {
    // Resolved before the sheet opens: the screen can be gone by the time it
    // closes, and a ref is not usable after that.
    final CardRepository cards = ref.read(cardRepositoryProvider);
    final SearchRepository search = ref.read(searchRepositoryProvider);

    final CardType? type = ref
        .read(cardDetailProvider(widget.cardId))
        .value
        ?.card
        .type;
    final String? result = await showNoteSheet(
      context,
      hint: noteHintFor(type ?? CardType.visitingCard),
      question: 'Why did you save this?',
      explanation: current == null
          ? "You'll search by this later, so write it how you'd say it."
          : "You'll search by this later. Clear it to remove the note.",
      primaryLabel: 'Save note',
      secondaryLabel: 'Cancel',
      secondaryResult: null,
      initial: current ?? '',
    );
    if (result == null || result.trim() == (current ?? '').trim()) return;

    await cards.setNote(cardId: widget.cardId, body: result);
    // The note is the most valuable text search has; a stale index would keep
    // finding the card by what it used to say.
    await search.reindexCard(widget.cardId);
  }

  /// "Card", "Receipt", "Warranty".
  static String _heading(CardType type) {
    final String noun = paperNoun(type);
    return '${noun[0].toUpperCase()}${noun.substring(1)}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final CardType? type = ref
        .read(cardDetailProvider(widget.cardId))
        .value
        ?.card
        .type;
    final String noun = type == null ? 'card' : paperNoun(type);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete this $noun?'),
        content: const Text(
          'It moves to Recently deleted, on the Needs attention screen, and '
          'waits there for 30 days before it is removed for good.',
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

/// Everything under the photograph: the title, the note, the actions and the
/// field list. The photograph itself is pinned by the screen above, so a field
/// can be checked against the printing while it is corrected rather than from
/// memory.
class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.onRegionChanged,
    required this.onEditNote,
  });

  final CardDetail detail;
  final ValueChanged<FieldHighlight?> onRegionChanged;

  /// Called with the current note, or null when the card has none.
  final ValueChanged<String?> onEditNote;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? note = detail.notes
        .map((Note n) => n.body)
        .whereType<String>()
        .where((String b) => b.trim().isNotEmpty)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      children: <Widget>[
        Text(detail.title, style: AppText.title(c)),
        const SizedBox(height: Gap.md),
        // What people open a card to do — call, say hello, find the shop —
        // straight under the name (M7½). It sat under three blocks, at the
        // bottom edge of the screen, below the fold on a smaller phone. A
        // card with nothing to call or mail (most receipts) has no row and
        // no gap.
        if (_Actions.hasAny(detail)) ...<Widget>[
          _Actions(detail: detail),
          const SizedBox(height: Gap.md),
        ],
        // Always present: a card with no note is exactly the one that most
        // needs one, and hiding the block hid the only way to add it.
        _NoteBlock(
          note: note,
          colors: c,
          paper: paperNoun(detail.card.type),
          ofPerson: IdentityRepository.peopleCardTypes.contains(
            detail.card.type,
          ),
          onTap: () => onEditNote(note),
        ),
        const SizedBox(height: Gap.sm),
        // A warranty's end and what it was bought with, a receipt's warranty
        // (B3). Nothing for anyone's card; each block spaces itself.
        PurchaseBlocks(cardId: detail.card.id, type: detail.card.type),
        // What happens next, then how you know them: the note says why the
        // card mattered, these two say what to do about it.
        NextStepsBlock(cardId: detail.card.id),
        // Only somebody's card has somebody you met. A receipt bought at a
        // fair was not met there (B2), and the block said so on every one.
        if (IdentityRepository.peopleCardTypes.contains(
          detail.card.type,
        )) ...<Widget>[
          const SizedBox(height: Gap.sm),
          MetBlock(cardId: detail.card.id, scannedOn: detail.card.capturedAt),
        ],
        const SizedBox(height: Gap.lg),
        SectionHeader(
          'On the ${paperNoun(detail.card.type)}',
          count: detail.fields.length,
        ),
        const SizedBox(height: Gap.sm),
        EditableFieldList(detail: detail, onRegionChanged: onRegionChanged),
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
    );
  }
}

/// Why the card was kept — or, when nobody said, the invitation to say it.
/// The label is the existing copy, deliberately. Tapping opens the same sheet
/// the save flow uses.
class _NoteBlock extends StatelessWidget {
  const _NoteBlock({
    required this.note,
    required this.colors,
    required this.onTap,
    this.paper = 'card',
    this.ofPerson = true,
  });

  final String? note;
  final AppColors colors;
  final VoidCallback onTap;

  /// What the paper is called, and whether somebody's name is on it — a
  /// receipt is not found again by a name that was forgotten.
  final String paper;
  final bool ofPerson;

  @override
  Widget build(BuildContext context) {
    final String? text = note;
    return PressFade(
      onTap: onTap,
      semanticLabel: text == null
          ? 'Add why you saved this'
          : 'Why you saved this: $text. Edit',
      child: Container(
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
            Row(
              children: <Widget>[
                Expanded(
                  child: MicroLabel(
                    'Why you saved this',
                    color: colors.ochreInk,
                  ),
                ),
                Icon(
                  text == null ? Icons.add : Icons.edit_outlined,
                  size: 16,
                  color: colors.inkMuted,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            if (text != null)
              Text(
                text,
                style: AppText.rowTitle(colors).copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w400,
                  fontVariations: AppFonts.weight(400),
                  height: 1.45,
                ),
              )
            else
              Text(
                ofPerson
                    ? "Nothing yet. Add a line — it's how you'll find this "
                          'card when you have forgotten the name.'
                    : "Nothing yet. Add a line — it's how you'll find this "
                          '$paper later.',
                style: AppText.body(colors).copyWith(color: colors.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Call, say hello, message, mail, map.
class _Actions extends ConsumerWidget {
  const _Actions({required this.detail});

  final CardDetail detail;

  /// Whether the card has anything to act on: a number, an email or an
  /// address. Every action and the hello line hang off one of the three.
  static bool hasAny(CardDetail d) =>
      d.allOf(FieldKeys.phone).isNotEmpty ||
      d.valueOf(FieldKeys.email) != null ||
      d.valueOf(FieldKeys.address) != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CardField> phones = detail.allOf(FieldKeys.phone);
    final String? email = detail.valueOf(FieldKeys.email);
    final String? address = detail.valueOf(FieldKeys.address);

    final String? primaryPhone = phones.isEmpty
        ? null
        : (phones.first.normalizedValue ?? phones.first.value);

    // A hello goes to the first *mobile* on the card, which need not be the
    // first number: an office line printed above a mobile is common.
    final HelloReach reach = HelloReach(
      mobile: phones
          .map((CardField f) => f.normalizedValue ?? f.value)
          .where(PhoneExtractor.isMobile)
          .firstOrNull,
      email: email,
    );
    // Watched here so both are ready by the time the button is pressed.
    final Encounter? met = ref.watch(encounterProvider(detail.card.id)).value;
    final ProfileDetail? me = ref.watch(myProfileProvider).value;

    // Derived, never four fixed buttons. A landline wa.me link opens to an
    // error, which reads as the app being broken.
    final Widget pills = Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: <Widget>[
        if (primaryPhone != null)
          // Ink-filled, alone among the four. Calling is what people came to
          // this screen to do; the rest are alternatives to it.
          _ActionPill(
            label: 'Call',
            primary: true,
            onTap: () => reachOut(
              context,
              ref,
              Uri(scheme: 'tel', path: primaryPhone),
              cardId: detail.card.id,
              kind: InteractionKind.callOpened,
            ),
          ),
        // Only where a hello can go: a card with nothing but a landline has
        // no button, rather than one that opens a sheet with no way out.
        if (!reach.isEmpty)
          _ActionPill(
            label: 'Say hello',
            onTap: () => sayHello(
              context,
              ref,
              cardId: detail.card.id,
              reach: reach,
              signed: me != null && me.name.isNotEmpty,
              message: helloMessage(
                now: DateTime.now(),
                theirName: detail.valueOf(FieldKeys.personName),
                place: met?.place,
                metOn: met?.metOn,
                myName: me?.name,
                myCompany: me?.valueOf(FieldKeys.company),
              ),
            ),
          ),
        if (primaryPhone != null && PhoneExtractor.isMobile(primaryPhone))
          _ActionPill(
            label: 'WhatsApp',
            onTap: () => reachOut(
              context,
              ref,
              Uri.parse('https://wa.me/${primaryPhone.replaceAll("+", "")}'),
              cardId: detail.card.id,
              kind: InteractionKind.messageOpened,
              detail: 'whatsapp',
            ),
          ),
        if (email != null)
          _ActionPill(
            label: 'Email',
            onTap: () => reachOut(
              context,
              ref,
              Uri(scheme: 'mailto', path: email),
              cardId: detail.card.id,
              kind: InteractionKind.emailOpened,
            ),
          ),
        if (address != null)
          _ActionPill(
            label: 'Map',
            onTap: () => reachOut(
              context,
              ref,
              Uri.https('www.google.com', '/maps/search/', <String, String>{
                'api': '1',
                'query': address,
              }),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        pills,
        HelloLine(cardId: detail.card.id),
      ],
    );
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
  static const EdgeInsets _target = EdgeInsets.symmetric(
    vertical: (kMinTarget - _art) / 2,
  );

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
