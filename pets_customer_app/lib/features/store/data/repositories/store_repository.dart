import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/api_constants.dart';
import '../models/brand_model.dart';
import '../models/product_model.dart';

class StoreRepository {
  Future<List<BrandModel>> getBrands() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.brands));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> brandsJson = data['data'];
          return brandsJson.map((json) => BrandModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching brands: $e');
      return [];
    }
  }

  Future<List<ProductModel>> getProducts({String? brandCode}) async {
    try {
      String url = '${ApiConstants.baseUrl}/store/products';
      if (brandCode != null && brandCode.isNotEmpty) {
        url += '?brand_code=$brandCode';
      }
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Laravel paginate returns {data: {data: []}}
          final List<dynamic> productsJson = data['data']['data']; 
          return productsJson.map((json) => ProductModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Error fetching products: $e');
    }
  }
}
