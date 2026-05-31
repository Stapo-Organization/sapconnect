import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../product/presentation/pages/product_details_screen.dart';
import '../../../cart/presentation/pages/cart_screen.dart';
import '../../../store/presentation/pages/store_screen.dart';
import '../../../profile/presentation/pages/invoices_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          // Flat Blue Header Background
          Container(
            height: 220,
            decoration: const BoxDecoration(
              color: Color(0xFF4671AD),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderInfo(context),
                  const SizedBox(height: 10),
                  
                  // Wrap Stats in a container that overlaps the blue header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildStatsCards(context),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildServicesGrid(context),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSupportButtons(),
                  ),
                  
                  const SizedBox(height: 100), // padding for custom bottom nav
                ],
              ),
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // User Info
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80'),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  Positioned(
                    bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD7D7D7), Color(0xFFFFFFFF), Color(0xFFB9B9B9)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'فضي',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'مرحبا، مصطفي',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'تفقد إحصائياتك فى التطبيق',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Action Icons (8 Point Star implementation via clip or stack)
          Row(
            children: [
              _buildStarIconContainer(
                icon: Iconsax.notification,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              Stack(
                alignment: Alignment.topRight,
                clipBehavior: Clip.none,
                children: [
                  _buildStarIconContainer(
                    icon: Iconsax.shopping_cart,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CartScreen()),
                      );
                    },
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3BF45),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '23',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontFamily: 'Expo Arabic',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarIconContainer({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10), // Approximating the starry shape with rounded box for now until CustomPainter
          // actually, an 8-pointed star can be mimicked by a rotated box over a box!
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 3.14159 / 4,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Icon(icon, color: const Color(0xFF4671AD), size: 18), // Icon is blue
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildSingleStatCard(
            title: 'الفواتير',
            value: '5.200',
            unit: 'ر.س',
            icon: Iconsax.money_2,
            isShareek: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InvoicesScreen(), // From profile features
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSingleStatCard(
            title: 'الطلبات الغير مكتملة',
            value: '12',
            unit: 'طلب',
            icon: Iconsax.shopping_bag,
            isShareek: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSingleStatCard(
            title: 'نقاط شريك',
            value: '1.500',
            unit: 'ر.س',
            icon: null,
            isShareek: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStatCard({
    required String title,
    required String value,
    required String unit,
    IconData? icon,
    required bool isShareek,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isShareek)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Text('شريك', style: TextStyle(fontFamily: 'Expo Arabic', color: Color(0xFF1E6351), fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            )
          else
            Icon(icon, color: Colors.black87, size: 28),
          
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 10,
              color: Color(0xFF9E9E9E),
              fontWeight: FontWeight.w500,
            ),
          ),
          
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$value ',
                  style: const TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 14,
                    color: Color(0xFFF3BF45), // exactly golden yellow like Figma!
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: const TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 8,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildServicesGrid(BuildContext context) {
    final List<Map<String, dynamic>> services = [
      {'title': 'انشاء طلب', 'icon': Icons.add},
      {'title': 'اعادة الطلب', 'icon': Icons.history},
      {'title': 'العروض', 'icon': Icons.local_offer_outlined},
      {'title': 'الفواتير', 'icon': Icons.receipt_long_outlined},
      {'title': 'طلباتي', 'icon': Iconsax.box},
      {'title': 'المرتجعات', 'icon': Icons.assignment_return_outlined},
      {'title': 'التعليم', 'icon': Icons.play_circle_outline},
      {'title': 'مكتبة المنتجات', 'icon': Icons.library_books_outlined},
      {'title': 'الاحصائيات', 'icon': Icons.pie_chart_outline},
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        return _buildServiceItem(
          title: services[index]['title'],
          icon: services[index]['icon'],
          onTap: () {
            if (services[index]['title'] == 'مكتبة المنتجات') {
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const ProductDetailsScreen()),
             );
            } else if (services[index]['title'] == 'انشاء طلب' || services[index]['title'] == 'العروض') {
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const StoreScreen()),
             );
            }
          },
        );
      },
    );
  }

  Widget _buildServiceItem({required String title, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF9F9F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFF3BF45), size: 30), // Golden and large! No circle background!
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Expo Arabic',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSupportButton(
            title: 'محادثة مع\nالدعم الفني',
            icon: Iconsax.message_text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSupportButton(
            title: 'محادثة مع\nمدير الحساب',
            icon: Iconsax.user_tick,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportButton({required String title, required IconData icon}) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF9F9F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Expo Arabic',
                fontSize: 10,
                color: Colors.black,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: const Color(0xFFF3BF45), size: 24),
        ],
      ),
    );
  }

}
