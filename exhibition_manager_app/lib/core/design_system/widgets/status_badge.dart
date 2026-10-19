import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Shopify badge («المتجر»): a soft tone fill with darker text in the same
/// hue, 8px corners, no border. The leading dot is opt-in and small.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.showDot = false,
    this.icon,
  });

  /// Text/icon colour for a badge of [color]: deepened on light surfaces,
  /// lifted on dark ones, so it always reads against its own soft fill.
  static Color ink(Color color) => AppThemeController.isDark
      ? Color.lerp(color, Colors.white, 0.25)!
      : Color.lerp(color, Colors.black, 0.38)!;

  static Color fill(Color color) => color.withValues(alpha: AppThemeController.isDark ? 0.22 : 0.14);

  @override
  Widget build(BuildContext context) {
    final fg = ink(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: fill(color), borderRadius: AppRadius.borderSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label, style: AppTypography.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
