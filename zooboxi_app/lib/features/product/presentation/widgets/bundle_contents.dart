import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';

/// «محتويات البكج» — the products inside a bundle, as a horizontal strip of
/// tappable cards.
///
/// A bundle's page has to answer one question before anything else: what am I
/// actually getting? A stripped-HTML paragraph answers it in the worst
/// possible way, so the same list the description carries is drawn here as
/// real cards — photo, name, how many of it the bundle holds, its size — each
/// opening the product it stands for.
class BundleContents extends StatelessWidget {
  const BundleContents({super.key, required this.components});

  final List<BundleComponent> components;

  /// Wide enough that a long Arabic product name gets real room, narrow
  /// enough that the next card peeks in and says «there is more».
  static const double _maxCardWidth = 300;
  static const double _cardHeight = 104;

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final cardWidth =
        ((MediaQuery.sizeOf(context).width - 32) * 0.82).clamp(240.0, _maxCardWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text(l.bundleContentsTitle, style: context.tt.titleMedium)),
              Text(
                l.bundleContentsCount(components.length),
                style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Gap.h8,
        SizedBox(
          height: scale.scale(_cardHeight),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: components.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _ComponentCard(
              component: components[index],
              width: cardWidth,
            ),
          ),
        ),
      ],
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.component, required this.width});

  final BundleComponent component;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: component.name,
        child: PressScale(
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          haptic: Haptics.light,
          onTap: () => context.push('/product/${component.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // The photo takes the card's full height and no more, so
                // every pixel the tile gains in width goes to the name.
                AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(ZbTokens.rMd),
                    ),
                    child: ZbImage(
                      url: component.image,
                      radius: BorderRadius.circular(ZbTokens.rMd),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        component.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // The count is the whole point of a component row —
                      // it gets the weight of a headline, not of a footnote.
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '×${component.qty}',
                              style: context.tt.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (component.isGift) ...[
                            const SizedBox(width: 6),
                            _tag(context, l.bundleGiftTag, bg: cs.error),
                          ],
                          if (component.weightLabel != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                component.weightLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text, {required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: context.tt.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}
