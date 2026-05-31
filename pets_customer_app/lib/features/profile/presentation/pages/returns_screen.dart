import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 0 = الجديدة (New), 1 = الجارية (In-Progress), 2 = السابقة (Previous)
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmptyState(
                    title: 'لا توجد اي مرتجعات جديدة',
                    subtitle: 'ليس لديك اى طلبات مرتجعات جديدة فى الوقت الحالي\nعند وجود طلبات جديدة سوف تظهر هنا',
                  ),
                  _buildEmptyState(
                    title: 'لا توجد طلبات جارية',
                    subtitle: 'ليس لديك اى طلبات مرتجعات جارية فى الوقت الحالي',
                  ),
                  _buildEmptyState(
                    title: 'لا توجد طلبات سابقة',
                    subtitle: 'ليس لديك اى طلبات مرتجعات سابقة',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              const Text(
                'المرتجعات',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Iconsax.arrow_right_1, color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Custom Tab Bar with 3 items
        Container(
          height: 55,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF4671AD),
            borderRadius: BorderRadius.circular(100),
          ),
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              return Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(0),
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _tabController.index == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'الجديدة',
                          style: TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _tabController.index == 0 ? const Color(0xFF4671AD) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(1),
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _tabController.index == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'الجارية',
                          style: TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _tabController.index == 1 ? const Color(0xFF4671AD) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(2),
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _tabController.index == 2 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'السابقة',
                          style: TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _tabController.index == 2 ? const Color(0xFF4671AD) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.document_1, size: 80, color: const Color(0xFFF3BF45).withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Expo Arabic',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 14,
              color: Color(0xFF9F9F9F),
            ),
          ),
        ],
      ),
    );
  }
}
