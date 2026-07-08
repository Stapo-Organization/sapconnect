import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/promotions/data/models/campaign.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/widgets/retry_network_image.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/widgets/promotion_card.dart'
    show campaignTypeColor, campaignTypeIcon, campaignTypeLabel;

/// Compact, image-forward promo card for dense layouts — the Home horizontal
/// slider and the 2-column suggestions grid. The image fills all spare height
/// (no dead space under the name); bundles show a 2–3 product collage. Tap opens
/// the composer/detail page.
class CompactPromotionCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const CompactPromotionCard({
    super.key,
    required this.campaign,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppDomain.promotions.accent;
    final typeColor = campaignTypeColor(campaign.campaignType);
    final concept = campaign.isSuggested;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── imagery (fills all spare height) ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageArea(accent),
                  PositionedDirectional(top: 8, start: 8, child: _typeChip(context, typeColor)),
                  if (concept && onDismiss != null)
                    PositionedDirectional(top: 5, end: 5, child: _dismissBtn())
                  else if (!concept)
                    PositionedDirectional(top: 8, end: 8, child: _statusPill(context)),
                ],
              ),
            ),

            // ── footer (sizes to content — no gap) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.displayName,
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  _why(context, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── imagery ──
  Widget _imageArea(Color accent) {
    final banner = campaign.primaryCreative?.image;
    if (banner != null) {
      return RetryNetworkImage(url: banner, fit: BoxFit.cover, errorBuilder: (_) => _placeholder(accent));
    }
    final imgs = campaign.products.map((p) => p.imageUrl).whereType<String>().toList();
    if (imgs.isEmpty) return _placeholder(accent);
    if (imgs.length == 1) return _photo(imgs.first, accent);
    return _collage(imgs.take(3).toList(), accent);
  }

  /// Single product on a clean white stage.
  Widget _photo(String url, Color accent) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(6),
        child: RetryNetworkImage(url: url, fit: BoxFit.contain, errorBuilder: (_) => _cellError()),
      );

  /// 2–3 products side by side (bundles).
  Widget _collage(List<String> imgs, Color accent) => Container(
        color: Colors.white,
        child: Row(
          children: [
            for (int i = 0; i < imgs.length; i++) ...[
              if (i > 0) Container(width: 1, color: AppColors.borderLight),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: RetryNetworkImage(url: imgs[i], fit: BoxFit.contain, errorBuilder: (_) => _cellError()),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _cellError() => Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.textTertiary, size: 22),
      );

  Widget _placeholder(Color accent) => Container(
        decoration: BoxDecoration(gradient: AppDomain.promotions.gradient),
        child: const Center(child: Icon(Icons.campaign_rounded, color: Colors.white, size: 30)),
      );

  // ── overlays ──
  Widget _typeChip(BuildContext context, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 5, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(campaignTypeIcon(campaign.campaignType), color: Colors.white, size: 11),
            const SizedBox(width: 3),
            Text(campaignTypeLabel(context, campaign.campaignType),
                style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
          ],
        ),
      );

  Widget _dismissBtn() => DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
        child: InkWell(
          onTap: onDismiss,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, color: Colors.white, size: 14),
          ),
        ),
      );

  Widget _statusPill(BuildContext context) {
    final (label, color) = switch (campaign.status) {
      'approved' => (context.tr('promo_status_preview'), AppColors.warning),
      'active' => (context.tr('promo_tab_active'), AppColors.success),
      'scheduled' => (context.tr('promo_tab_scheduled'), AppColors.info),
      _ => (context.tr('promo_tab_ended'), AppColors.textTertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }

  // ── one-line "why" ──
  Widget _why(BuildContext context, Color accent) {
    final reason = campaign.reason;
    if (reason != null && reason.isNotEmpty) {
      return Row(
        children: [
          Icon(Icons.lightbulb_rounded, size: 12, color: accent),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              reason,
              style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Text(
      campaignTypeLabel(context, campaign.campaignType),
      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
