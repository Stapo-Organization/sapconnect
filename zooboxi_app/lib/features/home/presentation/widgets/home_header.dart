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
import '../../../catalog/data/catalog_models.dart';
import '../../../location/presentation/location_sheet.dart';
import '../../../search/presentation/express_search_field.dart';
import '../../../search/presentation/search_transition.dart';
import 'shelf_tabs.dart';

/// The home header: who we're delivering to, and the two things a customer
/// reaches for first — search and their saved list.
///
/// [onCanvas] renders it for the hero canvas — the deep colored panel the
/// header fuses with — so every stroke turns light and the search field stays
/// a bright, obvious well on top of the color.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, this.onCanvas = false, this.scope});

  final bool onCanvas;

  /// The active shelf, as the server resolved it: it decides the arrival time
  /// on the address line and carries the express branch's opening hours for
  /// the tab. Null (the ghost twin, a payload still loading) falls back to
  /// the saved location — same height either way, so ghost and overlay agree.
  final CatalogScope? scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final fg = onCanvas ? _canvasFg(context) : null;
    final express = scope?.shelf == 'express';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The two storefronts, above everything — the first decision on the
          // page is which shop you are in, not which product you want.
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8, bottom: 10),
            child: ShelfTabs(
              onCanvas: onCanvas,
              hours: scope?.expressHours,
              expressAvailable: scope?.expressAvailable,
              standardCutoffMinutes: scope?.standardCutoffMinutes,
            ),
          ),
          Row(
            children: [
              const _LogoSticker(),
              Gap.w10,
              // The chip stays Expanded, so the sticker's fixed width is the
              // only thing it gives up. It now carries the arrival time on
              // its own second line, so no promise badge rides beside it.
              Expanded(child: LocationChip(onCanvas: onCanvas, scope: scope)),
              // Search is a button, not a field: the strip under the address
              // is worth more as store than as an empty input, and the button
              // opens by *becoming* that input.
              //
              // The flight belongs to whoever is on screen: `branch` keeps
              // home's hero out of a search opened from another tab.
              //
              // إكسبريس is the exception — it gets the field, full width, on
              // its own row below (there is no shop window to protect, and
              // the customer arrives knowing what they want). One Hero per
              // tag per route, so the button steps aside for it.
              if (!express) SearchHeroButton(onCanvas: onCanvas, branch: 0),
              if (!express) Gap.w4,
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
          if (express) ...[
            Gap.h8,
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 8, end: 8),
              child: SearchHeroField(branch: 0),
            ),
          ],
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
