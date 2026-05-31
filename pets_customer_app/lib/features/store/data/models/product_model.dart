
class ProductModel {
  final int id;
  final String itemCode;
  final String name;
  final String foreignName;
  final String inventoryUom;
  final String imageUrl;
  final String price;

  ProductModel({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.foreignName,
    required this.inventoryUom,
    required this.imageUrl,
    required this.price,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String extractPrice(dynamic pricesRaw) {
      if (pricesRaw == null) return "0.0";
      try {
        if (pricesRaw is List && pricesRaw.isNotEmpty) {
          final firstPrice = pricesRaw.first;
          if (firstPrice is Map && firstPrice.containsKey('Price')) {
            return firstPrice['Price'].toString();
          }
        }
      } catch (e) {
        // ignore parsing error
      }
      return "0.0";
    }

    final rawUrl = json['image_url'] ?? '';
    final finalUrl = rawUrl.isNotEmpty ? '\${ApiConstants.baseUrl}/store/proxy-image?url=\${Uri.encodeComponent(rawUrl)}' : '';

    return ProductModel(
      id: json['id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      name: json['item_name'] ?? '',
      foreignName: json['foreign_name'] ?? '',
      inventoryUom: json['inventory_uom'] ?? '',
      imageUrl: finalUrl,
      price: extractPrice(json['prices']),
    );
  }
}
