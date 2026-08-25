import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'zb_colors.dart';
import 'zooboxi_tokens.dart';

/// The app's Material 3 themes.
///
/// Two rules hold everywhere:
///
/// 1. **Every** text style lists `SaudiRiyal` in `fontFamilyFallback`. The new
///    Saudi Riyal symbol lives at U+E900 (private-use area) in that bundled
///    one-glyph font, so any `Text` containing it renders ﷼ inline — in both
///    languages, at every size, without a separate widget.
/// 2. Type family follows the *content* language, not the device: Tajawal for
///    Arabic (it has real Arabic weights), Manrope for English.
abstract final class AppTheme {
  /// The one-glyph Riyal font, appended to every style's fallback chain.
  static const List<String> riyalFallback = ['SaudiRiyal'];

  static ThemeData light(Locale locale) => _build(locale, Brightness.light);
  static ThemeData dark(Locale locale) => _build(locale, Brightness.dark);

  // ── Color schemes ────────────────────────────────────────────────────

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: ZbTokens.teal,
    onPrimary: Colors.white,
    primaryContainer: ZbTokens.tealTint,
    onPrimaryContainer: ZbTokens.tealDeep,
    secondary: ZbTokens.coral,
    onSecondary: Colors.white,
    secondaryContainer: ZbTokens.peach,
    onSecondaryContainer: ZbTokens.coralDark,
    tertiary: ZbTokens.amber,
    onTertiary: ZbTokens.ink,
    tertiaryContainer: Color(0xFFFDF2D2),
    onTertiaryContainer: Color(0xFF6B5200),
    error: ZbTokens.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFDE7E7),
    onErrorContainer: Color(0xFF8C1D21),
    surface: ZbTokens.paper,
    onSurface: ZbTokens.ink,
    onSurfaceVariant: ZbTokens.inkSoft,
    surfaceDim: Color(0xFFE9ECEA),
    surfaceBright: ZbTokens.paper,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFBFCFB),
    surfaceContainer: ZbTokens.canvasLight,
    surfaceContainerHigh: Color(0xFFF1F4F2),
    surfaceContainerHighest: Color(0xFFEAEEEC),
    outline: Color(0xFFC4CCC6),
    outlineVariant: ZbTokens.line,
    inverseSurface: Color(0xFF23302A),
    onInverseSurface: Color(0xFFF3F6F4),
    inversePrimary: ZbTokens.tealOnDark,
    shadow: Color(0xFF0D1512),
    scrim: Color(0xFF000000),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: ZbTokens.tealOnDark,
    onPrimary: Color(0xFF00312F),
    primaryContainer: ZbTokens.tealContainerDark,
    onPrimaryContainer: Color(0xFFB6E9E7),
    secondary: ZbTokens.coralOnDark,
    onSecondary: Color(0xFF3A130C),
    secondaryContainer: ZbTokens.coralContainerDark,
    onSecondaryContainer: Color(0xFFFFD9D0),
    tertiary: ZbTokens.amberOnDark,
    onTertiary: Color(0xFF3B2E00),
    tertiaryContainer: Color(0xFF453702),
    onTertiaryContainer: Color(0xFFFBE3A6),
    error: ZbTokens.errorOnDark,
    onError: Color(0xFF48090C),
    errorContainer: Color(0xFF5C1418),
    onErrorContainer: Color(0xFFFFDAD9),
    surface: ZbTokens.graphite,
    onSurface: ZbTokens.inkDark,
    onSurfaceVariant: ZbTokens.inkSoftDark,
    surfaceDim: ZbTokens.graphite,
    surfaceBright: Color(0xFF353D3A),
    surfaceContainerLowest: Color(0xFF0C100F),
    surfaceContainerLow: Color(0xFF161B1A),
    surfaceContainer: ZbTokens.graphiteRaised,
    surfaceContainerHigh: ZbTokens.graphiteHigh,
    surfaceContainerHighest: ZbTokens.graphiteHighest,
    outline: Color(0xFF4A5350),
    outlineVariant: ZbTokens.lineDark,
    inverseSurface: Color(0xFFE8EDEA),
    onInverseSurface: Color(0xFF1A201E),
    inversePrimary: ZbTokens.tealDark,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // ── Typography ───────────────────────────────────────────────────────

  /// Builds the text theme for [locale], with the Riyal glyph appended to
  /// every style's fallback chain.
  static TextTheme _textTheme(Locale locale, ColorScheme cs) {
    final base = _baseTypography(cs);
    final isArabic = locale.languageCode == 'ar';
    final family = isArabic
        ? GoogleFonts.tajawalTextTheme(base)
        : GoogleFonts.manropeTextTheme(base);

    return family.apply(
      fontFamilyFallback: riyalFallback,
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );
  }

  /// Sizes/weights first, family second — so switching language never shifts
  /// the layout. Slightly tighter than M3 defaults: commerce screens are dense.
  static TextTheme _baseTypography(ColorScheme cs) {
    const even = TextLeadingDistribution.even;
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -0.8, leadingDistribution: even),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6, leadingDistribution: even),
      displaySmall: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4, leadingDistribution: even),
      headlineLarge: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3, leadingDistribution: even),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.28, letterSpacing: -0.2, leadingDistribution: even),
      headlineSmall: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3, leadingDistribution: even),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.35, leadingDistribution: even),
      titleMedium: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.4, leadingDistribution: even),
      titleSmall: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4, leadingDistribution: even),
      bodyLarge: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400, height: 1.55, leadingDistribution: even),
      bodyMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.55, leadingDistribution: even),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, leadingDistribution: even),
      labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3, leadingDistribution: even),
      labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3, leadingDistribution: even),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.3, leadingDistribution: even),
    );
  }

  // ── ThemeData ────────────────────────────────────────────────────────

  static ThemeData _build(Locale locale, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final cs = dark ? _darkScheme : _lightScheme;
    final text = _textTheme(locale, cs);
    final zb = dark ? ZbColors.dark : ZbColors.light;
    final canvas = dark ? ZbTokens.graphite : ZbTokens.canvasLight;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: brightness,
      textTheme: text,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      // Belt-and-braces: any style that slips past `textTheme` (a raw
      // `TextStyle()` in a widget) still resolves the Riyal glyph.
      fontFamilyFallback: riyalFallback,
      splashFactory: InkSparkle.splashFactory,
      extensions: [zb],
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      cardTheme: CardThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),

      // Pill-ish 14 radius on every button family.
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(text)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(text).copyWith(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(cs.surface),
          foregroundColor: WidgetStatePropertyAll(cs.onSurface),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(text).copyWith(
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? cs.outlineVariant : cs.outline,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZbTokens.rMd)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? ZbTokens.graphiteHigh : cs.surfaceContainerHigh,
        hintStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        floatingLabelStyle: text.labelMedium?.copyWith(color: cs.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(cs.primary, width: 1.6),
        errorBorder: _inputBorder(cs.error),
        focusedErrorBorder: _inputBorder(cs.error, width: 1.6),
        disabledBorder: _inputBorder(Colors.transparent),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        selectedColor: cs.primaryContainer,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: cs.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? ZbTokens.graphiteRaised : cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall!.copyWith(
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? ZbTokens.graphiteRaised : cs.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? ZbTokens.graphiteRaised : cs.surface,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: cs.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ZbTokens.rXl)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: dark ? ZbTokens.graphiteRaised : cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZbTokens.rXl)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),

      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZbTokens.rMd)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZbTokens.rMd)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceContainerHighest,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(ZbTokens.rXs),
        ),
        textStyle: text.bodySmall?.copyWith(color: cs.onInverseSurface),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ButtonStyle _buttonStyle(TextTheme text) => FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZbTokens.rMd)),
        elevation: 0,
      );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        borderSide: BorderSide(color: color, width: width),
      );
}
