import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/shared/widgets/status_bar_wrapper.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';
import 'package:exhibition_manager_app/features/home/presentation/controllers/home_controller.dart';
import 'package:exhibition_manager_app/features/home/presentation/widgets/action_center.dart';
import 'package:exhibition_manager_app/features/home/presentation/widgets/your_day_strip.dart';
import 'package:exhibition_manager_app/features/home/presentation/pages/action_center_page.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/cycle_count_detail_page.dart';
import 'package:exhibition_manager_app/features/gamification/data/models/gamification_models.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_tasks_page.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_task_detail_page.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/presentation/pages/zooboxi_orders_page.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/presentation/pages/zooboxi_order_detail_page.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/pages/product_search_page.dart';

/// Home Dashboard — a smart, context-aware command center.
///
/// One `/home/overview` call powers everything. The screen is deliberately just
/// two working blocks so nothing is said twice:
///  1. **Action Center** — the single, de-duplicated list of things to *do now*.
///  2. **Quick Look** — one unified grid of per-domain counters to *navigate*.
/// A motivational header + your-day strip sit on top; the gamification strip
/// sits at the very bottom. All state lives in [HomeController]; the page renders.
class HomePage extends StatefulWidget {
  final User user;

  /// Jump to a bottom-nav tab by its domain. Domain-based (not index-based)
  /// so it keeps working when tabs are hidden by the user's permissions.
  final void Function(AppDomain domain)? onNavigateToDomain;

  const HomePage({super.key, required this.user, this.onNavigateToDomain});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  HomeOverview? get _ov => _controller.overview;
  HomeModules? get _m => _ov?.modules;
  User get _user => widget.user;

  void _refresh() => _controller.refresh();

  /// The priority feed, filtered to items the user is actually allowed to open.
  List<HomeFeedItem> get _visibleFeed {
    final feed = _ov?.feed ?? const [];
    return feed
        .where((f) => f.feature.isEmpty || _user.hasFeature(f.feature))
        .toList();
  }

  /// The feed, de-duplicated: repeated items of the same type+title collapse
  /// into one [FeedGroup] carrying the total count. The Action Center surfaces
  /// the top few; the rest live behind "view all". (The server already caps the
  /// raw feed, so the full folded list is short.)
  List<FeedGroup> get _foldedFeed {
    final byKey = <String, ({HomeFeedItem lead, int count})>{};
    final order = <String>[];
    for (final f in _visibleFeed) {
      final key = '${f.type}|${f.title}';
      final g = byKey[key];
      if (g == null) {
        byKey[key] = (lead: f, count: 1);
        order.add(key);
      } else {
        byKey[key] = (lead: g.lead, count: g.count + 1);
      }
    }
    return [
      for (final k in order) FeedGroup(byKey[k]!.lead, byKey[k]!.count),
    ];
  }

  // ─── Feed routing ───────────────────────────────────────────
  void _openFeedItem(HomeFeedItem item) {
    Future<dynamic>? nav;
    switch (item.type) {
      case 'zooboxi_order':
        nav = item.orderId != null
            ? Navigator.push(context,
                MaterialPageRoute(builder: (_) => ZooboxiOrderDetailPage(orderId: item.orderId!)))
            : Navigator.push(context, MaterialPageRoute(builder: (_) => const ZooboxiOrdersPage()));
      case 'overdue_quality':
      case 'due_quality':
        nav = item.taskId != null
            ? Navigator.push(context,
                MaterialPageRoute(builder: (_) => QualityTaskDetailPage(instanceId: item.taskId!)))
            : Navigator.push(context, MaterialPageRoute(builder: (_) => const QualityTasksPage()));
      case 'overdue_cycle':
      case 'due_cycle':
        if (item.sessionId != null) {
          nav = Navigator.push(context,
              MaterialPageRoute(builder: (_) => CycleCountDetailPage(sessionId: item.sessionId!)));
        } else {
          widget.onNavigateToDomain?.call(AppDomain.counting);
        }
      case 'pending_receive':
      case 'pending_send':
        widget.onNavigateToDomain?.call(AppDomain.transfers);
      case 'promo_approval':
        nav = Navigator.push(context, MaterialPageRoute(builder: (_) => const PromotionsPage()));
    }
    nav?.then((_) => _refresh());
  }

  // ─── Header greeting ────────────────────────────────────────
  String _greeting(BuildContext context) {
    switch (_ov?.greetingPeriod) {
      case 'afternoon':
        return context.tr('greeting_afternoon');
      case 'evening':
        return context.tr('greeting_evening');
      case 'morning':
        return context.tr('greeting_morning');
      default:
        return context.tr('welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return StatusBarWrapper(
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: _controller.refresh,
            edgeOffset: MediaQuery.of(context).padding.top + 80,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => CustomScrollView(
                slivers: _slivers(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _slivers(BuildContext context) {
    final showError = _controller.hasError && _ov == null;
    final loading = _controller.loading && _ov == null;

    return [
      SliverToBoxAdapter(child: _header(context)),

      if (showError)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(child: ErrorStateWidget(onRetry: _controller.refresh)),
          ),
        )
      else if (loading)
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          sliver: const SliverToBoxAdapter(
            child: SkeletonList(itemCount: 4, cardHeight: 76),
          ),
        )
      else ...[
        // Your-day strip (motivation only).
        if (_ov != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
            sliver: SliverToBoxAdapter(
              child: YourDayStrip(day: _ov!.yourDay, progress: _ov!.progress)
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
            ),
          ),

        // Action Center — the ONE de-duplicated list of things to do now.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          sliver: SliverToBoxAdapter(
            child: ActionCenter(
              groups: _foldedFeed,
              onItemTap: _openFeedItem,
              onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActionCenterPage(
                    groups: _foldedFeed,
                    onItemTap: _openFeedItem,
                  ),
                ),
              ).then((_) => _refresh()),
            ),
          ),
        ),

        // Quick Look — one unified grid of per-domain counters + the primary
        // "start a new count" action. Replaces the old module sections, quick
        // actions and stat rows so every number appears exactly once.
        // (Points/level/streak now live in the header, merged with the greeting.)
        if (_glanceTiles(context).isNotEmpty)
          SliverToBoxAdapter(child: _quickLook(context)),
      ],

      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
    ];
  }

  // ─── Quick Look — unified per-domain counter grid ───────────
  Widget _quickLook(BuildContext context) {
    final tiles = _glanceTiles(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('quick_look'),
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          LayoutBuilder(
            builder: (context, c) {
              final tileW = (c.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final t in tiles) SizedBox(width: tileW, child: t),
                ],
              );
            },
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }

  /// The counter tiles the user is allowed to see — one per actionable domain.
  List<Widget> _glanceTiles(BuildContext context) {
    final m = _m;
    final tiles = <Widget>[];

    if (_user.hasFeature(Feature.inventoryCounting)) {
      tiles.add(_GlanceTile(
        icon: Icons.autorenew_rounded,
        label: context.tr('cycle_count'),
        value: m?.countingTasks.length ?? 0,
        domain: AppDomain.counting,
        onTap: () => widget.onNavigateToDomain?.call(AppDomain.counting),
      ));
    }
    if (_user.hasFeature(Feature.qualityControl)) {
      tiles.add(_GlanceTile(
        icon: Icons.verified_rounded,
        label: context.tr('quality_tasks'),
        value: m?.qcDue ?? 0,
        overdue: m?.qcOverdue ?? 0,
        domain: AppDomain.quality,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QualityTasksPage()),
        ).then((_) => _refresh()),
      ));
    }
    if (_user.hasFeature(Feature.stockTransfer)) {
      tiles.add(_GlanceTile(
        icon: Icons.local_shipping_outlined,
        label: context.tr('transfers_pending_send'),
        value: m?.pendingSend ?? 0,
        domain: AppDomain.transfers,
        onTap: () => widget.onNavigateToDomain?.call(AppDomain.transfers),
      ));
      tiles.add(_GlanceTile(
        icon: Icons.inventory_outlined,
        label: context.tr('transfers_pending_receive'),
        value: m?.pendingReceive ?? 0,
        domain: AppDomain.transfers,
        onTap: () => widget.onNavigateToDomain?.call(AppDomain.transfers),
      ));
    }
    if (_user.hasFeature(Feature.zooboxiOrders)) {
      tiles.add(_GlanceTile(
        icon: Icons.bolt_rounded,
        label: context.tr('zooboxi_urgent_orders'),
        value: m?.zbCount ?? 0,
        domain: AppDomain.zooboxi,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ZooboxiOrdersPage()),
        ).then((_) => _refresh()),
      ));
    }
    if (_user.hasFeature(Feature.promotions) && (_ov?.isOwner ?? false)) {
      tiles.add(_GlanceTile(
        icon: Icons.auto_awesome_rounded,
        label: context.tr('promotions'),
        value: m?.promoPending ?? 0,
        domain: AppDomain.promotions,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PromotionsPage()),
        ).then((_) => _refresh()),
      ));
    }
    return tiles;
  }

  // ─── Header — premium gradient hero with depth ──────────────
  Widget _header(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // Gamification is merged into the header (points + level + streak) when
    // the user has the feature and the payload has loaded.
    final gam = _user.hasFeature(Feature.gamification) ? _m?.gamification : null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxxl)),
      child: Stack(
        children: [
          // Base brand gradient.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          // Decorative depth circles.
          Positioned(top: -46, right: -34, child: _headerCircle(150, Colors.white.withValues(alpha: 0.07))),
          Positioned(top: 24, right: 48, child: _headerCircle(70, AppColors.accent.withValues(alpha: 0.16))),
          Positioned(bottom: -56, left: -40, child: _headerCircle(150, Colors.white.withValues(alpha: 0.05))),
          // Content.
          Padding(
            padding: EdgeInsets.only(
              top: topPad + AppSpacing.base,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _headerAvatar(level: gam?.level),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(context),
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _user.name,
                            style: AppTypography.headlineSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (gam != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _headerGamChips(context, gam),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _headerSearchButton(),
                    const SizedBox(width: AppSpacing.sm),
                    _headerRefreshButton(),
                  ],
                ),
                if (_user.warehouseCodes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _headerWarehousesBar(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _headerAvatar({int? level}) {
    final avatar = Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        _user.name.isNotEmpty ? _user.name[0] : '?',
        style: AppTypography.titleLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (level == null) return avatar;
    // Rank badge — the user's level, tucked on the avatar's corner.
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: -5,
            right: -5,
            child: Container(
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryDark, width: 2),
              ),
              child: Text(
                '$level',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Points + level + streak, merged into the header next to the greeting.
  /// The whole strip taps through to the Achievements tab.
  Widget _headerGamChips(BuildContext context, GamificationProfile g) {
    final label = g.levelLabel.isNotEmpty
        ? '${g.pointsTotal} ${context.tr('points')} · ${g.levelLabel}'
        : '${g.pointsTotal} ${context.tr('points')}';
    return Pressable(
      onTap: () => widget.onNavigateToDomain?.call(AppDomain.achievements),
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _glassPill(
              icon: Icons.stars_rounded,
              iconColor: const Color(0xFFFFD27A),
              text: label,
            ),
          ),
          if (g.streak.current > 0) ...[
            const SizedBox(width: 6),
            _glassPill(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFFB066),
              text: '${g.streak.current}',
            ),
          ],
          const SizedBox(width: 2),
          Icon(
            AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _glassPill({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Glass search button — opens product lookup (name / SAP code / barcode →
  /// stock across every warehouse). A frequently-needed manager utility, so it
  /// lives in the header, always one tap away.
  Widget _headerSearchButton() {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductSearchPage(myWarehouses: _user.warehouseCodes)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
        ),
        child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _headerRefreshButton() {
    return Pressable(
      onTap: _refresh,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
        ),
        child: _controller.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  /// Frosted "glass" bar listing the user's warehouses as soft chips.
  Widget _headerWarehousesBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warehouse_rounded, color: Colors.white, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in _user.warehouseCodes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      code,
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single per-domain counter in the Quick Look grid — big number, domain-
/// coloured icon chip, an optional overdue pill, tappable to its feature screen.
class _GlanceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final int overdue;
  final AppDomain domain;
  final VoidCallback onTap;

  const _GlanceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.domain,
    required this.onTap,
    this.overdue = 0,
  });

  @override
  Widget build(BuildContext context) {
    final accent = domain.accent;
    final muted = value == 0;
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.borderXl,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderXl,
          border: Border.all(color: AppColors.borderLight),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: domain.soft, borderRadius: AppRadius.borderMd),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const Spacer(),
                if (overdue > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.tr('feed_count_overdue').replaceAll('{n}', '$overdue'),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$value',
              style: AppTypography.headlineSmall.copyWith(
                color: muted ? AppColors.textTertiary : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
