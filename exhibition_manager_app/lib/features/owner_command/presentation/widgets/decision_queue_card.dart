import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/pressable.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../owner_theme.dart';

/// عنصر واحد في طابور القرارات.
class DecisionItem {
  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final bool ok; // هل حُمِّل مصدره بنجاح؟ (المصادر الفاشلة تُحجب)
  final VoidCallback onTap;

  const DecisionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.ok,
    required this.onTap,
  });
}

/// بطاقة «ما ينتظر قرارك» — صفوف المصادر التي تحتاج تدخّل المالك (عروض/توزيع/
/// جودة/شحن)، كلٌّ بعدّاده ونقرة تفتح الصفحة المعنيّة. الصفوف الصفرية مخفيّة؛
/// إن خلا الطابور أُظهرت حالة «كل شيء على ما يرام».
class DecisionQueueCard extends StatelessWidget {
  final List<DecisionItem> items;

  const DecisionQueueCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final active = items.where((e) => e.ok && e.count > 0).toList();
    final total = active.fold<int>(0, (a, b) => a + b.count);

    return Container(
      decoration: BoxDecoration(
        color: OwnerTheme.surface,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: OwnerTheme.hairline),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // البرق يهتز اهتزازة تنبيهية عند وجود قرارات معلّقة.
              if (total > 0)
                WiggleIcon(
                  delay: const Duration(milliseconds: 500),
                  child: Icon(Icons.bolt_rounded, size: 18, color: OwnerTheme.accent),
                )
              else
                Icon(Icons.bolt_rounded, size: 18, color: OwnerTheme.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('owner_queue_title'),
                  style: AppTypography.titleSmall.copyWith(
                    color: OwnerTheme.textHi,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (total > 0) _totalBadge(total),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (active.isEmpty)
            _allClear(context)
          else
            ...List.generate(
              active.length,
              (i) => PopIn(
                delay: Duration(milliseconds: 60 * i),
                child: _row(context, active[i], i == active.length - 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalBadge(int total) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: OwnerTheme.accent,
          borderRadius: AppRadius.borderFull,
        ),
        child: Text(
          '$total',
          style: AppTypography.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _row(BuildContext context, DecisionItem item, bool last) {
    return Pressable(
      onTap: item.onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        margin: EdgeInsets.only(bottom: last ? 0 : AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: OwnerTheme.surfaceHi,
          borderRadius: AppRadius.borderMd,
        ),
        child: Row(
          children: [
            GlowIconChip(icon: item.icon, color: item.color, size: 30, iconSize: 16, borderRadius: AppRadius.borderSm),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: OwnerTheme.textHi,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.20),
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                '${item.count}',
                style: AppTypography.labelMedium.copyWith(
                  color: item.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, size: 20, color: OwnerTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _allClear(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        decoration: BoxDecoration(
          color: OwnerTheme.positive.withValues(alpha: 0.10),
          borderRadius: AppRadius.borderMd,
        ),
        child: Column(
          children: [
            // «كل شيء تمام» تتنفّس بهدوء — إشارة حيّة مطمئنة.
            BreathingIcon(
              child: Icon(Icons.verified_rounded, size: 30, color: OwnerTheme.positive),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('owner_queue_clear'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: OwnerTheme.textHi,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}
