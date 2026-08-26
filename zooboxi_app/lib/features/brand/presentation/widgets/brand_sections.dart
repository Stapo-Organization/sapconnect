import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/category_art.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'brand_identity.dart';

/// The brand's lifestyle tiles. Present only for brands whose boutique kit has
/// been synced, which is why this is a plain strip rather than a slot the page
/// reserves: no kit, no strip, no gap where one would have been.
class BrandTilesStrip extends StatelessWidget {
  const BrandTilesStrip({super.key, required this.tiles});

  final List<BrandTile> tiles;

  static const double _width = 150;
  static const double _height = 110;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => Gap.w12,
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(ZbTokens.rMd),
            child: SizedBox(
              width: _width,
              height: _height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ZbImage(url: tile.image, fit: BoxFit.cover),
                  if (tile.headline.isNotEmpty) ...[
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB3000000)],
                          stops: [0.42, 1],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 10,
                      end: 10,
                      bottom: 9,
                      child: Text(
                        tile.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The department filter: «الكل» plus the categories this brand actually sells
/// into. It is a *filter*, not navigation — the grid below re-queries in place,
/// so a customer comparing the brand's cat food to its dog food never leaves
/// the brand.
class BrandCategoryChips extends StatelessWidget {
  const BrandCategoryChips({
    super.key,
    required this.page,
    required this.selected,
    required this.onSelect,
  });

  final BrandPage page;

  /// Null means «الكل».
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (page.categories.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final accent = brandAccent(context, page);
    final categories = page.categories;

    return SizedBox(
      height: _Chip.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Chip(
              label: l.brandAllCategories,
              // «الكل» wears the brand's own mark — it *is* the whole brand.
              art: _AllArt(page: page, accent: accent),
              accent: accent,
              selected: selected == null,
              onTap: () => onSelect(null),
            );
          }
          final category = categories[index - 1];
          return _Chip(
            label: category.name,
            count: category.count,
            art: CategoryArt(
              image: category.image,
              icon: category.icon,
              size: _Chip.artSize,
            ),
            accent: accent,
            selected: selected == category.slug,
            onTap: () => onSelect(category.slug),
          );
        },
      ),
    );
  }
}

/// The «الكل» chip's leading circle: the brand logo on white, else its initial.
class _AllArt extends StatelessWidget {
  const _AllArt({required this.page, required this.accent});

  final BrandPage page;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Chip.artSize,
      height: _Chip.artSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.isDark ? context.cs.surfaceContainerHighest : Colors.white,
        border: Border.all(color: context.cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipOval(
        child: ZbImage(
          url: page.brand.logo,
          padding: const EdgeInsets.all(6),
          backgroundColor: Colors.transparent,
          fallback: Center(
            child: Text(
              page.name.characters.take(1).toString().toUpperCase(),
              style: context.tt.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A department as a face, not a word: the category's own artwork in a ring,
/// its name beside it, the shelf size in quiet digits.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.art,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  static const double height = 56;
  static const double artSize = 38;

  final String label;
  final int count;
  final Widget art;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rPill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.motion(Motion.select),
        curve: Motion.decelerate,
        padding: const EdgeInsetsDirectional.only(start: 9, end: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: context.isDark ? 0.22 : 0.12)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
          border: Border.all(
            width: 1.4,
            color: selected ? accent.withValues(alpha: 0.6) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            art,
            Gap.w8,
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelMedium?.copyWith(
                color: selected ? accent : cs.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              Gap.w6,
              Text(
                Fmt.number(count, locale: locale, decimals: 0),
                style: context.tt.labelSmall?.copyWith(
                  color: (selected ? accent : cs.onSurfaceVariant).withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// First paint: the stage, the identity block and a grid, in their real shapes.
/// A brand page that shimmers into the same layout it lands in never jumps.
class BrandPageSkeleton extends StatelessWidget {
  const BrandPageSkeleton({super.key, this.stageHeight = 230});

  final double stageHeight;

  @override
  Widget build(BuildContext context) {
    return ShimmerGroup(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SkeletonBox(width: double.infinity, height: stageHeight, radius: 0),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Column(
              children: [
                SkeletonBox(
                  width: BrandIdentity.tile,
                  height: BrandIdentity.tile,
                  radius: ZbTokens.rLg,
                ),
                Gap.h12,
                SkeletonBox(width: 140, height: 18),
                Gap.h8,
                SkeletonBox(width: 200, height: 12),
              ],
            ),
          ),
          Gap.h20,
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, _) => Gap.w8,
              itemBuilder: (_, _) =>
                  const SkeletonBox(width: 118, height: 56, radius: ZbTokens.rPill),
            ),
          ),
          Gap.h12,
          const SkeletonProductGrid(),
        ],
      ),
    );
  }
}
