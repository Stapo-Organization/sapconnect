import 'categories_screen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'products_list_screen.dart';
import '../../data/repositories/store_repository.dart';
import '../../data/models/brand_model.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomNavigationBar(context),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Spacer for the overlapping search bar (header height + overlap height)
                const SizedBox(height: 190), 
                
                // Top Promo Banners
                SizedBox(
                  height: 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildBanner('assets/images/store/top_banner_1.png', const Color(0xFFF3BF45).withOpacity(0.3)),
                      const SizedBox(width: 10),
                      _buildBanner('assets/images/store/top_banner_2.png', const Color(0xFF4671AD)),
                      const SizedBox(width: 10),
                      _buildBanner('assets/images/store/top_banner_3.png', const Color(0xFF4671AD).withOpacity(0.5)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Recently added 
                _buildSectionHeader('وصل حديثا'),
                const SizedBox(height: 15),
                _buildBrandGrid(),

                const SizedBox(height: 30),
                
                // Categories
                _buildSectionHeader('التصنيفات', onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CategoriesScreen()),
                  );
                }),
                const SizedBox(height: 15),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildCategorySquare('اثاث وخداشات', Icons.kitchen_outlined, const Color(0xFFF3BF45)),
                      _buildCategorySquare('العاب وهدايا', Iconsax.gift, const Color(0xFFF3BF45)),
                      _buildCategorySquare('النظافة والعناية', Iconsax.bubble, const Color(0xFFF3BF45)),
                      _buildCategorySquare('اوعية الطعام', Icons.local_cafe_outlined, const Color(0xFFF3BF45)),
                      _buildCategorySquare('صناديق واقفاص', Icons.inventory_2_outlined, const Color(0xFFF3BF45)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Brands
                _buildSectionHeader('العلامات التجارية'),
                const SizedBox(height: 15),
                _buildBrandGrid(),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          // Custom Header overlapping Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 144,
          padding: const EdgeInsets.only(top: 50, left: 24, right: 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4671AD), Color(0xFF6F8EB8)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location + Text (Will be on the Right if RTL)
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3BF45).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Color(0xFFF3BF45), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'متجر الرياض',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            '27 شارع الملك فهد، الرياض، السعودية',
                            style: TextStyle(
                              fontFamily: 'Expo Arabic',
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              
              // Cart and Back (Will be on the Left if RTL)
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                       const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28),
                       Positioned(
                         top: -4,
                         left: -4, // Changed to left side for RTL logic compatibility or specific layout
                         child: Container(
                           padding: const EdgeInsets.all(4),
                           decoration: const BoxDecoration(
                             color: Color(0xFFFE3A46),
                             shape: BoxShape.circle,
                           ),
                           child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                         ),
                       )
                    ],
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20), 
                    // arrow_forward_ios points left in RTL environment typically replacing arrow_back
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Search Bar overlapping
        Positioned(
          top: 116,
          left: 24,
          right: 24,
          child: Container(
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFEFEF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Iconsax.search_normal, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                const Text('البحث', style: TextStyle(fontFamily: 'Expo Arabic', fontSize: 12, color: Color(0xFFBDBDBD))),
                const Spacer(),
                const Icon(Iconsax.setting_4, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: onViewAll,
            child: const Text(
              'عرض الكل',
              style: TextStyle(
                fontFamily: 'Expo Arabic',
                fontSize: 14,
                color: Color(0xFF9F9F9F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<List<BrandModel>>(
        future: StoreRepository().getBrands(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF3BF45)));
          }
          
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد علامات تجارية', style: TextStyle(fontFamily: 'Expo Arabic', color: Colors.grey)));
          }
          
          final brands = snapshot.data!;
          final displayBrands = brands.take(6).toList();
          
          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 120 / 89,
            ),
            itemCount: displayBrands.length,
            itemBuilder: (context, index) {
              final brand = displayBrands[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFEFEFEF)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductsListScreen(
                          categoryName: brand.name,
                          brandCode: brand.code,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: brand.imageUrl != null 
                      ? Image.network(
                          brand.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(brand.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ),
                        )
                      : Center(
                          child: Text(brand.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBanner(String path, Color placeholderColor) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: placeholderColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySquare(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 13),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 36),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(Iconsax.more, 'المزيد', false),
          _buildBottomNavItem(Iconsax.document_text, 'شريك', false),
          _buildBottomNavItem(Iconsax.shop, 'انشاء طلب', false),
          _buildBottomNavItem(Iconsax.box, 'طلباتي', false),
          _buildBottomNavItem(Iconsax.home_25, 'الرئيسية', true),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? const Color(0xFF4671AD) : const Color(0xFFBDBDBD);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Expo_Arabic',
          ),
        ),
      ],
    );
  }
}

