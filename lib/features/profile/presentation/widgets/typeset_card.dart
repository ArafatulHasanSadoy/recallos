import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/imaging/sealed_file_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/card_face.dart';
import '../../../../core/ui/primitives.dart';
import '../../../contacts/presentation/widgets/contact_widgets.dart';
import '../../data/profile_repository.dart';

/// The user's own card, set rather than photographed.
///
/// Every other card in this wallet is a picture of a piece of paper. This one
/// is the exception and looks like it on purpose: same paper, same ochre corner
/// fold, same proportions — but typeset in the app's own faces, because it was
/// never printed. That contrast is the whole visual idea, and it is why this
/// draws a card and not a profile page.
///
/// Takes a [ProfileCard], which is a plain value type with no database behind
/// it. That is what lets the editor's live preview and the saved card be the
/// same widget: one is built from a draft nobody has committed, the other from
/// stored rows, and this cannot tell them apart.
class TypesetCardFace extends StatelessWidget {
  const TypesetCardFace({required this.card, this.compact = false, super.key});

  final ProfileCard card;

  /// Drops the contact lines and the tagline, for the small copy that sits in
  /// the home header. Same face, less of it.
  final bool compact;

  /// A card is 1.586 times as wide as it is tall — the ratio the design system
  /// already names for a real one.
  static const double ratio = 1.586;

  /// How wide the card is ever drawn.
  ///
  /// A real card does not get bigger because the paper did. Without this a
  /// tablet — or a phone held sideways, or a widget test on the default 800px
  /// surface — gets a half-metre of business card, because the height follows
  /// the width through [ratio].
  static const double maxWidth = 420;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool dark = isDarkTheme(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320;
        final double width = compact
            ? available
            : available.clamp(0.0, maxWidth);

        return SizedBox(
          width: width,
          child: ConstrainedBox(
            // A floor rather than an `AspectRatio` cage. The accessibility floor
            // says to check at textScaleFactor 1.3, and a rigid box with scaled
            // serif in it overflows — so the card is 1.586 at normal scale and
            // grows taller when the type demands it, which is what a real card
            // would do if it could.
            constraints: BoxConstraints(minHeight: width / ratio),
            child: DecoratedBox(
              decoration: AppDecoration.card(c, isDark: dark),
              child: Stack(
                children: <Widget>[
                  // The dog-ear, top right. Rule 2: ochre is a marker.
                  Positioned(
                    top: 0,
                    right: 0,
                    child: CornerFold(size: compact ? 14 : 34, colors: c),
                  ),
                  Padding(
                    padding: EdgeInsets.all(compact ? Gap.sm : Gap.lg),
                    child: _Contents(card: card, compact: compact, colors: c),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Contents extends StatelessWidget {
  const _Contents({
    required this.card,
    required this.compact,
    required this.colors,
  });

  final ProfileCard card;
  final bool compact;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final AppColors c = colors;
    final String name = card.name.trim();
    final String? designation = _clean(card.designation);
    final String? company = _clean(card.company);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Portrait(card: card, radius: compact ? 11 : 22),
        SizedBox(height: compact ? Gap.xs : Gap.md),

        Text(
          // A card with no name yet still has to draw as a card — this is what
          // the editor previews on the first keystroke.
          name.isEmpty ? 'Your name' : name,
          style: (compact ? AppText.rowSerif(c) : AppText.title(c)).copyWith(
            color: name.isEmpty ? c.inkFaint : c.ink,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        if (!compact) ...<Widget>[
          if (designation != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                designation,
                style: AppText.rowTitle(c).copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (company != null)
            Text(
              company,
              style: AppText.body(c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          if (card.lines.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.sm),
            // A 44px rail, which is one of the five things ochre is allowed to
            // be. It separates who you are from how to reach you, the way the
            // rule on a printed card does.
            Container(height: 2, width: 44, color: c.ochre),
            const SizedBox(height: Gap.sm),
            for (final ProfileLine line in card.lines) _Line(line: line),
          ],

          if (_clean(card.tagline) case final String tagline) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Text(
              tagline,
              // Rule 3 keeps the serif italic for the app's own voice, so this
              // is the roman serif: it is the user's sentence, not ours.
              style: AppText.rowSerif(
                c,
              ).copyWith(fontSize: 14, color: c.inkMuted, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ],
    );
  }

  static String? _clean(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}

/// One reachable line: a caps label and the value beside it.
///
/// The label is micro-caps at `inkFaint`; the **value is not**. The
/// accessibility floor reserves `inkFaint` for micro-caps metadata and forbids
/// it for body copy, and a phone number somebody has to read off this card at
/// arm's length is the payload, not metadata. So the label whispers and the
/// value is legible — which is how a printed card sets it anyway.
class _Line extends StatelessWidget {
  const _Line({required this.line});

  final ProfileLine line;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: MicroLabel(line.label, color: c.inkFaint),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              line.value,
              style: AppText.small(c).copyWith(color: c.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The portrait, or the initials that stand in for one.
///
/// [InitialsAvatar] is what a scanned contact with no photograph already wears,
/// so a card with no portrait looks like it belongs rather than looking broken.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.card, required this.radius});

  final ProfileCard card;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String? path = card.photoPath;
    if (path == null || !File(path).existsSync()) {
      return InitialsAvatar(
        initials: contactInitials(card.name.trim().isEmpty ? '?' : card.name),
        seed: card.seed,
        radius: radius,
      );
    }

    final double side = radius * 2;
    return ClipOval(
      child: Image(
        // Decoded at the size it is drawn, the way `CardFace` does it — a
        // full-resolution portrait held for a 44px disc is pure waste.
        image: sealedPhoto(
          File(path),
          cacheWidth: (side * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
        width: side,
        height: side,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (BuildContext context, Object _, StackTrace? _) =>
            InitialsAvatar(
              initials: contactInitials(
                card.name.trim().isEmpty ? '?' : card.name,
              ),
              seed: card.seed,
              radius: radius,
            ),
      ),
    );
  }
}
