import 'package:flutter/material.dart';
import '../../../home/presentation/pages/main_layout.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _nextField(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: TextField(
          controller: _otpControllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (value) => _nextField(value, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تاكيد رقم الجوال',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Expo_Arabic',
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Password Placeholder Icon
              Stack(
                alignment: Alignment.centerRight,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '***',
                      style: TextStyle(fontSize: 40, letterSpacing: 8, height: 1.2),
                    ),
                  ),
                  Positioned(
                    right: -15,
                    bottom: -10,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock, color: Color(0xFFF3BF45), size: 45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Description
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontFamily: 'Expo_Arabic',
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(text: 'أدخل رمز التأكيد OTP المكون من 4 ارقام الذى تم أرساله\n'),
                    TextSpan(text: 'إلى رقم الجوال '),
                    TextSpan(
                      text: '+966 40 246 6733',
                      style: TextStyle(fontFamily: 'sans-serif'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Change Number Link
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'تغيير رقم الجوال',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFF3BF45),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Expo_Arabic',
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFF3BF45),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) => _buildOtpBox(index)),
              ),
              
              const SizedBox(height: 32),
              // Resend code timer
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9F9F9F),
                    fontFamily: 'Expo_Arabic',
                  ),
                  children: [
                    TextSpan(text: 'يمكنك إعادة ارسال الكود خلال '),
                    TextSpan(
                      text: '01:59',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        color: Color(0xFF4671AD),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to MainLayout upon success
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainLayout()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4671AD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'تأكيد',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Expo_Arabic',
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
