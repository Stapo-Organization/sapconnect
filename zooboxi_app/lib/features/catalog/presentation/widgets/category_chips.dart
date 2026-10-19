import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/facet_sticker.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
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

/// The department row a listing gets from the store itself (`context`):
/// the node's children, or its siblings with the parent as «الكل» — so
/// «الطعام الرطب» sits beside «الجاف» and «الحليب» at any depth of the tree,
/// each with its sticker and shelf count.
class ContextChips extends StatefulWidget {
  const ContextChips({super.key, required this.context, required this.onSelect, this.species});

  final ListingContext context;
  final String? species;
  final void Function(String slug, String title) onSelect;

  @override
  State<ContextChips> createState() => _ContextChipsState();
}

class _ContextChipsState extends State<ContextChips> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(ContextChips old) {
    super.didUpdateWidget(old);
    if (old.context.node.slug != widget.context.node.slug) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    final ctx = _selectedKey.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = widget.context;
    final all = c.chipsAreSiblings ? (c.parent ?? c.node) : c.node;
    final current = c.chipsAreSiblings ? c.node.slug : null;

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        children: [
          _StickerChip(
            key: current == null ? _selectedKey : null,
            label: l.actionSeeAll,
            count: all.count,
            sticker: widget.species == 'dog' ? 'dog_adult' : 'cat_adult',
            selected: current == null,
            onTap: () => widget.onSelect(all.slug, all.name),
          ),
          for (final chip in c.chips) ...[
            Gap.w8,
            _StickerChip(
              key: chip.slug == current ? _selectedKey : null,
              label: chip.name,
              count: chip.count,
              sticker: departmentSticker(chip.name, widget.species),
              selected: chip.slug == current,
              onTap: () => widget.onSelect(chip.slug, chip.name),
            ),
          ],
        ],
      ),
    );
  }
}

/// A department's sticker from its name — the store's tree has no icon keys.
String? departmentSticker(String name, String? species) {
  final n = name.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('ة', 'ه');
  final dog = species == 'dog';
  if (n.contains('رطب')) return 'pouch';
  if (n.contains('جاف')) return 'dry';
  if (n.contains('حليب') || n.contains('سوائل')) return 'milk';
  if (n.contains('صغير') || n.contains('بوبي') || n.contains('جراء')) return dog ? 'puppy' : 'kitten';
  if (n.contains('مسن') || n.contains('كبير')) return dog ? 'dog_senior' : 'cat_senior';
  if (n.contains('بالغ')) return dog ? 'dog_adult' : 'cat_adult';
  if (n.contains('وزن')) return 'light';
  if (n.contains('هضم')) return 'digest';
  if (n.contains('حساسي')) return 'hypo';
  if (n.contains('مكافا') || n.contains('سناك') || n.contains('بسكوت')) return 'treat';
  if (n.contains('كريمي')) return 'pouch';
  if (n.contains('فيتامين')) return 'vet';
  if (n.contains('كرات الشعر')) return 'hairball';
  if (n.contains('معقم')) return 'sterilised';
  if (n.contains('بولي')) return 'urinary';
  if (n.contains('اسنان')) return 'tooth';
  if (n.contains('جلد') || n.contains('فرو') || n.contains('شامبو')) return 'brush';
  if (n.contains('بكج')) return 'bundle';
  if (n.contains('صحه')) return 'vet';
  if (n.contains('طعام')) return 'dry';
  return null;
}

class _StickerChip extends StatelessWidget {
  const _StickerChip({
    super.key,
    required this.label,
    required this.count,
    required this.sticker,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final String? sticker;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    final hasSticker = FacetSticker.has(sticker);
    return Material(
      color: selected ? cs.primary : cs.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? cs.primary : cs.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected
            ? null
            : () {
                Haptics.selection();
                onTap();
              },
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: hasSticker ? 5 : 14, end: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSticker) ...[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: selected ? Colors.white : cs.surfaceContainerHigh, shape: BoxShape.circle),
                  child: FacetSticker(sticker, size: 24),
                ),
                Gap.w6,
              ],
              Text(
                label,
                maxLines: 1,
                style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: selected ? FontWeight.w800 : FontWeight.w700),
              ),
              if (count > 0) ...[
                Gap.w4,
                Text(
                  Fmt.number(count, locale: Localizations.localeOf(context).languageCode, decimals: 0),
                  style: context.tt.labelSmall?.copyWith(color: fg.withValues(alpha: 0.75)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
