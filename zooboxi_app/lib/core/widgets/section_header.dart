import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../l10n/app_localizations.dart';
import '../characters/characters.dart';
import '../characters/companion.dart';

/// How the section titles under it are dressed. The home page is a store, so
/// its titles stand on shelves — a thin kraft plank under each — and the
/// customer's animal naps on exactly one of them ([nap]). Elsewhere a title is
/// just a title.
class ShelfLook extends InheritedWidget {
  const ShelfLook({
    super.key,
    required super.child,
    this.plank = true,
    this.nap = false,
    this.endCard = false,
    this.endPeek = false,
  });

  /// Draws the plank under every [SectionHeader] below.
  final bool plank;

  /// The animal asleep on this section's plank. One per page.
  final bool nap;

  /// Horizontal rails end in a «شوف الكل» card instead of stopping dead.
  final bool endCard;

  /// …and on this rail, the animal peeks into that card. One per page.
  final bool endPeek;

  static ShelfLook? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShelfLook>();

  /// Re-dresses one section inside the page's look.
  static Widget section(BuildContext context, Widget child, {bool nap = false, bool endPeek = false}) {
    final look = maybeOf(context);
    return ShelfLook(
      plank: look?.plank ?? true,
      endCard: look?.endCard ?? false,
      nap: nap,
      endPeek: endPeek,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(ShelfLook old) =>
      plank != old.plank || nap != old.nap || endCard != old.endCard || endPeek != old.endPeek;
}

/// The shelf a section title stands on: kraft, the logo's cardboard, with the
/// thickness of its front edge drawn as a darker lip.
class _Plank extends StatelessWidget {
  const _Plank();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF4A3A2C) : const Color(0xFFE9C9A0),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: dark ? const Color(0xFF33281F) : const Color(0xFFD4A976), offset: const Offset(0, 2)),
          BoxShadow(color: const Color(0xFF5A2C2F).withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 5)),
        ],
      ),
    );
  }
}

/// Title row above a rail or section, with an optional "الكل" link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.leading,
    this.padding = const EdgeInsetsDirectional.only(start: 16, end: 16),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  /// A mark before the title — the section's own glyph, when it has one.
  final Widget? leading;

  final EdgeInsetsGeometry padding;

  /// Where the napping animal lies, measured in from the end edge: clear of
  /// the «الكل» link.
  static const double _napEnd = 72;
  static const double _napHeight = 38;

  @override
  Widget build(BuildContext context) {
    final look = ShelfLook.maybeOf(context);
    if (look == null || !look.plank) return _row(context);
    final napping = look.nap;
    final napWidth = ZbSticker.sizeOf('cat-lie', height: _napHeight).width;
    return Padding(
      padding: padding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A title never slides under the sleeper.
              _row(context, padding: EdgeInsets.zero, reserve: napping ? napWidth + 8 : 0),
              const SizedBox(height: 6),
              const _Plank(),
            ],
          ),
          if (napping)
            PositionedDirectional(
              end: onSeeAll != null ? _napEnd : 4,
              bottom: 5,
              child: Companion(
                ZbPose.lie,
                height: _napHeight,
                idle: ZbIdle.sleep,
                flip: !context.isRtl,
                delay: const Duration(milliseconds: 250),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {EdgeInsetsGeometry? padding, double reserve = 0}) {
    final l = L.of(context);
    final cs = context.cs;

    return Padding(
      padding: padding ?? this.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: reserve),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.tt.titleLarge,
                  maxLines: reserve > 0 ? 1 : null,
                  overflow: reserve > 0 ? TextOverflow.ellipsis : null,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.actionSeeAll),
                  const SizedBox(width: 2),
                  // Flips with the reading direction, so it always points
                  // "forward" rather than always right.
                  Icon(
                    context.isRtl
                        ? Icons.keyboard_arrow_left_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
