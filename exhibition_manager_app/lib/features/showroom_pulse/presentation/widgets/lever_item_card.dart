import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/pulse_overview.dart';
import 'pulse_helpers.dart';

/// Professional lever item card: product image, name, SAP code + barcode
/// (with icons), a status pill, a stats line, and a money-hero footer with a
/// compact action. Pure presentation — the page supplies the action.
class LeverItemCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String itemCode;
  final String? barcode;
  final String healthStatus;
  final String heroValue;   // e.g. "١٣٬١٠٧ ر.س"
  final String heroLabel;   // e.g. "خسارة شهرية متوقعة"
  final Color accent;
  final String statsText;   // e.g. "يبيع ٠٫٩/يوم · المخزون ٠"
  final Widget action;
  final VoidCallback? onOpenProduct; // tap the card → product detail

  const LeverItemCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.itemCode,
    required this.barcode,
    required this.healthStatus,
    required this.heroValue,
    required this.heroLabel,
    required this.accent,
    required this.statsText,
    required this.action,
    this.onOpenProduct,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              productThumb(imageUrl, size: 56, accent: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _codeLine(),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _healthPill(),
            ],
          ),
          if (statsText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              statsText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heroValue,
                      style: AppTypography.titleLarge.copyWith(color: accent, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 1),
                    Text(heroLabel, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              action,
            ],
          ),
        ],
      ),
    );
    if (onOpenProduct == null) return card;
    return GestureDetector(
      onTap: onOpenProduct,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }

  Widget _codeLine() {
    final parts = <Widget>[
      Icon(Icons.tag_rounded, size: 13, color: AppColors.textTertiary),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          itemCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
        ),
      ),
    ];
    if (barcode != null && barcode!.isNotEmpty) {
      parts.addAll([
        const SizedBox(width: 10),
        Icon(Icons.qr_code_2_rounded, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            barcode!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ]);
    }
    return Row(children: parts);
  }

  Widget _healthPill() {
    final c = healthColor(healthStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
      child: Text(
        healthLabel(healthStatus),
        style: AppTypography.labelSmall.copyWith(color: c, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Compact pill action (≈38px tall, content-width) — far lighter than the
/// full-width AppButton, so the money figure stays the hero of the card.
Widget _compactBtn({
  required String label,
  IconData? icon,
  required Color fg,
  Color? bg,
  Color? borderColor,
  bool loading = false,
  VoidCallback? onTap,
}) {
  final content = Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      border: borderColor != null ? Border.all(color: borderColor, width: 1.4) : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else ...[
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Text(label, style: AppTypography.labelMedium.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ],
    ),
  );
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(borderRadius: BorderRadius.circular(11), onTap: loading ? null : onTap, child: content),
  );
}

/// 🔴 Build a bleeding card from a [BleedingItem].
Widget bleedingCard(
  BleedingItem item, {
  required bool busy,
  required bool requested,
  required VoidCallback onRequest,
  VoidCallback? onOpenProduct,
}) {
  final hasLoss = item.lostRevenueMonthly > 0;
  final heroValue = hasLoss
      ? sar(item.lostRevenueMonthly)
      : (item.daysOfCover != null
          ? AppLocalizations.translate('sp_covers_n_days')
              .replaceAll('{n}', '${item.daysOfCover!.round()}')
          : AppLocalizations.translate('sp_low_stock'));
  final heroLabel = hasLoss
      ? AppLocalizations.translate('sp_expected_monthly_loss')
      : AppLocalizations.translate('sp_stock_cover');
  final stats = <String>[
    if (item.velocity > 0)
      AppLocalizations.translate('sp_sells_per_day')
          .replaceAll('{n}', item.velocity.toStringAsFixed(1)),
    AppLocalizations.translate('sp_in_branch').replaceAll('{n}', '${item.currentStock.round()}'),
    AppLocalizations.translate('sp_total_stock').replaceAll('{n}', '${item.totalStock.round()}'),
  ].join('  ·  ');

  return LeverItemCard(
    imageUrl: item.imageUrl,
    name: item.name,
    itemCode: item.itemCode,
    barcode: item.barcode,
    healthStatus: item.healthStatus,
    heroValue: heroValue,
    heroLabel: heroLabel,
    accent: kBleedingColor,
    statsText: stats,
    onOpenProduct: onOpenProduct,
    action: requested
        ? _compactBtn(
            label: AppLocalizations.translate('sp_submitted'),
            icon: Icons.check_rounded,
            fg: AppColors.success,
            bg: AppColors.success.withValues(alpha: 0.12),
          )
        : _compactBtn(
            label: AppLocalizations.translate('sp_request_transfer'),
            icon: Icons.local_shipping_outlined,
            fg: Colors.white,
            bg: AppColors.primary,
            loading: busy,
            onTap: onRequest,
          ),
  );
}

/// 🟢 Build a basket (frequently-bought-together) pair card. Two product chips
/// with a "+" between them and the co-purchase line — the merchandising advice.
Widget basketCard(BasketPair pair, {void Function(WarehouseRef ref)? onOpenItem}) {
  return Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.borderXl,
      border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _basketPairChip(
                pair.itemA,
                onTap: onOpenItem == null ? null : () => onOpenItem(pair.itemA),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Icon(Icons.add_rounded, size: 18, color: AppColors.textTertiary),
            ),
            Expanded(
              child: _basketPairChip(
                pair.itemB,
                onTap: onOpenItem == null ? null : () => onOpenItem(pair.itemB),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(Icons.push_pin_outlined, size: 14, color: kBasketColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                AppLocalizations.translate('sp_bought_together')
                    .replaceAll('{pct}', pctLabel(pair.confidence * 100)),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.3),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _basketPairChip(WarehouseRef ref, {VoidCallback? onTap}) {
  final chip = Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(color: kBasketColor.withValues(alpha: 0.10), borderRadius: AppRadius.borderMd),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        productThumb(ref.imageUrl, size: 36, accent: kBasketColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            ref.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  if (onTap == null) return chip;
  return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: chip);
}

/// "يكفي …" coverage label from days-of-cover (years / months / days).
String _coverLabel(double? days) {
  if (days == null || days <= 0) return AppLocalizations.translate('sp_cover_long');
  if (days >= 365) {
    final y = days / 365;
    return AppLocalizations.translate('sp_cover_years')
        .replaceAll('{n}', y >= 10 ? y.toStringAsFixed(0) : y.toStringAsFixed(1));
  }
  if (days >= 60) {
    return AppLocalizations.translate('sp_cover_months').replaceAll('{n}', '${(days / 30).round()}');
  }
  return AppLocalizations.translate('sp_cover_days').replaceAll('{n}', '${days.round()}');
}

/// Percent with up to one decimal (Western digits).
String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// 🟡 Build a trapped card from a [TrappedItem].
Widget trappedCard(
  TrappedItem item, {
  required bool busy,
  required bool suggested,
  required VoidCallback onSuggest,
  VoidCallback? onOpenProduct,
}) {
  // Demand-aware reason (replaces the weak "days since last sale"):
  //  • dead  → no sales at all; the whole quantity is frozen cash.
  //  • else  → how long current stock lasts at the real sell rate + the excess.
  // Reason is told on AVAILABLE stock (stock − committed): committed units are
  // reserved for orders, so they're not idle. Excess is the available surplus.
  final isDead = item.healthStatus == 'dead' || item.velocity <= 0;
  final stats = isDead
      ? AppLocalizations.translate('sp_dead_stats').replaceAll('{n}', '${item.available.round()}')
      : AppLocalizations.translate('sp_trapped_stats')
          .replaceAll('{cover}', _coverLabel(item.coverAvailable))
          .replaceAll('{n}', '${item.excessUnits.round()}');
  final heroLabel = item.valueRatioPct > 0
      ? AppLocalizations.translate('sp_pct_of_trapped_cash')
          .replaceAll('{pct}', '${_pct(item.valueRatioPct)}$pctSign')
      : AppLocalizations.translate('sp_trapped_capital');

  return LeverItemCard(
    imageUrl: item.imageUrl,
    name: item.name,
    itemCode: item.itemCode,
    barcode: item.barcode,
    healthStatus: item.healthStatus,
    heroValue: sar(item.capitalAtRiskSar),
    heroLabel: heroLabel,
    accent: kTrappedColor,
    statsText: stats,
    onOpenProduct: onOpenProduct,
    action: suggested
        ? _compactBtn(
            label: AppLocalizations.translate('sp_submitted'),
            icon: Icons.check_rounded,
            fg: AppColors.success,
            bg: AppColors.success.withValues(alpha: 0.12),
          )
        : _compactBtn(
            label: AppLocalizations.translate('sp_suggest_discount'),
            icon: Icons.sell_outlined,
            fg: kTrappedColor,
            borderColor: kTrappedColor.withValues(alpha: 0.5),
            loading: busy,
            onTap: onSuggest,
          ),
  );
}
