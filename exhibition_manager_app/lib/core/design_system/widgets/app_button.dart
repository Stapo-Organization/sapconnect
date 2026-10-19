import 'package:flutter/material.dart';
import '../responsive.dart';
import '../theme/theme_controller.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';
import 'pressable.dart';

enum AppButtonVariant { filled, tonal, outline }

/// Shopify-style button («المتجر»).
///
/// * **filled** — the primary action: solid near-black (blue in dark mode),
///   white label, a 1px lift. A semantic [color] (e.g. error for "delete")
///   fills with that colour instead.
/// * **tonal** — the secondary action: white surface, grey hairline, dark label.
/// * **outline** — a quieter secondary: transparent with a hairline.
///
/// Press feedback, optional leading icon and a loading state.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final Color? color;
  final bool expand;
  final bool loading;
  final Gradient? gradient;

  /// Small size (36pt) for toolbars and inline actions.
  final bool dense;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.color,
    this.expand = true,
    this.loading = false,
    this.gradient,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppThemeController.isDark;
    final color = this.color ?? AppColors.primary;
    final disabled = onPressed == null || loading;
    final isFilled = variant == AppButtonVariant.filled;
    final isTonal = variant == AppButtonVariant.tonal;
    // A non-primary colour on a secondary button is meaning (e.g. error), so
    // the label takes it; otherwise secondary buttons stay neutral ink.
    final neutral = this.color == null || this.color == AppColors.primary;
    final hairline = dark ? const Color(0xFF4A4A4A) : const Color(0xFFD4D4D4);

    Color fg;
    Color? bg;
    Gradient? grad;
    BoxBorder? border;
    List<BoxShadow>? shadow;

    if (isFilled) {
      bg = color;
      grad = gradient;
      // A light fill (e.g. white on a dark summary panel) takes ink, not white.
      fg = color.computeLuminance() > 0.6 ? const Color(0xFF303030) : Colors.white;
      shadow = disabled
          ? null
          : [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.4 : 0.18), blurRadius: 0, offset: const Offset(0, 1))];
    } else if (isTonal) {
      bg = AppColors.surface;
      fg = neutral ? AppColors.textPrimary : color;
      border = Border.all(color: hairline);
      shadow = [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05), blurRadius: 0, offset: const Offset(0, 1))];
    } else {
      bg = Colors.transparent;
      fg = neutral ? AppColors.textPrimary : color;
      border = Border.all(color: neutral ? hairline : color.withValues(alpha: 0.5));
    }

    final content = Container(
      height: dense ? 36 : 48,
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: dense ? 12 : context.byWidth(regular: 18.0, compact: 12.0)),
      decoration: BoxDecoration(
        color: disabled && isFilled ? AppColors.border : (grad == null ? bg : null),
        gradient: disabled ? null : grad,
        borderRadius: dense ? BorderRadius.circular(10) : AppRadius.borderMd,
        border: border,
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else ...[
            if (icon != null) ...[
              Icon(icon, size: 18, color: disabled && isFilled ? AppColors.textTertiary : fg),
              const SizedBox(width: 8),
            ],
            // Full-width buttons shrink a long label to fit narrow phones
            // instead of overflowing; inline buttons keep their natural size.
            if (expand)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      maxLines: 1,
                      style: AppTypography.labelLarge.copyWith(
                          fontSize: 15, color: disabled && isFilled ? AppColors.textTertiary : fg)),
                ),
              )
            else
              Text(label,
                  style: AppTypography.labelLarge.copyWith(
                      fontSize: dense ? 13 : 14, color: disabled && isFilled ? AppColors.textTertiary : fg)),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: disabled && !isFilled ? 0.5 : 1,
      child: Pressable(onTap: disabled ? null : onPressed, child: content),
    );
  }
}
