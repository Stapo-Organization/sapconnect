import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';

/// Featured brands. Logos sit on a neutral tile rather than on the brand's own
/// colour: a strip of eight different brand colours is noise, and the logos
/// already carry the identity. The kit accent is spent on the tile's edge and a
/// breath of glow underneath — enough that the strip has rhythm, not so much
/// that eight brands start shouting over each other.
class BrandStrip extends StatelessWidget {
  const BrandStrip({super.key, required this.brands});

  final List<BrandSummary> brands;

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.homeBrands),
        Gap.h12,
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: brands.length,
            separatorBuilder: (_, _) => Gap.w12,
            itemBuilder: (context, index) => _BrandTile(brand: brands[index]),
          ),
        ),
      ],
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.brand});

  final BrandSummary brand;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final accent = hexColor(brand.accent);

    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      onTap: () => context.push(
        Uri(
          path: '/listing',
          queryParameters: {'brand': brand.slug, 'title': brand.name},
        ).toString(),
      ),
      child: Container(
        width: 118,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          border: Border.all(
            color: accent?.withValues(alpha: context.isDark ? 0.55 : 0.40) ??
                cs.outlineVariant,
          ),
          boxShadow: accent == null
              ? null
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: context.isDark ? 0.16 : 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.center,
        child: brand.logo == null || brand.logo!.isEmpty
            ? Text(
                brand.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelMedium,
              )
            : ZbImage(
                url: brand.logo,
                backgroundColor: Colors.transparent,
              ),
      ),
    );
  }
}
