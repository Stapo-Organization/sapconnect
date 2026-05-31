import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'products_list_screen.dart'; // Import to navigate to products

class CategoriesScreen extends StatelessWidget {
  CategoriesScreen({super.key});

  final List<Map<String, dynamic>> categories = [
    {'title': 'مستلزمات العناية', 'icon': Iconsax.health},
    {'title': 'مستلزمات الرمل', 'icon': Iconsax.brush_2},
    {'title': 'مستلزمات التدريب', 'icon': Iconsax.award},
    {'title': 'طعام ومكملات', 'icon': Iconsax.reserve},
    {'title': 'صناديق واقغاص', 'icon': Iconsax.home},
    {'title': 'اوعية الطعام', 'icon': Iconsax.cup},
    {'title': 'النظافة والعناية', 'icon': Iconsax.drop},
    {'title': 'العاب وهدايا', 'icon': Iconsax.game},
    {'title': 'اثاث وخداشات', 'icon': Iconsax.home_trend_up},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'التصنيفات',
          style: TextStyle(
            fontFamily: 'Expo Arabic',
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const SizedBox(), 
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: GridView.builder(
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // Changed to 3 columns as per Figma 1:22613
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.75, 
          ),
          itemBuilder: (context, index) {
            final cat = categories[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductsListScreen(categoryName: cat['title']),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80, // Approximate 90px relative to screen width
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF3BF45).withOpacity(0.2)),
                    ),
                    child: Center(
                      // We use icon as placeholder since actual category images are not in assets
                      child: Icon(cat['icon'], color: const Color(0xFFF3BF45), size: 30),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      cat['title'],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
