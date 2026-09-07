/// The design system's shared parts.
///
/// Phase 1 of `design/DESIGN.md` §3. Nothing here knows anything about cards,
/// contacts or search — these are the pieces every screen is assembled from,
/// and putting them in one place is what stops the next screen quietly
/// reinventing a slightly different pill.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Whether the surrounding theme is the dark one.
///
/// Several decorations need this, and reading it from `Theme.of` rather than
/// from a widget flag means a nested `Theme` — the capture screen forces the
/// dark one — is respected without anything being passed down.
bool isDarkTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// The recessed surface. The app's signature.
///
/// Rule 1 of the design: inputs are *pockets*, never outlines. Anything the
/// user can type into or edit in place goes through this, so there is exactly
/// one description of what a hole in the paper looks like.
class Pocket extends StatelessWidget {
  const Pocket({
    required this.child,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: Gap.md),
    this.trailing,
    super.key,
  });

  final Widget child;

  /// Null lets the content size it — a multi-line note pocket grows.
  final double? height;

  final EdgeInsetsGeometry padding;

  /// Sits at the right-hand end, inside the recess: a clear button, a unit, a
  /// confidence dot.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Widget? trail = trailing;

    return Container(
      height: height,
      padding: padding,
      decoration: AppDecoration.pocket(c, isDark: isDarkTheme(context)),
      child: Row(
        children: <Widget>[
          Expanded(child: child),
          if (trail != null) ...<Widget>[const SizedBox(width: Gap.sm), trail],
        ],
      ),
    );
  }
}

/// Press feedback without a ripple.
///
/// Rule 5: no splashes. A Material ink ripple is the single loudest tell that
/// an app is stock, and it looks wrong spreading across something that is
/// meant to be a piece of paper. This presses the whole object instead —
/// scale down slightly, fade slightly — which is what a physical card does.
///
/// Replaces every `InkWell` and `GestureDetector` on a tappable surface.
class PressFade extends StatefulWidget {
  const PressFade({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.985,
    this.semanticLabel,
    this.hitPadding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Deliberately shallow. A card that shrinks visibly reads as a button.
  final double scale;

  final String? semanticLabel;

  /// Invisible area that still counts as a press.
  ///
  /// Inside the gesture detector and outside the artwork, so a control can be
  /// drawn at the size the frames give it and still meet the 52px floor. The
  /// alternative — inflating the art to 52 — changes a design decision to
  /// satisfy a number nobody can see.
  final EdgeInsets hitPadding;

  @override
  State<PressFade> createState() => _PressFadeState();
}

class _PressFadeState extends State<PressFade> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null || widget.onLongPress != null;

    return Semantics(
      label: widget.semanticLabel,
      button: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: Padding(
          padding: widget.hitPadding,
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: AppMotion.quick,
            curve: AppMotion.curve,
            child: AnimatedOpacity(
              opacity: _down ? 0.88 : 1,
              duration: AppMotion.quick,
              curve: AppMotion.curve,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared geometry and content for the three pills.
///
/// Three widgets rather than one with a `variant` enum, as the design asks —
/// they carry different shadows, and a variant flag is how those get muddled
/// into one "close enough" shadow.
class _PillBody extends StatelessWidget {
  const _PillBody({
    required this.label,
    required this.height,
    required this.foreground,
    this.icon,
  });

  final String label;
  final double height;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final IconData? glyph = icon;

    return SizedBox(
      height: height,
      child: Padding(
        // The frames give every pill 18px of horizontal breathing room. It is
        // invisible on a full-width pill, where the content is centred in far
        // more space than it needs, and load-bearing on one that hugs its
        // label: the corner radius is half the height, so without it the
        // rounded ends cut into the first and last letters.
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          // Min so an intrinsically sized pill hugs its label. Under the tight
          // constraints a full-width pill gets, this has no effect.
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              Icon(glyph, size: 19, color: foreground),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.button(c, on: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The primary action in light mode: an ink fill that casts its own shadow.
class InkPill extends StatelessWidget {
  const InkPill({
    required this.label,
    this.icon,
    this.onTap,
    this.height = 56,
    this.hitPadding = EdgeInsets.zero,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  /// See [PressFade.hitPadding].
  final EdgeInsets hitPadding;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    // Rule 2 inverted for dark: ink on ink has no contrast, so the primary
    // action takes the ochre there instead.
    final bool dark = isDarkTheme(context);

    return PressFade(
      onTap: onTap,
      scale: 0.97,
      hitPadding: hitPadding,
      child: DecoratedBox(
        decoration: dark
            ? AppDecoration.ochrePill(c, height)
            : AppDecoration.inkPill(c, height),
        child: _PillBody(
          label: label,
          height: height,
          icon: icon,
          foreground: dark ? c.onOchre : c.onInk,
        ),
      ),
    );
  }
}

/// An ochre fill. Reserved — see rule 2. In light mode this is *not* a general
/// button; it is for the shutter and for a single destructive-adjacent
/// confirmation, and everything else uses [InkPill] or [OutlinePill].
class OchrePill extends StatelessWidget {
  const OchrePill({
    required this.label,
    this.icon,
    this.onTap,
    this.height = 56,
    this.hitPadding = EdgeInsets.zero,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  /// See [PressFade.hitPadding].
  final EdgeInsets hitPadding;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return PressFade(
      onTap: onTap,
      scale: 0.97,
      hitPadding: hitPadding,
      child: DecoratedBox(
        decoration: AppDecoration.ochrePill(c, height),
        child: _PillBody(
          label: label,
          height: height,
          icon: icon,
          foreground: c.onOchre,
        ),
      ),
    );
  }
}

/// The secondary action: a hairline outline on the page, no fill.
class OutlinePill extends StatelessWidget {
  const OutlinePill({
    required this.label,
    this.icon,
    this.onTap,
    this.height = 56,
    this.hitPadding = EdgeInsets.zero,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  /// See [PressFade.hitPadding].
  final EdgeInsets hitPadding;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return PressFade(
      onTap: onTap,
      scale: 0.97,
      hitPadding: hitPadding,
      child: DecoratedBox(
        decoration: AppDecoration.outlinePill(c, height),
        child: _PillBody(
          label: label,
          height: height,
          icon: icon,
          foreground: c.ink,
        ),
      ),
    );
  }
}

/// Micro-caps text. Trivial, and centralised so the tracking is never retyped.
///
/// The wide tracking in [AppText.micro] is load-bearing: at 10.5px without it
/// this size is unreadable mud.
class MicroLabel extends StatelessWidget {
  const MicroLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Text(
      text.toUpperCase(),
      style: AppText.micro(c).copyWith(color: color),
    );
  }
}

/// The caps line on a wallet tile — "FARMGATE · 3D".
///
/// Separate from [MicroLabel] because the design has two micro sizes and they
/// do different jobs: a section header labels a region of the screen, this
/// labels one row. Set at the header's size and tracking it competes with the
/// row's own title.
class MetaLabel extends StatelessWidget {
  const MetaLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.meta(c).copyWith(color: color),
    );
  }
}

/// A micro-caps label, a hairline that takes the remaining width, and an
/// optional serif numeral on the right.
///
/// Used on nine screens. The numeral is serif because standalone numbers are
/// the one place the display face appears outside a title.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {this.count, this.trailing, super.key});

  final String label;

  /// Rendered as a serif numeral at the right-hand end.
  final int? count;

  /// Anything else for the right-hand end. Ignored when [count] is set.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final int? n = count;
    final Widget? trail = trailing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          MicroLabel(label),
          const SizedBox(width: Gap.sm + 2),
          Expanded(child: Container(height: 1, color: c.hairline)),
          if (n != null) ...<Widget>[
            const SizedBox(width: Gap.sm + 2),
            Text(
              '$n',
              style: AppText.rowSerif(
                c,
              ).copyWith(fontSize: 19, color: c.inkMuted),
            ),
          ] else if (trail != null) ...<Widget>[
            const SizedBox(width: Gap.sm + 2),
            trail,
          ],
        ],
      ),
    );
  }
}

/// The header every screen below home shares: a way back, a caps title, and
/// optional actions.
///
/// Not an `AppBar`. Material's brings its own height, its own title style and
/// a scroll-under tint, none of which match the frames — where the title is a
/// micro-caps line, not a heading.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final VoidCallback? back = onBack;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.md, Gap.sm),
      child: Row(
        children: <Widget>[
          if (back != null)
            PressFade(
              onTap: back,
              scale: 0.9,
              semanticLabel: 'Back',
              child: SizedBox(
                width: kMinTarget,
                height: kMinTarget,
                child: Icon(Icons.chevron_left, size: 26, color: c.ink),
              ),
            )
          else
            const SizedBox(width: Gap.md),
          Expanded(child: MicroLabel(title)),
          ...actions,
        ],
      ),
    );
  }
}

/// A round icon button: 36px of art inside a 52px target.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return PressFade(
      onTap: onTap,
      scale: 0.92,
      semanticLabel: tooltip,
      child: SizedBox(
        width: kMinTarget,
        height: kMinTarget,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tint ?? c.hairline),
            ),
            child: Icon(icon, size: 18, color: tint ?? c.ink),
          ),
        ),
      ),
    );
  }
}

/// Initials on a tinted disc.
///
/// The tint comes from a stable hash of the identity's id, never from a
/// counter or a random — the same person has to keep the same colour between
/// builds, or the colour stops being a recognition aid and becomes noise.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.initials,
    required this.seed,
    this.radius = 13,
    super.key,
  });

  final String initials;

  /// The identity's database id.
  final int seed;

  final double radius;

  /// Muted enough to sit under ink text at 4.5:1.
  static const List<Color> _tints = <Color>[
    Color(0xFFB9A88A),
    Color(0xFF9FAE86),
    Color(0xFFC3A57F),
    Color(0xFFA8A395),
    Color(0xFFBFA096),
    Color(0xFF97A7A6),
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Color tint = _tints[seed.abs() % _tints.length];

    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      child: Text(
        initials,
        style: AppText.meta(c).copyWith(
          fontSize: radius * 0.72,
          letterSpacing: 0.4,
          color: const Color(0xFF241E14),
        ),
      ),
    );
  }
}

/// The storefront glyph that marks an organization row.
///
/// Companies get a shape rather than initials, which is what keeps the two row
/// types apart at a glance in a single mixed list.
class OrgGlyph extends StatelessWidget {
  const OrgGlyph({this.radius = 13, super.key});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.pocket,
        shape: BoxShape.circle,
        border: Border.all(color: c.hairline),
      ),
      child: Icon(Icons.storefront_outlined, size: radius, color: c.inkMuted),
    );
  }
}

/// A 46×28 switch.
///
/// Hand-built because `SwitchListTile`'s Material thumb and ripple are, per
/// the design notes, the single loudest giveaway in a bespoke app.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final ValueChanged<bool>? change = onChanged;

    return PressFade(
      onTap: change == null ? null : () => change(!value),
      scale: 0.94,
      semanticLabel: value ? 'On' : 'Off',
      child: SizedBox(
        width: kMinTarget,
        height: kMinTarget,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.curve,
            width: 46,
            height: 28,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: value
                ? BoxDecoration(
                    color: c.ink,
                    borderRadius: BorderRadius.circular(14),
                  )
                : AppDecoration.pocket(
                    c,
                    isDark: isDarkTheme(context),
                  ).copyWith(borderRadius: BorderRadius.circular(14)),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? c.ochre : c.card,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row in a grouped settings block.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.label,
    this.description,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String label;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final String? note = description;
    final Widget? trail = trailing;

    return PressFade(
      onTap: onTap,
      semanticLabel: label,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    label,
                    style: AppText.rowTitle(c).copyWith(fontSize: 15),
                  ),
                  if (note != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(note, style: AppText.small(c)),
                  ],
                ],
              ),
            ),
            if (trail != null) ...<Widget>[
              const SizedBox(width: Gap.sm),
              trail,
            ],
          ],
        ),
      ),
    );
  }
}

/// A grouped block of rows on paper, hairline-ruled between them.
class SettingGroup extends StatelessWidget {
  const SettingGroup({required this.label, required this.children, super.key});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(label),
        const SizedBox(height: Gap.sm),
        DecoratedBox(
          decoration: AppDecoration.card(
            c,
            isDark: isDarkTheme(context),
            lifted: false,
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: Gap.md),
                    child: Container(height: 1, color: c.hairlineOnCard),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A chip you pick, in the app's own clothes.
///
/// Replaces `ChoiceChip` and `FilterChip`, which arrive with a Material
/// outline, a ripple and a check-mark animation that belong to a different
/// app. Selection here is an ink fill — the same ink the primary button uses —
/// against a plain hairline when it is not chosen.
class SelectChip extends StatelessWidget {
  const SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dim = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Quieter text, for an option that is offered but already spoken for.
  final bool dim;

  static const double height = 38;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool dark = isDarkTheme(context);
    final Color fill = dark ? c.ochre : c.ink;
    final Color on = dark ? c.onOchre : c.onInk;

    return PressFade(
      onTap: onTap,
      scale: 0.95,
      // The chips are 38 tall so a row of seven fits; the press target is
      // grown to the floor without moving the artwork.
      hitPadding: const EdgeInsets.symmetric(
        vertical: (kMinTarget - height) / 2,
      ),
      semanticLabel: label,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? fill : Colors.transparent,
          borderRadius: AppRadius.chipR,
          border: selected ? null : Border.all(color: c.hairline),
        ),
        // A `Row` that hugs, not `alignment: Alignment.center`. A Container
        // given an alignment wraps its child in an `Align`, which fills the
        // constraints it is handed — so inside a `Wrap` every chip claimed the
        // full width and seven of them came down the screen one per line. The
        // Row centres vertically by default and shrink-wraps horizontally,
        // which is what a chip wants.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.button(
                  c,
                  on: selected
                      ? on
                      : dim
                      ? c.inkFaint
                      : c.ink,
                ).copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inline text action: "Add back", "Restore", "Delete for good".
///
/// Sentence case, not micro-caps. The frames reserve caps for labels and
/// metadata — a section header, a field name, a provenance chip — and set every
/// *action* in sentence case, because caps read as a heading for the thing
/// below rather than as something to press.
///
/// Replaces `TextButton`, which brings a Material ripple and its own padding.
class TextAction extends StatelessWidget {
  const TextAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Defaults to `ochreInk`, the only ochre allowed to carry text on paper.
  final Color? tint;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Color colour = enabled ? (tint ?? c.ochreInk) : c.inkFaint;
    final IconData? glyph = icon;

    return PressFade(
      onTap: enabled ? onTap : null,
      scale: 0.95,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Gap.sm + 4,
          horizontal: Gap.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              Icon(glyph, size: 17, color: colour),
              const SizedBox(width: 7),
            ],
            // Flexible so a long action — "Add something it missed" — gives
            // way on a narrow phone instead of running off the edge. `maxLines`
            // alone cannot ellipsise text that was never constrained.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.button(c, on: colour).copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
