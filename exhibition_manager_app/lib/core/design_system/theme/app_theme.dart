import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import 'theme_controller.dart';

/// Muntajat HUB — App Theme («المتجر», Material 3, RTL-first).
///
/// Shopify-calm defaults for every stock Material widget, built from the
/// current-mode [AppColors] getters: white bars with hairlines, near-black
/// filled actions, outlined inputs with a blue focus ring, flat 12px cards,
/// and native iOS page transitions (with swipe-back).
class AppTheme {
  AppTheme._();

  /// Back-compat alias — callers used `AppTheme.lightTheme`.
  static ThemeData get lightTheme => theme;

  static TextStyle _t(double size, FontWeight w, Color c) => TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
        fontSize: size,
        fontWeight: w,
        color: c,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static ThemeData get theme {
    final dark = AppThemeController.isDark;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final r10 = BorderRadius.circular(10);
    final r12 = BorderRadius.circular(12);

    final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.primary,
      onSecondary: AppColors.textOnPrimary,
      secondaryContainer: AppColors.secondary,
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: AppColors.link,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceVariant,
      surfaceTint: Colors.transparent,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.border,
      outlineVariant: AppColors.borderLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: AppColors.borderLight,

      // ─── Top bar ────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: _t(15, FontWeight.w700, AppColors.textPrimary),
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      ),

      // ─── Buttons ────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: r12),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: _t(15, FontWeight.w600, AppColors.textOnPrimary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: r12),
          textStyle: _t(14, FontWeight.w600, AppColors.textOnPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: r12),
          side: BorderSide(color: dark ? const Color(0xFF4A4A4A) : const Color(0xFFD4D4D4)),
          textStyle: _t(15, FontWeight.w600, AppColors.textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.link,
          shape: RoundedRectangleBorder(borderRadius: r10),
          textStyle: _t(14, FontWeight.w600, AppColors.link),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary, highlightColor: AppColors.secondary),
      ),

      // ─── FAB ────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: _t(15, FontWeight.w600, AppColors.textOnPrimary),
      ),

      // ─── Inputs (Polaris: white field, grey stroke, blue focus) ─
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: AppColors.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: AppColors.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: AppColors.link, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: AppColors.error, width: 2)),
        disabledBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: AppColors.border)),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.textPrimary,
        selectionColor: AppColors.link.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.link,
      ),

      // ─── Card ───────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: r12, side: BorderSide(color: AppColors.borderLight)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: _t(14, FontWeight.w600, AppColors.textPrimary),
        subtitleTextStyle: _t(12.5, FontWeight.w400, AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),

      // ─── Bottom navigation ──────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? AppColors.textPrimary : AppColors.textTertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _t(11, selected ? FontWeight.w600 : FontWeight.w500,
              selected ? AppColors.textPrimary : AppColors.textTertiary);
        }),
      ),

      // ─── Tabs ───────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.textPrimary,
        dividerColor: AppColors.borderLight,
        labelStyle: _t(14, FontWeight.w600, AppColors.textPrimary),
        unselectedLabelStyle: _t(14, FontWeight.w500, AppColors.textSecondary),
      ),

      // ─── Controls ───────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.border),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.transparent),
        side: BorderSide(color: AppColors.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.textPrimary,
        linearTrackColor: AppColors.borderLight,
        circularTrackColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: _t(13, FontWeight.w500, AppColors.textPrimary),
      ),

      // ─── Divider ────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: AppColors.borderLight, thickness: 1, space: 1),

      // ─── SnackBar ───────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF3A3A3A) : const Color(0xFF303030),
        contentTextStyle: _t(14, FontWeight.w500, Colors.white),
        actionTextColor: dark ? const Color(0xFF9CC4FF) : const Color(0xFF9CC4FF),
        shape: RoundedRectangleBorder(borderRadius: r12),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
      ),

      // ─── Sheets & dialogs ───────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: r12, side: BorderSide(color: AppColors.borderLight)),
        textStyle: _t(14, FontWeight.w500, AppColors.textPrimary),
      ),

      // ─── Page transitions: native on iOS (swipe-back) ───────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
