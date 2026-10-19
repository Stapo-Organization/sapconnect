import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/rail.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../brand/data/brand_activation.dart';
import '../../../brand/presentation/widgets/brand_activation_widgets.dart';
import '../../../cart/presentation/add_to_cart.dart';
import '../../../home/presentation/widgets/link_navigation.dart';
import '../../../loyalty/presentation/widgets/supply_card.dart';
import '../../data/care_models.dart';

// «تفعيل البراندات» C on a pet's profile: the brands this pet eats, each with
// how long its bag lasts and one tap to renew it — the brand at the moment
// the customer thinks about the animal, not the catalogue.

/// One of the pet's brands: logo, the last thing bought from it, a bar of
/// what is left and «جدّد».
class PetBrandRow extends StatelessWidget {
  const PetBrandRow({super.key, required this.item, required this.busy, required this.onRenew});

  final PetBrand item;
  final bool busy;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final supply = item.supply;
    final brand = item.brand;
    final hue = supplyHue(context, supply);

    return PressScale(
      onTap: () => context.push(brandLocation(brand.slug, title: brand.name)),
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                BrandSummaryPlate(brand: brand, width: 60, height: 38, shadow: false),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brand.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        l.petBrandLast(supply.product.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Gap.w8,
                FilledButton.icon(
                  onPressed: busy ? null : onRenew,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                  ),
                  icon: const Icon(Icons.autorenew_rounded, size: 17),
                  label: Text(l.petBrandRenew),
                ),
              ],
            ),
            Gap.h12,
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: supply.remaining,
                      minHeight: 8,
                      color: hue,
                      backgroundColor: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Gap.w8,
                Text(
                  supplyDaysLabel(l, supply),
                  style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «جديد من براندات تتابعها» — what the followed brands added lately that
/// this shelf can send. Nothing followed, nothing new: nothing drawn.
class FollowedNewRail extends ConsumerWidget {
  const FollowedNewRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(followedFreshProvider).value ?? const [];
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ProductRailView(
        title: L.of(context).petFollowedNew,
        products: products,
        zone: 'followed_new',
        edge: 0,
        onAdd: (product) => addToCart(context, ref, product: product, zone: 'followed_new', quiet: true),
      ),
    );
  }
}
