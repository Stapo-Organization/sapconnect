import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';

/// A titled group of settings rows, rendered as one card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: Text(
              title!,
              style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            border: Border.all(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 52),
                    child: Divider(height: 1, color: cs.outlineVariant),
                  ),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One settings row. A null [onTap] renders it as informational rather than
/// as a broken button.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.trailingLabel,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? trailingLabel;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final foreground = destructive ? cs.error : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: destructive ? cs.error : cs.onSurfaceVariant),
              Gap.w16,
              Expanded(
                child: Text(
                  label,
                  style: context.tt.bodyLarge?.copyWith(color: foreground),
                ),
              ),
              if (trailingLabel != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    trailingLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              if (onTap != null) ...[
                Gap.w4,
                Icon(
                  context.isRtl
                      ? Icons.keyboard_arrow_left_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
