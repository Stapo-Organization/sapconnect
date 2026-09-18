import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/delivery/delivery_eta.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'hero_live_copy.dart';

// «الحيّ الأبيض» — the زوبكسي slide the owner picked on 2026-09-18.
//
// The old slider painted every subject on a deep three-stop field and crammed
// a badge, a headline, a line, a pill and three product photos into a band
// 123pt tall. It read as busy, and busy reads as cheap. This is the opposite
// discipline, the one Amazon's home runs on: a light canvas, one pastel card
// per subject, the type in ink, and ONE product group big enough to be the
// picture — spilling over the card's bottom edge into the page, which is
// where the depth comes from instead of from height.
//
// Three things on the reading side, never more: a chip with the number, the
// headline, the button. Everything else is air.

/// The card's palette, one per subject. Light mode is the design; dark mode
/// is the same card in a darker room — the tint stays, dimmed onto graphite,
/// so «البكجات» is still the peach one at night.
@immutable
class LightSkin {
  const LightSkin({
    required this.card,
    required this.chip,
    required this.onChip,
    required this.cta,
    required this.onCta,
  });

  final Color card;
  final Color chip;
  final Color onChip;
  final Color cta;
  final Color onCta;

  static LightSkin of(BuildContext context, String? theme) {
    final dark = context.isDark;

    LightSkin skin(Color card, Color chip, Color cta) => LightSkin(
      card: dark ? Color.lerp(card, ZbTokens.graphiteHigh, 0.80)! : card,
      chip: chip,
      onChip: Colors.white,
      cta: cta,
      onCta: Colors.white,
    );

    return switch (theme) {
      // Peach: the generous one.
      'bundles' => skin(const Color(0xFFFFE6D3), ZbTokens.coral, ZbTokens.teal),
      // Mint: the deadline, calm — the clock does the urging.
      'cutoff' => skin(const Color(0xFFDCEFEE), ZbTokens.tealDark, ZbTokens.coral),
      // Rose: a sale, warm not loud.
      'clearance' => skin(ZbTokens.coralTint, ZbTokens.coralDark, ZbTokens.coralDark),
      // Warm paper: the brand's own mark carries the colour.
      'brand' => skin(const Color(0xFFF3EEE6), ZbTokens.inkSoft, ZbTokens.teal),
      'newin' => skin(const Color(0xFFE6F2DA), const Color(0xFF3F8F4A), ZbTokens.teal),
      'bestsellers' => skin(ZbTokens.amberTint, ZbTokens.amberDeep, ZbTokens.teal),
      _ => skin(const Color(0xFFDCEFEE), ZbTokens.tealDark, ZbTokens.teal),
    };
  }
}

/// Geometry shared with the carousel, so the page reserves exactly the room
/// the card and its spill need.
abstract final class LightCardMetrics {
  /// The card proper.
  static const double height = 172;

  /// How far the product hangs below the card's bottom edge, into the page.
  static const double spill = 30;

  static const double radius = 26;
  static const double margin = 16;

  /// Extra card height at the text-scale cap (the copy column is four lines
  /// of type; large text needs the room back).
  static const double scaleHeadroom = 90;
}

/// One server-composed slide on the light canvas.
class LightSlideCard extends StatelessWidget {
  const LightSlideCard({
    super.key,
    required this.slide,
    this.scope,
    this.now,
  });

  final HeroSlide slide;
  final CatalogScope? scope;

  /// Pins the clock for the design golden.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final skin = LightSkin.of(context, slide.theme);
    final live = HeroLive.of(slide.theme, scope, l, locale, now: now);
    final cutoff = slide.theme == 'cutoff';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The card. Its own clip keeps the glow and the sparkles inside;
            // the product sits OUTSIDE it, on the stack, so it can spill.
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(LightCardMetrics.radius),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: skin.card),
                  child: Stack(
                    children: [
                      // A soft white bloom where the product lands.
                      PositionedDirectional(
                        end: 10,
                        top: 14,
                        child: Container(
                          width: h * 0.95,
                          height: h * 0.95,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(
                                  alpha: context.isDark ? 0.10 : 0.85,
                                ),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _SparklePainter(context.isDark)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // The picture: one product group, big, hanging over the edge.
            _Art(slide: slide, cardWidth: w, cardHeight: h),

            // The words.
            PositionedDirectional(
              start: 20,
              top: 16,
              bottom: 16,
              width: w * 0.54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cutoff)
                    ..._cutoffCopy(context, l, locale, skin, live)
                  else
                    ..._copy(context, skin, live),
                  if ((slide.ctaLabel ?? '').isNotEmpty) ...[
                    Gap.h12,
                    _Cta(label: slide.ctaLabel!, bg: skin.cta, fg: skin.onCta),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Chip · headline · line — the general anatomy.
  List<Widget> _copy(BuildContext context, LightSkin skin, HeroLive live) {
    final badge = live.badge ?? slide.badge;
    final title = live.title ?? slide.title;
    final sub = slide.subtitle;
    return [
      if ((badge ?? '').isNotEmpty) ...[
        _Chip(label: badge!, bg: skin.chip, fg: skin.onChip),
        Gap.h8,
      ],
      if ((title ?? '').isNotEmpty)
        Text(
          title!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.tt.headlineSmall?.copyWith(
            color: context.cs.onSurface,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
      if ((sub ?? '').isNotEmpty) ...[
        Gap.h4,
        Text(
          sub!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    ];
  }

  /// The deadline: the chip names it, the HOUR is the headline, and while it
  /// is still today the ticking pill replaces the line under it.
  List<Widget> _cutoffCopy(
    BuildContext context,
    L l,
    String locale,
    LightSkin skin,
    HeroLive live,
  ) {
    final minutes = scope?.standardCutoffMinutes ?? standardCutoffMinutes;
    final at = timeOfDayToday(minutes, now: now);
    final clock = Fmt.clockShort(at, locale);
    final today = live.deadlineAt != null;
    return [
      _Chip(
        label: today ? l.heroCutoffChip : (live.title ?? slide.title ?? ''),
        bg: skin.chip,
        fg: skin.onChip,
        icon: Icons.schedule_rounded,
      ),
      Gap.h8,
      Text(
        clock,
        maxLines: 1,
        style: context.tt.headlineLarge?.copyWith(
          color: context.cs.onSurface,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      Gap.h4,
      if (today)
        HeroLivePill(
          live: live,
          fg: context.cs.onSurface,
          accent: skin.chip,
          now: now,
          compact: true,
        )
      else if ((slide.title ?? '').isNotEmpty)
        Text(
          slide.title!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
    ];
  }
}

/// The product group on the far side. One pack is the picture; a second, when
/// the slide brought one, stands behind it a size down. A brand slide shows
/// its mark on a white tile instead — logos are drawn for paper.
class _Art extends StatelessWidget {
  const _Art({required this.slide, required this.cardWidth, required this.cardHeight});

  final HeroSlide slide;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final logo = slide.theme == 'brand' ? slide.brand?.logo : null;
    if (logo != null && logo.isNotEmpty) {
      return PositionedDirectional(
        end: 18,
        top: (cardHeight - 96) / 2,
        child: Container(
          width: 132,
          height: 96,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ZbImage(url: logo, backgroundColor: Colors.transparent),
        ),
      );
    }

    final images = slide.productImages.where((u) => u.isNotEmpty).take(2).toList();
    if (images.isEmpty) return const SizedBox.shrink();

    // The lead pack is about 55% of the card wide and hangs below its edge.
    final big = (cardWidth * 0.55).clamp(150.0, 220.0);
    final small = big * 0.62;
    return PositionedDirectional(
      end: -6,
      bottom: -LightCardMetrics.spill,
      width: big + (images.length > 1 ? small * 0.35 : 0),
      height: big,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (images.length > 1)
            PositionedDirectional(
              start: 0,
              bottom: 14,
              child: _Pack(url: images[1], size: small, tilt: 0.07),
            ),
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: _Pack(url: images[0], size: big, tilt: -0.03),
          ),
        ],
      ),
    );
  }
}

/// A cut-out pack with a soft floor shadow — the same trick as the bundle
/// card the owner approved, and nothing else.
class _Pack extends StatelessWidget {
  const _Pack({required this.url, required this.size, this.tilt = 0});

  final String url;
  final double size;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final pack = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: size * 0.16,
            end: size * 0.16,
            bottom: size * 0.02,
            child: Container(
              height: size * 0.08,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(size * 0.4, size * 0.04),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3C1A0A).withValues(alpha: 0.30),
                    blurRadius: size * 0.14,
                    spreadRadius: -size * 0.02,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ZbImage(
              url: url,
              fit: BoxFit.contain,
              backgroundColor: Colors.transparent,
              decodeWidth: ZbDecode.hero,
            ),
          ),
        ],
      ),
    );
    return tilt == 0 ? pack : Transform.rotate(angle: tilt, child: pack);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg, this.icon});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 11, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            Gap.w4,
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Gap.w4,
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 18,
            color: fg,
          ),
        ],
      ),
    );
  }
}

/// The logo's confetti, three pieces of it: a teal star, a coral heart, an
/// orange dot — placed over the product's side where the bloom is, never over
/// the words. Enough to say whose card this is.
class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rtl = size.width > 0; // paints in the card's own coordinate space
    // The product side is the END side; in RTL that is the left.
    double x(double fromEnd) => rtl ? fromEnd : size.width - fromEnd;
    final alpha = dark ? 0.55 : 0.9;

    _star(canvas, Offset(x(size.width * 0.40), 22), 7, ZbTokens.teal.withValues(alpha: alpha));
    _star(canvas, Offset(x(size.width * 0.12), size.height * 0.72), 4.5, ZbTokens.coral.withValues(alpha: alpha));
    _heart(canvas, Offset(x(size.width * 0.06), 34), 6, ZbTokens.coral.withValues(alpha: alpha));
    canvas.drawCircle(
      Offset(x(size.width * 0.34), size.height * 0.86),
      3,
      Paint()..color = const Color(0xFFF2A54A).withValues(alpha: alpha),
    );
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.2, c.dx - r * 0.6, c.dy - r * 1.3, c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.6, c.dy - r * 1.3, c.dx + r * 1.6, c.dy - r * 0.2, c.dx, c.dy + r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.dark != dark;
}
