import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../core/motion/motion.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/product_card_foot.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// Clearance as price tags.
///
/// The news on a clearance item is the cut, not the product, so the cut is
/// the headline: the percentage at display size in the sale accent, the new
/// price under it against the struck one, the name in a whisper. And the
/// card is cut like a tag — a pointed end and a punched hole on the start
/// side — because a shape the hand knows says «مخفّض» faster than any word.
class PriceCutRail extends ConsumerWidget {
  const PriceCutRail({
    super.key,
    required this.products,
    this.onAdd,
    this.zone,
  });

  final List<ProductCard> products;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  static const double width = 224;

  static double height(BuildContext context) => math.max(
        118,
        12 * 2 + context.displayLine + 2 + context.priceLine + 4 + context.labelLine + formSlack,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    final stagger = !context.reduceMotion;

    return SizedBox(
      height: height(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final tag = _Tag(product: products[index], onAdd: onAdd, zone: zone);
          if (!stagger) return tag;
          return tag
              .animate()
              .fadeIn(duration: 240.ms, delay: Motion.stagger * index.clamp(0, 6))
              .moveX(begin: 16, end: 0, duration: 240.ms, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

class _Tag extends ConsumerWidget {
  const _Tag({required this.product, required this.onAdd, required this.zone});

  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  /// How deep the pointed end runs into the card.
  static const double tip = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final sale = context.zb.sale;
    final pct = product.discountPercent;
    final h = PriceCutRail.height(context);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProductCardMetrics.maxTextScale,
      child: Semantics(
        button: true,
        label: product.name,
        child: GestureDetector(
          onTap: () {
            Haptics.light();
            openProduct(context, ref, product, zone: zone);
          },
          child: SizedBox(
            width: PriceCutRail.width,
            height: h,
            child: CustomPaint(
              painter: _TagPainter(
                fill: cs.surface,
                line: sale.withValues(alpha: 0.35),
                hole: context.isDark ? cs.surfaceContainerLowest : cs.surfaceContainerLow,
                rtl: context.isRtl,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(tip + 8, 12, 96, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: context.displayLine,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: pct > 0
                                ? Text(
                                    l.priceOff(pct),
                                    maxLines: 1,
                                    style: context.tt.headlineSmall?.copyWith(
                                      color: sale,
                                      fontWeight: FontWeight.w900,
                                      height: 1.25,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  )
                                : InlinePrice(product: product, style: context.tt.headlineSmall, color: sale),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: context.priceLine,
                          width: double.infinity,
                          child: pct > 0
                              ? InlinePrice(product: product, style: context.tt.titleMedium)
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: context.labelLine,
                          width: double.infinity,
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: PhotoPlate(
                        product: product,
                        radius: 14,
                        inset: 6,
                        status: false,
                        color: context.isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                      ),
                    ),
                  ),
                  if (product.inStock)
                    PositionedDirectional(
                      bottom: 8,
                      end: 8,
                      child: ProductCardAddOverlay(product: product, onAdd: onAdd),
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

/// The tag: a rounded body, a pointed start end, and a punched hole.
class _TagPainter extends CustomPainter {
  const _TagPainter({required this.fill, required this.line, required this.hole, required this.rtl});

  final Color fill;
  final Color line;
  final Color hole;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 16.0;
    const tip = _Tag.tip;

    // Drawn LTR with the point on the left, then mirrored for Arabic so the
    // point always sits at the reading start.
    final body = Path()
      ..moveTo(tip, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(tip, h)
      ..lineTo(0, h / 2)
      ..close();
    final punched = Path.combine(
      PathOperation.difference,
      body,
      Path()..addOval(Rect.fromCircle(center: Offset(tip * 0.62, h / 2), radius: 4.5)),
    );

    canvas.save();
    if (rtl) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawShadow(punched, Colors.black.withValues(alpha: 0.35), 3, true);
    canvas.drawPath(punched, Paint()..color = fill);
    canvas.drawPath(
      punched,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // The string hole shows the band behind it.
    canvas.drawCircle(
      Offset(tip * 0.62, h / 2),
      3.2,
      Paint()..color = hole,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TagPainter old) =>
      old.fill != fill || old.line != line || old.hole != hole || old.rtl != rtl;
}
