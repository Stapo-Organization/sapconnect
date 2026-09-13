import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/product_card_foot.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../core/icons/zb_icons.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// «وصل حديثاً» as a wall of polaroids.
///
/// New arrivals are looked at, not looked for — nobody knows they want them
/// yet. So the form is the one that says "look": three across, each photo
/// in a white polaroid frame taped to the page at a slightly different angle,
/// a «جديد» sticker on the first. Quick to scan, cheap to ignore, and unlike
/// anything above it.
abstract final class ArrivalsWall {
  static const int columns = 3;
  static const double _frame = 8;

  static double tileWidth(BuildContext context) =>
      ProductCardMetrics.tileWidth(context, crossAxisCount: columns);

  static double photoSide(BuildContext context) => tileWidth(context) - _frame * 2;

  static double extent(BuildContext context) =>
      10 +
      photoSide(context) +
      8 +
      context.labelMediumLine +
      4 +
      math.max(context.priceLine, 30) +
      10 +
      formSlack +
      8;

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
          padding: const EdgeInsets.only(bottom: 16),
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
            (context, index) => ArrivalTile(product: products[index], index: index, onAdd: onAdd, zone: zone),
            childCount: products.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: ProductCardMetrics.gridSpacing + 4,
            crossAxisSpacing: ProductCardMetrics.gridSpacing,
            mainAxisExtent: extent(context),
          ),
        ),
      ),
    ];
  }
}

class ArrivalTile extends ConsumerWidget {
  const ArrivalTile({super.key, required this.product, this.index = 0, this.onAdd, this.zone});

  final ProductCard product;

  /// Its place on the wall — decides the angle it was taped at.
  final int index;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  static const List<double> _tilt = [-2.5, 1.5, -1.5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final l = L.of(context);
    final side = ArrivalsWall.photoSide(context);
    final degrees = _tilt[index % _tilt.length] * (context.isRtl ? -1 : 1);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProductCardMetrics.maxTextScale,
      child: Semantics(
        button: true,
        label: product.name,
        child: Transform.rotate(
          angle: degrees * math.pi / 180,
          child: PressScale(
            borderRadius: BorderRadius.circular(6),
            haptic: Haptics.light,
            onTap: () => openProduct(context, ref, product, zone: zone),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 2, offset: const Offset(0, 1)),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.22),
                    blurRadius: 22,
                    spreadRadius: -10,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: side,
                          height: side,
                          child: PhotoPlate(
                            product: product,
                            radius: 4,
                            inset: 6,
                            border: true,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: context.labelMediumLine,
                          width: double.infinity,
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: math.max(context.priceLine, 30),
                          child: Row(
                            children: [
                              Expanded(
                                child: InlinePrice(product: product, style: context.tt.titleSmall, compare: false),
                              ),
                              if (product.inStock)
                                ProductCardAddOverlay(product: product, onAdd: onAdd)
                              else
                                Flexible(
                                  child: Text(
                                    l.cardOutOfStock,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The tape.
                  Positioned(
                    top: -6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Transform.rotate(
                        angle: (index.isEven ? -3 : 4) * math.pi / 180,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ZbTokens.amberOnDark.withValues(alpha: 0.55),
                            border: Border.all(color: ZbTokens.amberDeep.withValues(alpha: 0.12)),
                          ),
                          child: const SizedBox(width: 54, height: 14),
                        ),
                      ),
                    ),
                  ),
                  if (index == 0) const PositionedDirectional(top: 12, end: -6, child: _NewSticker()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sticker, landed at the angle a thumb leaves it.
class _NewSticker extends StatelessWidget {
  const _NewSticker();

  static const Color _plum = Color(0xFF7C6BC9);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (context.isRtl ? 8 : -8) * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _plum,
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
          boxShadow: [
            BoxShadow(color: _plum.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Text(
          '${L.of(context).cardNewSticker} ✦',
          style: context.tt.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
