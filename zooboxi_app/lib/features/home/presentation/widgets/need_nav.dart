import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';

/// «تحتاج الآن؟» — the needs a quick order starts from.
///
/// A pet store is browsed by animal, but a two-hour order is placed by need:
/// the litter ran out, the pouches are gone. So this row sits under the row of
/// animals and answers the second question in one tap. One row, deliberately —
/// a second row of tiles is where a quick-commerce home starts to feel like
/// several apps stacked on top of each other.
///
/// The species is the customer's own (their pet on file, else what they buy),
/// and the order is theirs too: the bird owner sees seed before treats.
class NeedNav extends StatelessWidget {
  const NeedNav({super.key, required this.items});

  final List<NeedNavItem> items;

  /// The tiles for one customer, from the payload's per-species rows and the
  /// feed's hint about which species and which need first.
  static List<NeedNavItem> resolve(Map<String, List<NeedNavItem>> bySpecies, NeedsHint hint) {
    final tiles = bySpecies[hint.species] ?? bySpecies['cat'] ?? const [];
    if (hint.order.isEmpty) return tiles;

    // The needs they buy lead, in the order they buy them; the rest keep
    // their curated order behind.
    final rank = {for (var i = 0; i < hint.order.length; i++) hint.order[i]: i};
    final sorted = List<NeedNavItem>.of(tiles)
      ..sort((a, b) {
        final ra = rank[a.key] ?? 1000 + tiles.indexOf(a);
        final rb = rank[b.key] ?? 1000 + tiles.indexOf(b);
        return ra.compareTo(rb);
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final reduceMotion = context.reduceMotion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 10),
          child: Text(l.homeNeedsTitle, style: context.tt.titleMedium),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => Gap.w12,
            itemBuilder: (context, index) {
              final tile = _NeedTile(item: items[index]);
              if (reduceMotion) return tile;
              return tile
                  .animate()
                  .fadeIn(duration: 220.ms, delay: Motion.stagger * index.clamp(0, 6))
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                    duration: 240.ms,
                    curve: Curves.easeOutBack,
                  );
            },
          ),
        ),
      ],
    );
  }
}

class _NeedTile extends StatelessWidget {
  const _NeedTile({required this.item});

  final NeedNavItem item;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tint = _tint(context, item.key);

    return SizedBox(
      width: 68,
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: context.isDark ? 0.22 : 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(item.icon), size: 26, color: tint),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(String key) => switch (key) {
        'dry' => Icons.grain_rounded,
        'wet' => Icons.soup_kitchen_rounded,
        'litter' => Icons.inventory_2_rounded,
        'treats' => Icons.cookie_rounded,
        'health' => Icons.favorite_rounded,
        'toys' => Icons.toys_rounded,
        'clean' => Icons.soap_rounded,
        'food' => Icons.restaurant_rounded,
        'supplies' => Icons.category_rounded,
        _ => Icons.category_rounded,
      };

  /// Each need keeps one colour so the row reads at a glance — the same
  /// family the product badges use, never the express ember or the sale coral.
  static Color _tint(BuildContext context, String key) {
    final zb = context.zb;
    final cs = context.cs;
    return switch (key) {
      'dry' || 'food' => ZbTokens.orange,
      'wet' => cs.primary,
      'litter' => ZbTokens.tealDeep,
      'treats' => ZbTokens.amber,
      'health' => zb.success,
      'toys' => zb.tierPickup.fg,
      'clean' => ZbTokens.teal,
      _ => cs.onSurfaceVariant,
    };
  }
}
