import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/typography.dart';

/// Unified AppBar for all screens in the Exhibition Manager app.
///
/// Features:
/// - Consistent royal blue background across all screens
/// - White centered title with bold weight
/// - White icons
/// - Dynamic status bar brightness (light icons on blue)
/// - Optional bottom widget (e.g. search bar, tabs)
/// - Optional actions
class MuntajatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;

  const MuntajatAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation = 0,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: AppTypography.titleLarge.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textOnPrimary,
      elevation: elevation,
      scrolledUnderElevation: 0,
      // Rich brand gradient header for a modern look.
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
      ),
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
      bottom: bottom,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
