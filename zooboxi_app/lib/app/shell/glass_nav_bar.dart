import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme/zb_colors.dart';
import '../theme/zooboxi_tokens.dart';

/// The floating glass tab bar.
///
/// It does not sit *under* the store, it floats **over** it: the page keeps
/// scrolling beneath a blurred pill, so the customer never loses the sense that
/// there is more shop below. That is the whole reason for the glass — a solid
/// bar cuts the page off at a hard line, a blurred one keeps the product they
/// were reading faintly present behind the controls.
///
/// Three details carry it, and all three are the reason it reads as material
/// rather than as a translucent rectangle: a real backdrop blur, a one-pixel
/// specular hairline that is bright at the top edge and gone by the bottom (how
/// light actually falls on a curved glass lip), and a soft shadow that lifts it
/// off the page.
class GlassNavBar extends ConsumerWidget {
  const GlassNavBar({super.key, required this.index, required this.onSelect});

  /// The active branch.
  final int index;
  final ValueChanged<int> onSelect;

  /// The pill's own height, before the safe-area margin under it.
  static const double barHeight = 64;

  static const double _radius = 28;
  static const double _sideMargin = 14;

  /// The floor under the pill on a phone with no home indicator.
  static const double _minBottomMargin = 10;

  /// A fixed-extent element carrying live text: the arithmetic and the painted
  /// copy have to agree, so both are clamped at the same ceiling.
  static const double _maxTextScale = 1.3;

  /// Test/behaviour handle for the sliding highlight.
  static const Key pillKey = Key('zb-nav-pill');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final dark = context.isDark;
    final cartCount = ref.watch(cartCountProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final destinations = <_Destination>[
      _Destination(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: l.navHome,
      ),
      _Destination(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: l.navCategories,
      ),
      _Destination(
        icon: Icons.shopping_bag_outlined,
        activeIcon: Icons.shopping_bag_rounded,
        label: l.navCart,
        badge: cartCount,
      ),
      _Destination(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: l.navAccount,
      ),
    ];

    // -1 at the start edge, +1 at the end edge — directional, so the pill
    // tracks tab 0 to the right in Arabic without any mirroring arithmetic.
    final slots = destinations.length;
    final pillX = slots < 2 ? 0.0 : -1 + 2 * (index / (slots - 1));

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: _sideMargin,
          end: _sideMargin,
          bottom: math.max(bottomInset, _minBottomMargin),
        ),
        child: DecoratedBox(
          // The hairline: an outer gradient showing through 1.2pt of padding.
          // Painting it as a border would give the whole edge one flat colour;
          // as a gradient it catches the light at the top lip and fades out.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.02),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0.06),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.34 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius - 1.2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: SizedBox(
                  height: barHeight,
                  child: ColoredBox(
                    color: dark
                        ? ZbTokens.graphiteRaised.withValues(alpha: 0.58)
                        : cs.surface.withValues(alpha: 0.62),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          key: pillKey,
                          alignment: AlignmentDirectional(pillX, 0),
                          duration: context.motion(Motion.select),
                          curve: Motion.emphasized,
                          child: FractionallySizedBox(
                            widthFactor: 1 / slots,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.primary
                                      .withValues(alpha: dark ? 0.22 : 0.14),
                                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < slots; i++)
                              Expanded(
                                child: _NavItem(
                                  destination: destinations[i],
                                  selected: i == index,
                                  onTap: () => onSelect(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _Destination {
  const _Destination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final color = selected ? cs.primary : cs.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      container: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        // The pill under the icon is already the selection feedback; a splash
        // on top of frosted glass reads as a smudge.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Glyph(destination: destination, selected: selected, color: color),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tab glyph, plus the cart's unit-count badge.
///
/// The badge animates in and bumps on change, which is the app's confirmation
/// that "add to cart" landed even when the customer is three screens away from
/// the cart — the one piece of the old Material bar worth carrying over intact.
class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.destination,
    required this.selected,
    required this.color,
  });

  final _Destination destination;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;
    final count = destination.badge;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(selected ? destination.activeIcon : destination.icon, size: 23, color: color),
        if (count > 0)
          PositionedDirectional(
            top: -5,
            end: -7,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(count),
              tween: Tween(begin: context.reduceMotion ? 1 : 0.6, end: 1),
              duration: Motion.select,
              curve: Motion.spring,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: zb.sale,
                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                  border: Border.all(color: cs.surface, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: context.tt.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
