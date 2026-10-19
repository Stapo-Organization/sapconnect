import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/facet_sticker.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';

/// Sort options, supplied by the server so "recommended" can mean whatever the
/// ranking engine currently says it means — and so «الأوفر للكيلو» and «أكبر
/// خصم» only appear on a list where they mean something.
class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.options, this.selected});

  final List<SortOption> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // With nothing chosen, the first option is what the server is already
    // applying — showing it as selected keeps the sheet honest.
    final effective = selected ?? (options.isEmpty ? null : options.first.key);

    return BottomSheetScaffold(
      title: l.listingSortTitle,
      bodyPadding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _SortRow(
              option: option,
              selected: option.key == effective,
              onTap: () {
                Haptics.selection();
                Navigator.of(context).pop(option.key);
              },
            ),
          Gap.h8,
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.option, required this.selected, required this.onTap});

  final SortOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final accent = context.isDark ? ZbTokens.tealOnDark : ZbTokens.teal;
    final tint = context.isDark ? ZbTokens.tealContainerDark : ZbTokens.tealTintSoft;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? tint : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)))),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Center(
                    child: option.icon == 'spark' || !FacetSticker.has(option.icon)
                        ? Icon(Icons.auto_awesome_rounded, color: accent, size: 24)
                        : FacetSticker(option.icon, size: 30),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: context.tt.bodyLarge?.copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                      ),
                      if (option.sub != null && option.sub!.isNotEmpty)
                        Text(option.sub!, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Gap.w8,
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent : Colors.transparent,
                    border: Border.all(color: selected ? accent : cs.outline.withValues(alpha: 0.7), width: 2),
                  ),
                  child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
