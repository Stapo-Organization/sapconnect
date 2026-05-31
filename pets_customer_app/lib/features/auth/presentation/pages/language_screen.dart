import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/logo_transparent.png',
                  height: 100,
                ),
              ),
              const SizedBox(height: 40),
              
              // Title
              const Text(
                'قم باختيار لغتك المفضلة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose Your Default Language',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // Buttons
              _buildLanguageButton(
                context,
                title: 'اللغة العربية',
                flagUrl: 'https://flagcdn.com/w80/sa.png',
                isActive: true,
              ),
              const SizedBox(height: 15),
              _buildLanguageButton(
                context,
                title: 'English Language',
                flagUrl: 'https://flagcdn.com/w80/us.png',
              ),
              const SizedBox(height: 15),
              _buildLanguageButton(
                context,
                title: 'اُرْدُوْ',
                flagUrl: 'https://flagcdn.com/w80/in.png',
              ),

              const Spacer(),
              // Footer
              const Text(
                'يمكنك تغير اللغة لاحقاً من الاعدادات',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'You Can Change The Language Later In The Settings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context, {
    required String title,
    required String flagUrl,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      },
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? Colors.black : Colors.black12, width: isActive ? 1.5 : 1),
          boxShadow: [
            if (!isActive)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            // Next arrow Icon (left side)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3BF45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Expo Arabic',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 15),
            // Flag
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                flagUrl,
                width: 30,
                height: 20,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.flag, size: 20, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
