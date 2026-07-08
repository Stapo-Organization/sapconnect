import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/gradient_header.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/pressable.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../owner_theme.dart';

/// مدخل واحد في مركز فرعي للمالك.
class OwnerHubEntry {
  final IconData icon;
  final Color color;
  final String titleKey;
  final String subtitleKey;
  final WidgetBuilder builder; // الصفحة الكاملة تُفتح بالدفع (زر الرجوع يعمل طبيعياً)

  const OwnerHubEntry({
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.subtitleKey,
    required this.builder,
  });
}

/// مركز فرعي سليت قابل لإعادة الاستخدام (تبويبا «المخزون والشحن» و«الموافقات»).
/// بطاقات كبيرة تدفع الصفحات الكاملة بدل تضمينها — فتبقى رؤوسها وأزرار رجوعها
/// سليمة دون تعديل تلك الصفحات.
class OwnerHubPage extends StatelessWidget {
  final String titleKey;
  final String subtitleKey;
  final List<OwnerHubEntry> entries;

  const OwnerHubPage({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: OwnerTheme.bg,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              gradient: OwnerTheme.heroGradient,
              title: context.tr(titleKey),
              subtitle: context.tr(subtitleKey),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
                child: _card(context, entries[i])
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (i * 70).ms)
                    .slideY(begin: 0.10, curve: Curves.easeOutCubic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, OwnerHubEntry e) {
    return Pressable(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: e.builder)),
      borderRadius: AppRadius.borderXl,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: OwnerTheme.surface,
          borderRadius: AppRadius.borderXl,
          border: Border.all(color: OwnerTheme.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: e.color.withValues(alpha: 0.18),
                borderRadius: AppRadius.borderLg,
              ),
              child: Icon(e.icon, size: 24, color: e.color),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(e.titleKey),
                    style: AppTypography.titleMedium.copyWith(
                      color: OwnerTheme.textHi,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr(e.subtitleKey),
                    style: AppTypography.bodySmall.copyWith(color: OwnerTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_left_rounded, size: 22, color: OwnerTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
