import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Selectable rounded chip (filters). Replaces ad-hoc `_FilterChip`s.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c : AppColors.surface,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: selected ? c : AppColors.border),
          boxShadow: selected
              ? [BoxShadow(color: c.withValues(alpha: 0.20), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
