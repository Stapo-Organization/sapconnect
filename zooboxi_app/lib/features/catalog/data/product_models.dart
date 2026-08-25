import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';

/// A brand reference as it appears on a card or a product page.
@immutable
class BrandRef {
  const BrandRef({required this.name, this.slug, this.code, this.accent, this.logo});

  final String name;
  final String? slug;
  final String? code;

  /// Hex accent from the brand kit, e.g. `#429D9C`. Parsed lazily by the UI.
  final String? accent;
  final String? logo;

  factory BrandRef.fromJson(Map<String, dynamic> json) => BrandRef(
        name: asString(json['name']),
        slug: asStringOrNull(json['slug']),
        code: asStringOrNull(json['code']),
        accent: asStringOrNull(json['accent']),
        logo: asStringOrNull(json['logo']),
      );

  static BrandRef? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final brand = BrandRef.fromJson(map);
    return brand.name.isEmpty ? null : brand;
  }
}

/// A merchandising badge computed server-side (`hot`, `trending`, `new`,
/// `low_stock`, `back_in_stock`). The label arrives already localized; the app
/// only maps [type] to a color pair.
@immutable
class ProductBadge {
  const ProductBadge({required this.type, required this.label, this.icon});

  final String type;
  final String label;

  /// Emoji supplied by the server, e.g. 🔥.
  final String? icon;

  factory ProductBadge.fromJson(Map<String, dynamic> json) => ProductBadge(
        type: asString(json['type']),
        label: asString(json['label']),
        icon: asStringOrNull(json['icon']),
      );

  static ProductBadge? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final badge = ProductBadge.fromJson(map);
    return badge.label.isEmpty ? null : badge;
  }
}

/// The little "2 hours" / "tomorrow" chip on a card, resolved for the
/// customer's current location.
@immutable
class DeliveryChip {
  const DeliveryChip({required this.tier, required this.label, this.icon});

  final String tier;
  final String label;
  final String? icon;

  factory DeliveryChip.fromJson(Map<String, dynamic> json) => DeliveryChip(
        tier: asString(json['tier'], fallback: 'shipping'),
        label: asString(json['label']),
        icon: asStringOrNull(json['icon']),
      );

  static DeliveryChip? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final chip = DeliveryChip.fromJson(map);
    return chip.label.isEmpty ? null : chip;
  }
}

/// The card DTO — the single product shape used by rails, grids, search
/// results, wishlist, buy-again and the "frequently bought" strips.
@immutable
class ProductCard {
  const ProductCard({
    required this.id,
    required this.name,
    this.itemCode,
    this.brand,
    this.image,
    this.price = 0,
    this.regularPrice,
    this.salePrice,
    this.onSale = false,
    this.priceFrom = false,
    this.currency,
    this.stockStatus = 'instock',
    this.stockQty,
    this.isVariable = false,
    this.badge,
    this.deliveryChip,
    this.wishlisted = false,
  });

  final int id;
  final String name;
  final String? itemCode;
  final BrandRef? brand;
  final String? image;

  /// The price the customer pays now.
  final double price;
  final double? regularPrice;
  final double? salePrice;
  final bool onSale;

  /// True for variable products where the shown price is the cheapest variant
  /// — the UI prefixes it with "يبدأ من".
  final bool priceFrom;
  final String? currency;

  /// `instock` | `outofstock` | `onbackorder`, already location-aware.
  final String stockStatus;
  final int? stockQty;
  final bool isVariable;
  final ProductBadge? badge;
  final DeliveryChip? deliveryChip;
  final bool wishlisted;

  bool get inStock => stockStatus != 'outofstock';

  /// Only shown when there is a real saving to show.
  int get discountPercent {
    final regular = regularPrice;
    if (!onSale || regular == null || regular <= price) return 0;
    return (((regular - price) / regular) * 100).floor();
  }

  factory ProductCard.fromJson(Map<String, dynamic> json) => ProductCard(
        id: asInt(json['id']),
        name: asString(json['name']),
        itemCode: asStringOrNull(json['item_code']),
        brand: BrandRef.maybe(json['brand']),
        image: asStringOrNull(json['image']),
        price: asDouble(json['price']),
        regularPrice: asDoubleOrNull(json['regular_price']),
        salePrice: asDoubleOrNull(json['sale_price']),
        onSale: asBool(json['on_sale']),
        priceFrom: asBool(json['price_from']),
        currency: asStringOrNull(json['currency']),
        stockStatus: asString(json['stock_status'], fallback: 'instock'),
        stockQty: asIntOrNull(json['stock_qty']),
        isVariable: asBool(json['is_variable']),
        badge: ProductBadge.maybe(json['badge']),
        deliveryChip: DeliveryChip.maybe(json['delivery_chip']),
        wishlisted: asBool(json['wishlisted']),
      );

  static List<ProductCard> listFrom(dynamic value) =>
      asMapList(value).map(ProductCard.fromJson).toList();

  /// The PDP swaps in the richer `brand_detail` (code + kit accent + logo).
  ProductCard copyWithBrand(BrandRef brand) => ProductCard(
        id: id,
        name: name,
        itemCode: itemCode,
        brand: brand,
        image: image,
        price: price,
        regularPrice: regularPrice,
        salePrice: salePrice,
        onSale: onSale,
        priceFrom: priceFrom,
        currency: currency,
        stockStatus: stockStatus,
        stockQty: stockQty,
        isVariable: isVariable,
        badge: badge,
        deliveryChip: deliveryChip,
        wishlisted: wishlisted,
      );

  ProductCard copyWith({bool? wishlisted}) => ProductCard(
        id: id,
        name: name,
        itemCode: itemCode,
        brand: brand,
        image: image,
        price: price,
        regularPrice: regularPrice,
        salePrice: salePrice,
        onSale: onSale,
        priceFrom: priceFrom,
        currency: currency,
        stockStatus: stockStatus,
        stockQty: stockQty,
        isVariable: isVariable,
        badge: badge,
        deliveryChip: deliveryChip,
        wishlisted: wishlisted ?? this.wishlisted,
      );
}

/// One row of the delivery promise card on a product page: a warehouse that
/// holds stock, the tier it serves under, and the dated promise.
@immutable
class DeliveryTier {
  const DeliveryTier({
    required this.tier,
    this.warehouseName,
    this.stock = 0,
    this.fee,
    this.label,
    this.dateLabel,
    this.relativeLabel,
    this.color,
    this.icon,
  });

  final String tier;
  final String? warehouseName;
  final int stock;
  final double? fee;

  /// Tier name in the customer's language, e.g. "توصيل سريع".
  final String? label;

  /// Concrete date, e.g. "الأربعاء 27 أغسطس".
  final String? dateLabel;

  /// Relative phrasing, e.g. "خلال ساعتين".
  final String? relativeLabel;

  /// Server-suggested hex. The app prefers its own tier palette and treats
  /// this as advisory only, so a theme change can't be undone by the server.
  final String? color;
  final String? icon;

  factory DeliveryTier.fromJson(Map<String, dynamic> json) => DeliveryTier(
        tier: asString(json['tier'], fallback: 'shipping'),
        warehouseName: asStringOrNull(json['warehouse_name']),
        stock: asInt(json['stock']),
        fee: asDoubleOrNull(json['fee']),
        label: asStringOrNull(json['label']),
        dateLabel: asStringOrNull(json['date_label']),
        relativeLabel: asStringOrNull(json['relative_label']),
        color: asStringOrNull(json['color']),
        icon: asStringOrNull(json['icon']),
      );
}

/// The full delivery projection for a product at the current location.
@immutable
class DeliveryInfo {
  const DeliveryInfo({this.headline, this.tiers = const [], this.reachableTotal = 0});

  /// One-line summary, e.g. "يصلك خلال ساعتين من فرع النخيل".
  final String? headline;
  final List<DeliveryTier> tiers;

  /// How many units can actually reach this customer across all tiers — the
  /// real cap on the quantity stepper.
  final int reachableTotal;

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) => DeliveryInfo(
        headline: asStringOrNull(json['headline']),
        tiers: asMapList(json['tiers']).map(DeliveryTier.fromJson).toList(),
        reachableTotal: asInt(json['reachable_total']),
      );
}

/// A per-warehouse stock line for the expandable availability panel.
@immutable
class WarehouseAvailability {
  const WarehouseAvailability({required this.warehouseName, required this.tier, this.stock = 0});

  final String warehouseName;
  final String tier;
  final int stock;

  factory WarehouseAvailability.fromJson(Map<String, dynamic> json) => WarehouseAvailability(
        warehouseName: asString(json['warehouse_name']),
        tier: asString(json['tier'], fallback: 'shipping'),
        stock: asInt(json['stock']),
      );
}

/// One selectable option inside an attribute, e.g. "دجاج 🍗".
@immutable
class VariationOption {
  const VariationOption({required this.slug, required this.label, this.emoji});

  final String slug;
  final String label;
  final String? emoji;

  factory VariationOption.fromJson(Map<String, dynamic> json) => VariationOption(
        slug: asString(json['slug']),
        label: asString(json['label']),
        emoji: asStringOrNull(json['emoji']),
      );
}

/// An attribute axis, e.g. "النكهة" with its options.
@immutable
class VariationAttribute {
  const VariationAttribute({required this.slug, required this.label, this.options = const []});

  final String slug;
  final String label;
  final List<VariationOption> options;

  factory VariationAttribute.fromJson(Map<String, dynamic> json) => VariationAttribute(
        slug: asString(json['slug']),
        label: asString(json['label']),
        options: asMapList(json['options']).map(VariationOption.fromJson).toList(),
      );
}

/// A concrete purchasable variant: the combination plus its own price, image
/// and stock cap.
@immutable
class ProductVariation {
  const ProductVariation({
    required this.variationId,
    required this.attributes,
    this.price = 0,
    this.regularPrice,
    this.image,
    this.inStock = true,
    this.maxQty,
  });

  final int variationId;

  /// attribute slug → option slug.
  final Map<String, String> attributes;
  final double price;
  final double? regularPrice;
  final String? image;
  final bool inStock;
  final int? maxQty;

  factory ProductVariation.fromJson(Map<String, dynamic> json) => ProductVariation(
        variationId: asInt(json['variation_id']),
        attributes: asMap(json['attributes'])
            .map((key, value) => MapEntry(key, asString(value))),
        price: asDouble(json['price']),
        regularPrice: asDoubleOrNull(json['regular_price']),
        image: asStringOrNull(json['image']),
        inStock: asBool(json['in_stock'], fallback: true),
        maxQty: asIntOrNull(json['max_qty']),
      );

  /// Whether this variant satisfies a (possibly partial) selection.
  bool matches(Map<String, String> selection) =>
      selection.entries.every((e) => attributes[e.key] == e.value);
}

/// The product page payload: the card plus everything that only matters once
/// someone is actually looking at the product.
@immutable
class ProductDetail {
  const ProductDetail({
    required this.card,
    this.gallery = const [],
    this.descriptionHtml,
    this.shortDescription,
    this.attributes = const [],
    this.variations = const [],
    this.delivery = const DeliveryInfo(),
    this.perWarehouse = const [],
    this.badges = const [],
    this.fbt = const [],
    this.substitutes = const [],
    this.langFallback = false,
  });

  final ProductCard card;
  final List<String> gallery;
  final String? descriptionHtml;
  final String? shortDescription;
  final List<VariationAttribute> attributes;
  final List<ProductVariation> variations;
  final DeliveryInfo delivery;
  final List<WarehouseAvailability> perWarehouse;
  final List<ProductBadge> badges;

  /// "Frequently bought together" — from the Laravel recommendations engine.
  final List<ProductCard> fbt;
  final List<ProductCard> substitutes;

  /// True when English was requested but only the Arabic content exists.
  final bool langFallback;

  int get id => card.id;
  String get name => card.name;
  bool get hasVariations => attributes.isNotEmpty && variations.isNotEmpty;

  /// Images to show in the gallery — the main image first, never duplicated.
  List<String> get images {
    final main = card.image;
    final all = <String>[if (main != null && main.isNotEmpty) main, ...gallery];
    return all.toSet().toList();
  }

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final variationsJson = asMap(json['variations']);
    // The PDP payload carries a richer brand_detail (code, kit accent, logo)
    // alongside the card's plain brand — prefer it.
    final base = ProductCard.fromJson(json);
    final brandDetail = BrandRef.maybe(json['brand_detail']);
    return ProductDetail(
      card: brandDetail == null ? base : base.copyWithBrand(brandDetail),
      gallery: asStringList(json['gallery']),
      descriptionHtml: asStringOrNull(json['description_html']),
      shortDescription: asStringOrNull(json['short_description']),
      attributes:
          asMapList(variationsJson['attributes']).map(VariationAttribute.fromJson).toList(),
      variations: asMapList(variationsJson['list']).map(ProductVariation.fromJson).toList(),
      delivery: DeliveryInfo.fromJson(asMap(json['delivery'])),
      perWarehouse:
          asMapList(json['per_warehouse']).map(WarehouseAvailability.fromJson).toList(),
      badges: asMapList(json['badges']).map(ProductBadge.fromJson).toList(),
      fbt: ProductCard.listFrom(json['fbt']),
      substitutes: ProductCard.listFrom(json['substitutes']),
      langFallback: asBool(json['lang_fallback']),
    );
  }

  ProductDetail copyWith({ProductCard? card}) => ProductDetail(
        card: card ?? this.card,
        gallery: gallery,
        descriptionHtml: descriptionHtml,
        shortDescription: shortDescription,
        attributes: attributes,
        variations: variations,
        delivery: delivery,
        perWarehouse: perWarehouse,
        badges: badges,
        fbt: fbt,
        substitutes: substitutes,
        langFallback: langFallback,
      );
}

/// A search-suggest row — deliberately lighter than a card.
@immutable
class SearchSuggestion {
  const SearchSuggestion({
    required this.id,
    required this.name,
    this.image,
    this.price,
    this.itemCode,
  });

  final int id;
  final String name;
  final String? image;
  final double? price;
  final String? itemCode;

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) => SearchSuggestion(
        id: asInt(json['id']),
        name: asString(json['name']),
        image: asStringOrNull(json['image']),
        price: asDoubleOrNull(json['price']),
        itemCode: asStringOrNull(json['item_code']),
      );
}
