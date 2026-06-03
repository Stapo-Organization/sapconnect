import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

class SegmentItem {
  final String label;
  final IconData? icon;
  final int? badge;
  const SegmentItem(this.label, {this.icon, this.badge});
}

/// Modern animated segmented control (e.g. Full / Cycle, or A/B/C filters).
/// A sliding pill highlights the selected segment.
class AppSegmentedControl extends StatelessWidget {
  final List<SegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color activeColor;

  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth / items.length;
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        return Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Stack(
            // Center non-positioned children vertically. Without this the Stack
            // defaults to topStart and pins the label Row to the top of the
            // 38px box — which is the "raised tab text" the labels suffered from.
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  items.length == 1
                      ? 0
                      : (isRtl ? -1 : 1) *
                          (selectedIndex / (items.length - 1) * 2 - 1),
                  0,
                ),
                child: Container(
                  width: w - 8,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.borderSm,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (i) {
                  final selected = i == selectedIndex;
                  final item = items[i];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(i);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (item.icon != null) ...[
                            Icon(item.icon,
                                size: 16,
                                color: selected ? activeColor : AppColors.textTertiary),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            item.label,
                            style: AppTypography.labelMedium.copyWith(
                              color: selected ? activeColor : AppColors.textSecondary,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (item.badge != null && item.badge! > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: selected ? activeColor : AppColors.textTertiary,
                                borderRadius: AppRadius.borderFull,
                              ),
                              child: Text(
                                '${item.badge}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
