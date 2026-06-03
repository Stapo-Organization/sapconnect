import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Small icon + label pill used for inline stats (items, pieces, dates).
class StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const StatChip({super.key, required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textSecondary).withValues(alpha: 0.06),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: c, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
