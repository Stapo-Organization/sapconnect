import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/pressable.dart';

import '../owner_theme.dart';

/// بطاقة مؤشّر داكنة مدمجة لصفّ «نبض الشبكة» — أيقونة ملوّنة + قيمة بارزة + وصف
/// مكتوم، على سطح سليت. ألوان صريحة (لا وراثة ثيم) لتعمل فوق الخلفية الداكنة.
class OwnerKpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback? onTap;
  final double width;

  const OwnerKpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.onTap,
    this.width = 150,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: OwnerTheme.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: OwnerTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowIconChip(icon: icon, color: accent, size: 34, iconSize: 18, borderRadius: AppRadius.borderMd),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              color: OwnerTheme.textHi,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(color: OwnerTheme.textMuted),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, borderRadius: AppRadius.borderLg, child: card);
  }
}
