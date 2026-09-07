import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_chips.dart';
import 'hero_live_copy.dart';
import 'hero_slide_layouts.dart';

// The hero slides the server composes when there is no bought banner to show.
// It ships copy plus a handful of product photos and lets the app draw them,
// so a "delivered in two hours" slide is the same object in both languages,
// both themes and at any text size — and costs a designer nothing.
//
// The composition rules are the ones ad designers use: copy block vertically
// centered on the reading side, artwork anchored to the far bottom corner and
// deliberately cropped by the slide edge (a full object floating in space
// reads as clip-art; a cropped one reads as a scene), and one quiet layer of
// decoration for depth.

/// Paint recipe for a server-composed slide. One per theme, so "express" looks
/// like the express promise everywhere it appears rather than like a generic
/// gradient with different words on it.
@immutable
class AutoSlideSkin {
  const AutoSlideSkin({
    required this.gradient,
    required this.fg,
    required this.muted,
    required this.accent,
  });

  final LinearGradient gradient;
  final Color fg;
  final Color muted;

  /// The deep theme color used for strokes on *white* — the badge text, the
  /// bolt inside its disc.
  final Color accent;

  static AutoSlideSkin of(BuildContext context, String? theme) {
    final zb = context.zb;
    final dark = context.isDark;
    final onDark = dark ? ZbTokens.inkDark : Colors.white;

    /// Deep field → the same field, one step deeper. Every canvas in this
    /// carousel is dark by construction: the header (white location, white
    /// search, white tabs) floats on top of whichever slide is showing.
    AutoSlideSkin skin(Color from, Color to, Color accent) => AutoSlideSkin(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: dark ? [ZbTokens.graphiteHigh, from] : [from, to],
          ),
          fg: onDark,
          muted: onDark.withValues(alpha: 0.82),
          accent: accent,
        );

    return switch (theme) {
      // ── إكسبريس: the branch, in teal. Bright, electric, close by. ──
      // The clock slide is the storefront's own promise, so it wears the
      // deepest teal — the colour the promise chip has always used.
      'express' || 'express_clock' => skin(ZbTokens.tealDeep, ZbTokens.tealDark, ZbTokens.tealDeep),
      'express_top' => skin(ZbTokens.tealDark, ZbTokens.teal, ZbTokens.tealDeep),
      'express_new' => skin(ZbTokens.teal, ZbTokens.tealDark, ZbTokens.tealDeep),
      // Closing time is an evening: the teal cools into the night.
      'express_hours' => skin(ZbTokens.tealDeep, ZbTokens.graphiteHighest, ZbTokens.tealDeep),

      // ── زوبكسي: the main store, in the warm half of the palette. Nothing
      //    here is teal, so the two sliders never read as the same shop. ──
      // The cutoff is a deadline, not a discount: deep green-ink, amber pill.
      'cutoff' => skin(ZbTokens.ink, ZbTokens.graphiteHighest, ZbTokens.orange),
      'bundles' => skin(ZbTokens.coral, ZbTokens.orange, ZbTokens.coralDark),
      'clearance' => skin(ZbTokens.coralDark, ZbTokens.coral, ZbTokens.coralDark),
      'newin' => skin(ZbTokens.graphite, ZbTokens.orange, ZbTokens.orange),

      // A brand slide belongs to the brand: a deep neutral stage, the logo on
      // its own white tile carrying the identity — the same reason the brand
      // strip refuses to tint itself.
      'brand' => AutoSlideSkin(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [ZbTokens.graphiteHighest, ZbTokens.graphiteHigh],
          ),
          fg: ZbTokens.inkDark,
          muted: ZbTokens.inkDark.withValues(alpha: 0.75),
          accent: ZbTokens.graphiteHighest,
        ),
      _ => AutoSlideSkin(
          gradient: zb.brandGradient,
          fg: onDark,
          muted: onDark.withValues(alpha: 0.85),
          accent: ZbTokens.tealDeep,
        ),
    };
  }
}

class HeroAutoCard extends StatelessWidget {
  const HeroAutoCard({
    super.key,
    required this.slide,
    this.flush = false,
    this.scope,
    this.now,
  });

  final HeroSlide slide;

  /// The shelf's own promise data — opening hours, the cut-off — which is what
  /// turns «توصيل خلال ساعتين» into «يوصلك الساعة 10:30 م».
  final CatalogScope? scope;

  /// Pins the clock. Only the design golden passes it: a sheet whose slides
  /// print the wall clock is a golden that fails by lunchtime.
  final DateTime? now;

  /// True when the slide sits on the hero canvas, which already painted this
  /// skin's gradient from the status bar down — paint everything but it.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final skin = AutoSlideSkin.of(context, slide.theme);
    final live = HeroLive.of(
      slide.theme,
      scope,
      L.of(context),
      Localizations.localeOf(context).languageCode,
      now: now,
    );
    final title = live.title ?? slide.title;
    final badge = live.badge ?? slide.badge;
    final express = (slide.theme ?? '').startsWith('express');

    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;

      // The slide band is 1/3.2 of the screen — about 123pt on a phone, 183
      // at the text-scale cap — so a composition either fits that or it is
      // cut. `compact` is what the classic layout composes itself down by;
      // the per-theme layouts are drawn for the short band from the start.
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final compact = h < 210 * textScale;

      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (!flush) DecoratedBox(decoration: BoxDecoration(gradient: skin.gradient)),
          // The two storefronts are not the same shop, so they are not the
          // same ground either: زوبكسي sits in a calm ring, إكسبريس in the
          // streaks of something moving.
          if (express)
            _SpeedLayer(fg: skin.fg, slideHeight: h)
          else
            _DecorLayer(fg: skin.fg, slideHeight: h),

          // …and on that ground, the composition this subject deserves.
          HeroSlideBody(
            slide: slide,
            skin: skin,
            live: live,
            title: title,
            badge: badge,
            height: h,
            compact: compact,
            now: now,
          ),
        ],
      );
    });
  }
}

/// The anatomy every slide used to have: a badge, a headline, a line under it
/// and a chip, with the artwork cropped into the far corner. Kept for the
/// themes that have no composition of their own — an older server's `express`
/// and `bestsellers`, and anything a newer one invents.
class ClassicSlideBody extends StatelessWidget {
  const ClassicSlideBody({
    super.key,
    required this.slide,
    required this.skin,
    required this.live,
    required this.title,
    required this.badge,
    required this.height,
    required this.compact,
    this.now,
  });

  final HeroSlide slide;
  final AutoSlideSkin skin;
  final HeroLive live;
  final String? title;
  final String? badge;
  final double height;
  final bool compact;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final h = height;
    final images = slide.productImages.take(3).toList();
    final logo = slide.theme == 'brand' ? slide.brand?.logo : null;
    final ranked = slide.theme == 'bestsellers';
    final pill = live.hint != null || live.deadlineAt != null;

    final Widget? art;
    if (logo != null) {
      art = _BrandTile(logo: logo);
    } else if (images.isNotEmpty) {
      art = _ProductCascade(images: images, ranked: ranked, slideHeight: h);
    } else if ((slide.theme ?? '').startsWith('express')) {
      art = _ExpressMotif(skin: skin, clock: slide.theme == 'express_hours');
    } else {
      art = null;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (art != null)
            PositionedDirectional(
              end: logo != null ? 16 : -10,
              bottom: logo != null ? (h - 116) / 2 : -12,
              child: art,
            ),
          PositionedDirectional(
            start: 20,
            top: 0,
            bottom: 6,
            width: w * (art == null ? 0.78 : 0.55),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((badge ?? '').isNotEmpty) ...[
                  _SlideBadge(label: badge!, accent: skin.accent),
                  Gap.h8,
                ],
                if ((title ?? '').isNotEmpty)
                  Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.headlineSmall?.copyWith(
                      color: skin.fg,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                if ((slide.subtitle ?? '').isNotEmpty) ...[
                  Gap.h4,
                  Flexible(
                    child: Text(
                      slide.subtitle!,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodyMedium?.copyWith(
                        color: skin.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                if (pill) ...[
                  Gap.h8,
                  HeroLivePill(live: live, fg: skin.fg, accent: skin.accent, now: now),
                ],
                if ((!pill || !compact) && (slide.ctaLabel ?? '').isNotEmpty) ...[
                  compact ? Gap.h8 : Gap.h16,
                  CampaignCta(label: slide.ctaLabel!),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// The white pill with the number that earns the slide its place —
/// "خصم حتى 45%" in the theme's own deep color.
class _SlideBadge extends StatelessWidget {
  const _SlideBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: context.tt.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// One quiet layer of depth behind everything: a big off-canvas ring and a
/// few bright specks. Enough that the color field isn't flat, never enough
/// to compete with the copy.
class _DecorLayer extends StatelessWidget {
  const _DecorLayer({required this.fg, required this.slideHeight});

  final Color fg;
  final double slideHeight;

  @override
  Widget build(BuildContext context) {
    final ring = slideHeight * 1.35;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          end: -ring * 0.32,
          top: -ring * 0.38,
          child: Container(
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: fg.withValues(alpha: 0.08), width: 1.6),
            ),
          ),
        ),
        for (final (dx, dy, size) in const [(0.46, 0.18, 5.0), (0.54, 0.72, 3.5), (0.40, 0.50, 4.0)])
          PositionedDirectional(
            start: MediaQuery.sizeOf(context).width * dx,
            top: slideHeight * dy,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withValues(alpha: 0.35),
              ),
            ),
          ),
      ],
    );
  }
}

/// إكسبريس's ground: three long diagonals leaning the way the reading runs,
/// as if the panel itself were moving. Quiet enough to sit under copy, and
/// nothing like the زوبكسي ring — which is the whole point.
class _SpeedLayer extends StatelessWidget {
  const _SpeedLayer({required this.fg, required this.slideHeight});

  final Color fg;
  final double slideHeight;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SpeedPainter(
          fg,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpeedPainter extends CustomPainter {
  const _SpeedPainter(this.fg, {required this.rtl});

  final Color fg;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    // Three streaks, thinning as they trail off — the same gesture as the
    // bolt, drawn at panel scale.
    const bands = [(0.16, 0.40, 4.0), (0.46, 0.30, 2.6), (0.76, 0.34, 1.8)];
    for (final (top, length, width) in bands) {
      final paint = Paint()
        ..color = fg.withValues(alpha: 0.18)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      final y = size.height * top;
      final dx = size.width * length;
      final start = Offset(rtl ? size.width : 0, y);
      final end = Offset(rtl ? size.width - dx : dx, y + size.height * 0.16);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(_SpeedPainter old) => old.fg != fg || old.rtl != rtl;
}

/// The express promise as a mark: pulse rings around a bright disc with the
/// same bolt the promise chip wears — the visual it already trained.
class _ExpressMotif extends StatelessWidget {
  const _ExpressMotif({required this.skin, this.clock = false});

  final AutoSlideSkin skin;

  /// The closing-time slide is about the hour, not the speed.
  final bool clock;

  @override
  Widget build(BuildContext context) {
    const outer = 196.0;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (size, alpha, width) in const [(196.0, 0.10, 1.5), (150.0, 0.16, 1.5)])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: skin.fg.withValues(alpha: alpha), width: width),
              ),
            ),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              clock ? Icons.schedule_rounded : Icons.bolt_rounded,
              size: 52,
              color: skin.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// The brand's mark on its own white tile: brand logos are drawn for light
/// paper, and the stage behind them is deep.
class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.logo});

  final String logo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 116,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ZbImage(url: logo, backgroundColor: Colors.transparent),
    );
  }
}

/// Product photos as a diagonal cascade of ringed circles falling into the
/// slide's corner — biggest nearest the customer's thumb, each one white-ringed
/// and shadowed so it sits *on* the color instead of dissolving into it.
/// [ranked] pins 1·2·3 medals on them, which is what "best sellers" means.
class _ProductCascade extends StatelessWidget {
  const _ProductCascade({
    required this.images,
    required this.ranked,
    required this.slideHeight,
  });

  final List<String> images;
  final bool ranked;
  final double slideHeight;

  @override
  Widget build(BuildContext context) {
    final big = (slideHeight * 0.56).clamp(88.0, 124.0);
    final sizes = [big, big * 0.82, big * 0.68];
    // (end, bottom) anchors: a diagonal from the corner up toward the copy.
    final anchors = [
      (0.0, 0.0),
      (big * 0.78, big * 0.52),
      (big * 0.22, big * 1.02),
    ];

    final count = images.length.clamp(0, 3);
    final width = big + (count > 1 ? anchors[1].$1 + sizes[1] * 0.4 : 0);
    final height = big + (count > 2 ? anchors[2].$2 : (count > 1 ? anchors[1].$2 : 0));

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = count - 1; i >= 0; i--)
            PositionedDirectional(
              end: anchors[i].$1,
              bottom: anchors[i].$2,
              child: _RingedProduct(
                url: images[i],
                size: sizes[i],
                rank: ranked ? i + 1 : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RingedProduct extends StatelessWidget {
  const _RingedProduct({required this.url, required this.size, this.rank});

  final String url;
  final double size;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: ZbImage(url: url, fit: BoxFit.cover, backgroundColor: Colors.white),
          ),
        ),
        if (rank != null)
          PositionedDirectional(
            top: -2,
            start: -2,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ZbTokens.amber,
                boxShadow: [
                  BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                '$rank',
                style: context.tt.labelSmall?.copyWith(
                  color: ZbTokens.ink,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
