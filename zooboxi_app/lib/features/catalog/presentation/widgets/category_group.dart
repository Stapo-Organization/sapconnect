import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/category_art.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';

/// One animal root and everything under it.
///
/// The store's tree is four animals deep and one level wide, so it is shown as
/// four boards rather than a drill-down: a headline row for the animal itself,
/// then its departments as artwork tiles. An extra tap between "قطط" and
/// "طعام" is an extra tap on the way to every purchase this store makes.
class CategoryGroup extends StatelessWidget {
  const CategoryGroup({super.key, required this.node, required this.onOpen});

  final CategoryNode node;

  /// Called with the slug and the title to show on the listing screen.
  final void Function(String slug, String title) onOpen;

  static const double _columns = 3;
  static const double _gutter = 10;
  static const double _labelGap = 6;

  /// The tile grid is sized from the label style, so the text has to be held
  /// to the same ceiling the sizing assumed.
  static const double maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(node: node, onTap: () => onOpen(node.slug, node.name)),
            if (node.hasChildren) ...[
              Divider(height: 1, color: cs.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tile =
                        (constraints.maxWidth - _gutter * (_columns - 1)) / _columns;
                    final label = _labelHeight(context);
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columns.toInt(),
                        crossAxisSpacing: _gutter,
                        mainAxisSpacing: 14,
                        // Exact, not an aspect-ratio guess: a two-line Arabic
                        // department name is common and must not be clipped.
                        mainAxisExtent: tile + _labelGap + label,
                      ),
                      itemCount: node.children.length,
                      itemBuilder: (context, index) {
                        final child = node.children[index];
                        return _ChildTile(
                          node: child,
                          size: tile,
                          labelHeight: label,
                          onTap: () => onOpen(child.slug, child.name),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Two lines of the label style, honoured up to a ceiling the tiles can
  /// still absorb.
  static double _labelHeight(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return scaler.scale(style?.fontSize ?? 11) * (style?.height ?? 1.3) * 2;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.node, required this.onTap});

  final CategoryNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final l = L.of(context);

    return PressScale(
      onTap: onTap,
      child: Container(
        // A whisper of the brand behind the animal, so the four boards read as
        // headings rather than as four more rows.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [
              cs.primaryContainer.withValues(alpha: context.isDark ? 0.32 : 0.55),
              cs.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CategoryArt(image: node.image, icon: node.icon, size: 58),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (node.count > 0)
                    Text(
                      l.listingResults(node.count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Gap.w8,
            Icon(
              context.isRtl
                  ? Icons.keyboard_arrow_left_rounded
                  : Icons.keyboard_arrow_right_rounded,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  const _ChildTile({
    required this.node,
    required this.size,
    required this.labelHeight,
    required this.onTap,
  });

  final CategoryNode node;
  final double size;
  final double labelHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryArt(
            image: node.image,
            icon: node.icon,
            size: size,
            circular: false,
            fit: BoxFit.contain,
            // The department art is line illustration on white; letting it
            // touch the edges of the well makes it look cropped.
            padding: EdgeInsets.all(math.max(6, size * 0.09)),
          ),
          const SizedBox(height: CategoryGroup._labelGap),
          SizedBox(
            height: labelHeight,
            width: double.infinity,
            child: Text(
              node.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
