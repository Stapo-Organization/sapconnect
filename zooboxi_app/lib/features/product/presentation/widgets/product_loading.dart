import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/price_text.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/product_models.dart';

/// What the product page shows while the detail request is in flight.
///
/// When the customer arrived by tapping a card, that card is passed through as
/// [preview] and its image, brand, name and price are painted immediately —
/// the transition lands on the product they chose, and only the parts we
/// genuinely don't know yet (variants, delivery tiers, availability) shimmer.
/// Reaching the page by deep link has no preview, so it falls back to a full
/// skeleton.
class ProductLoadingView extends StatelessWidget {
  const ProductLoadingView({super.key, this.preview});

  final ProductCard? preview;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final card = preview;

    if (card == null) return _BlankSkeleton(width: width);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        SizedBox(
          height: width * 0.86,
          child: ZbImage(
            url: card.image,
            padding: const EdgeInsets.all(20),
            backgroundColor: Colors.transparent,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (card.brand != null)
                Text(
                  card.brand!.name,
                  style: context.tt.labelMedium?.copyWith(color: context.cs.primary),
                ),
              Gap.h4,
              Text(card.name, style: context.tt.headlineSmall),
              Gap.h12,
              PriceText(
                price: card.price,
                regularPrice: card.regularPrice,
                onSale: card.onSale,
                priceFrom: card.priceFrom,
                style: context.tt.headlineMedium,
              ),
              Gap.h24,
              // Only the unknown parts shimmer.
              const ShimmerGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 13),
                    Gap.h12,
                    SkeletonBox(width: double.infinity, height: 96, radius: ZbTokens.rLg),
                    Gap.h12,
                    SkeletonBox(width: double.infinity, height: 62, radius: ZbTokens.rLg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlankSkeleton extends StatelessWidget {
  const _BlankSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ShimmerGroup(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          SkeletonBox(width: width, height: width * 0.86, radius: 0),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 90, height: 11),
                Gap.h12,
                SkeletonBox(width: double.infinity, height: 18),
                Gap.h8,
                SkeletonBox(width: 180, height: 18),
                Gap.h20,
                SkeletonBox(width: 120, height: 26, radius: 8),
                Gap.h24,
                SkeletonBox(width: double.infinity, height: 96, radius: ZbTokens.rLg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
