import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/theme/theme_controller.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/typography.dart';

/// Unified top bar for every pushed screen («المتجر», Shopify-calm).
///
/// White surface, a hairline underneath, dark centred title and dark icons —
/// the page content carries the colour, not the chrome. Status-bar icons
/// follow the mode (dark on the light bar, light on the graphite one).
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
    final dark = AppThemeController.isDark;
    return AppBar(
      title: Text(
        title,
        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
      centerTitle: centerTitle,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      actionsIconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      elevation: elevation,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
      bottom: bottom,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
