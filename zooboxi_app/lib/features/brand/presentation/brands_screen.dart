import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/zb_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../home/presentation/widgets/link_navigation.dart';

/// The brands directory — every house the store carries, biggest shelf first
/// (the server orders it), each one door to its boutique.
///
/// A wall of logos is the point: brand shoppers scan for a mark, not a word,
/// so the tile is mostly logo and the name is a caption.
class BrandsScreen extends ConsumerWidget {
  const BrandsScreen({super.key});

  static const double _tileExtent = 128;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final brands = ref.watch(brandsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.brandsTitle)),
      body: switch (brands) {
        AsyncValue(:final value?) => _Grid(brands: value),
        AsyncValue(hasError: true) => ErrorState(
            error: brands.error,
            onRetry: () => ref.invalidate(brandsProvider),
          ),
        _ => const _BrandsSkeleton(),
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.brands});

  final List<BrandSummary> brands;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return GridView.builder(
      padding: EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16 + bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: BrandsScreen._tileExtent,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: brands.length,
      itemBuilder: (context, index) {
        final tile = _BrandTile(brand: brands[index]);
        if (context.reduceMotion) return tile;
        return tile
            .animate(delay: Motion.stagger * (index % 12).clamp(0, 8))
            .fadeIn(duration: Motion.enter)
            .scale(
              begin: const Offset(0.92, 0.92),
              curve: Curves.easeOutBack,
              duration: Motion.enter,
            );
      },
    );
  }
}

class _BrandTile extends ConsumerWidget {
  const _BrandTile({required this.brand});

  final BrandSummary brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;

    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      onTap: () => context.push(brandLocation(brand.slug, title: brand.name)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            children: [
              Expanded(
                child: ZbImage(
                  url: brand.logo,
                  backgroundColor: Colors.transparent,
                  fallback: Center(
                    child: Text(
                      brand.name.characters.take(1).toString().toUpperCase(),
                      style: context.tt.headlineMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              Gap.h8,
              Text(
                brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (brand.count > 0)
                Text(
                  l.brandProductCount(brand.count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandsSkeleton extends StatelessWidget {
  const _BrandsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerGroup(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: BrandsScreen._tileExtent,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: 12,
        itemBuilder: (_, _) =>
            const SkeletonBox(width: double.infinity, height: double.infinity, radius: ZbTokens.rMd),
      ),
    );
  }
}
