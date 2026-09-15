import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/widgets/category_art.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../catalog/data/catalog_models.dart';

/// The animals as a row of pills — the express page has already spent its
/// tiles on the needs, so the species become a filter line, with the
/// customer's own animal lit.
class AnimalPills extends StatelessWidget {
  const AnimalPills({super.key, required this.items, this.species = ''});

  final List<AnimalNavItem> items;

  /// The customer's species from the feed (`cat`, `dog`…), matched loosely
  /// against the category slug so the pill that is theirs is the lit one.
  final String species;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, index) {
          final item = items[index];
          final lit = species.isNotEmpty && item.slug.toLowerCase().contains(species.toLowerCase());
          return _Pill(item: item, lit: lit);
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.item, required this.lit});

  final AnimalNavItem item;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      button: true,
      selected: lit,
      label: item.name,
      child: PressScale(
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        onTap: () => context.push(
          Uri(
            path: '/aisle/${item.id}',
            queryParameters: {'title': item.name},
          ).toString(),
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 14, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
            color: lit ? null : cs.surface,
            gradient: lit
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [ZbTokens.tealDark, ZbTokens.tealDeep],
                  )
                : null,
            border: lit ? null : Border.all(color: cs.outlineVariant),
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: ZbTokens.tealDeep.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: -6,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryArt(image: item.image, icon: item.icon, size: 28),
              Gap.w8,
              Text(
                item.name,
                style: context.tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: lit ? Colors.white : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
