import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/shared/widgets/status_bar_wrapper.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/counting_repository.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/cycle_count_detail_page.dart';
import 'package:exhibition_manager_app/features/gamification/data/gamification_repository.dart';
import 'package:exhibition_manager_app/features/gamification/data/models/gamification_models.dart';
import 'package:exhibition_manager_app/features/quality_control/data/quality_control_repository.dart';
import 'package:exhibition_manager_app/features/quality_control/data/models/quality_task_models.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/widgets/quality_task_card.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_tasks_page.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_task_detail_page.dart';

/// Home Dashboard Page — Shows real stats and navigable cards (Bilingual & Premium Redesign)
class HomePage extends StatefulWidget {
  final User user;
  final void Function(int tabIndex)? onNavigateToTab;

  const HomePage({super.key, required this.user, this.onNavigateToTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CountingRepository _countingRepo = CountingRepository();
  final GamificationRepository _gamRepo = GamificationRepository();
  final QualityControlRepository _qcRepo = QualityControlRepository();

  int _pendingSend = 0;
  int _pendingReceive = 0;
  int _inProgressCounting = 0;
  bool _isLoading = true;
  bool _hasError = false;

  List<CountingSession> _tasks = [];
  GamificationProfile? _gam;
  int _qcDue = 0;
  List<QualityTaskInstance> _qcTasks = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final result = await ApiClient().get(ApiEndpoints.dashboardStats);
    if (result.isSuccess && mounted) {
      setState(() {
        _pendingSend = result.data['pending_send'] ?? 0;
        _pendingReceive = result.data['pending_receive'] ?? 0;
        _inProgressCounting = result.data['in_progress_counting'] ?? 0;
        _isLoading = false;
        _hasError = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final sched = await _countingRepo.getSchedule();
    final gam = await _gamRepo.getMe();
    final qc = await _qcRepo.getSummary();
    if (!mounted) return;
    setState(() {
      _gam = gam.data;
      final tasks = <CountingSession>[];
      if (sched.success && sched.data != null) {
        for (final key in ['overdue', 'upcoming']) {
          final list = (sched.data![key] as List?) ?? [];
          tasks.addAll(list.map((e) => CountingSession.fromJson(Map<String, dynamic>.from(e as Map))));
        }
      }
      _tasks = tasks;
      _qcDue = qc.dueCount;
      _qcTasks = qc.due;
    });
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
            onRefresh: _loadStats,
            edgeOffset: MediaQuery.of(context).padding.top + 80,
            child: CustomScrollView(
              slivers: [
                // ─── Header Section ─────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + AppSpacing.base,
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      bottom: AppSpacing.xxl,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.xxxl),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.accent, // Gold highlight
                                child: Text(
                                  widget.user.name.isNotEmpty ? widget.user.name[0] : '?',
                                  style: AppTypography.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('welcome'),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  Text(
                                    widget.user.name,
                                    style: AppTypography.titleLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Refresh button
                            GestureDetector(
                              onTap: _loadStats,
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.borderMd,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        if (widget.user.warehouseCodes.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.base),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs + 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.22),
                              borderRadius: AppRadius.borderFull,
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warehouse_outlined, color: AppColors.accent, size: 16),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  widget.user.warehouseCodes.join(' • '),
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ─── Gamification strip ─────────────────────────
                if (_gam != null)
                  SliverToBoxAdapter(child: _buildGamStrip(context)),

                // ─── Quality Tasks ──────────────────────────────
                if (_qcDue > 0)
                  SliverToBoxAdapter(child: _buildQualitySection(context)),

                // ─── Your Tasks ─────────────────────────────────
                if (_tasks.isNotEmpty)
                  SliverToBoxAdapter(child: _buildTasks(context)),

                // ─── Quick Actions Section ──────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('quick_actions'),
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.base),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.swap_horiz_rounded,
                                label: context.tr('stock_transfers'),
                                color: AppDomain.transfers.accent,
                                bgColor: AppDomain.transfers.soft,
                                onTap: () => widget.onNavigateToTab?.call(1),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.qr_code_scanner_rounded,
                                label: context.tr('start_new_count'),
                                color: AppDomain.counting.accent,
                                bgColor: AppDomain.counting.soft,
                                onTap: () => widget.onNavigateToTab?.call(2),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.verified_rounded,
                                label: context.tr('quality_tasks'),
                                color: AppDomain.quality.accent,
                                bgColor: AppDomain.quality.soft,
                                badge: _qcDue > 0 ? _qcDue : null,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const QualityTasksPage()),
                                ).then((_) => _loadExtras()),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.10, end: 0, curve: Curves.easeOut),
                      ],
                    ),
                  ),
                ),

                // ─── Stats Section ──────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
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
                        if (_hasError)
                          ErrorStateWidget(
                            onRetry: _loadStats,
                          )
                        else ...[
                          _StatCard(
                            icon: Icons.local_shipping_outlined,
                            title: context.tr('transfers_pending_send'),
                            value: _isLoading ? '...' : '$_pendingSend',
                            color: AppDomain.transfers.accent,
                            onTap: () => widget.onNavigateToTab?.call(1),
                          ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideX(begin: 0.06, end: 0),
                          const SizedBox(height: AppSpacing.md),
                          _StatCard(
                            icon: Icons.inventory_outlined,
                            title: context.tr('transfers_pending_receive'),
                            value: _isLoading ? '...' : '$_pendingReceive',
                            color: AppDomain.transfers.accentDark,
                            onTap: () => widget.onNavigateToTab?.call(1),
                          ).animate().fadeIn(delay: 160.ms, duration: 350.ms).slideX(begin: 0.06, end: 0),
                          const SizedBox(height: AppSpacing.md),
                          _StatCard(
                            icon: Icons.assignment_outlined,
                            title: context.tr('active_counting_sessions'),
                            value: _isLoading ? '...' : '$_inProgressCounting',
                            color: AppDomain.counting.accent,
                            onTap: () => widget.onNavigateToTab?.call(2),
                          ).animate().fadeIn(delay: 240.ms, duration: 350.ms).slideX(begin: 0.06, end: 0),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Gamification strip (tap → Achievements tab) ────────────
  Widget _buildGamStrip(BuildContext context) {
    final g = _gam!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: AppCard(
        onTap: () => widget.onNavigateToTab?.call(3),
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: AppColors.goldGradient, shape: BoxShape.circle),
              child: Text('${g.level}',
                  style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${g.pointsTotal} ${context.tr('points')}',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  Text(g.levelLabel,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (g.streak.current > 0) ...[
              const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 2),
              Text('${g.streak.current}',
                  style: AppTypography.labelLarge.copyWith(
                      color: AppColors.warning, fontWeight: FontWeight.bold)),
              const SizedBox(width: AppSpacing.md),
            ],
            Icon(AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ─── Quality Tasks (due today) ──────────────────────────────
  Widget _buildQualitySection(BuildContext context) {
    final tasks = _qcTasks.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: AppDomain.quality.accent, size: 20),
              const SizedBox(width: 6),
              Text(context.tr('quality_tasks'),
                  style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: AppDomain.quality.accent, borderRadius: BorderRadius.circular(999)),
                child: Text('$_qcDue',
                    style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QualityTasksPage()),
                ).then((_) => _loadExtras()),
                child: Text(context.tr('view_all'),
                    style: AppTypography.labelMedium.copyWith(
                        color: AppDomain.quality.accentDark, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final t in tasks)
            QualityTaskCard(
              task: t,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QualityTaskDetailPage(instanceId: t.id)),
              ).then((_) => _loadExtras()),
            ),
        ],
      ),
    );
  }

  // ─── Your Tasks (due/overdue cycle counts) ──────────────────
  Widget _buildTasks(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final tasks = _tasks.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.tr('your_tasks'),
                  style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: AppDomain.counting.accent, borderRadius: BorderRadius.circular(999)),
                child: Text('${_tasks.length}',
                    style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final t in tasks) _taskCard(context, t, isArabic),
        ],
      ),
    );
  }

  Widget _taskCard(BuildContext context, CountingSession t, bool isArabic) {
    final overdue = _isOverdue(t.scheduledDate);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CycleCountDetailPage(sessionId: t.id)),
        ).then((_) => _loadExtras()),
        padding: const EdgeInsets.all(AppSpacing.base),
        borderColor: overdue ? AppColors.error.withValues(alpha: 0.25) : null,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (overdue ? AppColors.error : AppDomain.counting.accent).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.autorenew_rounded,
                  color: overdue ? AppColors.error : AppDomain.counting.accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.warehouseName ?? t.warehouseCode,
                      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusBadge(
                        label: overdue ? context.tr('overdue_label') : context.tr('due_label'),
                        color: overdue ? AppColors.error : AppColors.success,
                        icon: overdue ? Icons.warning_amber_rounded : Icons.event_available_rounded,
                      ),
                      const SizedBox(width: 6),
                      Text('${t.totalTargetItems} ${context.tr('items')}',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
            AppButton(
              label: context.tr('start_now'),
              expand: false,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CycleCountDetailPage(sessionId: t.id)),
              ).then((_) => _loadExtras()),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOverdue(String? date) {
    if (date == null) return false;
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }
}

/// Quick action card widget (Modern Redesign)
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final int? badge;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.borderXl,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.borderLight),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                        child: Text('$badge',
                            style: AppTypography.labelSmall.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

/// Stat card widget — tappable with premium styling
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Animated number value
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
    );
  }
}
