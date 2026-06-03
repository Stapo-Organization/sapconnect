import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_logo.dart';
import 'package:exhibition_manager_app/features/auth/data/auth_repository.dart';
import 'package:exhibition_manager_app/features/auth/presentation/pages/login_page.dart';
import 'package:exhibition_manager_app/features/home/presentation/pages/main_shell.dart';

/// Splash Page — Shows logo and checks auth status
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();

    // Check auth after animation
    Future.delayed(const Duration(seconds: 2), _checkAuth);
  }

  Future<void> _checkAuth() async {
    final repo = AuthRepository();
    final user = await repo.getCurrentUser();

    if (!mounted) return;

    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(user: user)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ─── Background Gradient & Watermark ───────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF3A71B3), // Royal Blue
                    Color(0xFF1E4880), // Deep Navy
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: Transform.scale(
                scale: 2.2,
                child: Image.asset(
                  'assets/images/watermark.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // ─── Center Content ────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reusable Premium Vector Logo
                        const MuntajatLogo(
                          size: 110,
                          showText: false,
                          isDark: true,
                        ),
                        SizedBox(height: AppSpacing.xl),
                        Text(
                          context.tr('app_title'),
                          style: AppTypography.headlineLarge.copyWith(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          context.tr('app_subtitle'),
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: AppSpacing.huge),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

