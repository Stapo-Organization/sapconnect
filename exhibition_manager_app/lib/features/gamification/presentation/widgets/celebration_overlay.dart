import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'badge_icons.dart';

/// Show a celebratory overlay after a count is completed, using the
/// `gamification` block returned by the complete endpoint.
Future<void> showCelebration(BuildContext context, Map<String, dynamic> gamification) {
  final points = gamification['points_earned'] ?? 0;
  if (points is int && points <= 0 && (gamification['new_badges'] as List?)?.isEmpty != false) {
    return Future.value();
  }
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'celebration',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _CelebrationDialog(data: gamification),
  );
}

class _CelebrationDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  const _CelebrationDialog({required this.data});

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final points = widget.data['points_earned'] ?? 0;
    final levelUp = widget.data['level_up'] == true;
    final level = widget.data['level'];
    final streak = widget.data['new_streak'];
    final badges = (widget.data['new_badges'] as List?) ?? [];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              blastDirection: math.pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 18,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.25,
              colors: [AppColors.accent, AppColors.primary, AppColors.success, AppColors.primaryLight],
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.xl),
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.borderXxxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(gradient: AppColors.goldGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 42),
                    ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      isArabic ? 'أحسنت! 🎉' : 'Well done! 🎉',
                      style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '+$points',
                      style: AppTypography.displayLarge.copyWith(color: AppColors.accentDark),
                    ).animate().fadeIn().slideY(begin: 0.3, end: 0),
                    Text(isArabic ? 'نقطة' : 'points',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    if (levelUp) ...[
                      const SizedBox(height: AppSpacing.md),
                      _banner(
                        icon: Icons.trending_up_rounded,
                        color: AppColors.primary,
                        text: isArabic ? 'ترقّيت للمستوى $level! 🚀' : 'Level up — Level $level! 🚀',
                      ),
                    ],
                    if (streak is int && streak >= 2) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _banner(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.warning,
                        text: isArabic ? 'سلسلة $streak أسابيع 🔥' : '$streak-week streak 🔥',
                      ),
                    ],
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(isArabic ? 'أوسمة جديدة' : 'New badges',
                          style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        alignment: WrapAlignment.center,
                        children: [
                          for (int i = 0; i < badges.length; i++)
                            _badgeChip(Map<String, dynamic>.from(badges[i] as Map), isArabic)
                                .animate().scale(delay: (200 * i).ms, duration: 350.ms, curve: Curves.easeOutBack),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: isArabic ? 'متابعة' : 'Continue',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.check_rounded,
                      gradient: AppColors.successGradient,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ).animate().scale(begin: const Offset(0.85, 0.85), duration: 300.ms, curve: Curves.easeOutBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(text, style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _badgeChip(Map<String, dynamic> badge, bool isArabic) {
    final name = isArabic ? (badge['name_ar'] ?? '') : (badge['name_en'] ?? '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: Icon(badgeIcon(badge['icon'] ?? 'star'), color: Colors.white, size: 26),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
