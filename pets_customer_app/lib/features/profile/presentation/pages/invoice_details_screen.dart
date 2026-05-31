import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  const InvoiceDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'تفاصيل الفاتورة',
          style: TextStyle(
            fontFamily: 'Expo Arabic',
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
        flexibleSpace: SafeArea(
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            child: const Icon(Iconsax.document_download, color: Colors.black, size: 24),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end, // RTL align
          children: [
            // Details Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFF5F5F5)),
              ),
              child: Column(
                children: [
                   _buildDetailRow('نوع الدفع', 'أجل'),
                   _buildDetailRow('رقم الفاتورة', '61515155468421', hasCopy: true),
                   _buildDetailRow('تاريخ الفاتورة', 'الأربعاء 15 مارس 2023'),
                   _buildDetailRow('تاريخ الاستحقاق', 'السبت 30 نوفمبر 2023'),
                   _buildDetailRow('المبلغ المستحق', '25.000 ر.س'),
                   _buildDetailRow('حالة الدفع', 'غير مدفوعة', valueColor: const Color(0xFFFE3A46), isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Products Title
            const Text(
              'المنتجات',
              style: TextStyle(
                fontFamily: 'Expo Arabic',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            
            // Product 1
            _buildProductRow(
              title: 'تيكي دوج الوها بتيتس حزمة متعددة\n4 نكهات للكلاب الصغيرة',
              unit: 'كرتون 6 حبة',
              price: '200 ر.س',
              quantity: '2',
              total: '400 ر.س',
              imageUrl: 'assets/images/store/product_1.png',
            ),
            const SizedBox(height: 10),

            // Product 2
            _buildProductRow(
              title: 'زولكس رودي كوب نشارة خشب الذرة 5 لتر برائحة التوت الأسود والليتشي',
              unit: 'كرتون 1 حبة',
              price: '200 ر.س',
              quantity: '1',
              total: '200 ر.س',
              imageUrl: 'assets/images/store/product_2.png',
            ),
            const SizedBox(height: 20),
            
            // Invoice Summary
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFF5F5F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Text(
                        'ملخص الفاتورة',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Iconsax.receipt, size: 20, color: Colors.black),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Divider(color: Color(0xFFEEEEEE), height: 1),
                  const SizedBox(height: 15),

                  _buildSummaryRow('عدد المنتجات', '3 منتجات'),
                  const SizedBox(height: 15),
                  _buildSummaryRow('سعر المنتجات', '600.00 ر.س'),
                  const SizedBox(height: 15),
                  _buildSummaryRow('الضريبة المضافة 15%', '15.00 ر.س'),
                  const SizedBox(height: 15),
                  _buildSummaryRow('الخصومات', '100.00 ر.س'),
                  const SizedBox(height: 15),
                  
                  const Divider(color: Color(0xFFEEEEEE), height: 1),
                  const SizedBox(height: 15),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '515.00 ر.س',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'السعر الإجمالي',
                        style: TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool hasCopy = false, Color? valueColor, bool isLast = false}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (hasCopy) const Icon(Icons.copy, size: 16, color: Colors.black54),
              if (hasCopy) const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: valueColor ?? Colors.black,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Expo Arabic',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: Color(0xFF9F9F9F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow({
    required String title,
    required String unit,
    required String price,
    required String quantity,
    required String total,
    required String imageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFF5F5F5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.black,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 12,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 10),
                // Price Breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                     // Total
                    Row(
                      children: [
                        Text(
                          total,
                          style: const TextStyle(fontFamily: 'Expo Arabic', fontSize: 12, color: Colors.black),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'الاجمالي :',
                          style: TextStyle(fontFamily: 'Expo Arabic', fontSize: 12, color: Color(0xFFE35446)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Unit price
                    Row(
                      children: [
                        Text(
                          '$quantity x',
                          style: const TextStyle(fontFamily: 'Expo Arabic', fontSize: 12, color: Colors.black),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          price,
                          style: const TextStyle(fontFamily: 'Expo Arabic', fontSize: 12, color: Colors.black),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'السعر :',
                          style: TextStyle(fontFamily: 'Expo Arabic', fontSize: 12, color: Color(0xFFE35446)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          // Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(imageUrl), // Usually remote in prod
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Expo Arabic',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 14,
            color: Color(0xFF757575),
          ),
        ),
      ],
    );
  }
}
