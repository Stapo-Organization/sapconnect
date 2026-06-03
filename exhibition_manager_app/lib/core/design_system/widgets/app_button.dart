import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/shadows.dart';
import '../tokens/typography.dart';
import 'pressable.dart';

enum AppButtonVariant { filled, tonal, outline }

/// Modern button with press-scale, optional gradient fill, leading icon,
/// loading state and a soft colored glow on the primary (filled) variant.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final Color color;
  final bool expand;
  final bool loading;
  final Gradient? gradient;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.color = AppColors.primary,
    this.expand = true,
    this.loading = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final isFilled = variant == AppButtonVariant.filled;
    final isTonal = variant == AppButtonVariant.tonal;

    Color fg;
    Color? bg;
    Gradient? grad;
    BoxBorder? border;
    List<BoxShadow>? shadow;

    if (isFilled) {
      grad = gradient ?? LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.12)!]);
      fg = Colors.white;
      shadow = disabled ? null : AppShadows.glow(color, alpha: 0.28);
    } else if (isTonal) {
      bg = color.withValues(alpha: 0.12);
      fg = color;
    } else {
      bg = Colors.transparent;
      fg = color;
      border = Border.all(color: color.withValues(alpha: 0.6), width: 1.5);
    }

    final content = Container(
      height: 52,
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: disabled && isFilled ? AppColors.textTertiary : bg,
        gradient: disabled ? null : grad,
        borderRadius: AppRadius.borderMd,
        border: border,
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
            )
          else ...[
            if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Pressable(onTap: disabled ? null : onPressed, child: content),
    );
  }
}
