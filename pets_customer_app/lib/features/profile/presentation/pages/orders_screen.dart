import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 0 = Current (الحالية), 1 = Previous (السابقة)
    _tabController = TabController(length: 2, vsync: this);
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
            const SizedBox(height: 15),
            _buildSearch(),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList(isCurrent: true),
                  _buildOrdersList(isCurrent: false),
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
                'طلباتي',
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
        // Custom Tab Bar
        Container(
          height: 55,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF4671AD),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Stack(
            children: [
              Row(
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
                          'الحالية',
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
                          'السابقة',
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
                ],
              ),
              // Let's make it rebuild when tab changes
              AnimatedBuilder(
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
                              'الحالية',
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
                              'السابقة',
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
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Iconsax.search_normal, color: Color(0xFFBDBDBD), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'البحث فى الطلبات',
                hintStyle: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 12,
                  color: Color(0xFFBDBDBD),
                ),
              ),
            ),
          ),
          const Icon(Iconsax.setting_4, color: Color(0xFF4671AD), size: 20),
        ],
      ),
    );
  }

  Widget _buildOrdersList({required bool isCurrent}) {
    if (!isCurrent) {
      return _buildEmptyState(
        title: 'لا توجد طلبات سابقة',
        subtitle: 'ليس لديك اى طلبات سابقة عند الانتهاء\nمن عملية شراء سوف يظهر الطلب هنا',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 15),
      itemBuilder: (context, index) {
        final statuses = ['فى انتظار تأكيد الطلب', 'جارى تجهيز الطلب', 'جارى توصيل الطلب'];
        return _buildOrderCard(statuses[index]);
      },
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.box_time, size: 80, color: const Color(0xFFF3BF45).withOpacity(0.5)),
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

  Widget _buildOrderCard(String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5F5F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Iconsax.document_text, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رقم الطلب : 2578951235',
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'تاريخ الطلب : 16 أكتوبر 2022 - 10:00 صباحاً',
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 12,
                        color: Color(0xFF9F9F9F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(color: Color(0xFFF5F5F5), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'عرض التفاصيل',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'حالة الطلب : ',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                  Text(
                    status,
                    style: const TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF4671AD),
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
}
