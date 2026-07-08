import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import 'pressable.dart';

/// A one-tap light/dark switch, styled as a frosted "glass" chip for placement
/// on a coloured hero header (both the manager and owner headers).
///
/// Uses its own [ValueListenableBuilder] so it always reflects the live mode —
/// even if a parent hands it down as a `const` child that Flutter would skip.
/// Tapping sets an explicit light/dark choice (the opposite of the current one).
class ThemeToggleButton extends StatelessWidget {
  final double size;
  const ThemeToggleButton({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppThemeController.modeNotifier,
      builder: (context, _, _) {
        final dark = AppThemeController.isDark;
        return Pressable(
          onTap: () => AppThemeController.setMode(
            dark ? AppThemeMode.light : AppThemeMode.dark,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
            ),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        );
      },
    );
  }
}
