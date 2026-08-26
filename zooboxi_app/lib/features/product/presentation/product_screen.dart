import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/badge_chip.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/price_text.dart';
import '../../../core/widgets/rail.dart';
import '../../../core/widgets/wishlist_heart.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/product_models.dart';
import '../../wishlist/data/wishlist_controller.dart';
import 'widgets/add_to_cart_bar.dart';
import 'widgets/delivery_card.dart';
import 'widgets/product_description.dart';
import 'widgets/product_gallery.dart';
import 'widgets/product_loading.dart';
import 'widgets/variation_picker.dart';
import 'widgets/warehouse_panel.dart';

/// The product page.
///
/// It opens with whatever card the customer tapped already painted — image,
/// name, price — so the transition lands on content rather than on a spinner,
/// and the detail request fills in the rest underneath.
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId, this.preview});

  final int productId;
  final ProductCard? preview;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  /// attribute slug → chosen option slug.
  final Map<String, String> _selection = {};
  int _qty = 1;
  bool _adding = false;
  bool _tracked = false;

  ProductVariation? _matchedVariation(ProductDetail detail) {
    if (!detail.hasVariations) return null;
    if (_selection.length < detail.attributes.length) return null;
    for (final variation in detail.variations) {
      if (variation.matches(_selection)) return variation;
    }
    return null;
  }

  /// The cap the stepper honours: the chosen variant's own limit if there is
  /// one, otherwise how many units can physically reach this customer.
  int? _maxQty(ProductDetail detail) {
    final variation = _matchedVariation(detail);
    final own = variation?.maxQty;
    // The variation-scoped delivery read speaks in this pack's units, so when
    // both ceilings exist the stepper honours the LOWER one — a units-blind
    // shelf number must never outrank what can actually be delivered.
    final reachable = detail.delivery.reachableTotal;
    if (own != null && reachable > 0) return own < reachable ? own : reachable;
    if (own != null) return own;
    if (reachable > 0) return reachable;
    return detail.card.stockQty;
  }

  double _price(ProductDetail detail) =>
      _matchedVariation(detail)?.price ?? detail.card.price;

  Future<void> _add(ProductDetail detail) async {
    final l = L.of(context);
    final variation = _matchedVariation(detail);

    // A variable product with an incomplete selection can't be added — say so
    // rather than silently adding the wrong flavour.
    if (detail.hasVariations && variation == null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.pdpSelectVariant)),
      );
      return;
    }

    setState(() => _adding = true);
    await addToCart(
      context,
      ref,
      product: detail.card,
      variationId: variation?.variationId,
      quantity: _qty,
      // A concrete variation carries its own combination server-side; sending
      // the slugs too only re-introduces encoding pitfalls. Attributes travel
      // only when no single variation could be resolved (an "Any …" axis).
      attributes: variation != null || _selection.isEmpty ? null : _selection,
      zone: 'pdp',
    );
    if (mounted) setState(() => _adding = false);
  }

  void _onLoaded(ProductDetail detail) {
    if (_tracked) return;
    _tracked = true;
    // Deferred out of build: these touch providers, local storage and state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.track(ZbEvent(type: ZbEvents.view, itemCode: detail.card.itemCode, zone: 'pdp'));
      ref.read(localStoreProvider).pushRecentlyViewed(detail.id);
      ref.read(wishlistControllerProvider.notifier).seedFrom([
        detail.card,
        ...detail.fbt,
        ...detail.substitutes,
      ]);

      // An axis with exactly one option isn't a choice — pre-select it so a
      // single-variant product doesn't demand a pointless tap before "add".
      final forced = <String, String>{
        for (final attribute in detail.attributes)
          if (attribute.options.length == 1) attribute.slug: attribute.options.first.slug,
      };
      if (forced.isNotEmpty) setState(() => _selection.addAll(forced));
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productProvider(widget.productId));

    if (detail.hasValue) {
      var data = detail.requireValue;
      _onLoaded(data);

      // A chosen pack (كرتون = N حبة) changes what the promise and warehouse
      // numbers MEAN — overlay the variation-scoped read the server converts.
      // The page itself never reloads; only the availability blocks swap.
      final matched = _matchedVariation(data);
      var availabilityRefreshing = false;
      if (matched != null) {
        final scoped = ref.watch(variationDeliveryProvider(
          (id: widget.productId, variationId: matched.variationId),
        ));
        availabilityRefreshing = scoped.isLoading;
        final scopedData = scoped.value;
        if (scopedData != null) {
          data = data.withAvailability(scopedData.delivery, scopedData.perWarehouse);
        }
      }

      return _Loaded(
        detail: data,
        selection: _selection,
        qty: _qty,
        adding: _adding,
        price: _price(data),
        maxQty: _maxQty(data),
        variation: matched,
        availabilityRefreshing: availabilityRefreshing,
        onSelect: (attribute, option) => setState(() {
          if (_selection[attribute] == option) {
            _selection.remove(attribute);
          } else {
            _selection[attribute] = option;
          }
          _qty = 1;
        }),
        onQty: (value) => setState(() => _qty = value),
        onAdd: () => _add(data),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: detail.hasError
          ? ErrorState(
              error: detail.error,
              onRetry: () => ref.invalidate(productProvider(widget.productId)),
            )
          : ProductLoadingView(preview: widget.preview),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.detail,
    required this.selection,
    required this.qty,
    required this.adding,
    required this.price,
    required this.maxQty,
    required this.variation,
    this.availabilityRefreshing = false,
    required this.onSelect,
    required this.onQty,
    required this.onAdd,
  });

  /// True while the variation-scoped availability read is in flight — the
  /// delivery blocks dim slightly instead of jumping numbers mid-read.
  final bool availabilityRefreshing;

  final ProductDetail detail;
  final Map<String, String> selection;
  final int qty;
  final bool adding;
  final double price;
  final int? maxQty;
  final ProductVariation? variation;
  final void Function(String attribute, String option) onSelect;
  final ValueChanged<int> onQty;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final card = detail.card;
    final outOfStock = !card.inStock || (maxQty != null && maxQty! <= 0);

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: WishlistHeart(
              productId: detail.id,
              seeded: card.wishlisted,
              size: 38,
              onSurface: true,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          ProductGallery(images: detail.images, heroImage: variation?.image),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.badges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final badge in detail.badges) BadgeChip(badge: badge),
                      ],
                    ),
                  ),
                if (card.brand != null)
                  Text(
                    card.brand!.name,
                    style: context.tt.labelMedium?.copyWith(color: cs.primary),
                  ),
                Gap.h4,
                Text(card.name, style: context.tt.headlineSmall),
                Gap.h12,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PriceText(
                      price: price,
                      regularPrice: variation?.regularPrice ?? card.regularPrice,
                      onSale: card.onSale,
                      style: context.tt.headlineMedium,
                    ),
                    Gap.w12,
                    DiscountPill(percent: card.discountPercent),
                  ],
                ),
                if (detail.langFallback) ...[
                  Gap.h12,
                  _FallbackNotice(message: l.pdpLangFallback),
                ],
              ],
            ),
          ),
          if (detail.hasVariations) ...[
            Gap.h20,
            VariationPicker(
              attributes: detail.attributes,
              variations: detail.variations,
              selection: selection,
              onSelect: onSelect,
            ),
          ],
          Gap.h20,
          AnimatedOpacity(
            opacity: availabilityRefreshing ? 0.45 : 1,
            duration: const Duration(milliseconds: 180),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DeliveryCard(delivery: detail.delivery),
                ),
                if (detail.perWarehouse.isNotEmpty) ...[
                  Gap.h12,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: WarehousePanel(rows: detail.perWarehouse),
                  ),
                ],
              ],
            ),
          ),
          if ((detail.descriptionHtml ?? detail.shortDescription ?? '').isNotEmpty) ...[
            Gap.h24,
            ProductDescription(detail: detail),
          ],
          if (detail.fbt.isNotEmpty) ...[
            Gap.h24,
            ProductRailView(
              title: l.pdpFbt,
              products: detail.fbt,
              zone: 'pdp_fbt',
              onAdd: (product) =>
                  addToCart(context, ref, product: product, zone: 'pdp_fbt', quiet: true),
            ),
          ],
          if (detail.substitutes.isNotEmpty) ...[
            Gap.h24,
            ProductRailView(
              title: l.pdpSubstitutes,
              products: detail.substitutes,
              zone: 'pdp_substitutes',
              onAdd: (product) =>
                  addToCart(context, ref, product: product, zone: 'pdp_substitutes', quiet: true),
            ),
          ],
        ],
      ),
      bottomNavigationBar: AddToCartBar(
        unitPrice: price,
        qty: qty,
        maxQty: maxQty,
        outOfStock: outOfStock,
        busy: adding,
        onQty: onQty,
        onAdd: onAdd,
      ),
    );
  }
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZbTokens.rXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.translate_rounded, size: 14, color: cs.onSurfaceVariant),
          Gap.w6,
          Flexible(
            child: Text(
              message,
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
