import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/active_branch.dart';
import '../../core/utils/haptics.dart';
import 'glass_nav_bar.dart';
import 'express_cart_bar.dart';
import 'live_order_bar.dart';

/// The four tab destinations, in bar order. Pushed pages use the same list to
/// jump straight to a tab, so there is exactly one place that knows which
/// route each icon leads to.
const List<String> navBranchPaths = ['/home', '/categories', '/cart', '/account'];

/// The four-tab shell. Each branch keeps its own navigation stack, so backing
/// out of a product returns to the list you found it in rather than to Home.
///
/// `extendBody` is what lets the glass bar float: the branch's content runs the
/// full height of the screen and the bar sits over it. Scaffold pays that back
/// by folding the bar's height into `MediaQuery.padding.bottom` for everything
/// below, so a screen that already respects the safe area keeps its last row
/// clear of the bar without knowing the bar exists.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final index = shell.currentIndex;
    // Remembered for the pushed pages above us, after this frame — a provider
    // must never be written while the tree that reads it is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(activeBranchProvider.notifier).set(index);
    });

    return Scaffold(
      extendBody: true,
      body: shell,
      // The live order rides ON TOP of the menu, inside the same slot, so
      // Scaffold folds both heights into `padding.bottom` and every page keeps
      // its last row clear of the pair without knowing either exists.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveOrderBar(),
          // The basket sits closest to the menu, under the order already on
          // its way: one is what you are building, the other is what is
          // already coming, and the nearer thumb belongs to the one you are
          // still adding to.
          const ExpressCartBar(),
          GlassNavBar(
            index: index,
            onSelect: (target) {
              Haptics.light();
              // Tapping the active tab pops that branch to its root — the
              // expected "take me back to the top" gesture.
              shell.goBranch(target, initialLocation: target == index);
            },
          ),
        ],
      ),
    );
  }
}

/// The same floating bar, carried by a page that is **not** a tab.
///
/// The owner's rule: the main menu travels with the customer everywhere. A
/// product, a brand, the wishlist, an order — none of them are dead ends any
/// more; the four destinations stay one thumb away, and the icon they came
/// from stays lit so "back to the shop" is a single tap rather than a guess
/// at how many pages deep they are.
///
/// It wraps rather than replaces the page: the inner screen keeps its own
/// Scaffold, and `extendBody` hands it the bar's height as bottom padding, so
/// a sticky add-to-cart row settles above the glass instead of under it.
class NavChrome extends ConsumerWidget {
  const NavChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(activeBranchProvider);

    // A raised keyboard owns the bottom of the screen. Floating the menu over
    // it would hide the very field being typed into, so the bar stands down
    // and the page gets the whole height back — search, in particular, needs
    // its last suggestions reachable while typing.
    //
    // The bar is dropped, never the wrapper: returning `child` bare here would
    // change the shape of this slot, Flutter would re-inflate the page below
    // it, and the field that raised the keyboard would be destroyed mid-tap.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: true,
      body: Builder(
        // Inside the body, Scaffold has already folded the bar's height into
        // `padding.bottom`. It leaves `viewPadding` alone, though, and that is
        // what Scaffold uses to place a floating action button — so a page
        // with a FAB would tuck it under the glass. Teach the page that the
        // bar is part of its safe area and everything lands above it.
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              viewPadding: mq.viewPadding.copyWith(
                bottom: math.max(mq.viewPadding.bottom, mq.padding.bottom),
              ),
            ),
            child: child,
          );
        },
      ),
      bottomNavigationBar: typing
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LiveOrderBar(),
                GlassNavBar(
                  index: index,
                  onSelect: (target) {
                    Haptics.light();
                    // `go`, not `push`: the tab is a destination, and leaving a
                    // pushed page behind it would strand the customer one
                    // back-swipe from a page they had already finished with.
                    GoRouter.of(context).go(navBranchPaths[target]);
                  },
                ),
              ],
            ),
    );
  }
}
