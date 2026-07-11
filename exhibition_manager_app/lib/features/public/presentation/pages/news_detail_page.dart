import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/public/data/public_repository.dart';
import 'package:exhibition_manager_app/shared/utils/date_names.dart';
import 'package:exhibition_manager_app/shared/widgets/full_screen_image_viewer.dart';

/// Public news article page — the full story behind a landing news card.
/// The card's image flies in (Hero), the headline sits editorial-style on the
/// page surface, and the body keeps its author line breaks.
class NewsDetailPage extends StatelessWidget {
  final NewsItem item;
  const NewsDetailPage({super.key, required this.item});

  String? get _dateLabel {
    final d = item.publishedAt;
    if (d == null) return null;
    return '${d.day} ${monthName(d.month, short: true)} ${d.year}';
  }

  Future<void> _openLink() async {
    final url = item.linkUrl;
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore — no handler available
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final date = _dateLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _topBar(context),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                if (hasImage)
                  Pressable(
                    onTap: () => showFullScreenGallery(context, [item.imageUrl!]),
                    child: Hero(
                      tag: 'news-${item.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(color: AppColors.shimmerBase),
                            errorWidget: (_, _, _) => DecoratedBox(
                                decoration: BoxDecoration(gradient: AppColors.heroGradient)),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 350.ms),
                if (hasImage) const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Text(
                        context.tr('news_tag'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accentDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.schedule_rounded, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: AppTypography.labelMedium.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ).animate().fadeIn(duration: 350.ms, delay: 60.ms),
                const SizedBox(height: AppSpacing.md),
                Text(
                  item.title,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 100.ms),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 46,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: AppRadius.borderFull,
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 140.ms),
                if ((item.body ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SelectableText(
                    item.body!,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.88),
                      height: 1.95,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 180.ms),
                ],
                if ((item.linkUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Pressable(
                    onTap: _openLink,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: AppRadius.borderLg,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 17),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            context.tr('read_more'),
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 220.ms),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final dark = AppThemeController.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        color: dark ? const Color(0xFF242734) : AppColors.primaryDeep,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, 8),
            child: Row(
              children: [
                Pressable(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: Icon(
                      AppLocalizations.isArabic
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
