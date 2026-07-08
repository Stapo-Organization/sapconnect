import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/public/data/public_repository.dart';
import 'package:exhibition_manager_app/features/public/presentation/widgets/brand_logo.dart';
import 'package:exhibition_manager_app/features/public/presentation/widgets/hero_decor.dart';
import 'package:exhibition_manager_app/shared/widgets/full_screen_image_viewer.dart';

/// Public per-brand intro page — editorial composition.
///
/// A short colour band (tinted by the brand's own blurred logo) with the logo
/// card riding its bottom edge; identity and meta live on the page surface
/// below it. The first product with an image becomes a full-width featured
/// card, the rest flow in a grid, and everything opens a full-screen,
/// swipeable gallery.
class BrandPage extends StatefulWidget {
  final BrandSummary brand;
  const BrandPage({super.key, required this.brand});

  @override
  State<BrandPage> createState() => _BrandPageState();
}

class _BrandPageState extends State<BrandPage> {
  final PublicRepository _repo = PublicRepository();

  bool _loading = true;
  BrandDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _repo.fetchBrand(widget.brand.code);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _detail = result.data;
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final products = _detail?.products ?? const <BrandProduct>[];

    // Gallery URLs + each product's position inside them.
    final urls = <String>[];
    final galleryIndex = List<int?>.filled(products.length, null);
    for (var i = 0; i < products.length; i++) {
      final u = products[i].imageUrl;
      if (u != null && u.isNotEmpty) {
        galleryIndex[i] = urls.length;
        urls.add(u);
      }
    }
    // First product with an image is promoted to the featured spot.
    final featured = galleryIndex.indexWhere((g) => g != null);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _identityBlock()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.base,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _sectionTitle(
                      context.tr('brand_products'),
                      count: _loading ? null : products.length,
                    ),
                  ),
                ),
                if (_loading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    sliver: _gridSkeleton(),
                  )
                else if (products.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: context.tr('brand_no_products'),
                      ),
                    ),
                  )
                else ...[
                  if (featured >= 0)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.base,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _FeaturedProductCard(
                          product: products[featured],
                          onTap: () => showFullScreenGallery(context, urls,
                              initialIndex: galleryIndex[featured]!),
                        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.base,
                        crossAxisSpacing: AppSpacing.base,
                        childAspectRatio: 0.74,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, gi) {
                          // Grid holds every product except the featured one.
                          final i = gi >= featured && featured >= 0 ? gi + 1 : gi;
                          return _ProductTile(
                            product: products[i],
                            onTap: galleryIndex[i] == null
                                ? null
                                : () => showFullScreenGallery(context, urls,
                                    initialIndex: galleryIndex[i]!),
                          ).animate().fadeIn(duration: 300.ms, delay: (40 * (gi % 8)).ms);
                        },
                        childCount: featured >= 0 ? products.length - 1 : products.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slim top bar (back + brand name) ────────────────────────
  Widget _topBar() {
    final dark = AppThemeController.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        color: dark ? const Color(0xFF242734) : AppColors.primaryDeep,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, 8),
            child: Row(
              children: [
                Pressable(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: Icon(
                      AppLocalizations.isArabic
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.brand.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Colour band + logo riding the edge + identity below ─────
  Widget _identityBlock() {
    final brand = widget.brand;
    final dark = AppThemeController.isDark;
    const bandHeight = 118.0;
    const logoSize = 104.0;
    const overlap = 46.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // The brand's colour aura: its own logo, giant and blurred, bleeding
            // through the band — a unique tint per brand, zero design work.
            SizedBox(
              height: bandHeight + overlap,
              width: double.infinity,
              child: Column(
                children: [
                  SizedBox(
                    height: bandHeight,
                    width: double.infinity,
                    child: ClipRect(
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: AppColors.heroGradient),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.directional(
                              textDirection: Directionality.of(context),
                              top: -90,
                              end: -60,
                              child: BlurredLogoWash(
                                logoUrl: brand.logoUrl,
                                size: 280,
                                opacity: dark ? 0.4 : 0.55,
                              ),
                            ),
                            const DotsPattern(opacity: 0.05),
                            const Positioned(
                                bottom: -60, left: -50, child: GlassCircle(size: 150, opacity: 0.05)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Logo card straddling the band's bottom edge.
            PositionedDirectional(
              start: AppSpacing.lg,
              top: bandHeight - (logoSize - overlap) - 12,
              child: BrandLogo(
                name: brand.name,
                logoUrl: brand.logoUrl,
                size: logoSize,
                light: true,
              ).animate().fadeIn(duration: 350.ms).scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
            ),
          ],
        ),
        // Identity on the page surface — not on the colour band.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                brand.name,
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ).animate().fadeIn(duration: 350.ms, delay: 60.ms),
              if ((_detail?.tagline ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _detail!.tagline!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 120.ms),
              ],
              const SizedBox(height: AppSpacing.md),
              _metaChips(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaChips() {
    final detail = _detail;
    final chips = <Widget>[];
    if ((detail?.country ?? '').isNotEmpty) {
      chips.add(_infoChip(Icons.public_rounded, detail!.country!, AppColors.primary));
    }
    if ((detail?.founded ?? '').isNotEmpty) {
      chips.add(_infoChip(Icons.calendar_today_rounded,
          '${context.tr('brand_founded')} ${detail!.founded!}', AppColors.primary));
    }
    if (!_loading && (detail?.products.isNotEmpty ?? false)) {
      chips.add(_infoChip(Icons.grid_view_rounded,
          '${detail!.products.length} ${context.tr('brand_products_unit')}', AppColors.accentDark));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < chips.length; i++)
          chips[i]
              .animate()
              .fadeIn(duration: 320.ms, delay: (160 + i * 70).ms)
              .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {int? count}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: AppRadius.borderFull,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadius.borderFull,
            ),
            child: Text(
              '$count',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _gridSkeleton() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.base,
        crossAxisSpacing: AppSpacing.base,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
          ),
        ),
        childCount: 6,
      ),
    );
  }
}

// ─── Featured product (full-width showcase) ──────────────────
class _FeaturedProductCard extends StatelessWidget {
  final BrandProduct product;
  final VoidCallback onTap;
  const _FeaturedProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: Row(
            children: [
              // White stage — product shots come on white in both themes.
              SizedBox(
                width: 140,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => ColoredBox(color: AppColors.shimmerBase),
                    errorWidget: (_, _, _) => Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: AppColors.textTertiary, size: 26),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Text(
                          context.tr('brand_featured'),
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.accentDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.fullscreen_rounded, size: 15, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('tap_to_view'),
                            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Product tile (tap → full-screen gallery) ────────────────
class _ProductTile extends StatelessWidget {
  final BrandProduct product;
  final VoidCallback? onTap;
  const _ProductTile({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              // Product shots come on white — keep the stage white in both
              // themes so photos sit naturally, framed by the card surface.
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: !hasImage
                    ? Center(
                        child: Icon(Icons.inventory_2_outlined,
                            color: AppColors.textTertiary, size: 30),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        placeholder: (_, _) => ColoredBox(color: AppColors.shimmerBase),
                        errorWidget: (_, _, _) => Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: AppColors.textTertiary, size: 26),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap!, child: card);
  }
}
