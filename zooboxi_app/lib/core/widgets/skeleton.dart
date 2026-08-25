import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import 'product_card_metrics.dart';

/// Wraps a skeleton layout in one shimmer sweep.
///
/// One sweep for the whole screen — not one per block — so the placeholders
/// read as a single loading surface instead of a disco.
class ShimmerGroup extends StatelessWidget {
  const ShimmerGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return Shimmer.fromColors(
      baseColor: zb.shimmerBase,
      highlightColor: zb.shimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// A single placeholder block. Put these inside a [ShimmerGroup].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  const SkeletonBox.circle({super.key, double size = 44})
      : width = size,
        height = size,
        radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.zb.shimmerBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder in the exact shape of a product card — same slots, same
/// heights — so nothing jumps when the real cards land.
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant, width: ProductCardMetrics.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: ProductCardMetrics.imageAspect,
            child: SkeletonBox(width: double.infinity, height: double.infinity, radius: 0),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(ProductCardMetrics.bodyPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 54, height: 9),
                  Spacer(),
                  SkeletonBox(width: double.infinity, height: 11),
                  Gap.h4,
                  SkeletonBox(width: 96, height: 11),
                  Gap.h8,
                  SkeletonBox(width: 78, height: 15, radius: 7),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column skeleton grid used by every listing screen's first load.
class SkeletonProductGrid extends StatelessWidget {
  const SkeletonProductGrid({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ShimmerGroup(
      child: GridView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: ProductCardMetrics.gridSpacing,
          crossAxisSpacing: ProductCardMetrics.gridSpacing,
          mainAxisExtent: ProductCardMetrics.gridExtent(
            context,
            horizontalPadding: padding.resolve(Directionality.of(context)).horizontal,
          ),
        ),
        itemCount: count,
        itemBuilder: (_, _) => const SkeletonProductCard(),
      ),
    );
  }
}

/// Skeleton for a horizontal rail: title line plus a few cards peeking in.
class SkeletonRail extends StatelessWidget {
  const SkeletonRail({super.key, this.cardWidth = ProductCardMetrics.railCardWidth});

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return ShimmerGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 16, end: 16),
            child: SkeletonBox(width: 130, height: 16),
          ),
          Gap.h12,
          SizedBox(
            height: ProductCardMetrics.height(context, cardWidth),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => Gap.w12,
              itemBuilder: (_, _) => SizedBox(
                width: cardWidth,
                child: const SkeletonProductCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
