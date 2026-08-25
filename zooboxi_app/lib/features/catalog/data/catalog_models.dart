import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';
import 'product_models.dart';

/// Where a merchandising slot points. `type` is one of `category`, `product`,
/// `brand`, `search`, `url` — anything else is ignored rather than guessed at.
@immutable
class ZbLink {
  const ZbLink({required this.type, required this.value});

  final String type;
  final String value;

  static ZbLink? maybe(dynamic raw) {
    final map = asMap(raw);
    final type = asStringOrNull(map['type']);
    final value = asStringOrNull(map['value']);
    if (type == null || value == null) return null;
    return ZbLink(type: type, value: value);
  }

  /// The hero/campaign admin stores plain store URLs. Recognise the ones we
  /// can serve natively (brand and category archives, or a known product id)
  /// and fall back to opening the URL in a custom tab.
  static ZbLink? fromUrl(String? url, {int? productId}) {
    if (productId != null && productId > 0) {
      return ZbLink(type: 'product', value: '$productId');
    }
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final brandIndex = segments.indexOf('brand');
    if (brandIndex != -1 && brandIndex + 1 < segments.length) {
      return ZbLink(type: 'brand', value: segments[brandIndex + 1]);
    }
    final catIndex = segments.indexOf('product-category');
    if (catIndex != -1 && catIndex + 1 < segments.length) {
      return ZbLink(type: 'category', value: segments[catIndex + 1]);
    }
    return ZbLink(type: 'url', value: url);
  }
}

@immutable
class HeroSlide {
  const HeroSlide({
    this.image,
    this.imageMobile,
    this.title,
    this.subtitle,
    this.ctaLabel,
    this.linkUrl,
  });

  final String? image;

  /// Portrait crop uploaded for phones; prefer it when present.
  final String? imageMobile;
  final String? title;
  final String? subtitle;
  final String? ctaLabel;

  /// Plain URL (the slider admin stores links, not typed targets). The UI
  /// resolves store product/category URLs to in-app routes where it can.
  final String? linkUrl;

  String? get bestImage => imageMobile ?? image;

  // Server fields: image, image_mobile, headline, subheadline, cta_label, link.
  factory HeroSlide.fromJson(Map<String, dynamic> json) => HeroSlide(
        image: asStringOrNull(json['image']),
        imageMobile: asStringOrNull(json['image_mobile']),
        title: asStringOrNull(json['headline']) ?? asStringOrNull(json['title']),
        subtitle: asStringOrNull(json['subheadline']) ?? asStringOrNull(json['subtitle']),
        ctaLabel: asStringOrNull(json['cta_label']),
        linkUrl: asStringOrNull(json['link']),
      );
}

/// A merchandising campaign placement. [campaignId] and [abVariant] travel
/// back with every impression/click event so the server can measure lift.
@immutable
class Campaign {
  const Campaign({
    required this.campaignId,
    this.zones = const [],
    this.abVariant,
    this.headline,
    this.image,
    this.itemCode,
    this.productId,
    this.linkUrl,
  });

  final String campaignId;

  /// Placement zones this creative was approved for (hero, shop_top, …).
  final List<String> zones;
  final String? abVariant;
  final String? headline;
  final String? image;
  final String? itemCode;

  /// When the campaign promotes one product, navigate in-app by id —
  /// no URL parsing needed.
  final int? productId;
  final String? linkUrl;

  bool inZone(String zone) => zones.isEmpty || zones.contains(zone);

  // Server fields: campaign_id, ab_variant, zones[], image, headline,
  // item_code, product_id, link.
  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
        campaignId: asString(json['campaign_id']),
        zones: asStringList(json['zones']),
        abVariant: asStringOrNull(json['ab_variant']),
        headline: asStringOrNull(json['headline']),
        image: asStringOrNull(json['image']),
        itemCode: asStringOrNull(json['item_code']),
        productId: asIntOrNull(json['product_id']),
        linkUrl: asStringOrNull(json['link']),
      );
}

/// One circle in the "shop by pet" strip.
@immutable
class AnimalNavItem {
  const AnimalNavItem({required this.id, required this.slug, required this.name, this.image});

  final int id;
  final String slug;
  final String name;
  final String? image;

  factory AnimalNavItem.fromJson(Map<String, dynamic> json) => AnimalNavItem(
        id: asInt(json['id']),
        slug: asString(json['slug']),
        name: asString(json['name']),
        image: asStringOrNull(json['image']),
      );
}

/// A titled horizontal strip of products (trending, best sellers, new,
/// clearance). [key] identifies it for "see all" and for analytics.
@immutable
class ProductRail {
  const ProductRail({required this.key, required this.title, this.products = const []});

  final String key;
  final String title;
  final List<ProductCard> products;

  factory ProductRail.fromJson(Map<String, dynamic> json) => ProductRail(
        key: asString(json['key']),
        title: asString(json['title']),
        products: ProductCard.listFrom(json['products']),
      );
}

@immutable
class BrandSummary {
  const BrandSummary({required this.slug, required this.name, this.code, this.logo, this.accent});

  final String slug;
  final String name;
  final String? code;
  final String? logo;
  final String? accent;

  factory BrandSummary.fromJson(Map<String, dynamic> json) => BrandSummary(
        slug: asString(json['slug']),
        name: asString(json['name']),
        code: asStringOrNull(json['code']),
        logo: asStringOrNull(json['logo']),
        accent: asStringOrNull(json['accent']),
      );
}

/// `GET /home` — everything above the fold, in one round trip.
@immutable
class HomePayload {
  const HomePayload({
    this.hero = const [],
    this.campaigns = const [],
    this.animalNav = const [],
    this.rails = const [],
    this.brands = const [],
  });

  final List<HeroSlide> hero;
  final List<Campaign> campaigns;
  final List<AnimalNavItem> animalNav;
  final List<ProductRail> rails;
  final List<BrandSummary> brands;

  bool get isEmpty =>
      hero.isEmpty && campaigns.isEmpty && animalNav.isEmpty && rails.isEmpty && brands.isEmpty;

  factory HomePayload.fromJson(Map<String, dynamic> json) => HomePayload(
        hero: asMapList(json['hero']).map(HeroSlide.fromJson).toList(),
        campaigns: asMapList(json['campaigns']).map(Campaign.fromJson).toList(),
        animalNav: asMapList(json['animal_nav']).map(AnimalNavItem.fromJson).toList(),
        rails: asMapList(json['rails'])
            .map(ProductRail.fromJson)
            .where((rail) => rail.products.isNotEmpty)
            .toList(),
        brands: asMapList(json['brands']).map(BrandSummary.fromJson).toList(),
      );
}

/// A category, possibly with children (the tree arrives one level at a time).
@immutable
class CategoryNode {
  const CategoryNode({
    required this.id,
    required this.slug,
    required this.name,
    this.image,
    this.count = 0,
    this.children = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String? image;
  final int count;
  final List<CategoryNode> children;

  bool get hasChildren => children.isNotEmpty;

  factory CategoryNode.fromJson(Map<String, dynamic> json) => CategoryNode(
        id: asInt(json['id']),
        slug: asString(json['slug']),
        name: asString(json['name']),
        image: asStringOrNull(json['image']),
        count: asInt(json['count']),
        children: asMapList(json['children']).map(CategoryNode.fromJson).toList(),
      );
}

@immutable
class FacetTerm {
  const FacetTerm({required this.slug, required this.name, this.count = 0});

  final String slug;
  final String name;
  final int count;

  factory FacetTerm.fromJson(Map<String, dynamic> json) => FacetTerm(
        slug: asString(json['slug']),
        name: asString(json['name']),
        count: asInt(json['count']),
      );
}

/// One filter axis, e.g. `pa_flavour` → "النكهة".
@immutable
class FacetGroup {
  const FacetGroup({required this.taxonomy, required this.label, this.terms = const []});

  final String taxonomy;
  final String label;
  final List<FacetTerm> terms;

  factory FacetGroup.fromJson(Map<String, dynamic> json) => FacetGroup(
        taxonomy: asString(json['taxonomy']),
        label: asString(json['label']),
        terms: asMapList(json['terms']).map(FacetTerm.fromJson).toList(),
      );
}

@immutable
class PriceFacet {
  const PriceFacet({required this.min, required this.max});

  final double min;
  final double max;

  bool get isUsable => max > min;

  factory PriceFacet.fromJson(Map<String, dynamic> json) =>
      PriceFacet(min: asDouble(json['min']), max: asDouble(json['max']));
}

@immutable
class SortOption {
  const SortOption({required this.key, required this.label});

  final String key;
  final String label;

  factory SortOption.fromJson(Map<String, dynamic> json) =>
      SortOption(key: asString(json['key']), label: asString(json['label']));
}

/// One page of `GET /catalog/products`, with the facets and sorts that apply
/// to *this* result set (they narrow as filters are applied).
@immutable
class ListingResult {
  const ListingResult({
    this.products = const [],
    this.total = 0,
    this.pages = 1,
    this.page = 1,
    this.facets = const [],
    this.price,
    this.sortOptions = const [],
  });

  final List<ProductCard> products;
  final int total;
  final int pages;
  final int page;
  final List<FacetGroup> facets;
  final PriceFacet? price;
  final List<SortOption> sortOptions;

  bool get hasMore => page < pages;

  factory ListingResult.fromJson(Map<String, dynamic> json) {
    final facetsJson = asMap(json['facets']);
    final priceJson = asMap(facetsJson['price']);
    return ListingResult(
      products: ProductCard.listFrom(json['products']),
      total: asInt(json['total']),
      pages: asInt(json['pages'], fallback: 1),
      page: asInt(json['page'], fallback: 1),
      facets: asMapList(facetsJson['groups']).map(FacetGroup.fromJson).toList(),
      price: priceJson.isEmpty ? null : PriceFacet.fromJson(priceJson),
      sortOptions: asMapList(json['sort_options']).map(SortOption.fromJson).toList(),
    );
  }
}

/// The filter state a listing screen owns. Kept immutable and value-equal so
/// it can key a provider family — changing any field re-queries.
@immutable
class ListingQuery {
  const ListingQuery({
    this.category,
    this.brand,
    this.q,
    this.sku,
    this.attributes = const {},
    this.minPrice,
    this.maxPrice,
    this.orderBy,
    this.perPage = 20,
  });

  final String? category;
  final String? brand;
  final String? q;
  final String? sku;

  /// `pa_*` taxonomy → selected term slugs.
  final Map<String, Set<String>> attributes;
  final double? minPrice;
  final double? maxPrice;
  final String? orderBy;
  final int perPage;

  int get activeFilterCount =>
      attributes.values.fold<int>(0, (sum, terms) => sum + terms.length) +
      ((minPrice != null || maxPrice != null) ? 1 : 0);

  bool get hasFilters => activeFilterCount > 0;

  ListingQuery copyWith({
    String? category,
    String? brand,
    String? q,
    Map<String, Set<String>>? attributes,
    double? minPrice,
    double? maxPrice,
    String? orderBy,
    bool clearPrice = false,
    bool clearOrderBy = false,
  }) =>
      ListingQuery(
        category: category ?? this.category,
        brand: brand ?? this.brand,
        q: q ?? this.q,
        sku: sku,
        attributes: attributes ?? this.attributes,
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        orderBy: clearOrderBy ? null : (orderBy ?? this.orderBy),
        perPage: perPage,
      );

  /// Drops facet + price filters, keeping the scope (category/brand/query).
  ListingQuery cleared() => ListingQuery(
        category: category,
        brand: brand,
        q: q,
        sku: sku,
        orderBy: orderBy,
        perPage: perPage,
      );

  Map<String, dynamic> toQueryParameters(int page) => {
        if (category != null) 'category': category,
        if (brand != null) 'brand': brand,
        if (q != null && q!.isNotEmpty) 'q': q,
        if (sku != null) 'sku': sku,
        for (final entry in attributes.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.join(','),
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (orderBy != null) 'orderby': orderBy,
        'page': page,
        'per_page': perPage,
      };

  @override
  bool operator ==(Object other) =>
      other is ListingQuery &&
      other.category == category &&
      other.brand == brand &&
      other.q == q &&
      other.sku == sku &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.orderBy == orderBy &&
      other.perPage == perPage &&
      _sameAttributes(other.attributes);

  bool _sameAttributes(Map<String, Set<String>> other) {
    if (other.length != attributes.length) return false;
    for (final entry in attributes.entries) {
      final mine = entry.value;
      final theirs = other[entry.key];
      if (theirs == null || theirs.length != mine.length || !theirs.containsAll(mine)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        category,
        brand,
        q,
        sku,
        minPrice,
        maxPrice,
        orderBy,
        perPage,
        Object.hashAllUnordered(
          attributes.entries.map((e) => Object.hash(e.key, Object.hashAllUnordered(e.value))),
        ),
      );
}

/// `GET /meta` — the remote kill-switches and constants the app must respect.
@immutable
class MetaConfig {
  const MetaConfig({
    this.minIosVersion,
    this.minAndroidVersion,
    this.freeShippingMin,
    this.fees = const {},
    this.currency,
    this.features = const {},
    this.maintenance = false,
  });

  final String? minIosVersion;
  final String? minAndroidVersion;
  final double? freeShippingMin;

  /// `express` / `standard` / `shipping` → fee.
  final Map<String, double> fees;
  final String? currency;
  final Map<String, bool> features;
  final bool maintenance;

  bool feature(String key, {bool fallback = false}) => features[key] ?? fallback;

  factory MetaConfig.fromJson(Map<String, dynamic> json) {
    final minVersion = asMap(json['min_app_version']);
    final fees = <String, double>{};
    asMap(json['fees']).forEach((k, v) => fees[k] = asDouble(v));
    final features = <String, bool>{};
    asMap(json['features']).forEach((k, v) => features[k] = asBool(v));

    return MetaConfig(
      minIosVersion: asStringOrNull(minVersion['ios']),
      minAndroidVersion: asStringOrNull(minVersion['android']),
      freeShippingMin: asDoubleOrNull(json['free_shipping_min']),
      fees: fees,
      currency: asStringOrNull(json['currency']),
      features: features,
      maintenance: asBool(json['maintenance']),
    );
  }
}

/// `GET /brands/{slug}` — a brand boutique page.
@immutable
class BrandPage {
  const BrandPage({
    required this.brand,
    this.accentDark,
    this.tagline,
    this.hero,
    this.story,
    this.country,
    this.founded,
    this.tiles = const [],
    this.categories = const [],
    this.products = const [],
  });

  final BrandSummary brand;
  final String? accentDark;
  final String? tagline;
  final String? hero;
  final String? story;
  final String? country;
  final String? founded;
  final List<String> tiles;
  final List<CategoryNode> categories;
  final List<ProductCard> products;

  factory BrandPage.fromJson(String slug, Map<String, dynamic> json) {
    final kit = asMap(json['kit']);
    // story arrives as { lead, country, founded, mood } — join what exists
    // into one readable paragraph; tiles as [{ image, headline }].
    final storyJson = asMap(json['story']);
    final storyParts = <String>[
      for (final key in ['lead', 'mood'])
        if (asStringOrNull(storyJson[key]) != null) asString(storyJson[key]),
    ];
    return BrandPage(
      brand: BrandSummary(
        slug: slug,
        name: asString(json['name'], fallback: slug),
        code: asStringOrNull(json['code']),
        logo: asStringOrNull(json['logo']),
        accent: asStringOrNull(kit['accent']),
      ),
      accentDark: asStringOrNull(kit['accent_dark']),
      tagline: asStringOrNull(kit['tagline']),
      hero: asStringOrNull(json['hero']),
      story: storyParts.isEmpty ? asStringOrNull(json['story']) : storyParts.join('\n\n'),
      country: asStringOrNull(storyJson['country']),
      founded: asStringOrNull(storyJson['founded']),
      tiles: [
        for (final tile in asMapList(json['tiles']))
          if (asStringOrNull(tile['image']) != null) asString(tile['image']),
      ],
      categories: asMapList(json['categories']).map(CategoryNode.fromJson).toList(),
      products: ProductCard.listFrom(json['products']),
    );
  }
}
