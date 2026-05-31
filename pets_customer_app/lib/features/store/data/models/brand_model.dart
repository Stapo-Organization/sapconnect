
class BrandModel {
  final int id;
  final String code;
  final String name;
  final String? imageUrl;

  BrandModel({
    required this.id,
    required this.code,
    required this.name,
    this.imageUrl,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['image_url'];
    final finalUrl = rawUrl != null ? '\${ApiConstants.baseUrl}/store/proxy-image?url=\${Uri.encodeComponent(rawUrl)}' : null;
    return BrandModel(
      id: json['id'],
      code: json['code'].toString(),
      name: json['name'] ?? '',
      imageUrl: finalUrl,
    );
  }
}
