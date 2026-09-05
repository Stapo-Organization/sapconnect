import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/category_art.dart';
import '../../data/catalog_models.dart';
import '../pet_palette.dart';

/// The pinned row of pets at the top of the categories screen.
///
/// It is a table of contents that scrolls with you: the chip of the pet whose
/// board is under the strip lights up in that pet's colour, and tapping any
/// chip glides the page to its board. Four pets fit the width, so the chips
/// share it equally instead of scrolling.
class PetStrip extends StatelessWidget {
  const PetStrip({
    super.key,
    required this.pets,
    required this.active,
    required this.onSelect,
    this.raised = false,
  });

  final List<CategoryNode> pets;
  final int active;
  final ValueChanged<int> onSelect;

  /// True once content has scrolled under the strip — it grows a hairline
  /// and a whisper of shadow so it reads as pinned rather than as a row that
  /// happens to be at the top.
  final bool raised;

  /// 8+8 strip padding, 6+6 chip padding, a 38 photo inside a 2+2.5 ring on
  /// each side, a 5 gap and one line of labelSmall at the section's scale
  /// ceiling — 94.3, rounded up so nothing ever clips.
  static const double height = 100;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return AnimatedContainer(
      duration: Motion.select,
      height: height,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: raised ? cs.outlineVariant : Colors.transparent,
          ),
        ),
        boxShadow: [
          if (raised)
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.35 : 0.06,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          for (final (index, pet) in pets.indexed)
            Expanded(
              child: _PetChip(
                pet: pet,
                palette: PetPalette.resolve(
                  context,
                  icon: pet.icon,
                  index: index,
                ),
                selected: index == active,
                onTap: () {
                  Haptics.selection();
                  onSelect(index);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  const _PetChip({
    required this.pet,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final CategoryNode pet;
  final PetPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final still = context.reduceMotion;
    final duration = still ? Duration.zero : Motion.select;

    return Semantics(
      button: true,
      selected: selected,
      label: pet.name,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: duration,
              curve: Motion.decelerate,
              decoration: BoxDecoration(
                color: selected
                    ? palette.chipFill(context)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(ZbTokens.rLg),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The ring is the selection: it swells in the pet's colour
                  // and the photo lifts a touch, like a sticker being pressed on.
                  // The ring always reserves its room; only its colour and
                  // the photo's scale move, so the label never shifts.
                  AnimatedContainer(
                    duration: duration,
                    curve: Motion.decelerate,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? palette.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AnimatedScale(
                      duration: duration,
                      curve: Motion.spring,
                      scale: selected ? 1.0 : 0.92,
                      child: CategoryArt(
                        image: pet.image,
                        icon: pet.icon,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: (context.tt.labelSmall ?? const TextStyle())
                        .copyWith(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected
                              ? palette.headline
                              : cs.onSurfaceVariant,
                        ),
                    child: Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins [PetStrip] under the app bar.
class PetStripHeader extends SliverPersistentHeaderDelegate {
  const PetStripHeader({
    required this.pets,
    required this.active,
    required this.onSelect,
  });

  final List<CategoryNode> pets;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  double get minExtent => PetStrip.height;

  @override
  double get maxExtent => PetStrip.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => PetStrip(
    pets: pets,
    active: active,
    onSelect: onSelect,
    raised: overlapsContent,
  );

  @override
  bool shouldRebuild(PetStripHeader old) =>
      old.active != active || old.pets != pets || old.onSelect != onSelect;
}
