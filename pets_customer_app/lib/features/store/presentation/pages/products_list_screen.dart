import 'package:flutter/material.dart';
import '../../../product/presentation/widgets/product_card.dart';
import '../../../product/presentation/widgets/product_horizontal_card.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/store_repository.dart';

class ProductsListScreen extends StatefulWidget {
  final String categoryName;
  final String? brandCode;

  const ProductsListScreen({
    super.key,
    required this.categoryName,
    this.brandCode,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  bool _isGridView = false; // Default to list view as in 5-7140
  int _selectedSubCategoryIndex = 2; // Default to 'النظافة والعناية'
  int _selectedPillIndex = 0;
  
  late Future<List<ProductModel>> _productsFuture;

  final List<String> subCategories = [
    'الكل',
    'طعام ومكملات',
    'أثاث وخداشات',
    'النظافة والعناية',
    'ألعاب وهدايا',
    'أوعية الطعام'
  ];

  final List<String> pills = [
    'الكل',
    'اسم التصنيف',
    'اسم التصنيف',
    'اسم التصنيف',
    'اسم التصنيف'
  ];

  @override
  void initState() {
    super.initState();
    print('Fetching products for brand: \${widget.brandCode}');
    _productsFuture = StoreRepository().getProducts(brandCode: widget.brandCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Light background like figma
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const SizedBox(), 
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20), // RTL back arrow
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Sub-categories horizontal scroll
          Container(
            height: 48,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF))),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: subCategories.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedSubCategoryIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSubCategoryIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? const Color(0xFF4671AD) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      subCategories[index],
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF4671AD) : const Color(0xFF333333),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          
          // Pills
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pills.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedPillIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPillIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4671AD) : Colors.white,
                      border: Border.all(color: const Color(0xFFEFEFEF)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      pills[index],
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Actions bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // View Toggles
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isGridView = false),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: !_isGridView ? const Color(0xFFF3BF45) : Colors.white,
                          border: Border.all(color: const Color(0xFFEFEFEF)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.view_agenda_rounded, size: 20, color: !_isGridView ? Colors.white : const Color(0xFFBDBDBD)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isGridView = true),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isGridView ? const Color(0xFFF3BF45) : Colors.white,
                          border: Border.all(color: const Color(0xFFEFEFEF)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.grid_view_rounded, size: 20, color: _isGridView ? Colors.white : const Color(0xFFBDBDBD)),
                      ),
                    ),
                  ],
                ),
                
                // Filters and Sort
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFEFEFEF)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.filter_list, size: 16, color: Color(0xFF9E9E9E)),
                          SizedBox(width: 6),
                          Text('فلتر', style: TextStyle(fontFamily: 'Expo Arabic', fontSize: 13, color: Color(0xFF9E9E9E))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFEFEFEF)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Text('ترتيب', style: TextStyle(fontFamily: 'Expo Arabic', fontSize: 13, color: Color(0xFF9E9E9E))),
                          SizedBox(width: 6),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9E9E9E)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<ProductModel>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4671AD)));
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${snapshot.error}',
                      style: const TextStyle(fontFamily: 'Expo Arabic'),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد منتجات لهذه الماركة',
                      style: TextStyle(fontFamily: 'Expo Arabic', fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final products = snapshot.data!;
                return _isGridView ? _buildGridView(products) : _buildListView(products);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<ProductModel> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.61, // Adjusted for the height required by the new Add To Cart buttons
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final name = product.foreignName.isNotEmpty ? product.foreignName : product.name;
        return ProductCard(
          title: name.isNotEmpty ? name : 'منتج بدون اسم',
          price: '${product.price} ر.س',
          unitText: product.inventoryUom,
          imageUrl: product.imageUrl,
          isAvailable: true, 
          tags: const [], // Can be updated later with real tags
        );
      },
    );
  }

  Widget _buildListView(List<ProductModel> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final name = product.foreignName.isNotEmpty ? product.foreignName : product.name;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ProductHorizontalCard(
            title: name.isNotEmpty ? name : 'منتج بدون اسم', 
            price: '${product.price} ر.س',
            unitText: product.inventoryUom,
            imageUrl: product.imageUrl, 
            isAvailable: true,
            tags: const [],
          ),
        );
      },
    );
  }
}
