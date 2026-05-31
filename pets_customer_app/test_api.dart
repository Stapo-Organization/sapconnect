import 'package:http/http.dart' as http;
import 'dart:convert';
import 'lib/features/store/data/models/product_model.dart';

void main() async {
  String url = 'https://sapapi.muntajat.sa/api/store/products?brand_code=173';
  
  try {
    print('Fetching from \$url');
    final response = await http.get(Uri.parse(url));
    print('Status: \${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Status string: \${data["status"]}');
      
      final List<dynamic> productsJson = data['data']['data'];
      print('Found \${productsJson.length} products');
      
      var models = productsJson.map((json) => ProductModel.fromJson(json)).toList();
      print('Parsed \${models.length} products successfully.');
      for (var p in models) {
        print(' - \${p.name} (\${p.price})');
      }
    } else {
      print('Error status code');
    }
  } catch (e) {
    print('Exception: \$e');
    print('Stack: \$stack');
  }
}
