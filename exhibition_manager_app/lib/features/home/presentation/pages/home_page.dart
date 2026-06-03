import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/shared/widgets/status_bar_wrapper.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';

/// Home Dashboard Page — Shows real stats and navigable cards (Bilingual & Premium Redesign)
class HomePage extends StatefulWidget {
  final User user;
  final void Function(int tabIndex)? onNavigateToTab;

  const HomePage({super.key, required this.user, this.onNavigateToTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _pendingSend = 0;
  int _pendingReceive = 0;
  int _inProgressCounting = 0;
  bool _isLoading = true;
  bool _hasError = false;

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
                                color: AppColors.primary,
                                bgColor: AppColors.primary.withValues(alpha: 0.08),
                                onTap: () => widget.onNavigateToTab?.call(1),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.qr_code_scanner_rounded,
                                label: context.tr('start_new_count'),
                                color: AppColors.success,
                                bgColor: AppColors.success.withValues(alpha: 0.08),
                                onTap: () => widget.onNavigateToTab?.call(2),
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
                            color: AppColors.warning,
                            onTap: () => widget.onNavigateToTab?.call(1),
                          ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideX(begin: 0.06, end: 0),
                          const SizedBox(height: AppSpacing.md),
                          _StatCard(
                            icon: Icons.inventory_outlined,
                            title: context.tr('transfers_pending_receive'),
                            value: _isLoading ? '...' : '$_pendingReceive',
                            color: AppColors.primary,
                            onTap: () => widget.onNavigateToTab?.call(1),
                          ).animate().fadeIn(delay: 160.ms, duration: 350.ms).slideX(begin: 0.06, end: 0),
                          const SizedBox(height: AppSpacing.md),
                          _StatCard(
                            icon: Icons.assignment_outlined,
                            title: context.tr('active_counting_sessions'),
                            value: _isLoading ? '...' : '$_inProgressCounting',
                            color: AppColors.success,
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
}

/// Quick action card widget (Modern Redesign)
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.borderLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderLg,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.borderLight),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: AppRadius.borderMd,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
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
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.borderLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderLg,
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
      ),
    );
  }
}
