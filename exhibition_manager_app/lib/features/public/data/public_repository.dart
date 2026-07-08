import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';

/// A single company-news item shown on the public (pre-login) landing screen.
class NewsItem {
  final int id;
  final String title;
  final String? body;
  final String? imageUrl;
  final String? linkUrl;
  final DateTime? publishedAt;

  const NewsItem({
    required this.id,
    required this.title,
    this.body,
    this.imageUrl,
    this.linkUrl,
    this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        id: (json['id'] as num).toInt(),
        title: (json['title'] ?? '').toString(),
        body: json['body']?.toString(),
        imageUrl: json['image_url']?.toString(),
        linkUrl: json['link_url']?.toString(),
        publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      );
}

/// A brand as shown in the landing showcase (logo + name).
class BrandSummary {
  final String code;
  final String name;
  final String? logoUrl;

  const BrandSummary({required this.code, required this.name, this.logoUrl});

  factory BrandSummary.fromJson(Map<String, dynamic> json) => BrandSummary(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        logoUrl: json['logo_url']?.toString(),
      );
}

/// A single product image on a brand page (no price — channel-safe).
class BrandProduct {
  final String name;
  final String? imageUrl;

  const BrandProduct({required this.name, this.imageUrl});

  factory BrandProduct.fromJson(Map<String, dynamic> json) => BrandProduct(
        name: (json['name'] ?? '').toString(),
        imageUrl: json['image_url']?.toString(),
      );
}

/// Full per-brand intro page payload.
class BrandDetail {
  final String code;
  final String name;
  final String? logoUrl;
  final String? tagline;
  final String? country;
  final String? founded;
  final List<BrandProduct> products;

  const BrandDetail({
    required this.code,
    required this.name,
    this.logoUrl,
    this.tagline,
    this.country,
    this.founded,
    this.products = const [],
  });

  factory BrandDetail.fromJson(Map<String, dynamic> json) => BrandDetail(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        logoUrl: json['logo_url']?.toString(),
        tagline: json['tagline']?.toString(),
        country: json['country']?.toString(),
        founded: json['founded']?.toString(),
        products: ((json['products'] ?? const []) as List)
            .whereType<Map<String, dynamic>>()
            .map(BrandProduct.fromJson)
            .toList(),
      );
}

/// A customer-facing branch / showroom shown on the landing.
class BranchInfo {
  final String name;
  final String? city;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;

  const BranchInfo({
    required this.name,
    this.city,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
  });

  factory BranchInfo.fromJson(Map<String, dynamic> json) => BranchInfo(
        name: (json['name'] ?? '').toString(),
        city: json['city']?.toString(),
        address: json['address']?.toString(),
        phone: json['phone']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  bool get hasCoords => latitude != null && longitude != null;
}

/// The full payload behind the landing screen: news + company info + brands + branches.
class LandingData {
  final List<NewsItem> news;
  final String companyName;
  final String? about;
  final List<BrandSummary> brands;
  final List<BranchInfo> branches;

  const LandingData({
    required this.news,
    required this.companyName,
    this.about,
    this.brands = const [],
    this.branches = const [],
  });
}

/// Fetches the public landing feed (no auth required).
class PublicRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, String? error, LandingData? data})> fetchLanding() async {
    final result = await _api.get(
      ApiEndpoints.landing,
      queryParams: {'lang': AppLocalizations.currentLanguage},
    );

    if (result.isSuccess) {
      final data = (result.data['data'] ?? const {}) as Map<String, dynamic>;

      final news = ((data['news'] ?? const []) as List)
          .whereType<Map<String, dynamic>>()
          .map(NewsItem.fromJson)
          .toList();

      final info = (data['company_info'] ?? const {}) as Map<String, dynamic>;

      final brands = ((data['brands'] ?? const []) as List)
          .whereType<Map<String, dynamic>>()
          .map(BrandSummary.fromJson)
          .toList();

      final branches = ((data['branches'] ?? const []) as List)
          .whereType<Map<String, dynamic>>()
          .map(BranchInfo.fromJson)
          .toList();

      return (
        success: true,
        error: null,
        data: LandingData(
          news: news,
          companyName: (info['name'] ?? 'Muntajat HUB').toString(),
          about: info['about']?.toString(),
          brands: brands,
          branches: branches,
        ),
      );
    }

    return (success: false, error: result.errorMessage, data: null);
  }

  /// Fetch a single brand's intro page (logo, info, product gallery).
  Future<({bool success, String? error, BrandDetail? data})> fetchBrand(String code) async {
    final result = await _api.get(
      ApiEndpoints.brandDetail(code),
      queryParams: {'lang': AppLocalizations.currentLanguage},
    );

    if (result.isSuccess) {
      final data = (result.data['data'] ?? const {}) as Map<String, dynamic>;
      return (success: true, error: null, data: BrandDetail.fromJson(data));
    }

    return (success: false, error: result.errorMessage, data: null);
  }
}
