import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';

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
            padding: EdgeInsets.only(top: 16),
            child: Column(
              children: [
                SkeletonBox(width: 200, height: 12),
                Gap.h12,
                SkeletonBox(width: 240, height: 26, radius: ZbTokens.rPill),
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
