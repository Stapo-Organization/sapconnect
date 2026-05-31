import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'home_screen.dart';
import '../../../profile/presentation/pages/orders_screen.dart';
import '../../../profile/presentation/pages/profile_dashboard_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0; // 0 answers to first tab in RTL.
  
  final List<Widget> _pages = [
    const HomeScreen(),
    const OrdersScreen(),
    const Center(child: Text('انشاء طلب')),
    const Center(child: Text('شريك')),
    const ProfileDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFF3BF45).withOpacity(0.2), // Light yellow bg from Figma
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: المزيد
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 4; // Assuming 4 is "المزيد" / Profile
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: const [
                    Text(
                      'المزيد',
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Iconsax.more_circle, size: 16, color: Colors.black87),
                  ],
                ),
              ),
            ),
            
            // Middle: كشف الحساب
            GestureDetector(
              onTap: () {
                // Future action
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4671AD),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: const [
                    Text(
                      'كشف الحساب',
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.download_outlined, size: 16, color: Colors.white), // closest to import/download
                  ],
                ),
              ),
            ),

            // Right: Logo Muntajat
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 0; // Home
                });
              },
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('Muntajat', style: TextStyle(fontFamily: 'VC_Henrietta', fontSize: 13, color: Color(0xFFF3BF45), fontWeight: FontWeight.bold)),
                      Text('منتجات', style: TextStyle(fontFamily: 'Expo Arabic', fontSize: 13, color: Color(0xFFF3BF45), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
