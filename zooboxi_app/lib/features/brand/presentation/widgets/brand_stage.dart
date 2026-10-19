import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../home/presentation/widgets/express_cards/card_form.dart';
import 'brand_palette.dart';

// «الواجهة» — the brand's storefront inside Zooboxi (the owner's pick, 2026-09-24).
//
// The stage is the brand's own colour, not the store's: the logo on a white
// plate, the name and the brand's own line in ink that reads on that colour,
// three of its products standing in front of a lighter disc, and the
// Zooboxi animal peeking over the edge of the page below — one character,
// touching the UI, the species the brand is made for.

/// How tall the stage stands (below the status bar) before it collapses.
double brandStageHeight({required bool express}) => express ? 388 : 348;

/// The corner of the page sheet that rises over the stage's bottom edge.
const double _lip = 28;

class BrandStage extends StatelessWidget {
  const BrandStage({super.key, required this.page, required this.palette, this.express = false});

  final BrandPage page;
  final BrandPalette palette;

  /// On the إكسبريس shelf the stage carries the two-hour promise.
  final bool express;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final shift = express ? 40.0 : 0.0;
    final width = MediaQuery.sizeOf(context).width;
    final copyWidth = (width * 0.47).clamp(150.0, 220.0);
    final art = [
      for (final p in page.products)
        if ((p.image ?? '').isNotEmpty) p.image!,
    ].take(3).toList();
    final kicker = [
      if ((page.country ?? '').isNotEmpty) page.country!,
      if ((page.founded ?? '').isNotEmpty) l.brandSince(page.founded!),
    ].join(' · ');

    return ColoredBox(
      color: palette.field,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // The disc the products stand in front of, and two quiet rings.
          PositionedDirectional(
            end: -90,
            top: top + 22 + shift,
            child: _Disc(size: 330, color: palette.ring),
          ),
          PositionedDirectional(
            end: -130,
            top: top - 18 + shift,
            child: _Disc(size: 410, border: palette.ink.withValues(alpha: 0.14)),
          ),
          PositionedDirectional(
            end: -170,
            top: top - 58 + shift,
            child: _Disc(size: 490, border: palette.ink.withValues(alpha: 0.08)),
          ),

          // The kit's second colour: a bar at the start edge beside the name.
          PositionedDirectional(
            start: 0,
            top: top + 44 + shift,
            child: Container(
              width: 6,
              height: 104,
              decoration: BoxDecoration(
                color: palette.stripe,
                borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(3)),
              ),
            ),
          ),

          // Three of its own products, fanned.
          if (art.isNotEmpty)
            PositionedDirectional(
              end: 18,
              top: top + 80 + shift,
              child: FloatingProduct(url: art[0], width: 132, height: 150, degrees: -7, shadow: 0.34, drop: 10),
            ),
          if (art.length > 1)
            PositionedDirectional(
              end: 118,
              top: top + 104 + shift,
              child: FloatingProduct(url: art[1], width: 92, height: 118, degrees: 8, shadow: 0.34, drop: 10),
            ),
          if (art.length > 2)
            PositionedDirectional(
              end: 54,
              top: top + 196 + shift,
              child: FloatingProduct(url: art[2], width: 118, height: 104, shadow: 0.36, drop: 8),
            ),

          if (express)
            PositionedDirectional(
              start: 16,
              top: top + 56,
              child: _ExpressPill(label: l.brandExpressPill),
            ),

          // Logo plate, name, where it is from, and its own line.
          PositionedDirectional(
            start: 22,
            top: top + 52 + shift,
            width: copyWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogoPlate(page: page, width: 118, height: 68),
                const SizedBox(height: 10),
                Text(
                  page.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.headlineMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (kicker.isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    kicker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelMedium?.copyWith(
                      color: palette.ink.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if ((page.tagline ?? '').isNotEmpty) ...[
                  Gap.h8,
                  Text(
                    page.tagline!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleSmall?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // The page sheet's rounded top, rising over the stage.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _lip,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(_lip)),
              ),
            ),
          ),

          // The animal the brand is for, its paws on the page.
          PositionedDirectional(
            start: 30,
            bottom: 10,
            child: BrandCharacter(species: page.species),
          ),
        ],
      ),
    );
  }
}

/// Who stands on a brand's stage: the cat or dog peeking over the page edge
/// for a cat or dog brand; a brand for several pets lets the customer's own
/// household choose; a bird or small-pet brand gets that animal sitting on
/// the edge (they have one pose, and a peek is a cat-or-dog silhouette).
class BrandCharacter extends StatelessWidget {
  const BrandCharacter({super.key, required this.species, this.height = 86});

  final String species;
  final double height;

  @override
  Widget build(BuildContext context) {
    final standing = switch (species) {
      'bird' => ZbCast.budgie,
      'small' => ZbCast.hamster,
      'fish' => ZbCast.fish,
      _ => null,
    };
    if (standing != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ZbSticker.cast(standing, ZbPose.sitUp, height: height * 0.8),
      );
    }
    return switch (species) {
      'cat' => ZbSticker.cast(ZbCast.cat, ZbPose.peek, height: height, idle: ZbIdle.peek),
      'dog' => ZbSticker.cast(ZbCast.dog, ZbPose.peek, height: height, idle: ZbIdle.peek),
      _ => Companion(ZbPose.peek, height: height, idle: ZbIdle.peek),
    };
  }
}

/// The logo on a white plate — a logo is drawn for white, whatever the stage.
class BrandLogoPlate extends StatelessWidget {
  const BrandLogoPlate({super.key, required this.page, required this.width, required this.height});

  final BrandPage page;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final logo = page.brand.logo;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: width * 0.1, vertical: height * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.24),
        boxShadow: [BoxShadow(color: ZbTokens.warmShadow.withValues(alpha: 0x2E / 255), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: logo == null
          ? FittedBox(
              child: Text(
                page.name,
                style: context.tt.titleLarge?.copyWith(
                  color: ZbTokens.logoInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : ZbImage(url: logo, fit: BoxFit.contain, backgroundColor: Colors.white),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, this.color, this.border});

  final double size;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: border == null ? null : Border.all(color: border!, width: 1.5),
      ),
    );
  }
}

class _ExpressPill extends StatelessWidget {
  const _ExpressPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        boxShadow: [BoxShadow(color: ZbTokens.earthShadow.withValues(alpha: 0x24 / 255), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 16, color: ZbTokens.expressFg),
          Gap.w4,
          Text(
            label,
            style: context.tt.labelMedium?.copyWith(
              color: ZbTokens.expressFg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// The facts plaque under the stage: where it is from, since when, how much
/// of it this shelf holds, and who it is for — only the facts that exist.
class BrandFacts extends StatelessWidget {
  const BrandFacts({super.key, required this.page, required this.palette});

  final BrandPage page;
  final BrandPalette palette;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cs = context.cs;
    final total = page.shelfTotal > 0 ? page.shelfTotal : page.productCount;

    final cells = <(IconData, String, String)>[
      if ((page.country ?? '').isNotEmpty) (Icons.public_rounded, page.country!, l.brandFactOrigin),
      if ((page.founded ?? '').isNotEmpty) (Icons.flag_rounded, page.founded!, l.brandFactFounded),
      if (total > 0) (Icons.inventory_2_rounded, Fmt.number(total, locale: locale, decimals: 0), l.brandFactProducts),
      if ((page.specialty ?? '').isNotEmpty)
        (Icons.pets_rounded, page.specialty!, l.brandFactSpecialty)
      else if (page.inStock > 0)
        (Icons.check_circle_rounded, Fmt.number(page.inStock, locale: locale, decimals: 0), l.brandFactInStock),
    ];
    if (cells.length < 2) return const SizedBox.shrink();

    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: context.isDark
            ? null
            : [BoxShadow(color: ZbTokens.warmShadow.withValues(alpha: 0x14 / 255), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, indent: 18, endIndent: 18, color: cs.outlineVariant),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cells[i].$1, size: 18, color: palette.deep),
                  const SizedBox(height: 3),
                  // Scaled to fit, never cut: «المملكة المتحدة» read as
                  // «المملكة المت…» in a quarter of the strip.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cells[i].$2,
                        maxLines: 1,
                        style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  Text(
                    cells[i].$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The brand's mood in a few words, and the way into its story.
class BrandMoodRow extends StatelessWidget {
  const BrandMoodRow({super.key, required this.page, required this.palette, this.onAbout});

  final BrandPage page;
  final BrandPalette palette;
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (page.mood.isEmpty && onAbout == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final word in page.mood)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.wash,
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        border: Border.all(color: palette.tint),
                      ),
                      child: Text(
                        word,
                        style: context.tt.labelMedium?.copyWith(
                          color: palette.deep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (onAbout != null)
          TextButton.icon(
            onPressed: onAbout,
            style: TextButton.styleFrom(
              foregroundColor: palette.deep,
              visualDensity: VisualDensity.compact,
              textStyle: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: Text(l.brandAbout(page.name)),
          ),
      ],
    );
  }
}
