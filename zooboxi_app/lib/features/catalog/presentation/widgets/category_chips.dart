import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';

/// The sibling departments of the aisle a listing was opened from, as a row
/// of chips above the grid.
///
/// A customer in "طعام القطط" who wants treats should not have to back out
/// to the categories screen: the whole cat aisle is one flick away up here.
/// The first chip is the pet itself ("الكل"); the active department is
/// filled and scrolled into view.
class CategoryChips extends StatefulWidget {
  const CategoryChips({
    super.key,
    required this.root,
    required this.currentSlug,
    required this.onSelect,
  });

  final CategoryNode root;

  /// Null means the pet itself is selected.
  final String? currentSlug;

  /// Called with the slug and the title to show — the pet's own for "all".
  final void Function(String slug, String title) onSelect;

  @override
  State<CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(CategoryChips old) {
    super.didUpdateWidget(old);
    if (old.currentSlug != widget.currentSlug) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(animate: true),
      );
    }
  }

  void _reveal({required bool animate}) {
    final ctx = _selectedKey.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: animate ? context.motion(Motion.select) : Duration.zero,
      curve: Motion.decelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final root = widget.root;
    final current = widget.currentSlug;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 6,
        bottom: 4,
      ),
      child: Row(
        children: [
          _Chip(
            key: current == null ? _selectedKey : null,
            label: l.actionSeeAll,
            selected: current == null,
            onTap: () => widget.onSelect(root.slug, root.name),
          ),
          for (final child in root.children) ...[
            Gap.w8,
            _Chip(
              key: child.slug == current ? _selectedKey : null,
              label: child.name,
              selected: child.slug == current,
              onTap: () => widget.onSelect(child.slug, child.name),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(ZbTokens.rPill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected
            ? null
            : () {
                Haptics.selection();
                onTap();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            style: context.tt.labelLarge?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurface,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
