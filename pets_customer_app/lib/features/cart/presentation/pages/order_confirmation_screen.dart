import 'package:flutter/material.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // No back button typically on confirmation screen, but keeping empty to let time show if needed
        automaticallyImplyLeading: false, 
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Check Icon Image (using an icon as placeholder, though Figma used an image)
              Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  color: Color(0xFF72B125), // Green color matching the checkmark
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 100,
                ),
              ),
              const SizedBox(height: 30),
              // Success Text
              const Text(
                'تم تأكيد طلبك بنجاح، يمكنك الان تتبع حالة الطلب\nاو عرض تفاصيل الفاتورة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              // Track Order Button
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4671AD),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'تتبع حالة الطلب',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Invoice Details Button
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F5), // Light grey
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'تفاصيل الفاتورة',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
