import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'home_page.dart';
import 'package:exhibition_manager_app/features/stock_transfer/presentation/pages/transfers_list_page.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/counting_sessions_page.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/pages/achievements_page.dart';
import 'package:exhibition_manager_app/features/profile/presentation/pages/profile_page.dart';

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
  late final List<Widget> _pages;

  /// Switch tab with a short fade + rise so navigation feels intentional
  /// instead of a hard cut. IndexedStack keeps every tab's state alive.
  void _navigateToTab(int index) {
    if (index == _currentIndex) return;
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
      value: 1, // first frame (home) is fully visible — no launch flash
    );
    _pages = [
      HomePage(user: widget.user, onNavigateToTab: _navigateToTab),
      const TransfersListPage(),
      CountingSessionsPage(warehouseCodes: widget.user.warehouseCodes),
      const AchievementsPage(),
      ProfilePage(user: widget.user),
    ];
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  static const List<AppDomain> _tabDomains = [
    AppDomain.home,
    AppDomain.transfers,
    AppDomain.counting,
    AppDomain.achievements,
    AppDomain.profile,
  ];

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final domain = _tabDomains[_currentIndex];
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
            children: _pages,
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
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded),
                  label: context.tr('nav_home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.swap_horiz_outlined),
                  selectedIcon: const Icon(Icons.swap_horiz_rounded),
                  label: context.tr('nav_transfers'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2_rounded),
                  label: context.tr('nav_counting'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.emoji_events_outlined),
                  selectedIcon: const Icon(Icons.emoji_events_rounded),
                  label: context.tr('nav_achievements'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: context.tr('nav_profile'),
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
