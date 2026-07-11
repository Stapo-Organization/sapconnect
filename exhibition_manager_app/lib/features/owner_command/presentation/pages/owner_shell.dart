import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/notifications/push_service.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';

import 'package:exhibition_manager_app/features/retail_dashboard/presentation/channel_tokens.dart';
import 'package:exhibition_manager_app/features/retail_dashboard/presentation/pages/retail_dashboard_page.dart';
import 'package:exhibition_manager_app/features/stock_distribution/presentation/pages/stock_distribution_page.dart';
import 'package:exhibition_manager_app/features/container_tracking/presentation/pages/container_tracking_page.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_admin_page.dart';
import 'package:exhibition_manager_app/features/profile/presentation/pages/profile_page.dart';

import '../owner_theme.dart';
import 'owner_command_page.dart';
import 'owner_hub_page.dart';

class _OwnerTab {
  final Widget page;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  const _OwnerTab({
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
  });
}

/// شِل المالك — «مركز القيادة». بديل [MainShell] لمدير الفرع: شريط سفلي سليت
/// معاد ترتيبه بخمسة تبويبات ثابتة (القيادة/الأداء/المخزون والشحن/الموافقات/الملف)
/// على هوية داكنة، دون مسّ الثيم الفاتح العام أو تجربة مدير الفرع.
class OwnerShell extends StatefulWidget {
  final User user;
  const OwnerShell({super.key, required this.user});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _transition;
  late List<_OwnerTab> _tabs;

  void _navigateToTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    _transition.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    _tabs = _buildTabs();

    PushService.instance.pendingType.addListener(_handlePendingNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingNotification());
  }

  /// يوجّه الإشعار المنقور إلى تبويب المالك المناسب. أنواع التشغيل التي لا تبويب
  /// لها عند المالك (تحويلات/جرد) تُوجَّه إلى «القيادة» فلا تصل لطريق مسدود.
  /// (نظير MainShell._handlePendingNotification — مُكرَّر عمداً لإبقاء main_shell بلا تغيير.)
  void _handlePendingNotification() {
    final type = PushService.instance.consumePendingType();
    if (type == null || !mounted) return;
    final index = switch (type) {
      'promotion' || 'promo_approval' => 3,
      'container' || 'container_delay' => 2,
      'stock_distribution' => 2,
      'stock_transfer' || 'cycle_due' => 0,
      _ => null,
    };
    if (index != null) _navigateToTab(index);
  }

  List<_OwnerTab> _buildTabs() {
    final user = widget.user;
    return [
      _OwnerTab(
        page: OwnerCommandPage(
          user: user,
          // خلية قناة في هيرو القيادة → تبويب الأداء على تلك القناة. النيّة عبر
          // ValueNotifier لأن صفحة الأداء حيّة داخل IndexedStack (بُنيت مسبقاً).
          onOpenPerformance: (channel) {
            PerformanceChannelIntent.pending.value = channel;
            _navigateToTab(1);
          },
        ),
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        labelKey: 'owner_nav_command',
      ),
      const _OwnerTab(
        page: RetailDashboardPage(showBack: false),
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        labelKey: 'owner_nav_performance',
      ),
      _OwnerTab(
        page: OwnerHubPage(
          titleKey: 'owner_nav_logistics',
          subtitleKey: 'owner_logistics_subtitle',
          entries: [
            OwnerHubEntry(
              icon: Icons.hub_rounded,
              color: AppDomain.stockDistribution.accent,
              titleKey: 'owner_logistics_stock',
              subtitleKey: 'owner_logistics_stock_sub',
              builder: (_) => const StockDistributionPage(),
            ),
            OwnerHubEntry(
              icon: Icons.directions_boat_rounded,
              color: AppDomain.containerTracking.accent,
              titleKey: 'owner_logistics_shipping',
              subtitleKey: 'owner_logistics_shipping_sub',
              builder: (_) => const ContainerTrackingPage(),
            ),
          ],
        ),
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping_rounded,
        labelKey: 'owner_nav_logistics_short',
      ),
      _OwnerTab(
        page: OwnerHubPage(
          titleKey: 'owner_nav_approvals',
          subtitleKey: 'owner_approvals_subtitle',
          entries: [
            OwnerHubEntry(
              icon: Icons.campaign_rounded,
              color: AppDomain.promotions.accent,
              titleKey: 'owner_approvals_promos',
              subtitleKey: 'owner_approvals_promos_sub',
              builder: (_) => const PromotionsPage(initialStatus: 'suggested'),
            ),
            OwnerHubEntry(
              icon: Icons.fact_check_rounded,
              color: AppDomain.quality.accent,
              titleKey: 'owner_approvals_quality',
              subtitleKey: 'owner_approvals_quality_sub',
              builder: (_) => const QualityAdminPage(),
            ),
          ],
        ),
        icon: Icons.task_alt_outlined,
        selectedIcon: Icons.task_alt_rounded,
        labelKey: 'owner_nav_approvals',
      ),
      _OwnerTab(
        page: ProfilePage(user: user),
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        labelKey: 'owner_nav_profile',
      ),
    ];
  }

  @override
  void dispose() {
    PushService.instance.pendingType.removeListener(_handlePendingNotification);
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    // Rebuild the whole shell (background + nav bar + every tab) whenever the
    // light/dark choice changes — this route is already mounted, so a top-level
    // rebuild alone won't reach it; listening here does. Rebuilding [_tabs]
    // hands fresh page instances to the IndexedStack so they recolour too.
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppThemeController.modeNotifier,
      builder: (context, _, _) {
        _tabs = _buildTabs();
        return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: OwnerTheme.bg,
        body: AnimatedBuilder(
          animation: _transition,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_transition.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 14),
                child: child,
              ),
            );
          },
          child: IndexedStack(
            index: _currentIndex,
            children: _tabs.map((t) => t.page).toList(),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: OwnerTheme.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: OwnerTheme.surface,
                indicatorColor: OwnerTheme.accent.withValues(alpha: 0.22),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    size: 24,
                    color: selected ? OwnerTheme.accent : OwnerTheme.textMuted,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? OwnerTheme.textHi : OwnerTheme.textMuted,
                    leadingDistribution: TextLeadingDistribution.even,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _navigateToTab,
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(
                      icon: Icon(t.icon),
                      // نبضة زنبركية لحظة اختيار التبويب (تعاد مع كل اختيار).
                      selectedIcon: AnimatedNavIcon(icon: t.selectedIcon),
                      label: context.tr(t.labelKey),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
        );
      },
    );
  }
}
