import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/icons/cart_box_icon.dart';
import '../../core/icons/zb_icons.dart';
import '../../core/motion/anchors.dart';
import '../../core/motion/motion.dart';
import '../../core/widgets/sparkles.dart';
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
      _Destination(kind: ZbIconKind.home, label: l.navHome),
      _Destination(kind: ZbIconKind.categories, label: l.navCategories),
      _Destination(kind: ZbIconKind.cart, label: l.navCart, badge: cartCount),
      _Destination(kind: ZbIconKind.account, label: l.navAccount),
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
          // Depth stays ours; the surface itself is the liquid-glass shader —
          // real refraction and edge lensing instead of a flat blur, with a
          // tint just strong enough to keep the glyphs legible over product
          // photography. The old hand-built hairline is gone: the shader
          // draws its own specular rim, and two rims read as a smudge.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.34 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: GlassContainer(
            shape: const LiquidRoundedSuperellipse(borderRadius: _radius),
            // Standard, not premium: this surface floats over every scrolling
            // list in the app, exactly the case the package's own guidance
            // reserves the heavier tier against.
            quality: GlassQuality.standard,
            clipBehavior: Clip.antiAlias,
            settings: LiquidGlassSettings(
              // Owner-tuned: barely-there tint — the store should show through
              // the glass, the refraction carries the legibility.
              glassColor: dark
                  ? ZbTokens.graphiteRaised.withValues(alpha: 0.24)
                  : cs.surface.withValues(alpha: 0.20),
              blur: 11,
            ),
            child: SizedBox(
              height: barHeight,
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
    );
  }
}

@immutable
class _Destination {
  const _Destination({
    required this.kind,
    required this.label,
    this.badge = 0,
  });

  final ZbIconKind kind;
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
/// Selection is not a swap between two icons: the *same* painted glyph fills
/// in, and squashes as it does, so the tab reads as coming to life under the
/// finger. The badge animates in and bumps on change, which is the app's
/// confirmation that "add to cart" landed even when the customer is three
/// screens away from the cart.
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
        _TabGlyph(kind: destination.kind, selected: selected, quiet: color),
        if (count > 0)
          PositionedDirectional(
            top: -5,
            end: -7,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(count),
              // A bump, not a grow-in: the badge is already there, it just
              // got bigger by one.
              tween: Tween(begin: context.reduceMotion ? 1 : 1.35, end: 1),
              duration: Motion.select,
              curve: Motion.decelerate,
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

/// One painted tab icon and its selection move.
class _TabGlyph extends StatefulWidget {
  const _TabGlyph({
    required this.kind,
    required this.selected,
    required this.quiet,
  });

  final ZbIconKind kind;
  final bool selected;

  /// The unselected outline colour — the glyph walks from this to the logo's
  /// own ink as it fills.
  final Color quiet;

  static const double size = 23;

  @override
  State<_TabGlyph> createState() => _TabGlyphState();
}

class _TabGlyphState extends State<_TabGlyph>
    with SingleTickerProviderStateMixin {
  static const Duration _in = Duration(milliseconds: 420);
  static const Duration _out = Duration(milliseconds: 240);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _in,
    reverseDuration: _out,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(_TabGlyph old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected) return;
    _c.duration = context.motion(_in);
    _c.reverseDuration = context.motion(_out);
    if (widget.selected) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final fill = _c.value;
        final ink = Color.lerp(widget.quiet, resolveZbInk(context), fill)!;
        final glyph = widget.kind == ZbIconKind.cart
            ? CartBoxIcon(
                key: cartTabAnchorKey,
                size: _TabGlyph.size,
                fill: fill,
                ink: ink,
              )
            : ZbIcon(widget.kind, size: _TabGlyph.size, fill: fill, ink: ink);

        // Squash only on the way in. Coming back out is a fade, not a move —
        // two tabs bouncing at once would read as a glitch.
        final squashing = _c.status == AnimationStatus.forward;
        final e = squashing ? math.sin(math.pi * fill) : 0.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1 + 0.18 * e, 1 - 0.18 * e, 1),
              child: glyph,
            ),
            if (squashing)
              const Positioned(
                left: -9,
                top: -8,
                width: 41,
                height: 39,
                child: SparkleField(sparkles: _selectBurst),
              ),
          ],
        );
      },
    );
  }
}

/// Three sparkles around the tab that just woke up. Logical `dx`, so the burst
/// mirrors itself in Arabic.
const List<SparkleSpec> _selectBurst = [
  SparkleSpec(dx: 0.05, dy: 0.16, size: 8, color: ZbTokens.sparkAmber),
  SparkleSpec(
    dx: 0.94,
    dy: 0.26,
    size: 6,
    color: ZbTokens.logoTeal,
    delay: Duration(milliseconds: 60),
    rotation: 0.4,
  ),
  SparkleSpec(
    dx: 0.78,
    dy: 0.93,
    size: 9,
    color: ZbTokens.logoCoral,
    delay: Duration(milliseconds: 110),
  ),
];
