import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';

/// Flavour / size / weight choice chips.
///
/// An option that no in-stock variant can satisfy given the *other* current
/// choices is shown disabled rather than hidden: a customer who sees "Salmon"
/// greyed out learns the store carries it and it's out, which is different
/// from it not existing.
class VariationPicker extends StatelessWidget {
  const VariationPicker({
    super.key,
    required this.attributes,
    required this.variations,
    required this.selection,
    required this.onSelect,
  });

  final List<VariationAttribute> attributes;
  final List<ProductVariation> variations;
  final Map<String, String> selection;
  final void Function(String attribute, String option) onSelect;

  /// Can [option] on [axis] still lead to an in-stock variant, holding every
  /// *other* chosen axis fixed? Shares [ProductVariation.matches] so the
  /// "Any …" wildcard semantics can never drift between chip and checkout.
  bool _isAvailable(String axis, String option) {
    final probe = {...selection, axis: option};
    return variations.any((v) => v.inStock && v.matches(probe));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attribute in attributes) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 8),
            child: Row(
              children: [
                Text(attribute.label, style: context.tt.titleSmall),
                Gap.w8,
                if (selection[attribute.slug] == null)
                  Text(
                    l.pdpVariantsHint,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in attribute.options)
                  _OptionChip(
                    option: option,
                    selected: selection[attribute.slug] == option.slug,
                    available: _isAvailable(attribute.slug, option.slug),
                    onTap: () {
                      Haptics.selection();
                      onSelect(attribute.slug, option.slug);
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.option,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final VariationOption option;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final emoji = option.emoji;

    final background = selected
        ? cs.primaryContainer
        : (available ? cs.surfaceContainerHigh : cs.surfaceContainer);
    final foreground = selected
        ? cs.onPrimaryContainer
        : (available ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.45));

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: available ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? cs.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null && emoji.isNotEmpty) ...[
                Text(emoji, style: const TextStyle(fontSize: 14)),
                Gap.w6,
              ],
              Text(
                option.label,
                style: context.tt.labelMedium?.copyWith(
                  color: foreground,
                  decoration: available ? null : TextDecoration.lineThrough,
                  decorationColor: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
