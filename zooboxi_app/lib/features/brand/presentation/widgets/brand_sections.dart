import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
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
      height: 42,
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
              accent: accent,
              selected: selected == null,
              onTap: () => onSelect(null),
            );
          }
          final category = categories[index - 1];
          return _Chip(
            label: category.name,
            count: category.count,
            accent: accent,
            selected: selected == category.slug,
            onTap: () => onSelect(category.slug),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final int count;
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
        padding: const EdgeInsetsDirectional.only(start: 14, end: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: context.isDark ? 0.22 : 0.14)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.55) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                SkeletonBox(
                  width: BrandIdentity.tile,
                  height: BrandIdentity.tile,
                  radius: ZbTokens.rLg,
                ),
                Gap.w16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 18),
                      Gap.h8,
                      SkeletonBox(width: double.infinity, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap.h20,
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, _) => Gap.w8,
              itemBuilder: (_, _) =>
                  const SkeletonBox(width: 86, height: 42, radius: ZbTokens.rPill),
            ),
          ),
          Gap.h12,
          const SkeletonProductGrid(),
        ],
      ),
    );
  }
}
