import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/promotions/data/models/campaign.dart';

/// Arabic label for a campaign type.
String campaignTypeLabel(BuildContext context, String type) {
  switch (type) {
    case 'clearance':
      return context.tr('promo_type_clearance');
    case 'bundle':
      return context.tr('promo_type_bundle');
    case 'new_arrival':
      return context.tr('promo_type_new_arrival');
    case 'express':
      return context.tr('promo_type_express');
    case 'spotlight':
    default:
      return context.tr('promo_type_spotlight');
  }
}

/// Accent color per campaign type (visual variety in the feed).
Color campaignTypeColor(String type) {
  switch (type) {
    case 'clearance':
      return const Color(0xFFE0533B); // warm red
    case 'express':
      return const Color(0xFF0E9F8E); // teal
    case 'bundle':
      return const Color(0xFF2D7DD2); // blue
    case 'new_arrival':
      return const Color(0xFF3FA34D); // green
    case 'spotlight':
    default:
      return const Color(0xFF9333EA); // violet
  }
}

IconData campaignTypeIcon(String type) {
  switch (type) {
    case 'clearance':
      return Icons.local_fire_department_rounded;
    case 'express':
      return Icons.bolt_rounded;
    case 'bundle':
      return Icons.layers_rounded;
    case 'new_arrival':
      return Icons.fiber_new_rounded;
    case 'spotlight':
    default:
      return Icons.star_rounded;
  }
}

/// Bold, image-forward suggestion card: product imagery leads, the "why" reason
/// is prominent, smart signals as chips, and a clear "turn into ad" CTA.
class PromotionCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const PromotionCard({super.key, required this.campaign, required this.onTap, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final accent = AppDomain.promotions.accent;
    final typeColor = campaignTypeColor(campaign.campaignType);
    final banner = campaign.primaryCreative?.image; // AI banner once generated
    final concept = campaign.isSuggested; // no ad yet → discovery card

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── imagery ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 168,
                    width: double.infinity,
                    child: banner != null ? _banner(banner, accent) : _collage(accent),
                  ),
                  // type chip
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: _typeChip(context, typeColor),
                  ),
                  // status (only when past suggestion)
                  if (!concept)
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: _statusPill(context),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.displayName,
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((campaign.reason ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _reasonBox(accent),
                  ],
                  ..._signals(context, accent),
                  const SizedBox(height: AppSpacing.md),
                  concept ? _conceptActions(context, accent) : _footer(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── imagery widgets ──
  Widget _banner(String url, Color accent) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (c, u) => _shimmer(),
        errorWidget: (_, _, _) => _placeholder(accent),
      );

  Widget _collage(Color accent) {
    final imgs = campaign.products.map((p) => p.imageUrl).whereType<String>().take(3).toList();
    if (imgs.isEmpty) return _placeholder(accent);
    if (imgs.length == 1) {
      return Container(
        color: Colors.white,
        child: CachedNetworkImage(
          imageUrl: imgs.first,
          fit: BoxFit.contain,
          placeholder: (c, u) => _shimmer(),
          errorWidget: (_, _, _) => _placeholder(accent),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          for (int i = 0; i < imgs.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: CachedNetworkImage(
                imageUrl: imgs[i],
                fit: BoxFit.contain,
                placeholder: (c, u) => _shimmer(),
                errorWidget: (_, _, _) => Container(color: AppColors.surfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.surface,
        child: Container(color: Colors.white),
      );

  Widget _placeholder(Color accent) => Container(
        decoration: BoxDecoration(gradient: AppDomain.promotions.gradient),
        child: const Center(child: Icon(Icons.campaign_rounded, color: Colors.white, size: 40)),
      );

  // ── overlay chips ──
  Widget _typeChip(BuildContext context, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(campaignTypeIcon(campaign.campaignType), color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(campaignTypeLabel(context, campaign.campaignType),
                style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }

  // ── reason ──
  Widget _reasonBox(Color accent) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: AppRadius.borderSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_rounded, color: accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                campaign.reason!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  // ── smart signals ──
  List<Widget> _signals(BuildContext context, Color accent) {
    final chips = <Widget>[];
    final r = campaign.rationale;
    num? n(String k) => r[k] is num ? r[k] as num : num.tryParse('${r[k]}');
    String fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    void add(String label) => chips.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: AppTypography.labelSmall.copyWith(color: accent, fontWeight: FontWeight.w700)),
        ));

    if (n('lps') != null) add('${context.tr('promo_sig_lps')} ${fmt(n('lps')!)}');
    if (n('fbt_lift') != null) add('${context.tr('promo_sig_fbt')} ×${fmt(n('fbt_lift')!)}');
    if (n('days_of_cover') != null) add('${context.tr('promo_sig_cover')} ${fmt(n('days_of_cover')!)}');
    if (chips.length < 3 && n('composite_rank_score') != null) {
      add('${context.tr('promo_sig_rank')} ${fmt(n('composite_rank_score')!)}');
    }
    if (chips.length < 3 && r['abc_class'] != null) add('ABC ${r['abc_class']}');

    if (chips.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: 6, runSpacing: 6, children: chips.take(3).toList()),
    ];
  }

  // ── actions / footer ──
  Widget _conceptActions(BuildContext context, Color accent) => Row(
        children: [
          if (onDismiss != null) ...[
            Expanded(
              child: AppButton(
                label: context.tr('promo_dismiss'),
                onPressed: onDismiss,
                variant: AppButtonVariant.outline,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              label: context.tr('promo_convert'),
              icon: Icons.arrow_back_rounded,
              onPressed: onTap,
              color: accent,
            ),
          ),
        ],
      );

  Widget _footer(BuildContext context) => Row(
        children: [
          Icon(Icons.place_rounded, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              campaign.placement != null ? context.tr('promo_placement_${campaign.placement}') : context.tr('promo_open'),
              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textTertiary),
        ],
      );
}
