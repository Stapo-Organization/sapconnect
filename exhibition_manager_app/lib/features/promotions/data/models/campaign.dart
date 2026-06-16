// Models for the Promotions / Ad-Campaigns feature (owner only).
// Backed by GET /promotions/* — parses both summary rows and full detail.

double? _toDoubleN(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// One rendered creative (format × A/B variant).
class AdCreative {
  final int id;
  final String format; // hero | wide | card | strip
  final String variant; // A | B
  final String status; // queued | generating | ready | failed | approved | selected
  final String? finalUrl;
  final String? thumbUrl;

  AdCreative({
    required this.id,
    required this.format,
    required this.variant,
    required this.status,
    this.finalUrl,
    this.thumbUrl,
  });

  factory AdCreative.fromJson(Map<String, dynamic> json) => AdCreative(
        id: json['id'] ?? 0,
        format: json['format']?.toString() ?? 'hero',
        variant: json['variant']?.toString() ?? 'A',
        status: json['status']?.toString() ?? 'queued',
        finalUrl: json['final_url']?.toString(),
        thumbUrl: json['thumb_url']?.toString() ?? json['final_url']?.toString(),
      );

  bool get isReady => status == 'ready' || status == 'approved' || status == 'selected';
  bool get isApproved => status == 'approved';
  bool get isGenerating => status == 'generating' || status == 'queued';
  bool get isFailed => status == 'failed';
  String? get image => finalUrl ?? thumbUrl;
}

/// An available ad slot (where the banner can appear) — from /promotions/placements.
class AdPlacement {
  final String key;
  final String labelAr;
  final String format;

  AdPlacement({required this.key, required this.labelAr, required this.format});

  factory AdPlacement.fromJson(Map<String, dynamic> json) => AdPlacement(
        key: json['key']?.toString() ?? '',
        labelAr: json['label_ar']?.toString() ?? (json['key']?.toString() ?? ''),
        format: json['format']?.toString() ?? 'hero',
      );
}

/// A real product the campaign is about (main item or bundle companion).
class CampaignProduct {
  final String itemCode;
  final String name;
  final String? imageUrl;

  CampaignProduct({required this.itemCode, required this.name, this.imageUrl});

  factory CampaignProduct.fromJson(Map<String, dynamic> json) => CampaignProduct(
        itemCode: json['item_code']?.toString() ?? '',
        name: json['name']?.toString() ?? (json['item_code']?.toString() ?? ''),
        imageUrl: json['image_url']?.toString(),
      );
}

/// Wholesale-safety block (server-attested).
class CampaignSafety {
  final double? floorPrice;
  final double? retailPrice;
  final double? basePrice;
  final double? maxDiscountPct;
  final bool? floorSafe;

  CampaignSafety({this.floorPrice, this.retailPrice, this.basePrice, this.maxDiscountPct, this.floorSafe});

  factory CampaignSafety.fromJson(Map<String, dynamic> json) => CampaignSafety(
        floorPrice: _toDoubleN(json['floor_price']),
        retailPrice: _toDoubleN(json['retail_price']),
        basePrice: _toDoubleN(json['base_price']),
        maxDiscountPct: _toDoubleN(json['max_discount_pct']),
        floorSafe: json['floor_safe'] is bool ? json['floor_safe'] as bool : null,
      );

  /// Visibility campaigns are always safe; otherwise trust the server flag.
  bool get isSafe => floorSafe ?? true;
}

class Campaign {
  final int id;
  final String campaignType; // spotlight | clearance | bundle | new_arrival | express
  final String scope; // visibility | coupon | bundle
  final String status; // suggested | approved | scheduled | active | ended | rejected
  final String? itemCode;
  final List<String> companionItemCodes;
  final String? headlineAr;
  final String? subheadlineAr;
  final String? ctaAr;
  final String? badgeAr;
  final String? reason;
  final Map<String, dynamic> rationale;
  final List<String> zones;
  final double? discountPct;
  final String? couponCode;
  final String? startsAt;
  final String? endsAt;
  final bool abEnabled;
  final String? thumbUrl;
  final String? createdAt;
  final CampaignSafety? safety;
  final List<AdCreative> creatives;
  final List<CampaignProduct> products;
  final String? refinementNote;
  final String? placement;
  final String? designIdentity; // owner override: null | brand | zooboxi
  final String? brandName;      // primary brand behind the campaign (null = none)

  Campaign({
    required this.id,
    required this.campaignType,
    this.scope = 'visibility',
    this.status = 'suggested',
    this.itemCode,
    this.companionItemCodes = const [],
    this.headlineAr,
    this.subheadlineAr,
    this.ctaAr,
    this.badgeAr,
    this.reason,
    this.rationale = const {},
    this.zones = const [],
    this.discountPct,
    this.couponCode,
    this.startsAt,
    this.endsAt,
    this.abEnabled = false,
    this.thumbUrl,
    this.createdAt,
    this.safety,
    this.creatives = const [],
    this.products = const [],
    this.refinementNote,
    this.placement,
    this.designIdentity,
    this.brandName,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
        id: json['id'] ?? 0,
        campaignType: json['campaign_type']?.toString() ?? 'spotlight',
        scope: json['scope']?.toString() ?? 'visibility',
        status: json['status']?.toString() ?? 'suggested',
        itemCode: json['item_code']?.toString(),
        companionItemCodes: ((json['companion_item_codes'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        headlineAr: json['headline_ar']?.toString(),
        subheadlineAr: json['subheadline_ar']?.toString(),
        ctaAr: json['cta_ar']?.toString(),
        badgeAr: json['badge_ar']?.toString(),
        reason: json['reason']?.toString(),
        rationale: Map<String, dynamic>.from((json['rationale'] as Map?) ?? {}),
        zones: ((json['zones'] as List?) ?? []).map((e) => e.toString()).toList(),
        discountPct: _toDoubleN(json['discount_pct']),
        couponCode: json['coupon_code']?.toString(),
        startsAt: json['starts_at']?.toString(),
        endsAt: json['ends_at']?.toString(),
        abEnabled: json['ab_enabled'] == true,
        thumbUrl: json['thumb_url']?.toString(),
        createdAt: json['created_at']?.toString(),
        safety: json['safety'] != null
            ? CampaignSafety.fromJson(Map<String, dynamic>.from(json['safety'] as Map))
            : null,
        creatives: ((json['creatives'] as List?) ?? [])
            .map((e) => AdCreative.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        products: ((json['products'] as List?) ?? [])
            .map((e) => CampaignProduct.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        refinementNote: json['refinement_note']?.toString(),
        placement: json['placement']?.toString(),
        designIdentity: json['design_identity']?.toString(),
        brandName: json['brand_name']?.toString(),
      );

  bool get isSuggested => status == 'suggested';
  bool get isApproved => status == 'approved'; // preview (generated, not live yet)
  bool get isScheduled => status == 'scheduled';
  bool get isActive => status == 'active';
  bool get isPublished => isActive || isScheduled;
  bool get isEnded => status == 'ended' || status == 'rejected';

  /// Owner can still act on it (review / approve / publish).
  bool get isReviewable => isSuggested || isApproved;

  bool get floorSafe => safety?.isSafe ?? (scope == 'visibility');

  String get displayName => (headlineAr != null && headlineAr!.isNotEmpty) ? headlineAr! : (itemCode ?? '#$id');

  /// Best creative to show as a preview: the card thumb, else any ready one.
  AdCreative? get primaryCreative {
    if (creatives.isEmpty) return null;
    final ready = creatives.where((c) => c.isReady).toList();
    final pool = ready.isNotEmpty ? ready : creatives;
    return pool.firstWhere((c) => c.format == 'card', orElse: () => pool.first);
  }

  /// Creatives of one variant, ordered hero → wide → card → strip.
  List<AdCreative> creativesOf(String variant) {
    const order = ['hero', 'wide', 'card', 'strip'];
    final list = creatives.where((c) => c.variant == variant).toList();
    list.sort((a, b) => order.indexOf(a.format).compareTo(order.indexOf(b.format)));
    return list;
  }

  List<String> get variants {
    final set = creatives.map((c) => c.variant).toSet().toList()..sort();
    return set.isEmpty ? ['A'] : set;
  }
}
