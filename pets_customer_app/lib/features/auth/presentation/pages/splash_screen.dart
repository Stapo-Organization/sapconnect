import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LanguageScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Watermark Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Transform.scale(
                scale: 2.0,
                child: Image.asset(
                  'assets/images/watermark.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Heart Logo
                Image.asset(
                  'assets/images/logo_transparent.png',
                  height: 160,
                ),
                const SizedBox(height: 24),
                
                // Muntajat English Text
                const Text(
                  'Muntajat',
                  style: TextStyle(
                    fontSize: 44,
                    color: Color(0xFF3a71b3),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'serif',
                  ),
                ),
                
                // Muntajat Arabic SVG Logo
                SvgPicture.asset(
                  'assets/svgs/splash_logo.svg',
                  width: 120,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF3a71b3),
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
