import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../responsive.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import 'animated_icons.dart';

/// One destination of an [AppTabBar].
class AppTabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const AppTabItem({required this.icon, required this.selectedIcon, required this.label});
}

/// The bottom tab bar for both shells («المتجر»): white surface, a hairline on
/// top, outlined icons at rest and the filled ink icon + label when selected —
/// no pill, no glow. Fixed 56pt height; text never scales past the bar.
class AppTabBar extends StatelessWidget {
  final List<AppTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const AppTabBar({super.key, required this.items, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fontSize = navLabelFontSize(context, items.length);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _TabItem(
                      item: items[i],
                      selected: i == selectedIndex,
                      fontSize: fontSize,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(i);
                      },
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

class _TabItem extends StatelessWidget {
  final AppTabItem item;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  const _TabItem({required this.item, required this.selected, required this.fontSize, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppColors.textPrimary : AppColors.textTertiary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(size: 24, color: c),
              child: selected ? AnimatedNavIcon(icon: item.selectedIcon) : Icon(item.icon),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: fontSize,
                height: 1.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
