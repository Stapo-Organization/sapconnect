import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/notifications/push_service.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'home_page.dart';
import 'package:exhibition_manager_app/features/showroom_pulse/presentation/pages/showroom_pulse_page.dart';
import 'package:exhibition_manager_app/features/stock_transfer/presentation/pages/transfers_list_page.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/counting_sessions_page.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/pages/achievements_page.dart';
import 'package:exhibition_manager_app/features/profile/presentation/pages/profile_page.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/pages/product_search_page.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/presentation/pages/zooboxi_orders_page.dart';
import 'hub_pages.dart';
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

/// Main Shell — five calm tabs («المتجر»): الرئيسية · العمليات · البحث ·
/// الأداء · حسابي (+ الإدارة for owners). Features that used to be tabs of
/// their own (transfers, counting, pulse, achievements) live in the hubs and
/// open as pushed pages.
class MainShell extends StatefulWidget {
  final User user;

  const MainShell({super.key, required this.user});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
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
    if (index != -1) return _navigateToTab(index);
    // Not a tab any more → open the feature page on top of the current tab.
    final WidgetBuilder? page = switch (domain) {
      AppDomain.transfers => (_) => const TransfersListPage(),
      AppDomain.counting => (_) => CountingSessionsPage(warehouseCodes: widget.user.warehouseCodes),
      AppDomain.zooboxi => (_) => const ZooboxiOrdersPage(),
      AppDomain.showroomPulse => (_) => const ShowroomPulsePage(),
      AppDomain.achievements => (_) => const AchievementsPage(),
      _ => null,
    };
    if (page != null) Navigator.of(context).push(MaterialPageRoute(builder: page));
  }

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1, // first frame (home) is fully visible — no launch flash
    );
    _tabs = _buildTabs();

    // افتح تبويب الميزة عند فتح التطبيق بنقرة إشعار (إقلاع بارد أو عودة من الخلفية).
    PushService.instance.pendingType.addListener(_handlePendingNotification);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handlePendingNotification(),
    );
  }

  /// يحوّل نوع الإشعار المنقور إلى تبويب الميزة المناسب (إن كان ظاهراً لهذا المستخدم).
  void _handlePendingNotification() {
    final type = PushService.instance.consumePendingType();
    if (type == null || !mounted) return;
    final domain = switch (type) {
      'stock_transfer' => AppDomain.transfers,
      'cycle_due' => AppDomain.counting,
      // Both a new order and a Mrsool courier update point at the orders tab —
      // previously neither navigated anywhere when tapped.
      'zooboxi_order' => AppDomain.zooboxi,
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
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        labelKey: 'nav_home',
      ),
      if (OperationsHub.visibleFor(user))
        _TabDef(
          domain: AppDomain.operations,
          page: OperationsHub(user: user),
          icon: Icons.layers_outlined,
          selectedIcon: Icons.layers_rounded,
          labelKey: 'nav_operations',
        ),
      _TabDef(
        domain: AppDomain.productSearch,
        page: ProductSearchPage(myWarehouses: user.warehouseCodes, isTab: true),
        icon: Icons.search_rounded,
        selectedIcon: Icons.search_rounded,
        labelKey: 'nav_search',
      ),
      if (PerformanceHub.visibleFor(user))
        _TabDef(
          domain: AppDomain.performance,
          page: PerformanceHub(user: user),
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights_rounded,
          labelKey: 'nav_performance',
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
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: AnimatedBuilder(
              animation: _transition,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_transition.value);
                return Opacity(opacity: 0.4 + 0.6 * t, child: child);
              },
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs.map((t) => t.page).toList(),
              ),
            ),
            bottomNavigationBar: AppTabBar(
              selectedIndex: _currentIndex,
              onTap: _navigateToTab,
              items: [
                for (final t in _tabs)
                  AppTabItem(icon: t.icon, selectedIcon: t.selectedIcon, label: context.tr(t.labelKey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
