import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/haptics.dart';
import 'glass_nav_bar.dart';

/// The four-tab shell. Each branch keeps its own navigation stack, so backing
/// out of a product returns to the list you found it in rather than to Home.
///
/// `extendBody` is what lets the glass bar float: the branch's content runs the
/// full height of the screen and the bar sits over it. Scaffold pays that back
/// by folding the bar's height into `MediaQuery.padding.bottom` for everything
/// below, so a screen that already respects the safe area keeps its last row
/// clear of the bar without knowing the bar exists.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: GlassNavBar(
        index: shell.currentIndex,
        onSelect: (index) {
          Haptics.light();
          // Tapping the active tab pops that branch to its root — the
          // expected "take me back to the top" gesture.
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
      ),
    );
  }
}
