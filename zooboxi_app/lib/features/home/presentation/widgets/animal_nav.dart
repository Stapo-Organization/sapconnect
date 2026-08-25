import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';

/// "Shop by pet" — circular quick-nav.
///
/// This is the primary way people actually shop a pet store: they have a cat,
/// or a dog, and everything else is a filter on top of that. It sits directly
/// under the hero for exactly that reason.
class AnimalNav extends StatelessWidget {
  const AnimalNav({super.key, required this.items});

  final List<AnimalNavItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final reduceMotion = context.reduceMotion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 12),
          child: Text(l.homeAnimalNav, style: context.tt.titleLarge),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => Gap.w16,
            itemBuilder: (context, index) {
              final tile = _AnimalTile(item: items[index]);
              if (reduceMotion) return tile;
              return tile
                  .animate()
                  .fadeIn(
                    duration: 250.ms,
                    delay: Motion.stagger * index.clamp(0, 6),
                  )
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    end: const Offset(1, 1),
                    duration: 280.ms,
                    curve: Curves.easeOutBack,
                  );
            },
          ),
        ),
      ],
    );
  }
}

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({required this.item});

  final AnimalNavItem item;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return SizedBox(
      width: 72,
      child: PressScale(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          Uri(
            path: '/listing',
            queryParameters: {'category': item.slug, 'title': item.name},
          ).toString(),
        ),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary.withValues(alpha: 0.18), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: ZbImage(
                url: item.image,
                fit: BoxFit.cover,
                backgroundColor: Colors.transparent,
              ),
            ),
            Gap.h8,
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
