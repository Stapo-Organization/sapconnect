import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/analytics/events_buffer.dart';
import '../../../../../core/icons/zb_icons.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/price_text.dart';
import '../../../../../core/widgets/product_card_foot.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../core/widgets/zb_image.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';

/// What the six express card forms share.
///
/// إكسبريس is not one shelf, it is six different reasons to buy — what you
/// bought last time, what the branch is selling right now, what we picked for
/// your animal, what everyone buys, what is being cleared, what just landed.
/// Drawn with one card they read as one long section. So each gets a form of
/// its own, and the forms share only what must not drift between them: how a
/// product is opened, how its photo is mounted, how a rank is drawn, and how a
/// line of type is measured so a fixed-height row never clips at 130% type.
///
/// Every form is a *presentation* of the same [ProductCard]: the add control
/// is the very same morphing shell the standard card wears, so the count a
/// customer sees on «رائج الآن» is the count they see on «اشتريته سابقاً».

/// Opens the product page the way every card does, with the view attributed
/// to the slot it was tapped in.
void openProduct(
  BuildContext context,
  WidgetRef ref,
  ProductCard product, {
  String? zone,
}) {
  ref.track(ZbEvent(type: ZbEvents.view, itemCode: product.itemCode, zone: zone));
  context.push('/product/${product.id}', extra: product);
}

/// One rendered line of [style] at the card's clamped text scale — the same
/// arithmetic [ProductCardMetrics] uses, so a form's fixed height and the
/// pixels it paints come from one source.
double lineOf(BuildContext context, TextStyle? style, double fallbackSize, double fallbackHeight) =>
    ProductCardMetrics.scalerOf(context).scale(style?.fontSize ?? fallbackSize) *
    (style?.height ?? fallbackHeight);

/// Give inside every fixed-height form. A line of type can measure a pixel
/// taller than `fontSize × height` once the engine rounds each line up, and
/// a two-line name rounds twice; `RenderFlex` calls that an overflow. The
/// forms centre their text, so the give lands as breathing room, never as
/// a clipped slot.
const double formSlack = 4;

/// The text styles the forms measure against, resolved once per build.
extension CardFormLines on BuildContext {
  double get nameLine => lineOf(this, tt.titleSmall, 13.5, 1.4);
  double get bodyLine => lineOf(this, tt.bodyMedium, 14, 1.45);
  double get labelLine => lineOf(this, tt.labelSmall, 11, 1.3);
  double get labelMediumLine => lineOf(this, tt.labelMedium, 12, 1.3);
  double get priceLine => lineOf(this, tt.titleMedium, 15.5, 1.4);
  double get priceLargeLine => lineOf(this, tt.titleLarge, 20, 1.3);
  double get displayLine => lineOf(this, tt.headlineSmall, 24, 1.25);
}

/// The product photo, mounted.
///
/// Store photographs are shot on white, so the plate is the surface colour:
/// on a tinted card the white photo then reads as a deliberate mount rather
/// than as a white rectangle that forgot its background. The add control
/// rides the plate's bottom-end corner exactly as it does on the standard
/// card — the owner's call, the action where the eye already is.
class PhotoPlate extends StatelessWidget {
  const PhotoPlate({
    super.key,
    required this.product,
    this.onAdd,
    this.radius = ZbTokens.rMd,
    this.inset = 8,
    this.color,
    this.corner,
    this.addInset = 6,
    this.border = false,
    this.status = true,
  });

  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final double radius;
  final double inset;
  final Color? color;

  /// Something small in the top-start corner: a sticker, a rank coin.
  final Widget? corner;

  final double addInset;
  final bool border;

  /// Whether a sold-out plate says so on itself. Off for the small plates
  /// whose row already says it beside them.
  final bool status;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final l = L.of(context);
    final outOfStock = !product.inStock;
    final ground = color ?? (context.isDark ? cs.surfaceContainerHigh : cs.surface);

    final image = ZbImage(
      url: product.image,
      padding: EdgeInsets.all(inset),
      backgroundColor: ground,
    );

    return Container(
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: cs.outlineVariant) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        // The add control's shoulder badge overhangs its corner on purpose.
        clipBehavior: Clip.none,
        children: [
          outOfStock ? Opacity(opacity: 0.4, child: image) : image,
          if (corner != null) PositionedDirectional(top: 6, start: 6, child: corner!),
          if (outOfStock && status)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.inverseSurface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                ),
                child: Text(
                  l.cardOutOfStock,
                  maxLines: 1,
                  style: context.tt.labelSmall?.copyWith(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else if (!outOfStock && onAdd != null)
            PositionedDirectional(
              bottom: addInset,
              end: addInset,
              child: ProductCardAddOverlay(product: product, onAdd: onAdd),
            ),
        ],
      ),
    );
  }
}

/// A rank, as a coin. Filled for the podium, outlined after it.
class RankCoin extends StatelessWidget {
  const RankCoin({
    super.key,
    required this.rank,
    this.size = 22,
    this.filled = false,
    this.tone,
  });

  final int rank;
  final double size;
  final bool filled;

  /// The pair the coin is struck in; the trending badge pair by default.
  final ZbPair? tone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final pair = tone ?? context.zb.badgeTrending;
    final fg = filled ? pair.bg : pair.fg;
    final bg = filled ? pair.fg : cs.surface;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: filled ? pair.fg : pair.fg.withValues(alpha: 0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      // Built on the theme's label style, not a bare TextStyle: a coin that
      // sits straight in a sliver has no Material above it, and the default
      // there is the framework's monospace "you forgot a Material" face.
      child: Text(
        '$rank',
        style: (context.tt.labelSmall ?? const TextStyle()).copyWith(
          fontSize: size * 0.5,
          height: 1,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: fg,
        ),
      ),
    );
  }
}

/// The glyph that leads a section title — the one thing that says which of
/// the six reasons this is before the title is read. A tinted squircle, the
/// same size on every section, so the marks line up down the page like a
/// margin of chapter symbols.
class SectionMark extends StatelessWidget {
  const SectionMark({super.key, required this.pair, this.icon, this.glyph})
      : assert(icon != null || glyph != null);

  final ZbPair pair;
  final IconData? icon;
  final ZbIconKind? glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pair.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: glyph != null
          ? ZbIcon(glyph!, size: 17, ink: pair.fg)
          : Icon(icon, size: 17, color: pair.fg),
    );
  }
}

/// The price on one line: the «يبدأ من» prefix, the number, and the struck
/// original — scaled down rather than wrapped, because a price that wraps
/// stops being a price. The same treatment the standard card gives it.
class InlinePrice extends StatelessWidget {
  const InlinePrice({
    super.key,
    required this.product,
    this.style,
    this.color,
    this.compare = true,
    this.pill = false,
  });

  final ProductCard product;
  final TextStyle? style;
  final Color? color;

  /// Whether to show the struck-through regular price after the sale one.
  final bool compare;

  /// Whether to show the «-٣٠٪» pill instead of the struck price.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final regular = product.regularPrice;
    final showCompare = compare && product.onSale && regular != null && regular > product.price;
    final base = (style ?? context.tt.titleMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w800,
      color: color ?? cs.onSurface,
    );
    final muted = color == null ? cs.onSurfaceVariant : color!.withValues(alpha: 0.7);

    TextSpan money(double value, TextStyle s) => TextSpan(
          style: s,
          children: [
            TextSpan(text: Fmt.number(value, locale: locale)),
            const TextSpan(text: ' '),
            TextSpan(text: riyalSymbol, style: s.copyWith(fontSize: (s.fontSize ?? 15) * 0.86)),
          ],
        );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (product.priceFrom) ...[
            Text(l.priceFrom, style: context.tt.labelSmall?.copyWith(color: muted)),
            Gap.w4,
          ],
          Text.rich(money(product.price, base), maxLines: 1),
          if (showCompare && !pill) ...[
            Gap.w6,
            Text.rich(
              money(
                regular,
                (context.tt.bodySmall ?? const TextStyle()).copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: muted,
                ),
              ),
              maxLines: 1,
            ),
          ],
          if (pill && product.discountPercent > 0) ...[
            Gap.w6,
            DiscountPill(percent: product.discountPercent),
          ],
        ],
      ),
    );
  }
}
