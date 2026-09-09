import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/motion/motion.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/product_card_foot.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/catalog_models.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// «اشتريته سابقاً» as a strip of reorder stubs.
///
/// A third of express orders are one line someone is replacing. That customer
/// does not need a shelf of tall cards to browse — they need the thing they
/// bought, its price, when they last bought it, and one tap. So the form is a
/// receipt line: a small round photo, the name, the price, the date, and the
/// add control on a stub of its own, separated by a hairline the way a
/// tear-off is.
class ReorderStrip extends ConsumerWidget {
  const ReorderStrip({
    super.key,
    required this.slot,
    required this.products,
    this.onAdd,
    this.onSeeAll,
    this.zone,
  });

  final PersonalSlot slot;

  /// The products to draw — the slot's own, after the page's dedupe.
  final List<ProductCard> products;
  final Future<bool> Function(ProductCard product)? onAdd;
  final VoidCallback? onSeeAll;
  final String? zone;

  static const double _width = 256;
  static const double _photo = 60;

  static double height(BuildContext context) {
    final text = context.nameLine * 2 + 4 + context.priceLine;
    return 12 * 2 + (text > _photo ? text : _photo) + formSlack;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final stagger = !context.reduceMotion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: slot.title,
          subtitle: slot.anyDue ? l.homeReorderDue : null,
          leading: SectionMark(pair: context.zb.tierSameDay, icon: Icons.replay_rounded),
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              final stub = _Stub(
                product: product,
                hint: slot.hints[product.id],
                onAdd: onAdd,
                zone: zone,
              );
              if (!stagger) return stub;
              return stub
                  .animate()
                  .fadeIn(duration: 240.ms, delay: Motion.stagger * index.clamp(0, 6))
                  .moveX(begin: 14, end: 0, duration: 240.ms, curve: Curves.easeOutCubic);
            },
          ),
        ),
      ],
    );
  }
}

class _Stub extends ConsumerWidget {
  const _Stub({required this.product, required this.hint, required this.onAdd, required this.zone});

  final ProductCard product;
  final ReorderHint? hint;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final due = hint?.due ?? false;
    final days = hint?.lastOrderedDays;

    final when = due
        ? Text(
            l.reorderDueShort,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelSmall?.copyWith(color: zb.warning, fontWeight: FontWeight.w800),
          )
        : (days == null
            ? null
            : Text(
                l.searchBoughtDays(days),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ));

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        button: true,
        label: product.name,
        child: PressScale(
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          haptic: Haptics.light,
          onTap: () => openProduct(context, ref, product, zone: zone),
          child: Container(
            width: ReorderStrip._width,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: due ? zb.warning.withValues(alpha: 0.5) : cs.outlineVariant),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(10, 12, 8, 12),
            child: Row(
              children: [
                SizedBox(
                  width: ReorderStrip._photo,
                  height: ReorderStrip._photo,
                  child: PhotoPlate(
                    product: product,
                    radius: ReorderStrip._photo / 2,
                    inset: 4,
                    status: false,
                    color: context.isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                  ),
                ),
                Gap.w10,
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
                            // The price may take three fifths of the line and
                            // then scales down; the date takes what is left.
                            Flexible(
                              flex: 3,
                              child: InlinePrice(
                                product: product,
                                compare: false,
                                style: context.tt.titleSmall,
                              ),
                            ),
                            if (when != null) ...[
                              Gap.w8,
                              Flexible(flex: 2, child: when),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.w8,
                // The stub: a hairline, then the control on its own.
                Container(width: 1, height: 40, color: cs.outlineVariant),
                Gap.w8,
                if (product.inStock)
                  ProductCardAddOverlay(product: product, onAdd: onAdd)
                else
                  SizedBox(
                    width: 36,
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
    );
  }
}
