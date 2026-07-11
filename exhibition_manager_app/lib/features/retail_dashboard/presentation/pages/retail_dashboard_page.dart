import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../../data/models/retail_models.dart';
import '../channel_tokens.dart';
import '../controllers/retail_dashboard_controller.dart';
import '../widgets/channel_comparison.dart';
import '../widgets/leaderboard_row.dart';
import '../widgets/sales_profit_chart.dart';
import '../widgets/wholesale_customer_row.dart';
import 'branch_detail_page.dart';

/// Performance dashboard (الأداء) — the owner's whole-business view:
/// a channel switcher (الإجمالي / المعارض / الجملة), a count-up sales total,
/// period + sort filters, and the channel's natural drill-down — branches
/// ranked with pulse rings for retail, top customers for wholesale, and a
/// two-channel comparison for the total view.
class RetailDashboardPage extends StatefulWidget {
  /// يُخفي زر الرجوع في الهيرو عند عرض الصفحة كتبويب (لا كصفحة مدفوعة)،
  /// مثل تبويب «الأداء» في شِل المالك.
  final bool showBack;

  /// القناة الافتراضية عند أول فتح (الإجمالي ما لم يُطلب غيره).
  final String initialChannel;

  const RetailDashboardPage({
    super.key,
    this.showBack = true,
    this.initialChannel = SalesChannel.total,
  });

  @override
  State<RetailDashboardPage> createState() => _RetailDashboardPageState();
}

class _RetailDashboardPageState extends State<RetailDashboardPage> {
  late final RetailDashboardController _c =
      RetailDashboardController(initialChannel: widget.initialChannel);

  @override
  void initState() {
    super.initState();
    _c.load();
    // Owner-home channel cells set an intent then switch to this tab; the page
    // is kept alive inside the shell's IndexedStack, so listen — don't rebuild.
    PerformanceChannelIntent.pending.addListener(_onChannelIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChannelIntent());
  }

  void _onChannelIntent() {
    final channel = PerformanceChannelIntent.consume();
    if (channel != null && mounted) _c.setChannel(channel);
  }

  @override
  void dispose() {
    PerformanceChannelIntent.pending.removeListener(_onChannelIntent);
    _c.dispose();
    super.dispose();
  }

  static const _periods = ['today', 'week', 'month', 'year'];

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      locale: const Locale('ar'),
    );
    if (range != null) {
      final f = range.start.toIso8601String().split('T').first;
      final t = range.end.toIso8601String().split('T').first;
      _c.setPeriod('custom', from: f, to: t);
    }
  }

  String get _periodLabel => switch (_c.period) {
        'today' => 'rd_period_today',
        'week' => 'rd_period_week',
        'year' => 'rd_period_year',
        'custom' => 'rd_period_custom',
        _ => 'rd_period_month',
      };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            return RefreshIndicator(
              onRefresh: _c.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _hero(context),
                  _channelSwitcher(context),
                  _filters(context),
                  ..._body(context),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Hero: back + page name + big count-up KPI ───────────────
  Widget _hero(BuildContext context) {
    final d = _c.data;
    final net = d?.totalNet ?? 0;
    final channel = _c.channel;
    return GradientHeader(
      gradient: AppDomain.admin.gradient,
      leading: widget.showBack ? const BackButton(color: Colors.white) : null,
      title: context.tr('rd_title'),
      subtitle: context.tr('admin_hub_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${context.tr('rd_net_sales')} · ${context.tr(SalesChannel.labelKey(channel))} · ${context.tr(_periodLabel)}',
              style: AppTypography.labelMedium.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 2),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: net),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              sarAmount(v),
              style: AppTypography.displayMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if ((d?.totalProfit ?? 0) > 0)
                _heroPill(Icons.savings_rounded, '${context.tr('rd_profit_short')} ${sarCompact(d!.totalProfit)}', highlight: true),
              _heroPill(Icons.receipt_long_rounded, '${intGrouped(d?.totalInvoices ?? 0)} ${context.tr('rd_invoices')}'),
              // The third pill is the channel's natural count: branches for
              // retail, customers for wholesale, the split for total.
              if (channel == SalesChannel.wholesale)
                _heroPill(Icons.groups_rounded, '${d?.customersCount ?? 0} ${context.tr('rd_customers_count')}')
              else if (channel == SalesChannel.total && d?.channels != null)
                _heroPill(Icons.donut_large_rounded,
                    '${context.tr('rd_channel_retail')} ${(d!.channels!.retailShare * 100).toStringAsFixed(0)}٪ · ${context.tr('rd_channel_wholesale')} ${(d.channels!.wholesaleShare * 100).toStringAsFixed(0)}٪')
              else
                _heroPill(Icons.storefront_rounded, '${d?.branchesCount ?? 0} ${context.tr('rd_branches_count')}'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Channel switcher: الإجمالي / المعارض / الجملة ─────────────
  Widget _channelSwitcher(BuildContext context) {
    final selected = SalesChannel.order.indexOf(_c.channel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, 0),
      child: AppSegmentedControl(
        activeColor: SalesChannel.color(_c.channel),
        selectedIndex: selected < 0 ? 0 : selected,
        onChanged: (i) => _c.setChannel(SalesChannel.order[i]),
        items: [
          for (final ch in SalesChannel.order)
            SegmentItem(context.tr(SalesChannel.labelKey(ch)), icon: SalesChannel.icon(ch)),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? Colors.white : Colors.white.withValues(alpha: 0.18),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: highlight ? AppColors.success : Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: AppTypography.labelSmall.copyWith(
                color: highlight ? AppColors.success : Colors.white,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      ),
    );
  }

  // ─── Filters: period + custom-range; then a labelled sort row ─
  Widget _filters(BuildContext context) {
    final accent = SalesChannel.color(_c.channel);
    final selected = _periods.indexOf(_c.period);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: AppSegmentedControl(
              activeColor: accent,
              selectedIndex: selected < 0 ? 2 : selected,
              onChanged: (i) => _c.setPeriod(_periods[i]),
              items: [
                SegmentItem(context.tr('rd_period_today')),
                SegmentItem(context.tr('rd_period_week')),
                SegmentItem(context.tr('rd_period_month')),
                SegmentItem(context.tr('rd_period_year')),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _calendarButton(accent),
        ],
      ),
    );
  }

  // ─── Ranking section header + sort row (sits under the chart) ─
  Widget _rankingHeader(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppDomain.admin.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.tr('owner_section_leaderboard'),
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );

  Widget _sortRow(BuildContext context) => Row(
        children: [
          Text('${context.tr('rd_sort_label')}:',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: AppLocalizations.isArabic,
              child: Row(
                children: [
                  _sortPill(context, 'revenue', context.tr('rd_sort_revenue')),
                  _sortPill(context, 'profit', context.tr('rd_sort_profit')),
                  _sortPill(context, 'score', context.tr('rd_sort_score')),
                  _sortPill(context, 'bleeding', context.tr('rd_sort_bleeding')),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _calendarButton(Color accent) {
    final on = _c.period == 'custom';
    return Material(
      color: on ? accent : AppColors.surface,
      borderRadius: AppRadius.borderMd,
      child: InkWell(
        borderRadius: AppRadius.borderMd,
        onTap: _pickCustom,
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: on ? accent : AppColors.border),
          ),
          child: Icon(Icons.date_range_rounded, color: on ? Colors.white : accent, size: 20),
        ),
      ),
    );
  }

  Widget _sortPill(BuildContext context, String key, String label) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: PillChip(
          label: label,
          selected: _c.sort == key,
          onTap: () => _c.setSort(key),
          color: AppDomain.admin.accent,
        ),
      );

  /// Layout-matching skeleton (chart block + ranking rows) so switching period
  /// reads as the real page filling in, not a generic card list flashing.
  List<Widget> _loadingSkeleton() => [
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.base),
          child: SkeletonCard(height: 196),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            children: [for (var i = 0; i < 5; i++) const SkeletonCard(height: 84)],
          ),
        ),
      ];

  List<Widget> _body(BuildContext context) {
    if (_c.loading) {
      return _loadingSkeleton();
    }
    if (_c.hasError) {
      return [Padding(padding: const EdgeInsets.only(top: AppSpacing.huge), child: ErrorStateWidget(onRetry: _c.refresh))];
    }
    return switch (_c.channel) {
      SalesChannel.wholesale => _wholesaleBody(context),
      SalesChannel.total => _totalBody(context),
      _ => _retailBody(context),
    };
  }

  Widget _chart(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
        child: SalesProfitChart(
          trend: _c.data!.trend,
          salesColor: SalesChannel.color(_c.channel),
        ),
      );

  // ─── المعارض: chart + branch leaderboard (the original body) ──
  List<Widget> _retailBody(BuildContext context) {
    final branches = _c.sortedBranches;
    if (branches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.huge),
          child: EmptyState(icon: Icons.storefront_outlined, title: context.tr('rd_no_branches')),
        ),
      ];
    }
    return [
      _chart(context),
      const SizedBox(height: AppSpacing.base),
      ..._branchLeaderboard(context, branches),
    ];
  }

  List<Widget> _branchLeaderboard(BuildContext context, List<BranchCard> branches) {
    final maxNet = branches.map((b) => b.revenue.net).fold<double>(0, (a, b) => b > a ? b : a);
    return [
      // Branch ranking — below the chart, with its own sort controls.
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rankingHeader(context),
            const SizedBox(height: AppSpacing.sm),
            _sortRow(context),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Column(
          children: [
            for (var i = 0; i < branches.length; i++)
              LeaderboardRow(
                branch: branches[i],
                rank: i + 1,
                maxNet: maxNet,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BranchDetailPage(warehouseCode: branches[i].code, initialName: branches[i].name),
                  ),
                ),
              ).animate().fadeIn(duration: 280.ms, delay: (i * 45).ms).slideY(begin: 0.12, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    ];
  }

  // ─── الجملة: chart + top wholesale customers ──────────────────
  List<Widget> _wholesaleBody(BuildContext context) {
    final customers = _c.data?.customers ?? const <WholesaleCustomer>[];
    if (customers.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.huge),
          child: EmptyState(icon: Icons.groups_outlined, title: context.tr('rd_no_customers')),
        ),
      ];
    }
    final maxNet = customers.map((c) => c.net).fold<double>(0, (a, b) => b > a ? b : a);
    return [
      _chart(context),
      const SizedBox(height: AppSpacing.base),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.accentDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              context.tr('rd_top_customers'),
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${_c.data?.customersCount ?? customers.length} ${context.tr('rd_customers_count')}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Column(
          children: [
            for (var i = 0; i < customers.length; i++)
              WholesaleCustomerRow(customer: customers[i], rank: i + 1, maxNet: maxNet)
                  .animate()
                  .fadeIn(duration: 280.ms, delay: (i * 45).ms)
                  .slideY(begin: 0.12, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    ];
  }

  // ─── الإجمالي: chart + channel comparison + retail leaderboard ─
  List<Widget> _totalBody(BuildContext context) {
    final branches = _c.sortedBranches;
    final channels = _c.data?.channels;
    return [
      _chart(context),
      if (channels != null) ...[
        const SizedBox(height: AppSpacing.base),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.tr('rd_comparison_title'),
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: ChannelComparison(channels: channels, onOpenChannel: _c.setChannel)
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.08, curve: Curves.easeOutCubic),
        ),
      ],
      if (branches.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        ..._branchLeaderboard(context, branches),
      ],
    ];
  }
}
