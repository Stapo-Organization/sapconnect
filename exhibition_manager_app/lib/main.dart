import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/design_system/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'features/auth/presentation/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved language setting
  await AppLocalizations.initialize();
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Status bar will be managed per-screen via AnnotatedRegion
  // Default to light icons for splash screen
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MuntajatExhibitionApp());
}

class MuntajatExhibitionApp extends StatelessWidget {
  const MuntajatExhibitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocalizations.localeNotifier,
      builder: (context, currentLocale, _) {
        final isArabic = currentLocale.languageCode == 'ar';
        return MaterialApp(
          title: isArabic ? 'مدير المعرض' : 'Muntajat Exhibition',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: currentLocale,
          builder: (context, child) {
            // LocaleScope sits above the Navigator so every route (even ones
            // already pushed) that reads text via context.tr rebuilds when the
            // language changes — not just the global text direction.
            return LocaleScope(
              locale: currentLocale,
              child: Directionality(
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              ),
            );
          },
          home: const SplashPage(),
        );
      },
    );
  }
}

