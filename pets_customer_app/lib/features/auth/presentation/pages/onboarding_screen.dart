import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_screen.dart';
import 'register_company_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/svgs/category_bird.svg',
      'text': 'نظام ولاء مبتكر! احصل على نقاط مع كل عملية شراء نقوم بها. استخدم هذه النقاط في تحسين خدماتنا والاستفادة من العروض الحصرية والمزايا الأخرى.',
    },
    {
      'image': 'assets/svgs/category_cat.svg',
      'text': 'أدر مشتريات فروعك بكفاءة مع تطبيقنا. تتيح لك أدواتنا تحديد وتتبع مستلزمات الحيوانات الأليفة لكل فرع بسهولة، مما يوفر لك التحكم والاستدامة.',
    },
    {
      'image': 'assets/svgs/category_dog.svg',
      'text': 'تجربة تسوق فريدة لمنتجات حيواناتك الأليفة. اختر بسهولة وأطلب منتجاتك المفضلة من أي مكان في أي وقت من خلال تطبيقنا السهل الاستخدام.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/logo_transparent.png',
                  height: 60,
                ),
              ),
              const SizedBox(height: 40),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          _pages[index]['image']!,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 60),
                        SmoothPageIndicator(
                          controller: _controller,
                          count: _pages.length,
                          effect: const ExpandingDotsEffect(
                            dotHeight: 4,
                            dotWidth: 35,
                            activeDotColor: Color(0xFF4671AD),
                            dotColor: Color(0xFFE5E5E5),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _pages[index]['text']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.6,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Buttons
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4671AD),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterCompanyScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F0F0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'انشاء حساب جديد',
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
