import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../localization/app_localizations.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/shadows.dart';
import '../tokens/typography.dart';
import 'animated_icons.dart';

/// A Shopify card that holds a list («المتجر»): optional header (title, a
/// count, a trailing link) and rows separated by hairlines. The standard
/// container for anything list-shaped on a screen.
class AppSection extends StatelessWidget {
  final String? title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  /// Divider inset from the start edge (aligns hairlines with row text).
  final double dividerIndent;

  const AppSection({
    super.key,
    this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    required this.children,
    this.margin,
    this.dividerIndent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, indent: dividerIndent, color: AppColors.borderLight));
      rows.add(children[i]);
    }
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Flexible(
                    child: Text(title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary)),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.secondary, borderRadius: AppRadius.borderSm),
                      child: Text('$count',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  if (actionLabel != null && onAction != null)
                    GestureDetector(
                      onTap: onAction,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(actionLabel!,
                            style: AppTypography.labelLarge.copyWith(color: AppColors.link, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
          ...rows,
        ],
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// One row in an [AppSection] (or any list): leading visual, title, optional
/// subtitle, and a trailing slot (value, badge, chevron). Press shows a grey
/// highlight, like a Shopify resource row.
class AppListRow extends StatefulWidget {
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final int titleMaxLines;

  const AppListRow({
    super.key,
    this.leading,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.titleMaxLines = 1,
  });

  @override
  State<AppListRow> createState() => _AppListRowState();
}

class _AppListRowState extends State<AppListRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final lead = w.leading ??
        (w.icon != null ? GlowIconChip(icon: w.icon!, color: w.iconColor ?? AppColors.primary, size: 36, iconSize: 20) : null);
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      color: _down ? AppColors.secondary : Colors.transparent,
      padding: w.padding,
      child: Row(
        children: [
          if (lead != null) ...[lead, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(w.title,
                    maxLines: w.titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
                if (w.subtitle != null && w.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(w.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (w.trailing != null) ...[const SizedBox(width: 8), w.trailing!],
          if (w.chevron) ...[
            const SizedBox(width: 4),
            Icon(AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ],
      ),
    );
    if (w.onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        w.onTap!();
      },
      child: row,
    );
  }
}

/// Large page title on the canvas for tab-root screens (no coloured bar):
/// optional eyebrow line above, subtitle below and actions at the end —
/// the Shopify app's page header. Includes the top safe-area inset.
class PageHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? below;

  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Text(eyebrow!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              for (final a in actions) ...[const SizedBox(width: 8), a],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}

/// Square outlined icon button for page headers (search, filter, scan…).
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Widget? child;

  const HeaderIconButton({super.key, required this.icon, this.onTap, this.tooltip, this.child});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(child: child ?? Icon(icon, size: 20, color: AppColors.textPrimary)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
