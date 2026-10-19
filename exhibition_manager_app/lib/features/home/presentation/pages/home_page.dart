import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
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
            edgeOffset: MediaQuery.of(context).padding.top,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: YourDayStrip(day: _ov!.yourDay, progress: _ov!.progress)
                  .animate()
                  .fadeIn(duration: 250.ms),
            ),
          ),

        // Action Center — the ONE de-duplicated list of things to do now.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

  // ─── Quick Look — one card of counters ──────────────────────
  Widget _quickLook(BuildContext context) {
    final tiles = _glanceTiles(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AppSection(
        title: context.tr('quick_look'),
        children: [
          for (var r = 0; r < tiles.length; r += 2)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[r]),
                  if (r + 1 < tiles.length) ...[
                    VerticalDivider(width: 1, thickness: 1, color: AppColors.borderLight),
                    Expanded(child: tiles[r + 1]),
                  ],
                ],
              ),
            ),
        ],
      ).animate().fadeIn(duration: 250.ms),
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
        index: tiles.length,
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
        index: tiles.length,
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
        index: tiles.length,
        onTap: () => widget.onNavigateToDomain?.call(AppDomain.transfers),
      ));
      tiles.add(_GlanceTile(
        icon: Icons.inventory_outlined,
        label: context.tr('transfers_pending_receive'),
        value: m?.pendingReceive ?? 0,
        domain: AppDomain.transfers,
        index: tiles.length,
        onTap: () => widget.onNavigateToDomain?.call(AppDomain.transfers),
      ));
    }
    if (_user.hasFeature(Feature.zooboxiOrders)) {
      tiles.add(_GlanceTile(
        icon: Icons.bolt_rounded,
        label: context.tr('zooboxi_urgent_orders'),
        value: m?.zbCount ?? 0,
        domain: AppDomain.zooboxi,
        index: tiles.length,
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
        index: tiles.length,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PromotionsPage()),
        ).then((_) => _refresh()),
      ));
    }
    return tiles;
  }

  // ─── Header — calm page header (Shopify) ────────────────────
  Widget _header(BuildContext context) {
    // Points + level + streak sit as one quiet line under the greeting when
    // the user has gamification and the payload has loaded.
    final gam = _user.hasFeature(Feature.gamification) ? _m?.gamification : null;
    return PageHeader(
      title: _greeting(context),
      subtitle: _user.name,
      actions: [
        HeaderIconButton(
          icon: Icons.search_rounded,
          tooltip: context.tr('product_search'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductSearchPage(myWarehouses: _user.warehouseCodes)),
          ),
        ),
        HeaderIconButton(
          icon: Icons.refresh_rounded,
          onTap: _refresh,
          child: _controller.loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                )
              : null,
        ),
      ],
      below: (_user.warehouseCodes.isEmpty && gam == null)
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final code in _user.warehouseCodes) _headerTag(icon: Icons.storefront_outlined, text: code, mono: true),
                if (gam != null) _headerGam(context, gam),
              ],
            ),
    );
  }

  Widget _headerTag({required IconData icon, required String text, bool mono = false, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor ?? AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: (mono ? AppTypography.monoSmall : AppTypography.labelMedium)
                .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Points + level + streak as one tag; taps through to Achievements.
  Widget _headerGam(BuildContext context, GamificationProfile g) {
    final label = g.levelLabel.isNotEmpty && !context.isCompact
        ? '${g.pointsTotal} ${context.tr('points')} · ${g.levelLabel}'
        : '${g.pointsTotal} ${context.tr('points')}';
    return Pressable(
      onTap: () => widget.onNavigateToDomain?.call(AppDomain.achievements),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _headerTag(icon: Icons.star_rounded, text: label, iconColor: AppColors.accent),
          if (g.streak.current > 0) ...[
            const SizedBox(width: 8),
            _headerTag(
              icon: Icons.local_fire_department_rounded,
              text: '${g.streak.current}',
              iconColor: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

/// One counter cell in the Quick Look card — label, big tabular number and an
/// optional "late" badge; tappable to its feature screen. Neutral by design:
/// a zero reads grey, a late count gets the critical badge.
class _GlanceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final int overdue;
  final AppDomain domain;
  final VoidCallback onTap;
  final int index;

  const _GlanceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.domain,
    required this.onTap,
    this.overdue = 0,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final muted = value == 0;
    return Pressable(
      onTap: onTap,
      pressedScale: 1,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: AppTypography.displayMedium.copyWith(
                    fontSize: 24,
                    color: muted ? AppColors.textTertiary : AppColors.textPrimary,
                  ),
                ),
                if (overdue > 0) ...[
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: context.tr('feed_count_overdue').replaceAll('{n}', '$overdue'),
                    color: AppColors.error,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
