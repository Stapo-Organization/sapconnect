import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';

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

/// Placeholder in the exact shape of a product card, so the grid doesn't jump
/// when the real cards land.
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: context.cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(10),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SkeletonBox(width: double.infinity, height: double.infinity, radius: 12),
          ),
          Gap.h12,
          SkeletonBox(width: 60, height: 9),
          Gap.h8,
          SkeletonBox(width: double.infinity, height: 11),
          Gap.h4,
          SkeletonBox(width: 90, height: 11),
          Gap.h12,
          SkeletonBox(width: 74, height: 15, radius: 7),
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: count,
        itemBuilder: (_, _) => const SkeletonProductCard(),
      ),
    );
  }
}

/// Skeleton for a horizontal rail: title line plus a few cards peeking in.
class SkeletonRail extends StatelessWidget {
  const SkeletonRail({super.key, this.cardWidth = 158});

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
            height: 260,
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
