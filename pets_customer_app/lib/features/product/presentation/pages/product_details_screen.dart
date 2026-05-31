import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../widgets/product_card.dart';
import '../../../cart/presentation/pages/cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  bool _isInfoTabActive = true; 
  // true = معلومات عن المنتج, false = وصف عن المنتج

  final List<String> productImages = [
    'assets/images/placeholder_ad.png', // Replace with real asset
    'assets/images/placeholder_ad.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'تفاصيل المنتج',
          style: TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(), 
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100), // Space for bottom bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageSlider(),
                const SizedBox(height: 20),
                _buildProductTitle(),
                const SizedBox(height: 20),
                _buildTabs(),
                const SizedBox(height: 20),
                if (_isInfoTabActive) _buildInfoTable() else _buildDescription(),
                const SizedBox(height: 40),
                _buildRelatedProductsSecTitle('قد يعجبك أيضا'),
                const SizedBox(height: 15),
                _buildRelatedProducts(),
                const SizedBox(height: 40),
                _buildRelatedProductsSecTitle('منتجات مقترحة لك'),
                const SizedBox(height: 15),
                _buildRelatedProducts(),
                const SizedBox(height: 30),
              ],
            ),
          ),
          
          // Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -3),
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Row(
                children: [
                  // Add to Cart Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CartScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4671AD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'أضف الي السلة',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Cart Icon
                  Container(
                    width: 70,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3BF45).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Iconsax.shopping_cart,
                          color: Color(0xFF51526C),
                          size: 28,
                        ),
                        Positioned(
                          right: 15,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3BF45),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSlider() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              CarouselSlider(
                options: CarouselOptions(
                  height: 200,
                  viewportFraction: 1.0,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                ),
                items: productImages.map((img) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Image.network(
                        img.startsWith('asset') 
                            ? 'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=400&q=80'
                            : img,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Iconsax.image, color: Colors.grey, size: 80),
                      );
                    },
                  );
                }).toList(),
              ),
              
              // 3D Rotate Icon Placeholder
              Positioned(
                left: 24,
                bottom: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(5)),
                  ),
                  child: const Icon(Icons.threed_rotation, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        AnimatedSmoothIndicator(
          activeIndex: _currentImageIndex,
          count: productImages.length,
          effect: const ExpandingDotsEffect(
            dotHeight: 5,
            dotWidth: 20,
            activeDotColor: Color(0xFF6022B2),
            dotColor: Color(0xFFF0F2F7),
            expansionFactor: 1.5, 
          ),
        ),
      ],
    );
  }

  Widget _buildProductTitle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'تيكي دوج الوها بيتس حزمة متعددة 4 نكهات للكلاب الصغيرة',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Expo Arabic',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF4671AD),
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            // Description Tab
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isInfoTabActive = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: !_isInfoTabActive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'وصف عن المنتج',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: !_isInfoTabActive ? const Color(0xFF4671AD) : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            
            // Info Tab
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isInfoTabActive = true;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _isInfoTabActive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'معلومات عن المنتج',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isInfoTabActive ? const Color(0xFF4671AD) : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEAEAEA), style: BorderStyle.none),
          // We apply top and bottom borders only, with dashed lines between rows.
          // Since Flutter lacks native dashed borders, we'll simulate.
        ),
        child: Column(
          children: [
            _buildTableRow('الحد الأدنى للطلب', '5 كرتون', isBlackValue: true),
            _buildTableRow('سعر الكرتون', '٨٢٫٩٦ ر.س', valueColor: const Color(0xFFE35446)),
            _buildTableRow('الكمية', 'كرتون 6 حبة', isBlackValue: true),
            _buildTableRow('نوع الحيوان الاليف', 'الكلاب الصغيرة', isBlackValue: true),
            _buildTableRow('اللون', '-'),
            _buildTableRow('الابعاد', '-'),
            _buildTableRow('العلامة التجارية', 'Rigor cat', isBlackValue: true),
            _buildTableRow('SKU', '8683649140355', valueColor: const Color(0xFF4671AD), isLast: true),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTableRow(String label, String value, {Color? valueColor, bool isBlackValue = false, bool isLast = false}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
           bottom: BorderSide(
             color: const Color(0xFFEAEAEA),
             width: 1,
             style: BorderStyle.solid, // Using solid here as dashed is tricky without custom paints
           ),
           top: BorderSide(
             color: const Color(0xFFEAEAEA),
             width: 1,
             style: BorderStyle.solid,
           )
        )
      ),
      child: Row(
        children: [
          // Value side (Left equivalent in RTL)
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 14,
                  fontWeight: isBlackValue || valueColor != null ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ?? (isBlackValue ? Colors.black : const Color(0xFF757575)),
                ),
              ),
            ),
          ),
          
          // Vertical Separator
          Container(width: 1, color: const Color(0xFFEAEAEA)),
          
          // Label side (Right equivalent in RTL)
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF757575),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'هنا نضع وصف تفصيلي للمنتج...',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Expo Arabic',
          fontSize: 14,
          color: Color(0xFF757575),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildRelatedProductsSecTitle(String title) {
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
          const Text(
            'عرض الكل',
            style: TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 14,
              color: Color(0xFF9F9F9F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts() {
    return SizedBox(
      height: 282,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          // Providing variation for UI testing
          bool available = index != 2;
          return ProductCard(
            title: 'غذاء لطيور الزينة زولكس نوتريميل 2 كغ',
            price: '150 ر.س',
            unitText: 'كرتون 12 حبة',
            imageUrl: 'assets/images/placeholder_ad.png', 
            isAvailable: available,
          );
        },
      ),
    );
  }
}
