import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'invoice_details_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 0 = غير المدفوعة (Unpaid), 1 = المدفوعة (Paid)
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
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildInvoicesList(isPaid: false),
                  _buildInvoicesList(isPaid: true),
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
              const SizedBox(width: 28),
              const Text(
                'الفواتير',
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Custom Tab Bar with 2 items matching Figma 2:5176
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
                          'غير المدفوعة',
                          style: TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontWeight: FontWeight.w500,
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
                          'المدفوعة',
                          style: TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontWeight: FontWeight.w500,
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
        ),
      ],
    );
  }

  Widget _buildInvoicesList({required bool isPaid}) {
    // Generate dummy items simulating the Figma combinations
    final dummyData = [
      {'type': 'شحن', 'amount': '25.000', 'color': const Color(0xFFFFBE00), 'bg': const Color(0x33F0BC45)},
      {'type': 'خدمة', 'amount': '25.000', 'color': const Color(0xFF6FC200), 'bg': const Color(0x3385E900)},
      {'type': 'طلبات', 'amount': '25.000', 'color': const Color(0xFF0099FF), 'bg': const Color(0x330099FF)},
    ];

    if (isPaid) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        itemCount: 1,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildInvoiceCard(
          isPaid: true,
          type: 'طلبات',
          amount: '120.000',
          typeColor: const Color(0xFF0099FF),
          typeBg: const Color(0x330099FF),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: dummyData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = dummyData[index];
        return _buildInvoiceCard(
          isPaid: false,
          type: item['type'] as String,
          amount: item['amount'] as String,
          typeColor: item['color'] as Color,
          typeBg: item['bg'] as Color,
        );
      },
    );
  }

  Widget _buildInvoiceCard({
    required bool isPaid,
    required String type,
    required String amount,
    required Color typeColor,
    required Color typeBg,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5F5F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row (Type + Info)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: typeBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: typeColor,
                  ),
                ),
              ),
              // Info block
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'المبلغ المستحق : $amount ر.س',
                        style: const TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      const Text(
                        'رقم الفاتورة : 155468421',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontSize: 12,
                          color: Color(0xFF9F9F9F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 41,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Icon(Iconsax.receipt_2, size: 20, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1),
          const SizedBox(height: 15),
          
          // Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: const [
                      Text(
                        'تاريخ الاستحقاق',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: Color(0xFF9F9F9F),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.calendar_today, size: 12, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'الأربعاء 15 مارس 2023',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 30,
                color: const Color(0xFFEEEEEE),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: const [
                      Text(
                        'تاريخ الفاتورة',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: Color(0xFF9F9F9F),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.calendar_today, size: 12, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'الأربعاء 15 مارس 2023',
                    style: TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 15),
          const Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1),
          const SizedBox(height: 15),

          // Bottom Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvoiceDetailsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'عرض التفاصيل',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'حالة الدفع : ',
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                    TextSpan(
                      text: isPaid ? 'مدفوعة' : 'غير مدفوعة',
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: isPaid ? const Color(0xFF6FC200) : const Color(0xFFFE3A46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
