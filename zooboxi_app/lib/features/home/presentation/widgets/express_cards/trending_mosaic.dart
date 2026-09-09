import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/delivery_chip.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/product_card.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// «رائج الآن» as a leaderboard.
///
/// The branch's number one is not the first of eight equal tiles — it is the
/// thing more people in this neighbourhood are buying today than anything
/// else, and it gets the whole width to say so: a feature tile with the photo
/// mounted at the end, an ember eyebrow, the price at display size. The rest
/// keep the standard card, but each wears its rank as a coin on the artwork,
/// so the grid reads as a chart, not as a shelf.
abstract final class TrendingMosaic {
  static List<Widget> slivers(
    BuildContext context, {
    required String title,
    required List<ProductCard> products,
    Future<bool> Function(ProductCard product)? onAdd,
    String? zone,
    VoidCallback? onSeeAll,
  }) {
    if (products.isEmpty) return const [];
    final rest = products.skip(1).toList();
    final bodyHeight = ProductCardMetrics.bodyHeight(context);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionHeader(
            title: title,
            leading: SectionMark(pair: context.zb.tierExpress, icon: Icons.local_fire_department_rounded),
            onSeeAll: onSeeAll,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, ProductCardMetrics.gridSpacing),
          child: RepaintBoundary(
            child: FeatureTile(product: products.first, onAdd: onAdd, zone: zone),
          ),
        ),
      ),
      if (rest.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ProductCardView(product: rest[index], onAdd: onAdd, zone: zone),
                  // Bottom-start of the artwork: the one corner nothing else
                  // claims (badges top-start, heart top-end, add bottom-end).
                  PositionedDirectional(
                    bottom: bodyHeight + 8,
                    start: 8,
                    child: IgnorePointer(child: RankCoin(rank: index + 2, filled: index < 2)),
                  ),
                ],
              ),
              childCount: rest.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: ProductCardMetrics.gridSpacing,
              crossAxisSpacing: ProductCardMetrics.gridSpacing,
              mainAxisExtent: ProductCardMetrics.gridExtent(context),
            ),
          ),
        ),
    ];
  }
}

/// The number one, given the width.
class FeatureTile extends ConsumerWidget {
  const FeatureTile({super.key, required this.product, this.onAdd, this.zone});

  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  static double height(BuildContext context) {
    final text = 22 + 8 + context.nameLine * 2 + 2 + context.labelLine + 8 + context.priceLargeLine + 8 + 24;
    return math.max(176, 14 * 2 + text + formSlack);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final ember = context.zb.tierExpress;
    final h = height(context);
    final plate = (h - 28).clamp(110.0, 150.0);
    final chip = product.deliveryChip;
    final brand = product.brand?.name;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProductCardMetrics.maxTextScale,
      child: Semantics(
        button: true,
        label: product.name,
        child: PressScale(
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          haptic: Haptics.light,
          onTap: () => openProduct(context, ref, product, zone: zone),
          child: Container(
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
              border: Border.all(color: ember.fg.withValues(alpha: 0.18)),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  ember.bg,
                  Color.lerp(ember.bg, cs.surface, context.isDark ? 0.35 : 0.55)!,
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // The ember breath behind the photo, where the weight is.
                PositionedDirectional(
                  end: -h * 0.35,
                  top: -h * 0.3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [ember.fg.withValues(alpha: 0.14), ember.fg.withValues(alpha: 0)],
                      ),
                    ),
                    child: SizedBox(width: h * 1.4, height: h * 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                RankCoin(rank: 1, filled: true, tone: ember),
                                Gap.w6,
                                Flexible(
                                  child: Text(
                                    l.homeTopToday,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.tt.labelSmall?.copyWith(
                                      color: ember.fg,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: context.nameLine * 2,
                              child: Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: context.labelLine,
                              child: brand == null || brand.isEmpty
                                  ? null
                                  : Text(
                                      brand,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: context.priceLargeLine,
                              child: InlinePrice(
                                product: product,
                                pill: true,
                                style: context.tt.titleLarge,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 24,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: chip == null
                                    ? const SizedBox.shrink()
                                    : DeliveryChipView(chip: chip, compact: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Gap.w12,
                      SizedBox(
                        width: plate,
                        height: plate,
                        child: PhotoPlate(product: product, onAdd: onAdd, radius: ZbTokens.rLg, inset: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
