import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_chips.dart';

// The hero slides the server composes when there is no bought banner to show.
// It ships copy plus a handful of product photos and lets the app draw them,
// so a "delivered in two hours" slide is the same object in both languages,
// both themes and at any text size — and costs a designer nothing.

/// Paint recipe for a server-composed slide. One per theme, so "express" looks
/// like the express promise everywhere it appears rather than like a generic
/// gradient with different words on it.
@immutable
class AutoSlideSkin {
  const AutoSlideSkin({required this.gradient, required this.fg, required this.muted, this.icon});

  final LinearGradient gradient;
  final Color fg;
  final Color muted;
  final IconData? icon;

  static AutoSlideSkin of(BuildContext context, String? theme) {
    final zb = context.zb;
    final dark = context.isDark;
    final onDark = dark ? ZbTokens.inkDark : Colors.white;

    return switch (theme) {
      'express' => AutoSlideSkin(
          gradient: dark
              ? const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.tealContainerDark, ZbTokens.graphiteHigh],
                )
              : const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.tealDeep, ZbTokens.tealDark],
                ),
          fg: onDark,
          muted: onDark.withValues(alpha: 0.82),
          icon: Icons.bolt_rounded,
        ),
      'clearance' => AutoSlideSkin(
          gradient: dark
              ? const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.coralContainerDark, ZbTokens.graphiteHigh],
                )
              : const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.coralDark, ZbTokens.coral],
                ),
          fg: onDark,
          muted: onDark.withValues(alpha: 0.82),
          icon: Icons.local_offer_rounded,
        ),
      // A brand slide belongs to the brand: a deep neutral stage, the logo on
      // its own white tile carrying the identity — the same reason the brand
      // strip refuses to tint itself. Deep, because this gradient doubles as
      // the hero canvas and the header on top of it is always light.
      'brand' => AutoSlideSkin(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [ZbTokens.graphiteHighest, ZbTokens.graphiteHigh],
          ),
          fg: ZbTokens.inkDark,
          muted: ZbTokens.inkDark.withValues(alpha: 0.75),
        ),
      _ => AutoSlideSkin(
          gradient: zb.brandGradient,
          fg: onDark,
          muted: onDark.withValues(alpha: 0.82),
          icon: Icons.trending_up_rounded,
        ),
    };
  }
}

class HeroAutoCard extends StatelessWidget {
  const HeroAutoCard({super.key, required this.slide, this.flush = false});

  final HeroSlide slide;

  /// True when the slide sits on the hero canvas, which already painted this
  /// skin's gradient from the status bar down — paint everything but it.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final skin = AutoSlideSkin.of(context, slide.theme);
    final images = slide.productImages.take(3).toList();
    final logo = slide.theme == 'brand' ? slide.brand?.logo : null;
    final hasArt = images.isNotEmpty || logo != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!flush) DecoratedBox(decoration: BoxDecoration(gradient: skin.gradient)),
        if (skin.icon != null)
          PositionedDirectional(
            top: -14,
            end: -10,
            child: Icon(
              skin.icon,
              size: 108,
              color: skin.fg.withValues(alpha: 0.10),
            ),
          ),
        if (hasArt)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.42,
              child: logo != null
                  // The logo owns its own white tile: brand marks are drawn
                  // for light paper, and the stage behind them is deep.
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(maxHeight: 96, maxWidth: 132),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ZbTokens.rMd),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ZbImage(url: logo, backgroundColor: Colors.transparent),
                      ),
                    )
                  : _ProductStack(images: images),
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 12, top: 14, bottom: 14),
          child: FractionallySizedBox(
            widthFactor: hasArt ? 0.60 : 1,
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((slide.title ?? '').isNotEmpty)
                  Flexible(
                    child: Text(
                      slide.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleLarge?.copyWith(
                        color: skin.fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if ((slide.subtitle ?? '').isNotEmpty) ...[
                  Gap.h4,
                  Flexible(
                    child: Text(
                      slide.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall?.copyWith(color: skin.muted),
                    ),
                  ),
                ],
                if ((slide.ctaLabel ?? '').isNotEmpty) ...[
                  Gap.h12,
                  CampaignCta(label: slide.ctaLabel!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Up to three product photos as overlapping rings — an avatar stack, which
/// reads as "a set of things" at a glance where a grid of thumbnails reads as
/// clutter.
class _ProductStack extends StatelessWidget {
  const _ProductStack({required this.images});

  final List<String> images;

  static const double _size = 70;
  static const double _step = 46;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final cs = context.cs;

    return Center(
      child: SizedBox(
        height: _size,
        width: _size + _step * (images.length - 1),
        child: Stack(
          children: [
            for (var i = 0; i < images.length; i++)
              PositionedDirectional(
                start: i * _step,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface,
                    border: Border.all(color: cs.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: ZbImage(
                      url: images[i],
                      fit: BoxFit.cover,
                      backgroundColor: cs.surface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
