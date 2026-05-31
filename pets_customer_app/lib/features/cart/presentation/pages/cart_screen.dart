import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'order_confirmation_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Mock data for UI
  int item1Qty = 2;
  int item2Qty = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'السلة',
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCartItem(
                    title: 'تيكي دوج الوها بيتس حزمة متعددة 4 نكهات للكلاب الصغيرة',
                    price: '200 ر.س',
                    unit: 'كرتون 6 حبة',
                    imageUrl: 'assets/images/placeholder_ad.png', // Or use network
                    qty: item1Qty,
                    totalPrice: '${200 * item1Qty} ر.س',
                    onIncrement: () => setState(() => item1Qty++),
                    onDecrement: () => setState(() => item1Qty > 1 ? item1Qty-- : null),
                  ),
                  const SizedBox(height: 15),
                  _buildCartItem(
                    title: 'زولكس رودي كوب نشارة خشب الذرة 5 لتر برائحة التوت الأسود والليتشي',
                    price: '175 ر.س',
                    unit: 'كرتون 1 حبة',
                    imageUrl: 'assets/images/placeholder_ad.png', 
                    qty: item2Qty,
                    totalPrice: '${175 * item2Qty} ر.س',
                    onIncrement: () => setState(() => item2Qty++),
                    onDecrement: () => setState(() => item2Qty > 1 ? item2Qty-- : null),
                  ),
                  const SizedBox(height: 30),
                  _buildOrderSummary(),
                  const SizedBox(height: 20),
                  _buildShippingRatesBanner(),
                  const SizedBox(height: 100), // padding for bottom bar
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildCartItem({
    required String title,
    required String price,
    required String unit,
    required String imageUrl,
    required int qty,
    required String totalPrice,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5F5F5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top row: info and image
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Image.network(
                  imageUrl.startsWith('asset') 
                      ? 'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=400&q=80'
                      : imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Iconsax.image, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          unit,
                          style: const TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontSize: 12,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          '•',
                          style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          price,
                          style: const TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontSize: 13,
                            color: Color(0xFFE35446),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Dashed divider
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = constraints.constrainWidth();
              final dashWidth = 5.0;
              final dashHeight = 1.0;
              final dashCount = (boxWidth / (2 * dashWidth)).floor();
              return Flex(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                direction: Axis.horizontal,
                children: List.generate(dashCount, (_) {
                  return SizedBox(
                    width: dashWidth,
                    height: dashHeight,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFEAEAEA)),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 15),
          // Bottom row: Total and Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total
              Text(
                'المجموع : $totalPrice',
                style: const TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              // Stepper
              Row(
                children: [
                  GestureDetector(
                    onTap: onIncrement,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4671AD).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.add, color: Color(0xFF4671AD), size: 20),
                    ),
                  ),
                  Container(
                    width: 45,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: const Color(0xFFEAEAEA)),
                      ),
                    ),
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onDecrement,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: qty == 1 
                            ? const Color(0xFFFE3A46).withOpacity(0.08) 
                            : const Color(0xFF4671AD).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(
                        qty == 1 ? Iconsax.trash : Icons.remove,
                        color: qty == 1 ? const Color(0xFFFE3A46) : const Color(0xFF4671AD),
                        size: 20,
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

  Widget _buildOrderSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5F5F5)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الطلب',
            style: TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          _buildSummaryRow('عدد المنتجات', '2'),
          const SizedBox(height: 10),
          _buildSummaryRow('سعر المنتجات', '265.00 ر.س'),
          const SizedBox(height: 10),
          _buildSummaryRow('الضريبة المضافة 15%', '15.00 ر.س'),
          const SizedBox(height: 15),
          const Text(
            'هل لديك كود خصم',
            style: TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 10),
          // Discount Code Input
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEFEFEF)),
                  ),
                  child: const TextField(
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'أدخل كود الخصم',
                      hintStyle: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 12,
                        color: Color(0xFF9F9F9F),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                width: 95,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3BF45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'إضافة',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dashed divider
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = constraints.constrainWidth();
              final dashWidth = 5.0;
              final dashHeight = 1.0;
              final dashCount = (boxWidth / (2 * dashWidth)).floor();
              return Flex(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                direction: Axis.horizontal,
                children: List.generate(dashCount, (_) {
                  return SizedBox(
                    width: dashWidth,
                    height: dashHeight,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFEAEAEA)),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 20),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'السعر الاجمالي',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                '240.00 ر.س',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 14,
            color: Color(0xFF757575),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildShippingRatesBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5F5F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Truck icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Iconsax.truck, color: Colors.black),
          ),
          const SizedBox(width: 15),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'جدول مصاريف الشحن',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'تعرف علي تكاليف الشحن',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 12,
                    color: Color(0xFF9F9F9F),
                  ),
                ),
              ],
            ),
          ),
          // Arrow icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5).withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrderConfirmationScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4671AD),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: const Text(
          'إتمام الطلب',
          style: TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
