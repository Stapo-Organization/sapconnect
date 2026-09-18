import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/delivery/delivery_eta.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'hero_live_copy.dart';

// «لوحة البراند» — the زوبكسي slide the owner moved to on 2026-09-18, after a
// day on «الحيّ الأبيض».
//
// The whole unit is the brand's own teal, flat, with the header on it, the
// two mascots peeking over the top edge of a WHITE plate — and the plate is
// the slide. White is what packshots and logos are drawn for, so the picture
// needs no bloom and no tint to sit well; the colour is all around the plate
// instead of behind the product.
//
// On the reading side: a small teal kicker, one big ink line, one soft line,
// a coral button. The big line is the NUMBER when the slide has one («وفّر
// حتى 24%»), the brand's name on a brand slide, the hour on the deadline.

/// The plate's palette. Light mode is the design; dark mode keeps the board
/// teal, dims it, and gives the plate the raised graphite.
@immutable
class PlateSkin {
  const PlateSkin({
    required this.plate,
    required this.kicker,
    required this.ink,
    required this.soft,
    required this.glow,
    required this.cta,
    required this.onCta,
  });

  final Color plate;
  final Color kicker;
  final Color ink;
  final Color soft;
  final Color glow;
  final Color cta;
  final Color onCta;

  static PlateSkin of(BuildContext context) {
    final dark = context.isDark;
    return PlateSkin(
      plate: dark ? ZbTokens.graphiteHigh : Colors.white,
      kicker: dark ? ZbTokens.tealOnDark : ZbTokens.teal,
      ink: dark ? ZbTokens.inkDark : ZbTokens.ink,
      soft: dark ? ZbTokens.inkSoftDark : ZbTokens.inkSoft,
      // A warm breath at the product's feet — on graphite the plate is the
      // warmth already, so it only barely lifts.
      glow: dark ? const Color(0xFF3A3F3B) : const Color(0xFFFFEFE3),
      cta: ZbTokens.coral,
      onCta: Colors.white,
    );
  }
}

/// Geometry shared with the carousel, so the board reserves exactly the room
/// the plate, the mascots over it and the dots under it need.
abstract final class PlateMetrics {
  /// The plate proper.
  static const double height = 158;

  /// Air between the header and the plate — where the mascots peek.
  static const double peek = 54;

  /// Under the plate: the dots and the board's bottom margin.
  static const double foot = 32;

  static const double radius = 26;
  static const double margin = 16;

  /// Extra plate height at the text-scale cap (the copy is four lines).
  static const double scaleHeadroom = 70;

  /// The mascots' width; the board's bottom corners.
  static const double mascots = 170;
  static const double boardRadius = 32;
}

/// One server-composed slide, as the white plate.
class PlateSlideCard extends StatelessWidget {
  const PlateSlideCard({
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
    final skin = PlateSkin.of(context);
    final live = HeroLive.of(slide.theme, scope, l, locale, now: now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(PlateMetrics.radius),
          child: DecoratedBox(
            decoration: BoxDecoration(color: skin.plate),
            child: Stack(
              children: [
                // The warm breath under the product, on its side only.
                PositionedDirectional(
                  end: -30,
                  bottom: -50,
                  child: Container(
                    width: 210,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [skin.glow, skin.glow.withValues(alpha: 0)],
                        stops: const [0.0, 0.68],
                      ),
                    ),
                  ),
                ),

                _Art(slide: slide, plateHeight: h),

                PositionedDirectional(
                  start: 20,
                  top: 11,
                  bottom: 11,
                  width: w * 0.53,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._copy(context, l, locale, skin, live),
                      if ((slide.ctaLabel ?? '').isNotEmpty) ...[
                        Gap.h12,
                        _Cta(label: slide.ctaLabel!, bg: skin.cta, fg: skin.onCta),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Kicker · big line · soft line. Which words go where depends on what the
  /// slide brought: a number is always the big line.
  List<Widget> _copy(
    BuildContext context,
    L l,
    String locale,
    PlateSkin skin,
    HeroLive live,
  ) {
    final theme = slide.theme;
    final badge = live.badge ?? slide.badge;
    final title = live.title ?? slide.title;

    if (theme == 'cutoff') {
      final minutes = scope?.standardCutoffMinutes ?? standardCutoffMinutes;
      final at = timeOfDayToday(minutes, now: now);
      final today = live.deadlineAt != null;
      return [
        _Kicker(today ? l.heroCutoffChip : (title ?? ''), skin),
        Gap.h4,
        _Big(Fmt.clockShort(at, locale), skin, clock: true),
        Gap.h4,
        if (today)
          HeroLivePill(
            live: live,
            fg: skin.ink,
            accent: skin.kicker,
            now: now,
            compact: true,
          )
        else if ((slide.subtitle ?? '').isNotEmpty)
          _Soft(slide.subtitle!, skin),
      ];
    }

    if (theme == 'brand') {
      final name = slide.brand?.name;
      return [
        _Kicker(l.heroBrandKicker, skin),
        Gap.h4,
        _Big((name ?? '').isNotEmpty ? name! : (title ?? ''), skin),
        if ((slide.subtitle ?? '').isNotEmpty) ...[
          Gap.h4,
          _Soft(slide.subtitle!, skin),
        ],
      ];
    }

    final hasBadge = (badge ?? '').isNotEmpty;
    return [
      if (hasBadge && (title ?? '').isNotEmpty) ...[
        _Kicker(title!, skin),
        Gap.h4,
      ],
      _Big(hasBadge ? badge! : (title ?? ''), skin),
      if ((slide.subtitle ?? '').isNotEmpty) ...[
        Gap.h4,
        _Soft(slide.subtitle!, skin),
      ],
    ];
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text, this.skin);

  final String text;
  final PlateSkin skin;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.tt.labelMedium?.copyWith(
        color: skin.kicker,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.text, this.skin, {this.clock = false});

  final String text;
  final PlateSkin skin;
  final bool clock;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Flexible(
      child: Text(
        text,
        maxLines: clock ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: (clock ? context.tt.headlineLarge : context.tt.headlineMedium)
            ?.copyWith(
              color: skin.ink,
              fontWeight: FontWeight.w900,
              height: clock ? 1.0 : 1.12,
            ),
      ),
    );
  }
}

class _Soft extends StatelessWidget {
  const _Soft(this.text, this.skin);

  final String text;
  final PlateSkin skin;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.tt.bodySmall?.copyWith(color: skin.soft, height: 1.35),
      ),
    );
  }
}

/// The picture on the far side of the plate. One pack, big; a brand slide
/// shows its mark above a pack when it brought one, the mark alone when not —
/// straight on the white, the way logos are drawn to be seen.
class _Art extends StatelessWidget {
  const _Art({required this.slide, required this.plateHeight});

  final HeroSlide slide;
  final double plateHeight;

  @override
  Widget build(BuildContext context) {
    final logo = slide.theme == 'brand' ? (slide.brand?.logo ?? '') : '';
    final images = slide.productImages.where((u) => u.isNotEmpty).toList();

    if (logo.isNotEmpty) {
      if (images.isEmpty) {
        return PositionedDirectional(
          end: 24,
          top: 0,
          bottom: 0,
          child: Center(
            child: SizedBox(
              width: 124,
              height: 84,
              child: ZbImage(url: logo, backgroundColor: Colors.transparent),
            ),
          ),
        );
      }
      final pack = (plateHeight * 0.78).clamp(96.0, 124.0);
      return Stack(
        children: [
          PositionedDirectional(
            end: 26,
            top: 16,
            child: SizedBox(
              width: 92,
              height: 44,
              child: ZbImage(url: logo, backgroundColor: Colors.transparent),
            ),
          ),
          PositionedDirectional(
            end: 4,
            bottom: 6,
            child: _Pack(url: images.first, size: pack, tilt: -0.09),
          ),
        ],
      );
    }

    if (images.isEmpty) return const SizedBox.shrink();
    // The pack fills the plate's height, a hair of air above and below.
    final size = (plateHeight - 12).clamp(120.0, 150.0);
    return PositionedDirectional(
      end: 6,
      bottom: 6,
      child: _Pack(url: images.first, size: size),
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
                    color: const Color(0xFF3C1A0A).withValues(alpha: 0.26),
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

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 7, bottom: 7),
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
