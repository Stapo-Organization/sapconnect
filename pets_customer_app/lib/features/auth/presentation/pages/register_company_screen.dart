import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/main_layout.dart';
import 'login_screen.dart';

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(), 
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section (Title & Progress)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/svgs/progress_1_4.svg',
                        width: 86,
                        height: 86,
                      ),
                      const Text(
                        '1 من 4',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Expo_Arabic',
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        'معلومات الشركة',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontFamily: 'Expo_Arabic',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ادخل معلومات شركتك',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9F9F9F),
                          fontFamily: 'Expo_Arabic',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Form Fields
              _buildTextField('اسم الشركة'),
              const SizedBox(height: 20),
              _buildTextField('رقم السجل التجاري', keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              _buildTextField('عنوان المكتب الرئيسي'),
              const SizedBox(height: 20),
              _buildTextField('الرقم الضريبي', keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              _buildDropdownField('نشاط الشركة'),
              const SizedBox(height: 32),

              // Terms & Conditions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RichText(
                    text: const TextSpan(
                      text: 'أوافق علي ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontFamily: 'Expo_Arabic',
                      ),
                      children: [
                        TextSpan(
                          text: 'الشروط والاحكام',
                          style: TextStyle(
                            color: Color(0xFFF3BF45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' الخاصة بالتطبيق'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          _agreedToTerms = val ?? false;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Next Button
              ElevatedButton(
                onPressed: _agreedToTerms ? () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainLayout()),
                  );
                } : null,
                child: const Text('التالي'),
              ),
              const SizedBox(height: 24),

              // Login Link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'عندك حساب بالفعل؟ ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9F9F9F),
                        fontFamily: 'Expo_Arabic',
                      ),
                      children: [
                        TextSpan(
                          text: 'سجل الدخول',
                          style: TextStyle(
                            color: Color(0xFFF3BF45),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {TextInputType? keyboardType}) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextField(
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'Expo_Arabic',
          ),
          floatingLabelAlignment: FloatingLabelAlignment.start,
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DropdownButtonFormField<String>(
        items: const [],
        onChanged: (val) {},
        icon: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: SvgPicture.asset('assets/svgs/chevron_down.svg'),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'Expo_Arabic',
          ),
        ),
      ),
    );
  }
}
