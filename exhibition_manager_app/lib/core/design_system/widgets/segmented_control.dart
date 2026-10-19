import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme_controller.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

class SegmentItem {
  final String label;
  final IconData? icon;
  final int? badge;
  const SegmentItem(this.label, {this.icon, this.badge});
}

/// Segmented control («المتجر»): a grey track with a white sliding tab that
/// carries the selected label in full ink — the Shopify/iOS segmented look.
/// Colour stays neutral; [activeColor] only tints the selected icon/badge.
class AppSegmentedControl extends StatelessWidget {
  final List<SegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  /// Kept for call-site compatibility; the control is neutral in this design.
  final Color? activeColor;

  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth / items.length;
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        return Container(
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppThemeController.isDark ? const Color(0xFF333333) : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(10),
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
                    color: AppThemeController.isDark ? const Color(0xFF4A4A4A) : AppColors.surface,
                    borderRadius: AppRadius.borderSm,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 0, offset: const Offset(0, 1)),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
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
                      // scaleDown keeps a long label («البريد وكلمة المرور») whole
                      // on 360dp phones instead of clipping it at the segment edge.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (item.icon != null) ...[
                            Icon(item.icon,
                                size: 16,
                                color: selected ? AppColors.textPrimary : AppColors.textTertiary),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            item.label,
                            style: AppTypography.labelMedium.copyWith(
                              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          if (item.badge != null && item.badge! > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.textPrimary : AppColors.textTertiary,
                                borderRadius: AppRadius.borderFull,
                              ),
                              child: Text(
                                '${item.badge}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.surface,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                          ),
                        ),
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
