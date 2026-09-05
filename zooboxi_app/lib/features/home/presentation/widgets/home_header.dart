import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:math' as math;

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../location/presentation/location_sheet.dart';

/// The home header: who we're delivering to, and the two things a customer
/// reaches for first — search and their saved list.
///
/// [onCanvas] renders it for the hero canvas — the deep colored panel the
/// header fuses with — so every stroke turns light and the search field stays
/// a bright, obvious well on top of the color.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, this.onCanvas = false});

  final bool onCanvas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final fg = onCanvas ? _canvasFg(context) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LogoSticker(),
              Gap.w10,
              // The chip stays Expanded, so the sticker's fixed width is the
              // only thing it gives up.
              Expanded(child: LocationChip(onCanvas: onCanvas)),
              // The delivery promise rides the top row, shoulder to shoulder
              // with the wishlist — owner's call: no greeting line, the
              // header is address, promise, heart, search.
              PromiseLine(onCanvas: onCanvas),
              IconButton(
                onPressed: () {
                  Haptics.light();
                  context.push('/wishlist');
                },
                icon: ZbIcon(
                  ZbIconKind.heart,
                  size: 23,
                  ink: fg ?? context.cs.onSurfaceVariant,
                ),
                tooltip: l.wishlistTitle,
              ),
            ],
          ),
          Gap.h8,
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
            child: _SearchBar(
              onCanvas: onCanvas,
              onTap: () => context.push('/search'),
              onScan: () => context.push('/scan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The logo, sitting on the header as a small printed sticker.
///
/// It navigates nowhere — it is decor. But it *answers*: a tap makes it
/// wiggle and throw two sparkles, which is the cheapest possible piece of
/// delight and the one place in the app where the brand is allowed to be
/// purely playful.
class _LogoSticker extends StatefulWidget {
  const _LogoSticker();

  @override
  State<_LogoSticker> createState() => _LogoStickerState();
}

class _LogoStickerState extends State<_LogoSticker>
    with SingleTickerProviderStateMixin {
  /// Three full wiggles, ±6°, then still.
  static const double _sweep = 6 * math.pi / 180;
  static const int _cycles = 3;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _wiggle() {
    Haptics.selection();
    if (context.reduceMotion) return;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _wiggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final angle = t == 0 || t == 1
              ? 0.0
              : math.sin(_cycles * 2 * math.pi * t) * _sweep * (1 - 0.35 * t);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(angle: angle, child: child),
              if (_c.isAnimating)
                const Positioned(
                  left: -10,
                  top: -9,
                  width: 62,
                  height: 54,
                  child: SparkleField(sparkles: _stickerBurst),
                ),
            ],
          );
        },
        child: const _StickerFace(),
      ),
    );
  }
}

const List<SparkleSpec> _stickerBurst = [
  SparkleSpec(dx: 0.06, dy: 0.12, size: 9, color: ZbTokens.sparkAmber),
  SparkleSpec(
    dx: 0.93,
    dy: 0.78,
    size: 7,
    color: ZbTokens.logoTeal,
    delay: Duration(milliseconds: 80),
    rotation: 0.4,
  ),
];

class _StickerFace extends StatelessWidget {
  const _StickerFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.92) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // The sticker is height-driven; the aspect gives the Row a finite width
      // instead of the asset's intrinsic 1400px.
      child: const AspectRatio(
        aspectRatio: 1400 / 1204,
        child: Image(
          image: AssetImage('assets/brand/logo_full.png'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Foreground for header strokes sitting on the hero canvas — always light,
/// because every canvas color is deep by design.
Color _canvasFg(BuildContext context) =>
    context.isDark ? ZbTokens.inkDark : Colors.white;

/// A tap target that *looks* like a field but pushes the search screen — so
/// the keyboard and the suggestion list belong to one screen instead of
/// half-opening over the home feed.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap, required this.onScan, this.onCanvas = false});

  final VoidCallback onTap;
  final VoidCallback onScan;
  final bool onCanvas;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    // On the canvas the field is the one bright object — a white well in
    // light theme, the raised surface in dark. Off-canvas it stays subtle.
    final fill = onCanvas
        ? (context.isDark ? cs.surfaceContainerHigh : Colors.white)
        : cs.surfaceContainerHigh;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      clipBehavior: Clip.antiAlias,
      elevation: onCanvas ? 1.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: InkWell(
        onTap: () {
          Haptics.light();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 2, bottom: 2),
          child: Row(
            children: [
              ZbIcon(ZbIconKind.search, size: 20, ink: cs.onSurfaceVariant),
              Gap.w12,
              Expanded(
                child: Text(
                  l.searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              IconButton(
                onPressed: () {
                  Haptics.light();
                  onScan();
                },
                icon: ZbIcon(ZbIconKind.scan, size: 20, ink: cs.primary),
                tooltip: l.searchScan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
