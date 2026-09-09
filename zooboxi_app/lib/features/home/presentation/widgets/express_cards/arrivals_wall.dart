import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/icons/zb_icons.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// «وصل حديثاً» as a wall.
///
/// New arrivals are looked at, not looked for — nobody knows they want them
/// yet. So the form is the densest on the page: three across, the photo and
/// the price and nothing else, a teal «جديد» sticker slapped on each at the
/// angle a real sticker lands. Quick to scan, cheap to ignore, and unlike
/// anything above it.
abstract final class ArrivalsWall {
  static const int columns = 3;

  static double tileWidth(BuildContext context) =>
      ProductCardMetrics.tileWidth(context, crossAxisCount: columns);

  static double extent(BuildContext context) =>
      tileWidth(context) + 6 + context.labelMediumLine + 2 + context.priceLine + formSlack;

  static List<Widget> slivers(
    BuildContext context, {
    required String title,
    required List<ProductCard> products,
    Future<bool> Function(ProductCard product)? onAdd,
    String? zone,
    VoidCallback? onSeeAll,
  }) {
    if (products.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionHeader(
            title: title,
            leading: SectionMark(pair: context.zb.badgeNew, glyph: ZbIconKind.sparkle),
            onSeeAll: onSeeAll,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => ArrivalTile(product: products[index], onAdd: onAdd, zone: zone),
            childCount: products.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: ProductCardMetrics.gridSpacing,
            crossAxisSpacing: ProductCardMetrics.gridSpacing,
            mainAxisExtent: extent(context),
          ),
        ),
      ),
    ];
  }
}

class ArrivalTile extends ConsumerWidget {
  const ArrivalTile({super.key, required this.product, this.onAdd, this.zone});

  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final side = ArrivalsWall.tileWidth(context);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProductCardMetrics.maxTextScale,
      child: Semantics(
        button: true,
        label: product.name,
        child: PressScale(
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          haptic: Haptics.light,
          onTap: () => openProduct(context, ref, product, zone: zone),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: side,
                height: side,
                child: PhotoPlate(
                  product: product,
                  onAdd: onAdd,
                  radius: ZbTokens.rLg,
                  inset: 8,
                  border: true,
                  corner: const _NewSticker(),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: context.labelMediumLine,
                width: double.infinity,
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: context.priceLine,
                width: double.infinity,
                child: InlinePrice(product: product, style: context.tt.titleSmall, compare: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sticker, landed at the angle a thumb leaves it.
class _NewSticker extends StatelessWidget {
  const _NewSticker();

  @override
  Widget build(BuildContext context) {
    final pair = context.zb.badgeNew;
    return Transform.rotate(
      angle: (context.isRtl ? 1 : -1) * 10 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: context.isDark ? pair.fg : ZbTokens.teal,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: Text(
          L.of(context).cardNewSticker,
          style: context.tt.labelSmall?.copyWith(
            color: context.isDark ? pair.bg : Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
