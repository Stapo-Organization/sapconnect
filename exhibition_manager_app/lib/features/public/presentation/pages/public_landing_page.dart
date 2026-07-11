import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/auth/presentation/pages/login_page.dart';
import 'package:exhibition_manager_app/features/public/data/public_repository.dart';
import 'package:exhibition_manager_app/features/public/presentation/pages/brand_page.dart';
import 'package:exhibition_manager_app/features/public/presentation/pages/news_detail_page.dart';
import 'package:exhibition_manager_app/features/public/presentation/widgets/brand_logo.dart';
import 'package:exhibition_manager_app/features/public/presentation/widgets/hero_decor.dart';
import 'package:exhibition_manager_app/shared/utils/date_names.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_logo.dart';

/// Public, pre-login landing screen of the Muntajat HUB app.
///
/// Content-led, editorial composition: a slim identity band with a stats bento
/// riding its edge, magazine-style news cards, an auto-drifting two-row brand
/// marquee, and a branches map steered by city chips.
class PublicLandingPage extends StatefulWidget {
  /// Optional data prefetched during the splash so the page opens ready.
  final LandingData? initialData;
  const PublicLandingPage({super.key, this.initialData});

  @override
  State<PublicLandingPage> createState() => _PublicLandingPageState();
}

class _PublicLandingPageState extends State<PublicLandingPage> {
  final PublicRepository _repo = PublicRepository();

  bool _loading = true;
  String? _error;
  LandingData? _data;

  final PageController _newsController = PageController(viewportFraction: 0.88);
  int _newsPage = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      // Prefetched during splash → show content immediately, no spinner.
      _data = widget.initialData;
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAutoSlide(_data?.news.length ?? 0);
      });
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _newsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.fetchLanding();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.success ? null : (result.error ?? context.tr('loading_error'));
      _data = result.data;
    });
    _startAutoSlide(_data?.news.length ?? 0);
  }

  void _startAutoSlide(int count) {
    _autoTimer?.cancel();
    if (count <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_newsController.hasClients) return;
      final next = (_newsPage + 1) % count;
      _newsController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _toggleLanguage() async {
    await AppLocalizations.toggleLanguage();
    if (!mounted) return;
    await _load();
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _openBrand(BrandSummary b) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => BrandPage(brand: b),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  void _openNews(NewsItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        // Long enough for the news image Hero flight to read as one motion.
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => NewsDetailPage(item: item),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _heroBlock()
                      .animate()
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.xl),
                  _newsSection()
                      .animate()
                      .fadeIn(duration: 450.ms, delay: 80.ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                  if (!_loading && (_data?.about ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _aboutCard(_data!.about!),
                    )
                        .animate()
                        .fadeIn(duration: 450.ms, delay: 140.ms)
                        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                  ],
                  if (!_loading && (_data?.brands ?? const []).isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _sectionTitle(context.tr('our_brands'), count: _data!.brands.length),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    _brandMarquee(_data!.brands),
                  ],
                  if (!_loading && (_data?.branches ?? const <BranchInfo>[]).isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _sectionTitle(context.tr('our_branches'), count: _data!.branches.length),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _BranchesMap(branches: _data!.branches),
                    ),
                  ],
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slim top bar ────────────────────────────────────────────
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 10),
            child: Row(
              children: [
                const MuntajatLogo(size: 30, showText: false, isDark: true),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _data?.companyName ?? context.tr('app_title'),
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Pressable(
                  onTap: _toggleLanguage,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: AppRadius.borderFull,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: Center(
                      child: Text(
                        AppLocalizations.isArabic ? 'EN' : 'ع',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Pressable(
                  onTap: _goToLogin,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded, color: AppColors.primaryDark, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          context.tr('login'),
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

  // ─── Identity band + stats bento riding its edge ─────────────
  Widget _heroBlock() {
    const bandHeight = 128.0;
    const overlap = 30.0;
    return Stack(
      children: [
        Container(
          height: bandHeight + overlap,
          width: double.infinity,
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DotsPattern(opacity: 0.045),
              const Positioned(top: -80, right: -40, child: GlassCircle(size: 190, opacity: 0.05)),
              Positioned.directional(
                textDirection: Directionality.of(context),
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                top: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('app_subtitle'),
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 46,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: AppRadius.borderFull,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Bento stats straddling the band's bottom edge.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, bandHeight - overlap, AppSpacing.lg, 0),
          child: _statsBento(),
        ),
      ],
    );
  }

  Widget _statsBento() {
    if (_loading) {
      return Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      );
    }
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final cities = d.branches.map((b) => b.city).whereType<String>().where((c) => c.isNotEmpty).toSet().length;
    final cards = <Widget>[
      if (d.brands.isNotEmpty)
        _statCard(Icons.workspace_premium_rounded, AppColors.accent, '${d.brands.length}', context.tr('stat_brands')),
      if (d.branches.isNotEmpty)
        _statCard(Icons.storefront_rounded, AppColors.primary, '${d.branches.length}', context.tr('stat_branches')),
      if (cities > 0)
        _statCard(Icons.location_city_rounded, AppColors.success, '$cities', context.tr('stat_cities')),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: cards[i]
                .animate()
                .fadeIn(duration: 400.ms, delay: (120 + i * 90).ms)
                .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
          ),
        ],
      ],
    );
  }

  Widget _statCard(IconData icon, Color tint, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: AppRadius.borderMd,
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─── News (magazine cards) ───────────────────────────────────
  Widget _newsSection() {
    if (_loading) {
      return const _SliderSkeleton();
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: context.tr('loading_error'),
          actionLabel: context.tr('retry'),
          onAction: _load,
        ),
      );
    }

    final news = _data?.news ?? const <NewsItem>[];
    if (news.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _sectionTitle(context.tr('landing_news')),
        ),
        const SizedBox(height: AppSpacing.base),
        SizedBox(
          height: 252,
          child: PageView.builder(
            controller: _newsController,
            itemCount: news.length,
            onPageChanged: (i) => setState(() => _newsPage = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _NewsCard(item: news[i], onTap: () => _openNews(news[i])),
            ),
          ),
        ),
        if (news.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(news.length, (i) {
                final active = i == _newsPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: AppRadius.borderFull,
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  // ─── About (editorial quote card) ────────────────────────────
  Widget _aboutCard(String about) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Stack(
        children: [
          // Oversized quote glyph as a quiet watermark.
          PositionedDirectional(
            top: -18,
            end: -6,
            child: Text(
              '❝',
              style: TextStyle(
                fontSize: 88,
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: AppRadius.borderFull,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    context.tr('about_company'),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                about,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.88),
                  height: 1.9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Brand marquee: two rows drifting in opposite directions ─
  Widget _brandMarquee(List<BrandSummary> brands) {
    final row1 = <BrandSummary>[];
    final row2 = <BrandSummary>[];
    for (var i = 0; i < brands.length; i++) {
      (i.isEven ? row1 : row2).add(brands[i]);
    }
    return Column(
      children: [
        _MarqueeRow(brands: row1, onTap: _openBrand),
        const SizedBox(height: AppSpacing.md),
        if (row2.isNotEmpty) _MarqueeRow(brands: row2, reverse: true, onTap: _openBrand),
      ],
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

  // ─── Footer sign-off ─────────────────────────────────────────
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 2.5,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: AppRadius.borderFull,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const MuntajatLogo(size: 42, showText: false),
          const SizedBox(height: AppSpacing.md),
          Text(
            _data?.companyName ?? context.tr('app_title'),
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.tr('landing_footer_tag'),
            textAlign: TextAlign.center,
            style: AppTypography.labelMedium.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── Auto-drifting brand marquee row ─────────────────────────
class _MarqueeRow extends StatefulWidget {
  final List<BrandSummary> brands;
  final bool reverse;
  final void Function(BrandSummary) onTap;
  const _MarqueeRow({required this.brands, required this.onTap, this.reverse = false});

  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow> with SingleTickerProviderStateMixin {
  static const double _tile = 78;
  static const double _gap = 12;

  late final AnimationController _c = AnimationController(
    vsync: this,
    // Slow, ambient drift — roughly 2.8s per logo.
    duration: Duration(milliseconds: (widget.brands.length * 2800).clamp(18000, 180000)),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.brands.isEmpty) return const SizedBox.shrink();
    final loopWidth = widget.brands.length * (_tile + _gap);
    return SizedBox(
      height: _tile,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              final v = _c.value;
              final dx = widget.reverse ? -loopWidth + v * loopWidth : -v * loopWidth;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            // Two copies back-to-back → a seamless infinite loop. The boundary
            // caches the row as one layer so the drift is pure GPU work.
            child: RepaintBoundary(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.ltr,
                children: [
                  for (final b in [...widget.brands, ...widget.brands])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                      child: GestureDetector(
                        onTap: () => widget.onTap(b),
                        child: BrandLogo(name: b.name, logoUrl: b.logoUrl, size: _tile),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── News card: image with a floating caption panel ──────────
class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;
  const _NewsCard({required this.item, required this.onTap});

  String? get _dateLabel {
    final d = item.publishedAt;
    if (d == null) return null;
    return '${d.day} ${monthName(d.month, short: true)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final date = _dateLabel;
    return Pressable(
      onTap: onTap,
      child: Stack(
      children: [
        // Image ends above the card bottom → the caption "rides" its edge.
        Positioned.fill(
          bottom: 34,
          child: Hero(
            tag: 'news-${item.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.shimmerBase),
                      errorWidget: (_, _, _) =>
                          DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
                    )
                  : DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
            ),
          ),
        ),
        PositionedDirectional(
          bottom: 0,
          start: AppSpacing.md,
          end: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Text(
                        context.tr('news_tag'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accentDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.schedule_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        date,
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                    const Spacer(),
                    // Drill-in affordance (RTL-aware).
                    Icon(
                      AppLocalizations.isArabic
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

// ─── Branches map (city chips steer the camera) ──────────────
class _BranchesMap extends StatefulWidget {
  final List<BranchInfo> branches;
  const _BranchesMap({required this.branches});

  @override
  State<_BranchesMap> createState() => _BranchesMapState();
}

class _BranchesMapState extends State<_BranchesMap> {
  final MapController _map = MapController();
  int? _selected;
  String? _city; // null → all cities

  List<BranchInfo> get _located =>
      widget.branches.where((b) => b.hasCoords).toList();

  List<String> get _cities => _located
      .map((b) => b.city)
      .whereType<String>()
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList();

  void _focusCity(String? city) {
    setState(() {
      _city = city;
      _selected = null;
    });
    final targets = city == null
        ? _located
        : _located.where((b) => b.city == city).toList();
    if (targets.isEmpty) return;
    _map.fitCamera(CameraFit.coordinates(
      coordinates: [for (final b in targets) LatLng(b.latitude!, b.longitude!)],
      padding: const EdgeInsets.all(60),
      maxZoom: 12,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final located = _located;
    if (located.isEmpty) return const SizedBox.shrink();

    final points = [for (final b in located) LatLng(b.latitude!, b.longitude!)];
    final dark = AppThemeController.isDark;
    final cities = _cities;

    return Column(
      children: [
        if (cities.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                _cityChip(context.tr('all_label'), _city == null, () => _focusCity(null)),
                for (final c in cities)
                  _cityChip(c, _city == c, () => _focusCity(c)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(
                      coordinates: points,
                      padding: const EdgeInsets.all(50),
                      maxZoom: 11,
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.flingAnimation,
                    ),
                    onTap: (_, _) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      // Theme-matched tiles: light & dark CARTO basemaps.
                      urlTemplate: dark
                          ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                          : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                      userAgentPackageName: 'sa.muntajat.exhibitionManagerApp',
                    ),
                    MarkerLayer(
                      markers: [
                        for (int i = 0; i < located.length; i++)
                          if (_city == null || located[i].city == _city)
                            Marker(
                              point: points[i],
                              width: 42,
                              height: 42,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selected = i);
                                  _map.move(points[i], 13);
                                },
                                child: _Pin(selected: _selected == i),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
                // Attribution (required by OSM / CARTO)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (dark ? Colors.black : Colors.white).withValues(alpha: 0.6),
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: Text(
                      '© OpenStreetMap · CARTO',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.textTertiary, fontSize: 9),
                    ),
                  ),
                ),
                if (_selected != null && _selected! < located.length)
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: _BranchInfoBar(branch: located[_selected!])
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .slideY(begin: 0.4, end: 0, curve: Curves.easeOut),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cityChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: AppRadius.borderFull,
            border: Border.all(color: active ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: active ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final bool selected;
  const _Pin({required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentDark : AppColors.primary;
    final size = selected ? 40.0 : 30.0;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 15),
      ),
    );
  }
}

class _BranchInfoBar extends StatelessWidget {
  final BranchInfo branch;
  const _BranchInfoBar({required this.branch});

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore — no handler available
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = (branch.address ?? '').isNotEmpty
        ? branch.address!
        : (branch.city ?? '');
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: AppRadius.borderMd,
            ),
            child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  branch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if ((branch.phone ?? '').isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            _BranchAction(
              icon: Icons.call_rounded,
              color: AppColors.success,
              onTap: () => _open(Uri.parse('tel:${branch.phone}')),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          _BranchAction(
            icon: Icons.directions_rounded,
            color: AppColors.primary,
            onTap: () => _open(Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${branch.latitude},${branch.longitude}')),
          ),
        ],
      ),
    );
  }
}

class _BranchAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BranchAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderMd,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ─── Slider loading skeleton ─────────────────────────────────
class _SliderSkeleton extends StatelessWidget {
  const _SliderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          height: 252,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
        ),
      ),
    );
  }
}
