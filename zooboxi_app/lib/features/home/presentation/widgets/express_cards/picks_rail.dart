import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../core/icons/zb_icons.dart';
import '../../../../../core/motion/motion.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../catalog/data/product_models.dart';
import '../../../../catalog/presentation/pet_palette.dart';
import 'card_form.dart';

/// «مختارة لك» as mounted picks.
///
/// These were chosen for this customer's animal, and the form says so the
/// way a gallery does: each photo is mounted on a coloured mat, and the mats
/// cycle through the four pet hues so the row is warm and varied without
/// being random. No hairline border — the mat is the edge. Cards arrive with
/// a soft settle rather than the rails' slide, which is the second quiet cue
/// that this row is a different kind of thing.
class PicksRail extends ConsumerWidget {
  const PicksRail({
    super.key,
    required this.title,
    required this.products,
    this.onAdd,
    this.zone,
  });

  final String title;
  final List<ProductCard> products;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  static const double width = 156;
  static const double _mat = 8;

  static double height(BuildContext context) =>
      _mat + (width - _mat * 2) + 8 + context.labelLine + 2 + context.nameLine * 2 + 4 + context.priceLine + 12 + formSlack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    final stagger = !context.reduceMotion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          leading: SectionMark(pair: context.zb.badgeNew, glyph: ZbIconKind.paw),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final card = _Pick(
                product: products[index],
                palette: PetPalette.resolve(context, index: index),
                onAdd: onAdd,
                zone: zone,
              );
              if (!stagger) return card;
              return card
                  .animate()
                  .fadeIn(duration: 260.ms, delay: Motion.stagger * index.clamp(0, 6))
                  .scale(
                    begin: const Offset(0.94, 0.94),
                    end: const Offset(1, 1),
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  );
            },
          ),
        ),
      ],
    );
  }
}

class _Pick extends ConsumerWidget {
  const _Pick({required this.product, required this.palette, required this.onAdd, required this.zone});

  final ProductCard product;
  final PetPalette palette;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = product.brand?.name;
    const plate = PicksRail.width - PicksRail._mat * 2;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProductCardMetrics.maxTextScale,
      child: Semantics(
        button: true,
        label: product.name,
        child: PressScale(
          borderRadius: BorderRadius.circular(22),
          haptic: Haptics.light,
          onTap: () => openProduct(context, ref, product, zone: zone),
          child: Container(
            width: PicksRail.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.band, palette.bandEnd],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(PicksRail._mat, PicksRail._mat, PicksRail._mat, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: plate,
                  height: plate,
                  child: PhotoPlate(product: product, onAdd: onAdd, radius: 16, inset: 10),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: context.labelLine,
                        width: double.infinity,
                        child: brand == null || brand.isEmpty
                            ? null
                            : Text(
                                brand,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.labelSmall?.copyWith(color: palette.muted, letterSpacing: 0.2),
                              ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: context.nameLine * 2,
                        width: double.infinity,
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.headline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: context.priceLine,
                        width: double.infinity,
                        child: InlinePrice(
                          product: product,
                          color: palette.headline,
                          pill: true,
                          style: context.tt.titleMedium,
                        ),
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
