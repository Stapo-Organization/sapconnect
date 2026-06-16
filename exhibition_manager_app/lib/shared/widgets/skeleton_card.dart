import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/tokens/radius.dart';

/// Skeleton card that mimics the shape of a transfer or session card.
/// Use this while loading list data for better perceived performance.
class SkeletonCard extends StatelessWidget {
  final double height;

  const SkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.borderLight),
        ),
      ),
    );
  }
}

/// Skeleton list that shows multiple skeleton cards.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double cardHeight;

  const SkeletonList({super.key, this.itemCount = 5, this.cardHeight = 120});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => SkeletonCard(height: cardHeight),
    );
  }
}
