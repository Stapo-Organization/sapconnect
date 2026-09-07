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

  static const double _cardWidth = 132;

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

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
          // Image square + name (2 lines) + the meta line, all text-scaled.
          height: _cardWidth + scale.scale(84),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: components.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _ComponentCard(
              component: components[index],
              width: _cardWidth,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo with the two facts that belong ON it: how many the
                // bundle holds, and whether this one rides along free.
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ZbImage(
                        url: component.image,
                        padding: const EdgeInsets.all(8),
                      ),
                      PositionedDirectional(
                        start: 6,
                        bottom: 6,
                        child: _tag(
                          context,
                          '×${component.qty}',
                          bg: cs.primary,
                        ),
                      ),
                      if (component.isGift)
                        PositionedDirectional(
                          end: 6,
                          top: 6,
                          child: _tag(context, l.bundleGiftTag, bg: cs.error),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        component.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      if (component.weightLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          component.weightLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
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
