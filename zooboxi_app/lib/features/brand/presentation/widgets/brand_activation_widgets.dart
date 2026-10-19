import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_sheet.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../home/presentation/widgets/link_navigation.dart';
import '../../data/brand_activation.dart';
import 'brand_palette.dart';

// «تفعيل البراندات» A — «الوكيل الرسمي» (owner's pick, 2026-09-24).
//
// A brand is present wherever the customer looks: its own colours, the seal
// that says it comes from the official distributor, the customer's own
// brands first, a wall of every brand this shelf carries, and a follow
// button that brings its new products to them.

/// «أصلي 100٪ — من الموزّع الرسمي مباشرة»: the claim only Muntajat can make,
/// said once over the brands.
class OfficialBand extends StatelessWidget {
  const OfficialBand({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    final ink = dark ? ZbTokens.tealOnDark : ZbTokens.tealDeep;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: dark ? ZbTokens.tealContainerDark : ZbTokens.tealTint,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: context.cs.surface, shape: BoxShape.circle),
            child: Icon(Icons.verified_user_rounded, size: 20, color: ink),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.brandsOfficialTitle,
                    style: context.tt.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w800)),
                if (count > 0)
                  Text(l.brandsOfficialBody(count),
                      style: context.tt.labelMedium?.copyWith(color: ink, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small seal a brand card wears.
class OfficialSeal extends StatelessWidget {
  const OfficialSeal({super.key, this.color, this.background});

  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (context.isDark ? ZbTokens.tealOnDark : ZbTokens.tealDeep);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, size: 14, color: fg),
          Gap.w4,
          Text(L.of(context).brandsOfficialSeal,
              style: context.tt.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// A logo on its white plate from a brand summary; the name stands in when
/// there is no logo — a logo is drawn for white, whatever the ground.
class BrandSummaryPlate extends StatelessWidget {
  const BrandSummaryPlate({
    super.key,
    required this.brand,
    required this.width,
    required this.height,
    this.shadow = true,
  });

  final BrandSummary brand;
  final double width;
  final double height;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final logo = brand.logo;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: width * 0.1, vertical: height * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.26),
        border: shadow ? null : Border.all(color: const Color(0xFFE7EBE6)),
        boxShadow: shadow
            ? const [BoxShadow(color: Color(0x29281400), blurRadius: 14, offset: Offset(0, 6))]
            : null,
      ),
      child: logo == null
          ? FittedBox(
              child: Text(
                brand.name,
                style: context.tt.titleLarge?.copyWith(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w900),
              ),
            )
          : ZbImage(url: logo, fit: BoxFit.contain, backgroundColor: Colors.white),
    );
  }
}

/// Follow a brand: its new products come to the customer. Two faces — a
/// white disc for a brand's stage bar, and an outlined pill on a brand card.
class FollowBrandButton extends ConsumerStatefulWidget {
  const FollowBrandButton.disc({super.key, required this.slug, required this.name})
      : pill = false,
        ink = null;

  const FollowBrandButton.pill({super.key, required this.slug, required this.name, required Color this.ink})
      : pill = true;

  final String slug;
  final String name;
  final bool pill;
  final Color? ink;

  @override
  ConsumerState<FollowBrandButton> createState() => _FollowBrandButtonState();
}

class _FollowBrandButtonState extends ConsumerState<FollowBrandButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final l = L.of(context);
    if (!ref.read(sessionProvider).isAuthenticated) {
      final signedIn = await showAuthSheet(context, reason: l.brandFollowSignIn);
      if (!signedIn || !mounted) return;
    }
    Haptics.light();
    setState(() => _busy = true);
    try {
      final on = await ref.read(followedBrandsProvider.notifier).toggle(widget.slug);
      if (!mounted) return;
      AppToast.info(context, on ? l.brandFollowedToast(widget.name) : l.brandUnfollowedToast(widget.name));
    } catch (_) {
      if (mounted) AppToast.error(context, l.errUnknown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final on = ref.watch(isFollowingBrandProvider(widget.slug));
    final icon = on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded;

    if (!widget.pill) {
      return Tooltip(
        message: on ? l.brandFollowing : l.brandFollowTooltip(widget.name),
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggle,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 21, color: on ? ZbTokens.tealDark : const Color(0xFF1F2A22)),
            ),
          ),
        ),
      );
    }

    final ink = widget.ink!;
    return Semantics(
      button: true,
      toggled: on,
      label: on ? l.brandFollowing : l.brandFollowTooltip(widget.name),
      child: PressScale(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 12, 4),
          decoration: BoxDecoration(
            color: on ? ink : Colors.transparent,
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
            border: Border.all(color: ink, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: on ? _onInk(ink) : ink),
              Gap.w4,
              Text(
                on ? l.brandFollowing : l.brandFollow,
                style: context.tt.labelMedium?.copyWith(color: on ? _onInk(ink) : ink, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _onInk(Color ink) => ink.computeLuminance() > 0.4 ? const Color(0xFF1A1A1A) : Colors.white;
}

/// Soft rings behind a brand card's contents.
class _Rings extends StatelessWidget {
  const _Rings({required this.size, this.fill, this.alpha = 0.28});

  final double size;
  final Color? fill;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: fill == null ? Border.all(color: Colors.white.withValues(alpha: alpha), width: 1.5) : null,
      ),
    );
  }
}

/// «براندات لولو» — the brands this customer buys, each in its own colour.
class MyBrandsRow extends StatelessWidget {
  const MyBrandsRow({super.key, required this.brands, this.petName});

  final List<BrandSummary> brands;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final name = petName?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: name.isEmpty ? l.myBrandsTitleAny : l.myBrandsTitle(name),
          subtitle: l.myBrandsSub,
          onSeeAll: () => context.push('/brands'),
        ),
        Gap.h12,
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: brands.length,
            separatorBuilder: (_, _) => Gap.w12,
            itemBuilder: (context, i) => MyBrandCard(brand: brands[i], pose: i.isEven ? ZbPose.peek : ZbPose.wow),
          ),
        ),
      ],
    );
  }
}

class MyBrandCard extends StatelessWidget {
  const MyBrandCard({super.key, required this.brand, this.pose = ZbPose.peek});

  final BrandSummary brand;
  final ZbPose pose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = BrandPalette.ofSummary(context, brand);
    final meta = brand.lines.isNotEmpty
        ? brand.lines.join(' · ')
        : (brand.bought > 0 ? l.myBrandsBought(brand.bought) : l.brandProductCount(brand.count));

    return Semantics(
      button: true,
      label: brand.name,
      child: PressScale(
        onTap: () => context.push(brandLocation(brand.slug, title: brand.name)),
        borderRadius: BorderRadius.circular(22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 252,
            color: p.field,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PositionedDirectional(end: -60, top: 30, child: _Rings(size: 190, fill: p.ring)),
                const PositionedDirectional(end: -100, top: -10, child: _Rings(size: 270, alpha: 0.16)),
                PositionedDirectional(
                  start: 0,
                  top: 58,
                  child: Container(
                    width: 5,
                    height: 56,
                    decoration: BoxDecoration(
                      color: p.stripe,
                      borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(3)),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 16,
                  top: 16,
                  child: BrandSummaryPlate(brand: brand, width: 78, height: 42),
                ),
                PositionedDirectional(
                  start: 16,
                  top: 68,
                  width: 152,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleLarge?.copyWith(color: p.ink, fontWeight: FontWeight.w900),
                      ),
                      if (brand.tagline != null)
                        Text(
                          brand.tagline!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelMedium?.copyWith(color: p.ink, fontWeight: FontWeight.w700, height: 1.35),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.labelSmall?.copyWith(
                          color: p.ink.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  end: 8,
                  bottom: -4,
                  child: ExcludeSemantics(child: Companion(pose, height: 82, idle: ZbIdle.peek, entrance: false)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «كل البراندات» — the seal, then a wall of the brands this shelf carries,
/// each logo on white with its own colour as a strip underneath.
class BrandWall extends StatelessWidget {
  const BrandWall({super.key, required this.brands, required this.total, this.max = 9});

  final List<BrandSummary> brands;
  final int total;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final shown = brands.take(max).toList();
    final official = brands.any((b) => b.official);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.brandsWallTitle, onSeeAll: () => context.push('/brands')),
        Gap.h12,
        if (official) ...[
          OfficialBand(count: total > 0 ? total : brands.length),
          Gap.h12,
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.08,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [for (final b in shown) BrandWallTile(brand: b)],
          ),
        ),
      ],
    );
  }
}

class BrandWallTile extends StatelessWidget {
  const BrandWallTile({super.key, required this.brand});

  final BrandSummary brand;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final strip = hexColor(brand.accent) ?? cs.outlineVariant;
    final logo = brand.logo;
    return Semantics(
      button: true,
      label: brand.name,
      child: PressScale(
        onTap: () => context.push(brandLocation(brand.slug, title: brand.name)),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            border: Border.all(color: context.isDark ? Colors.transparent : const Color(0xFFE7EBE6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: logo == null
                      ? Center(
                          child: Text(
                            brand.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: context.tt.titleSmall?.copyWith(
                              color: const Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : ZbImage(url: logo, fit: BoxFit.contain, backgroundColor: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  L.of(context).brandProductCount(brand.count),
                  style: context.tt.labelSmall?.copyWith(color: const Color(0xFF5C6B5C), fontWeight: FontWeight.w600),
                ),
              ),
              Container(height: 5, color: strip),
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand answers first: a search that names a brand shows it in its own
/// colours — logo, where it is from, the seal, its lines, follow — above the
/// product suggestions, with one tap into its shop.
class BrandSearchCard extends StatelessWidget {
  const BrandSearchCard({super.key, required this.brand, required this.express});

  final BrandSummary brand;
  final bool express;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = BrandPalette.ofSummary(context, brand);
    final kicker = [
      if (brand.country != null) brand.country!,
      if (brand.founded != null) l.brandSince(brand.founded!),
    ].join(' · ');
    final linesTitle = express ? l.brandSearchLinesExpress(brand.name) : l.brandLinesTitle(brand.name);
    void open() => context.push(brandLocation(brand.slug, title: brand.name));
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          color: p.field,
          child: Stack(
            children: [
              PositionedDirectional(end: -80, top: 40, child: _Rings(size: 250, fill: p.ring)),
              const PositionedDirectional(end: -120, top: 0, child: _Rings(size: 330)),
              PositionedDirectional(
                start: 0,
                top: 76,
                child: Container(
                  width: 6,
                  height: 64,
                  decoration: BoxDecoration(
                    color: p.stripe,
                    borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(3)),
                  ),
                ),
              ),
              if (brand.images.isNotEmpty)
                PositionedDirectional(
                  end: 14,
                  top: 56,
                  width: 128,
                  height: 128,
                  child: ExcludeSemantics(child: _Fan(images: brand.images)),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BrandSummaryPlate(brand: brand, width: 92, height: 52),
                        Gap.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brand.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.headlineSmall?.copyWith(color: p.ink, fontWeight: FontWeight.w900),
                              ),
                              if (kicker.isNotEmpty)
                                Text(kicker,
                                    style: context.tt.labelMedium?.copyWith(color: p.ink, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Gap.h12,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (brand.official) OfficialSeal(color: p.deep),
                        FollowBrandButton.pill(slug: brand.slug, name: brand.name, ink: p.ink),
                      ],
                    ),
                    if (brand.lines.isNotEmpty) ...[
                      Gap.h12,
                      SizedBox(
                        width: 210,
                        child: Text(linesTitle,
                            style: context.tt.labelLarge?.copyWith(color: p.ink, fontWeight: FontWeight.w700)),
                      ),
                      Gap.h8,
                      SizedBox(
                        width: 214,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final line in brand.lines)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                                ),
                                child: Text(line,
                                    style: context.tt.labelMedium?.copyWith(
                                      color: const Color(0xFF1F1A12),
                                      fontWeight: FontWeight.w800,
                                    )),
                              ),
                          ],
                        ),
                      ),
                    ] else if (!express) ...[
                      Gap.h8,
                      Text(l.brandProductCount(brand.count),
                          style: context.tt.labelLarge?.copyWith(color: p.ink, fontWeight: FontWeight.w700)),
                    ],
                    Gap.h16,
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: open,
                        style: FilledButton.styleFrom(
                          backgroundColor: p.ink,
                          foregroundColor: p.field,
                          shape: const StadiumBorder(),
                          textStyle: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(l.brandSearchEnter(brand.name), overflow: TextOverflow.ellipsis)),
                            Gap.w4,
                            Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two of the brand's products standing in front of its rings.
class _Fan extends StatelessWidget {
  const _Fan({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Transform.rotate(
            angle: -0.1,
            child: ZbImage(url: images.first, fit: BoxFit.contain),
          ),
        ),
        if (images.length > 1)
          PositionedDirectional(
            start: -34,
            bottom: -12,
            width: 78,
            height: 78,
            child: Transform.rotate(angle: 0.14, child: ZbImage(url: images[1], fit: BoxFit.contain)),
          ),
      ],
    );
  }
}
