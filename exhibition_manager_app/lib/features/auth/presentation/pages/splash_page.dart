import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/storage/secure_storage.dart';
import 'package:exhibition_manager_app/features/auth/data/auth_repository.dart';
import 'package:exhibition_manager_app/features/owner_command/owner_routing.dart';
import 'package:exhibition_manager_app/features/public/data/public_repository.dart';
import 'package:exhibition_manager_app/features/public/presentation/pages/public_landing_page.dart';

/// Splash Page — Figma-based warm cream canvas with:
/// 1. Cream background (#F8EDDF)
/// 2. Paw-print & bone pattern overlay (Figma node 1-13719)
/// 3. Heart logo PNG (Figma node 1-13597)
/// 4. "Muntajat" PNG (Figma node 1-13708)
/// 5. "منتجات" SVG vector (Figma node 1-13709)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Figma-extracted palette
  static const _creamBg = Color(0xFFF8EDDF);
  static const _gold = Color(0xFFE4C88B);

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

    _boot();
  }

  Future<void> _clearSessionOnFreshInstall() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final marker = File('${dir.path}/.installed');
      if (!marker.existsSync()) {
        await SecureStorage.clearAuth();
        marker.createSync(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _boot() async {
    final repo = AuthRepository();
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 2400));

    await _clearSessionOnFreshInstall();
    final user = await repo.getCurrentUser();

    if (!mounted) return;

    if (user != null) {
      await minSplash;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OwnerRouting.shellFor(user)),
      );
      return;
    }

    final result = await PublicRepository().fetchLanding().timeout(
          const Duration(seconds: 5),
          onTimeout: () => (success: false, error: null, data: null),
        );

    await minSplash;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PublicLandingPage(initialData: result.data)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creamBg,
      body: Stack(
        children: [
          // ─── Layer 1: Paw-print & bone pattern (Figma node 1-13719) ─
          Positioned.fill(
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.35,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Tile the SVG pattern across the entire screen
                    final tileSize = 200.0;
                    final cols = (constraints.maxWidth / tileSize).ceil() + 1;
                    final rows = (constraints.maxHeight / tileSize).ceil() + 1;
                    return Stack(
                      children: [
                        for (int r = 0; r < rows; r++)
                          for (int c = 0; c < cols; c++)
                            Positioned(
                              left: c * tileSize,
                              top: r * tileSize,
                              child: SvgPicture.asset(
                                'assets/svgs/splash_bg_pattern.svg',
                                width: tileSize,
                                height: tileSize,
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // ─── Layer 2: Center Content (exact Figma elements) ──────
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
                        // ── Heart Logo (Figma node 1-13597) ──────
                        Image.asset(
                          'assets/images/logo_transparent.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: AppSpacing.lg),

                        // ── "Muntajat" English (Figma node 1-13708) ──
                        Text(
                          'Muntajat',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 38,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFF4BE2C),
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),

                        // ── "منتجات" Arabic SVG (Figma node 1-13709) ──
                        SvgPicture.asset(
                          'assets/svgs/logo.svg',
                          height: 33,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Layer 3: Bottom Loading Indicator ──────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(_gold.withValues(alpha: 0.6)),
                ),
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
          ),
        ],
      ),
    );
  }
}
