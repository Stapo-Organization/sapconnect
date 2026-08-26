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
    this.kind = 'manual',
    this.image,
    this.imageMobile,
    this.title,
    this.subtitle,
    this.ctaLabel,
    this.linkUrl,
    this.theme,
    this.brand,
    this.productImages = const [],
    this.badge,
  });

  /// `manual` — an uploaded banner image. `auto` — a slide the server composed
  /// from live merchandising (express stock, clearance, a brand, bestsellers);
  /// it ships copy and product art, and the app draws it natively.
  final String kind;

  final String? image;

  /// Portrait crop uploaded for phones; prefer it when present.
  final String? imageMobile;
  final String? title;
  final String? subtitle;
  final String? ctaLabel;

  /// Plain URL (the slider admin stores links, not typed targets). The UI
  /// resolves store product/category URLs to in-app routes where it can.
  final String? linkUrl;

  /// Auto slides only: `express` | `clearance` | `brand` | `bestsellers`.
  final String? theme;

  /// Auto slides only, on the `brand` theme.
  final BrandRef? brand;

  /// Auto slides only: up to four product photos to compose into the slide.
  final List<String> productImages;

  /// Auto slides only: a merchandising kicker with a real number in it
  /// ("خصم حتى 45%"). Null when the data can't honestly back one.
  final String? badge;

  bool get isAuto => kind == 'auto';

  String? get bestImage => imageMobile ?? image;

  // Server fields: kind, image, image_mobile, headline, subheadline,
  // cta_label, link, theme, brand{name,logo}, product_images[].
  factory HeroSlide.fromJson(Map<String, dynamic> json) => HeroSlide(
        kind: asString(json['kind'], fallback: 'manual'),
        image: asStringOrNull(json['image']),
        imageMobile: asStringOrNull(json['image_mobile']),
        title: asStringOrNull(json['headline']) ?? asStringOrNull(json['title']),
        subtitle: asStringOrNull(json['subheadline']) ?? asStringOrNull(json['subtitle']),
        ctaLabel: asStringOrNull(json['cta_label']),
        linkUrl: asStringOrNull(json['link']),
        theme: asStringOrNull(json['theme']),
        brand: BrandRef.maybe(json['brand']),
        productImages: asStringList(json['product_images']),
        badge: asStringOrNull(json['badge']),
      );
}

/// A merchandising campaign placement. [campaignId] and [abVariant] travel
/// back with every impression/click event so the server can measure lift.
///
/// Creatives arrive per format (`hero`, `wide`, `card`, `strip`, `app_hero`)
/// because one crop cannot serve a 4:1 strip and a 2:1 hero. The copy travels
/// *beside* the artwork rather than baked into it: the app composes headline,
/// badge, coupon and countdown natively, so nothing is ever cropped mid-word
/// and every chip respects the theme and the reading direction.
@immutable
class Campaign {
  const Campaign({
    required this.campaignId,
    this.zones = const [],
    this.abVariant,
    this.campaignType,
    this.headline,
    this.subheadline,
    this.cta,
    this.badge,
    this.couponCode,
    this.discountPct,
    this.startsAt,
    this.endsAt,
    this.creatives = const {},
    this.itemCode,
    this.productId,
    this.linkUrl,
  });

  final String campaignId;

  /// Placement zones this creative was approved for (hero, shop_top, …).
  final List<String> zones;
  final String? abVariant;

  /// `clearance` | `bundle` | `visibility` … — drives the accent, not layout.
  final String? campaignType;

  final String? headline;
  final String? subheadline;
  final String? cta;

  /// Short kicker rendered as a pill above the headline ("عرض محدود").
  final String? badge;

  final String? couponCode;
  final int? discountPct;
  final DateTime? startsAt;

  /// Drives the urgency chip. Null means "no deadline worth showing".
  final DateTime? endsAt;

  /// format → url.
  final Map<String, String> creatives;

  final String? itemCode;

  /// When the campaign promotes one product, navigate in-app by id —
  /// no URL parsing needed.
  final int? productId;
  final String? linkUrl;

  bool inZone(String zone) => zones.isEmpty || zones.contains(zone);

  /// True when the campaign was approved for *any* of [candidates]. A campaign
  /// with no zones at all is unrestricted, as in [inZone].
  bool inAnyZone(List<String> candidates) =>
      zones.isEmpty || candidates.any(zones.contains);

  /// First creative present in [preferredFormats] order, or null. Callers pass
  /// the shapes they can actually lay out, best fit first.
  String? artFor(List<String> preferredFormats) {
    for (final format in preferredFormats) {
      final url = creatives[format];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  // Server fields: campaign_id, ab_variant, zones[], campaign_type, headline,
  // subheadline, cta, badge, coupon_code, discount_pct, starts_at, ends_at,
  // creatives{}, item_code, product_id, link.
  factory Campaign.fromJson(Map<String, dynamic> json) {
    final creatives = <String, String>{};
    asMap(json['creatives']).forEach((key, value) {
      final url = asStringOrNull(value);
      if (url != null) creatives[key] = url;
    });
    // v1 payloads shipped a single flat `image`. Treat it as the hero crop so
    // an older server keeps rendering instead of going blank.
    final legacy = asStringOrNull(json['image']);
    if (creatives.isEmpty && legacy != null) creatives['hero'] = legacy;

    return Campaign(
      campaignId: asString(json['campaign_id']),
      zones: asStringList(json['zones']),
      abVariant: asStringOrNull(json['ab_variant']),
      campaignType: asStringOrNull(json['campaign_type']),
      headline: asStringOrNull(json['headline']),
      subheadline: asStringOrNull(json['subheadline']),
      cta: asStringOrNull(json['cta']),
      badge: asStringOrNull(json['badge']),
      couponCode: asStringOrNull(json['coupon_code']),
      discountPct: asIntOrNull(json['discount_pct']),
      startsAt: asDate(json['starts_at']),
      endsAt: asDate(json['ends_at']),
      creatives: creatives,
      itemCode: asStringOrNull(json['item_code']),
      productId: asIntOrNull(json['product_id']),
      linkUrl: asStringOrNull(json['link']),
    );
  }
}

/// One circle in the "shop by pet" strip.
@immutable
class AnimalNavItem {
  const AnimalNavItem({
    required this.id,
    required this.slug,
    required this.name,
    this.image,
    this.icon,
  });

  final int id;
  final String slug;
  final String name;

  /// Commissioned artwork. Preferred whenever it exists.
  final String? image;

  /// Emoji the server ships alongside the artwork (🐱, 🐶). It is the fallback
  /// for a category whose photo is missing or fails to load — a recognisable
  /// animal beats a generic placeholder glyph.
  final String? icon;

  factory AnimalNavItem.fromJson(Map<String, dynamic> json) => AnimalNavItem(
        id: asInt(json['id']),
        slug: asString(json['slug']),
        name: asString(json['name']),
        image: asStringOrNull(json['image']),
        icon: asStringOrNull(json['icon']),
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

/// One entry in the server-driven home order.
///
/// The server merchandises the page: it decides that clearance runs above the
/// new arrivals today and below them tomorrow. The app renders whatever it is
/// handed and **skips a `type` it does not know**, so the server can ship a new
/// slot before the app that draws it has shipped.
@immutable
class HomeLayoutSlot {
  const HomeLayoutSlot(this.type, {this.key, this.index});

  final String type;

  /// Which rail (`trending`, `foryou`, …) for `rail` / `feed_rail` slots.
  final String? key;

  /// Which campaign out of the banner pool, for `banner` slots.
  final int? index;

  factory HomeLayoutSlot.fromJson(Map<String, dynamic> json) => HomeLayoutSlot(
        asString(json['type']),
        key: asStringOrNull(json['key']),
        index: asIntOrNull(json['index']),
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
    this.layout = const [],
  });

  final List<HeroSlide> hero;
  final List<Campaign> campaigns;
  final List<AnimalNavItem> animalNav;
  final List<ProductRail> rails;
  final List<BrandSummary> brands;

  /// Empty means "use [defaultLayout]" — an older server, or a payload that
  /// predates the layout engine.
  final List<HomeLayoutSlot> layout;

  /// The order the app falls back to when the server sends none.
  static const List<HomeLayoutSlot> defaultLayout = [
    HomeLayoutSlot('hero'),
    HomeLayoutSlot('animal_nav'),
    HomeLayoutSlot('personal'),
    HomeLayoutSlot('shipping_nudge'),
    HomeLayoutSlot('rail', key: 'trending'),
    HomeLayoutSlot('banner', index: 0),
    HomeLayoutSlot('feed_rail', key: 'foryou'),
    HomeLayoutSlot('rail', key: 'bestsellers'),
    HomeLayoutSlot('feed_rail', key: 'incity'),
    HomeLayoutSlot('clearance_band'),
    HomeLayoutSlot('rail', key: 'new'),
    HomeLayoutSlot('banner', index: 1),
    HomeLayoutSlot('wishlist_rail'),
    HomeLayoutSlot('brands'),
    HomeLayoutSlot('trust'),
  ];

  List<HomeLayoutSlot> get slots => layout.isEmpty ? defaultLayout : layout;

  bool get isEmpty =>
      hero.isEmpty && campaigns.isEmpty && animalNav.isEmpty && rails.isEmpty && brands.isEmpty;

  ProductRail? rail(String? key) {
    if (key == null) return null;
    for (final rail in rails) {
      if (rail.key == key) return rail;
    }
    return null;
  }

  factory HomePayload.fromJson(Map<String, dynamic> json) => HomePayload(
        hero: asMapList(json['hero']).map(HeroSlide.fromJson).toList(),
        campaigns: asMapList(json['campaigns']).map(Campaign.fromJson).toList(),
        animalNav: asMapList(json['animal_nav']).map(AnimalNavItem.fromJson).toList(),
        rails: asMapList(json['rails'])
            .map(ProductRail.fromJson)
            .where((rail) => rail.products.isNotEmpty)
            .toList(),
        brands: asMapList(json['brands']).map(BrandSummary.fromJson).toList(),
        layout: asMapList(json['layout'])
            .map(HomeLayoutSlot.fromJson)
            .where((slot) => slot.type.isNotEmpty)
            .toList(),
      );
}

/// How overdue a buy-again product is, parsed off the card map so [ProductCard]
/// itself stays the one shape every list in the app speaks.
@immutable
class ReorderHint {
  const ReorderHint({this.lastOrderedDays, this.due = false});

  final int? lastOrderedDays;

  /// The server thinks this customer is due to run out.
  final bool due;
}

/// The personal strip at the top of the feed: what they buy, or — for someone
/// with no history — what they were just looking at.
@immutable
class PersonalSlot {
  const PersonalSlot({
    this.kind = 'none',
    this.title = '',
    this.products = const [],
    this.hints = const {},
  });

  /// `buyagain` | `recent` | `none`.
  final String kind;

  /// Arrives localized — the server knows the language from `?lang=`.
  final String title;
  final List<ProductCard> products;

  /// product id → reorder hint. Only populated for `buyagain`.
  final Map<int, ReorderHint> hints;

  static const PersonalSlot none = PersonalSlot();

  bool get isEmpty => kind == 'none' || products.isEmpty;

  /// Whether anything in the strip is actually due — drives the nudge line.
  bool get anyDue => hints.values.any((hint) => hint.due);

  factory PersonalSlot.fromJson(Map<String, dynamic> json) {
    final cards = asMapList(json['products']);
    final hints = <int, ReorderHint>{};
    for (final card in cards) {
      final days = asIntOrNull(card['last_ordered_days']);
      final due = asBool(card['due']);
      if (days == null && !due) continue;
      hints[asInt(card['id'])] = ReorderHint(lastOrderedDays: days, due: due);
    }
    return PersonalSlot(
      kind: asString(json['kind'], fallback: 'none'),
      title: asString(json['title']),
      products: cards.map(ProductCard.fromJson).toList(),
      hints: hints,
    );
  }
}

/// A titled strip that lives in the personalized feed rather than in the
/// cacheable home payload.
@immutable
class FeedRail {
  const FeedRail({required this.title, this.products = const []});

  final String title;
  final List<ProductCard> products;

  /// Null for "the server had nothing personal to say here" — which is a
  /// normal answer, not an error.
  static FeedRail? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final products = ProductCard.listFrom(map['products']);
    if (products.isEmpty) return null;
    return FeedRail(title: asString(map['title']), products: products);
  }
}

/// `GET /home/feed` — the per-customer half of the page.
///
/// Split from `/home` on purpose: `/home` is identical for everyone in a city
/// and therefore cacheable, while this is `no-store` and personal.
@immutable
class HomeFeed {
  const HomeFeed({
    this.personal = PersonalSlot.none,
    this.forYou,
    this.inCity,
    this.loginNudge = false,
  });

  final PersonalSlot personal;
  final FeedRail? forYou;
  final FeedRail? inCity;

  /// The server would have more to show if this person signed in.
  final bool loginNudge;

  static const HomeFeed empty = HomeFeed();

  factory HomeFeed.fromJson(Map<String, dynamic> json) => HomeFeed(
        personal: PersonalSlot.fromJson(asMap(json['personal'])),
        forYou: FeedRail.maybe(json['foryou']),
        inCity: FeedRail.maybe(json['incity']),
        loginNudge: asBool(json['login_nudge']),
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
    this.icon,
    this.count = 0,
    this.children = const [],
  });

  final int id;
  final String slug;
  final String name;

  /// Category artwork. The four animal roots carry a photographic tile; the
  /// children carry the illustrated set.
  final String? image;

  /// Emoji fallback for a node whose artwork is missing or fails to load. The
  /// server sends `""` for most children; `asStringOrNull` folds that to null.
  final String? icon;

  final int count;
  final List<CategoryNode> children;

  bool get hasChildren => children.isNotEmpty;

  factory CategoryNode.fromJson(Map<String, dynamic> json) => CategoryNode(
        id: asInt(json['id']),
        slug: asString(json['slug']),
        name: asString(json['name']),
        image: asStringOrNull(json['image']),
        icon: asStringOrNull(json['icon']),
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
    this.rail,
    this.attributes = const {},
    this.minPrice,
    this.maxPrice,
    this.orderBy,
    this.perPage = 20,
  });

  /// Rebuilds a query from a deep link / `context.push` URL.
  factory ListingQuery.fromJson(Map<String, String> params) => ListingQuery(
        category: asStringOrNull(params['category']),
        brand: asStringOrNull(params['brand']),
        q: asStringOrNull(params['q']),
        sku: asStringOrNull(params['sku']),
        rail: asStringOrNull(params['rail']),
      );

  final String? category;
  final String? brand;
  final String? q;
  final String? sku;

  /// A home rail's "see all" (`trending`, `bestsellers`, `new`, `clearance`).
  /// The server resolves it to the same ranking the rail was built from —
  /// otherwise page 2 of "الأكثر مبيعًا" would be sorted by date.
  final String? rail;

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
    bool clearCategory = false,
  }) =>
      ListingQuery(
        category: clearCategory ? null : (category ?? this.category),
        brand: brand ?? this.brand,
        q: q ?? this.q,
        sku: sku,
        rail: rail,
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
        rail: rail,
        orderBy: orderBy,
        perPage: perPage,
      );

  Map<String, dynamic> toQueryParameters(int page) => {
        if (category != null) 'category': category,
        if (brand != null) 'brand': brand,
        if (q != null && q!.isNotEmpty) 'q': q,
        if (sku != null) 'sku': sku,
        if (rail != null) 'rail': rail,
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
      other.rail == rail &&
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
        rail,
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

/// One lifestyle tile from a brand's boutique kit: artwork plus the line that
/// belongs on it. The headline is routinely empty — the tile then reads as a
/// plain photo rather than as a card missing its text.
@immutable
class BrandTile {
  const BrandTile({required this.image, this.headline = ''});

  final String image;
  final String headline;

  /// Null for a tile with no artwork — a headline alone is not a tile.
  static BrandTile? maybe(Map<String, dynamic> json) {
    final image = asStringOrNull(json['image']);
    if (image == null) return null;
    return BrandTile(image: image, headline: asString(json['headline']));
  }
}

/// `GET /brands/{slug}` — a brand boutique page.
///
/// Everything past the name is optional and usually *absent*: the AI boutique
/// kit (hero art, tagline, story, tiles) is synced per brand and most brands
/// are still waiting for theirs. So the model keeps every rich field nullable
/// or empty rather than defaulting it, and the screen is built to look
/// finished with nothing but a name, a logo, categories and products.
@immutable
class BrandPage {
  const BrandPage({
    required this.brand,
    this.boutique = false,
    this.accentDark,
    this.tagline,
    this.hero,
    this.story,
    this.country,
    this.founded,
    this.tiles = const [],
    this.categories = const [],
    this.products = const [],
    this.productCount = 0,
  });

  final BrandSummary brand;

  /// True once the AI boutique kit is synced for this brand.
  final bool boutique;

  final String? accentDark;
  final String? tagline;

  /// Wide AI hero artwork. Null for most brands today.
  final String? hero;

  /// `story.lead` (+ `story.mood`) folded into one readable paragraph.
  final String? story;

  final String? country;
  final String? founded;
  final List<BrandTile> tiles;

  /// The categories this brand actually sells into, biggest first — at most
  /// eight, because the chip row is a filter, not a sitemap.
  final List<CategoryNode> categories;

  /// Curated bestsellers for the brand. Merchandising, not a first page: the
  /// grid below still queries the full catalogue.
  final List<ProductCard> products;

  /// How many products carry the brand. 0 means "the server didn't say".
  final int productCount;

  String get slug => brand.slug;
  String get name => brand.name;

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
        slug: asString(json['slug'], fallback: slug),
        name: asString(json['name'], fallback: slug),
        code: asStringOrNull(json['code']),
        logo: asStringOrNull(json['logo']),
        accent: asStringOrNull(kit['accent']),
      ),
      boutique: asBool(json['boutique']),
      accentDark: asStringOrNull(kit['accent_dark']),
      tagline: asStringOrNull(kit['tagline']),
      hero: asStringOrNull(json['hero']),
      // A story object whose every line is empty is *no story*. Falling back
      // to `json['story']` there would stringify the map itself and print
      // "{lead: , country: , mood: }" on the page — which is exactly the shape
      // the server sends for a brand whose kit hasn't been written yet.
      story: storyParts.isNotEmpty
          ? storyParts.join('\n\n')
          : (json['story'] is Map ? null : asStringOrNull(json['story'])),
      country: asStringOrNull(storyJson['country']),
      founded: asStringOrNull(storyJson['founded']),
      tiles: [
        for (final tile in asMapList(json['tiles'])) ?BrandTile.maybe(tile),
      ],
      categories: asMapList(json['categories']).map(CategoryNode.fromJson).toList(),
      products: ProductCard.listFrom(json['products']),
      productCount: asInt(json['product_count']),
    );
  }
}
