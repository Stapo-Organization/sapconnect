import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/utils/haptics.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme/zb_colors.dart';

/// The four-tab shell. Each branch keeps its own navigation stack, so backing
/// out of a product returns to the list you found it in rather than to Home.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) {
          Haptics.selection();
          // Tapping the active tab pops that branch to its root — the
          // expected "take me back to the top" gesture.
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: l.navCategories,
          ),
          NavigationDestination(
            icon: _CartIcon(count: cartCount, selected: false),
            selectedIcon: _CartIcon(count: cartCount, selected: true),
            label: l.navCart,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l.navAccount,
          ),
        ],
      ),
    );
  }
}

/// Cart glyph with the unit-count badge. The badge animates in and bumps on
/// change, which is the app's confirmation that "add to cart" landed even
/// when the customer is three screens away from the cart.
class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined),
        if (count > 0)
          PositionedDirectional(
            top: -5,
            end: -7,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(count),
              tween: Tween(begin: context.reduceMotion ? 1 : 0.6, end: 1),
              duration: Motion.select,
              curve: Motion.spring,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: zb.sale,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.surface, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: context.tt.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
