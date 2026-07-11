import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/notifications/push_service.dart';
import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'home_page.dart';
import 'package:exhibition_manager_app/features/showroom_pulse/presentation/pages/showroom_pulse_page.dart';
import 'package:exhibition_manager_app/features/stock_transfer/presentation/pages/transfers_list_page.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/counting_sessions_page.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/pages/achievements_page.dart';
import 'package:exhibition_manager_app/features/profile/presentation/pages/profile_page.dart';
import 'package:exhibition_manager_app/features/admin_hub/presentation/pages/admin_hub_page.dart';

/// تعريف تبويب واحد في الشريط السفلي — يجمع الصفحة وهويتها وأيقوناتها،
/// فتبقى الفهرسة متّسقة مهما ظهر/اختفى تبويب حسب الصلاحيات.
class _TabDef {
  final AppDomain domain;
  final Widget page;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;

  const _TabDef({
    required this.domain,
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
  });
}

/// Main Shell — Material 3 bottom navigation with 5 tabs and localization.
class MainShell extends StatefulWidget {
  final User user;

  const MainShell({super.key, required this.user});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  late final AnimationController _transition;
  late List<_TabDef> _tabs;

  /// Switch tab with a short fade + rise so navigation feels intentional
  /// instead of a hard cut. IndexedStack keeps every tab's state alive.
  void _navigateToTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    _transition.forward(from: 0);
  }

  /// Jump to a feature tab by its domain, if it's visible for this user.
  /// Lets the Home page navigate to e.g. Transfers without hard-coded indices
  /// (which shift when a tab is hidden by permissions).
  void _navigateToDomain(AppDomain domain) {
    final index = _tabs.indexWhere((t) => t.domain == domain);
    if (index != -1) _navigateToTab(index);
  }

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1, // first frame (home) is fully visible — no launch flash
    );
    _tabs = _buildTabs();

    // افتح تبويب الميزة عند فتح التطبيق بنقرة إشعار (إقلاع بارد أو عودة من الخلفية).
    PushService.instance.pendingType.addListener(_handlePendingNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingNotification());
  }

  /// يحوّل نوع الإشعار المنقور إلى تبويب الميزة المناسب (إن كان ظاهراً لهذا المستخدم).
  void _handlePendingNotification() {
    final type = PushService.instance.consumePendingType();
    if (type == null || !mounted) return;
    final domain = switch (type) {
      'stock_transfer' => AppDomain.transfers,
      'cycle_due' => AppDomain.counting,
      _ => null,
    };
    if (domain != null) _navigateToDomain(domain);
  }

  /// Build the visible tab set from the user's abilities.
  /// Home and Profile are always present; the rest appear only when granted.
  List<_TabDef> _buildTabs() {
    final user = widget.user;
    return [
      _TabDef(
        domain: AppDomain.home,
        page: HomePage(user: user, onNavigateToDomain: _navigateToDomain),
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        labelKey: 'nav_home',
      ),
      if (user.hasFeature(Feature.showroomPulse))
        const _TabDef(
          domain: AppDomain.showroomPulse,
          page: ShowroomPulsePage(),
          icon: Icons.favorite_outline_rounded,
          selectedIcon: Icons.favorite_rounded,
          labelKey: 'nav_showroom_pulse',
        ),
      if (user.hasFeature(Feature.stockTransfer))
        const _TabDef(
          domain: AppDomain.transfers,
          page: TransfersListPage(),
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz_rounded,
          labelKey: 'nav_transfers',
        ),
      if (user.hasFeature(Feature.inventoryCounting))
        _TabDef(
          domain: AppDomain.counting,
          page: CountingSessionsPage(warehouseCodes: user.warehouseCodes),
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          labelKey: 'nav_counting',
        ),
      if (user.hasFeature(Feature.gamification))
        const _TabDef(
          domain: AppDomain.achievements,
          page: AchievementsPage(),
          icon: Icons.emoji_events_outlined,
          selectedIcon: Icons.emoji_events_rounded,
          labelKey: 'nav_achievements',
        ),
      // ─── خصائص المالك (Super Admin): تبويب "الإدارة" واحد يفتح الهَب ───
      if (_canSeeAdmin(user))
        const _TabDef(
          domain: AppDomain.admin,
          page: AdminHubPage(),
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings_rounded,
          labelKey: 'nav_admin',
        ),
      _TabDef(
        domain: AppDomain.profile,
        page: ProfilePage(user: user),
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        labelKey: 'nav_profile',
      ),
    ];
  }

  /// تبويب «الإدارة» حصري لتجربة المالك (Super Admin). نفس حارس توجيه الشِل
  /// [User.isOwnerExperience] — لا [User.can] التي تسمح بكل شيء حين تغيب
  /// abilities، فيظهر التبويب خطأً لمدير الفرع.
  bool _canSeeAdmin(User user) => user.isOwnerExperience;

  @override
  void dispose() {
    PushService.instance.pendingType.removeListener(_handlePendingNotification);
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    // Rebuild the whole shell (background + nav bar + every tab) when the
    // light/dark choice changes — this mounted route won't be reached by a
    // top-level rebuild otherwise. Fresh [_tabs] recolour the IndexedStack pages.
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppThemeController.modeNotifier,
      builder: (context, _, _) {
        _tabs = _buildTabs();
        final domain = _tabs[_currentIndex].domain;
        return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
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
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            // Tint the active destination with its domain accent so moving
            // between tabs carries a subtle, animated sense of place.
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: domain.soft,
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    size: 24,
                    color: selected ? domain.accent : AppColors.textTertiary,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? domain.accent : AppColors.textTertiary,
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
