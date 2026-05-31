import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ProfileDashboardScreen extends StatefulWidget {
  const ProfileDashboardScreen({super.key});

  @override
  State<ProfileDashboardScreen> createState() => _ProfileDashboardScreenState();
}

class _ProfileDashboardScreenState extends State<ProfileDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
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
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildActionButtons(),
          const SizedBox(height: 20),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildClientDataTab(),
                _buildTransactionHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Background gradient
        Container(
          height: 350,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF0F2F7), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              // AppBar substitute
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24), // Placeholder for balance
                    const Text(
                      'الملف الشخصي',
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
              // Profile Info
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4671AD), width: 2),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/placeholder_ad.png'), // Replace with actual avatar
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF696969), Color(0xFFC7C7C7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'عميل فضي',
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'محمد مصطفي',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 25),
              // Financial Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildFinancialCard(
                      title: 'الدفعات المدفوعة',
                      amount: '1,200,000',
                      icon: Iconsax.tick_circle,
                    ),
                    const SizedBox(width: 10),
                    _buildFinancialCard(
                      title: 'الدفعات المستحقة',
                      amount: '600,000',
                      icon: Iconsax.clock,
                    ),
                    const SizedBox(width: 10),
                    _buildFinancialCard(
                      title: 'رصيد العميل',
                      amount: '900,000',
                      icon: Iconsax.wallet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard({
    required String title,
    required String amount,
    required IconData icon,
  }) {
    return Container(
      width: 130,
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFF3BF45), size: 28),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Expo Arabic',
              fontSize: 11,
              color: Color(0xFF9F9F9F),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF4671AD),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'ر.س',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 10,
                  color: Color(0xFF9F9F9F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Iconsax.call, color: Color(0xFF3A71B3), size: 20),
              label: const Text(
                'اتصال',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF3A71B3),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A71B3).withOpacity(0.12),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFF3A71B3)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Iconsax.messages_2, color: Colors.white, size: 20),
              label: const Text(
                'محادثة',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4671AD),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEAEAEA), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black,
        unselectedLabelColor: const Color(0xFF757575),
        labelStyle: const TextStyle(
          fontFamily: 'Expo Arabic',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Expo Arabic',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        indicatorColor: const Color(0xFF4671AD),
        indicatorWeight: 3,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 24),
        tabs: const [
          Tab(text: 'بيانات العميل'),
          Tab(text: 'سجل العمليات'),
        ],
      ),
    );
  }

  Widget _buildClientDataTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildInfoBox(
          title: 'تاريخ فتح الحساب',
          subtitle: '23 يناير 2024',
          icon: Iconsax.calendar_1,
        ),
        const SizedBox(height: 15),
        _buildInfoBox(
          title: 'العنوان',
          subtitle: '95 شارع ناصر بن حعوان,حفر الباطن',
          icon: Iconsax.location,
        ),
        const SizedBox(height: 15),
        _buildInfoBox(
          title: 'رقم الجوال',
          subtitle: '+966563913735',
          icon: Iconsax.call,
        ),
        const SizedBox(height: 15),
        _buildInfoBox(
          title: 'تاريخ اخر فاتورة',
          subtitle: '23 يناير 2024',
          icon: Iconsax.document,
        ),
      ],
    );
  }

  Widget _buildInfoBox({required String title, required String subtitle, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF6F6F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF4671AD), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
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
    );
  }

  Widget _buildTransactionHistoryTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFFEAEAEA), height: 30),
      itemBuilder: (context, index) {
        final isPositive = index == 0 || index == 2;
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down_2,
                color: isPositive ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عملية شراء للمنتجات',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '16 أكتوبر 2022 - 10:00 صباحاً',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 12,
                      color: Color(0xFF9F9F9F),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'نقطة',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 12,
                    color: Color(0xFF9F9F9F),
                  ),
                ),
                Text(
                  isPositive ? '+ 150' : '- 150',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
