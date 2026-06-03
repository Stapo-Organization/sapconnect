import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';

/// Reusable Premium Vector-based Brand Logo for Muntajat
/// Fully matches the high-fidelity designs from Figma.
class MuntajatLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDark;
  final double fontSize;

  const MuntajatLogo({
    super.key,
    this.size = 80.0,
    this.showText = true,
    this.isDark = false,
    this.fontSize = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    // Premium color values matching Muntajat branding tokens
    final accentColor = AppColors.accent; // Gold
    final textColor = isDark ? Colors.white : AppColors.primary;
    final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ─── Premium Brand Icon Container ─────────────────────────
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3A71B3), // Royal Blue
                Color(0xFF1E4880), // Deep Navy
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E4880).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer gold decorative accent ring fragment
              Positioned(
                right: size * 0.10,
                top: size * 0.10,
                child: Container(
                  width: size * 0.26,
                  height: size * 0.26,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Inner premium transparent brand icon (Heart/Paw brand mark)
              Padding(
                padding: EdgeInsets.all(size * 0.16),
                child: Image.asset(
                  'assets/images/logo_transparent.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),

        // ─── Typography & Brand Script ────────────────────────────
        if (showText) ...[
          SizedBox(height: size * 0.18),
          
          // Arabic Vector Logo from Figma Node 1-20111
          SvgPicture.asset(
            'assets/svgs/logo.svg',
            height: fontSize * 0.9,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              textColor,
              BlendMode.srcIn,
            ),
          ),
          
          SizedBox(height: size * 0.06),
          
          // English subtitle logo text
          Text(
            'MUNTAJAT',
            style: AppTypography.labelSmall.copyWith(
              color: subtextColor,
              fontSize: fontSize * 0.34,
              letterSpacing: 3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}
