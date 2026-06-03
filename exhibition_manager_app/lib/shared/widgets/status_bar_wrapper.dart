import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/tokens/colors.dart';

/// Wraps a child with an [AnnotatedRegion] that sets the status bar style
/// based on the background color brightness.
///
/// Use this on screens that have a light background (e.g. white scaffold)
/// to ensure status bar icons are dark.
/// Screens with dark backgrounds (e.g. blue AppBar) already get light icons
/// from [MuntajatAppBar].
class StatusBarWrapper extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const StatusBarWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.background;
    final brightness = ThemeData.estimateBrightnessForColor(bg);
    final statusBarIconBrightness =
        brightness == Brightness.dark ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: brightness,
      ),
      child: child,
    );
  }
}
