import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/permissions/app_session.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/product_detail_launcher.dart';

/// A single counting record (line). Each scan creates its own record, so the
/// same product can appear multiple times with different quantities — every
/// entry is shown separately and is independently editable / deletable.
///
/// When [entryNumber] is non-null the card shows a "Entry N" chip so duplicate
/// records of the same item are distinguishable; a time chip (from createdAt)
/// adds further distinction.
class CountingLineCard extends StatelessWidget {
  final CountingLine line;
  final int? entryNumber;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CountingLineCard({
    super.key,
    required this.line,
    this.entryNumber,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(line.createdAt);
    final hasMeta = entryNumber != null || time != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: AppRadius.borderSm,
            child: CachedNetworkImage(
              imageUrl: line.imageUrl ?? '',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppColors.surfaceVariant,
                highlightColor: AppColors.surface,
                child: Container(width: 48, height: 48, color: Colors.white),
              ),
              errorWidget: (_, _, _) => Container(
                width: 48,
                height: 48,
                color: AppColors.surfaceVariant,
                child: Icon(Icons.image_not_supported_rounded, size: 24, color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: GestureDetector(
              onTap: () => openProductDetail(context, line.itemCode,
                  name: line.getLocalizedName(AppLocalizations.isArabic),
                  myWarehouses: AppSession.user?.warehouseCodes ?? const []),
              behavior: HitTestBehavior.opaque,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.getLocalizedName(AppLocalizations.isArabic),
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${line.pieceBarcode ?? ""} • ${line.itemCode}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (hasMeta) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (entryNumber != null)
                        _MetaChip(
                          icon: Icons.tag_rounded,
                          label: context.tr('entry_n').replaceAll('{n}', '$entryNumber'),
                          color: AppColors.primary,
                        ),
                      if (entryNumber != null && time != null) const SizedBox(width: 6),
                      if (time != null)
                        _MetaChip(
                          icon: Icons.schedule_rounded,
                          label: time,
                          color: AppColors.textTertiary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Quantity badge (tap to edit)
          GestureDetector(
            onTap: canEdit ? onEdit : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('${line.countedQuantity.toInt()}',
                      style: AppTypography.titleMedium.copyWith(color: AppColors.primary)),
                  if (canEdit) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded, size: 13, color: AppColors.primary),
                  ],
                ],
              ),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
            ),
          ],
        ],
      ),
    );
  }

  static String? _formatTime(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Assigns a 1-based entry number to each line *within the same item_code*,
/// but only when that item has more than one record (so unique items show no
/// "Entry N" noise). Returns records in the original order.
List<({CountingLine line, int? entry})> withEntryNumbers(List<CountingLine> lines) {
  final totals = <String, int>{};
  for (final l in lines) {
    totals[l.itemCode] = (totals[l.itemCode] ?? 0) + 1;
  }
  final seen = <String, int>{};
  return lines.map((l) {
    final n = (seen[l.itemCode] ?? 0) + 1;
    seen[l.itemCode] = n;
    final showEntry = (totals[l.itemCode] ?? 0) > 1;
    return (line: l, entry: showEntry ? n : null);
  }).toList();
}
