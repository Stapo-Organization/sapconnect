import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/product_card_foot.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// «الأكثر مبيعاً» as a chart.
///
/// A best-seller list is a ranking, and a ranking is read down, not across:
/// one board, numbered rows, the podium struck in amber, the price at the
/// end of each line where the eye lands after the name. Six rows and a
/// «الكل» — a chart with twenty entries is a shelf again.
class RankedList extends ConsumerWidget {
  const RankedList({
    super.key,
    required this.title,
    required this.products,
    this.onAdd,
    this.onSeeAll,
    this.zone,
    this.rows = 6,
  });

  final String title;
  final List<ProductCard> products;
  final Future<bool> Function(ProductCard product)? onAdd;
  final VoidCallback? onSeeAll;
  final String? zone;
  final int rows;

  static const double _photo = 64;

  static double rowHeight(BuildContext context) =>
      12 * 2 + math.max(_photo, context.nameLine * 2 + 4 + context.priceLine) + formSlack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    final cs = context.cs;
    final shown = products.take(rows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          leading: SectionMark(pair: context.zb.badgeTrending, icon: Icons.emoji_events_rounded),
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // The board is its own Material, so a row's ink stays inside the
          // rounded edge instead of bleeding onto the page.
          child: Material(
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
              side: BorderSide(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 56, end: 16),
                      child: Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.7)),
                    ),
                  _Row(rank: i + 1, product: shown[i], onAdd: onAdd, zone: zone),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.rank, required this.product, required this.onAdd, required this.zone});

  final int rank;
  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final l = L.of(context);
    final brand = product.brand?.name;
    final podium = rank <= 3;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProductCardMetrics.maxTextScale,
      child: Semantics(
        button: true,
        label: product.name,
        child: InkWell(
          onTap: () {
            Haptics.light();
            openProduct(context, ref, product, zone: zone);
          },
          child: SizedBox(
            height: RankedList.rowHeight(context),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 10, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: podium
                          ? RankCoin(rank: rank, size: 24, filled: rank == 1)
                          : Text(
                              '$rank',
                              style: context.tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurfaceVariant,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                    ),
                  ),
                  Gap.w8,
                  SizedBox(
                    width: RankedList._photo,
                    height: RankedList._photo,
                    child: PhotoPlate(
                      product: product,
                      radius: ZbTokens.rMd,
                      inset: 4,
                      status: false,
                      color: context.isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: context.nameLine * 2,
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: context.priceLine,
                          child: Row(
                            children: [
                              Flexible(child: InlinePrice(product: product, style: context.tt.titleSmall)),
                              if (brand != null && brand.isNotEmpty) ...[
                                Gap.w8,
                                Flexible(
                                  child: Text(
                                    brand,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.w8,
                  if (product.inStock)
                    ProductCardAddOverlay(product: product, onAdd: onAdd)
                  else
                    SizedBox(
                      width: 44,
                      child: Text(
                        l.cardOutOfStock,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, height: 1.1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
