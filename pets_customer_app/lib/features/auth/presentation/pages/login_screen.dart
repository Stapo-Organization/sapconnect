import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'register_company_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Heart Logo
              Center(
                child: Image.asset(
                  'assets/images/logo_transparent.png',
                  height: 116,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // Header
              const Text(
                'أهلا بعودتك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Expo_Arabic',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سجل الدخول الى حسابك الان للتمتع بخدماتنا.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9F9F9F),
                  fontFamily: 'Expo_Arabic',
                ),
              ),
              const SizedBox(height: 40),

              // Phone Number Input field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'رقم الجوال',
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontFamily: 'Expo_Arabic',
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  alignLabelWithHint: true,
                  hintText: '214219401242',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF4671AD)),
                  ),
                  suffixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF249F58),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: SvgPicture.asset(
                              'assets/svgs/sa_flag.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '+966',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9F9F9F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to OTP instead of MainLayout right away for the flow
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OtpScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4671AD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Expo_Arabic',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Register Link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterCompanyScreen()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'ما عندك حساب؟ ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9F9F9F),
                        fontFamily: 'Expo_Arabic',
                      ),
                      children: [
                        TextSpan(
                          text: 'انشاء حساب جديد',
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
}
