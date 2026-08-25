import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/account_models.dart';

/// One saved address.
///
/// The same card serves the address book and the checkout picker: at checkout
/// it carries a radio, in the book it carries an overflow menu. Two cards
/// would inevitably describe the same address two different ways.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    this.selected = false,
    this.selectable = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onMakeDefault,
  });

  final Address address;
  final bool selected;
  final bool selectable;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMakeDefault;

  /// Edit alone is a button, not a menu — a one-item overflow is a worse
  /// version of the icon it hides.
  bool get _hasMenu => onDelete != null || onMakeDefault != null;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final active = selectable && selected;

    return AnimatedContainer(
      duration: context.motion(Motion.select),
      curve: Motion.decelerate,
      decoration: BoxDecoration(
        color: active ? cs.primaryContainer.withValues(alpha: 0.30) : cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(
          color: active ? cs.primary : cs.outlineVariant,
          width: active ? 1.6 : 1,
        ),
      ),
      child: PressScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectable) ...[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? cs.primary : cs.outline,
                ),
                Gap.w12,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: _LabelChip(address: address)),
                        if (address.isDefault) ...[
                          Gap.w8,
                          _DefaultBadge(label: l.addressDefaultBadge),
                        ],
                      ],
                    ),
                    Gap.h8,
                    Text(
                      address.name,
                      style: context.tt.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap.h4,
                    Text(
                      [address.addressLine, address.summary]
                          .where((e) => e.isNotEmpty)
                          .join('، '),
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (address.phone.isNotEmpty) ...[
                      Gap.h4,
                      Text(
                        Fmt.phone(address.phone),
                        textDirection: TextDirection.ltr,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (_hasMenu)
                _Menu(
                  canMakeDefault: onMakeDefault != null && !address.isDefault,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onMakeDefault: onMakeDefault,
                )
              else if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                )
              else
                Gap.w8,
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final label = (address.label ?? '').trim();
    final resolved = label.isEmpty ? l.addressLabelOther : label;

    const homeWords = {'المنزل', 'منزل', 'البيت', 'home', 'Home'};
    const workWords = {'العمل', 'عمل', 'المكتب', 'work', 'Work'};
    final icon = homeWords.contains(resolved)
        ? Icons.home_rounded
        : workWords.contains(resolved)
            ? Icons.work_rounded
            : Icons.push_pin_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          Gap.w4,
          Flexible(
            child: Text(
              resolved,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: zb.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        label,
        style: context.tt.labelSmall?.copyWith(
          color: zb.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.canMakeDefault,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final bool canMakeDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      tooltip: '',
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: onEdit,
            child: _MenuRow(icon: Icons.edit_outlined, label: l.addressEditTitle),
          ),
        if (canMakeDefault && onMakeDefault != null)
          PopupMenuItem(
            value: onMakeDefault,
            child: _MenuRow(icon: Icons.star_outline_rounded, label: l.addressSetDefault),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: onDelete,
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: l.addressDelete,
              color: context.cs.error,
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          Gap.w12,
          Text(label, style: TextStyle(color: color)),
        ],
      );
}
