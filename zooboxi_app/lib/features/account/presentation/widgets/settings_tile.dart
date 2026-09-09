import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';

/// A titled group of settings rows, rendered as one card.
///
/// The title sits outside the card in the platform's own idiom — a quiet,
/// spaced label — so the card itself carries nothing but the rows.
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
              style: context.tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
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
                    // Starts past the icon, so the rows read as one stack
                    // rather than as separate slabs.
                    padding: const EdgeInsetsDirectional.only(start: 62),
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
///
/// The icon sits in a soft rounded square rather than bare on the surface: at
/// 20pt a lone glyph beside 16pt text reads as debris, and the tile gives every
/// row the same optical weight no matter which icon it drew.
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
    final tint = destructive ? cs.error : cs.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: destructive
                      ? cs.error.withValues(alpha: 0.10)
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              Gap.w12,
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
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
