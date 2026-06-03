import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
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

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(user: widget.user, onNavigateToTab: _navigateToTab),
      const TransfersListPage(),
      CountingSessionsPage(warehouseCodes: widget.user.warehouseCodes),
      const AchievementsPage(),
      ProfilePage(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
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
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
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
    );
  }
}
