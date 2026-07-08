import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/design_system/theme/app_theme.dart';
import 'core/design_system/theme/theme_controller.dart';
import 'core/localization/app_localizations.dart';
import 'core/notifications/push_service.dart';
import 'features/auth/presentation/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locale + theme choice are the only things needed before the first frame.
  await AppLocalizations.initialize();
  await AppThemeController.initialize();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Status bar will be managed per-screen via AnnotatedRegion
  // Default to light icons for splash screen
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Render the UI immediately — never block the first frame on Firebase or the
  // network. Push init runs in the background; any failure stays silent.
  runApp(const MuntajatExhibitionApp());
  unawaited(_initFirebase());
}

/// Firebase / FCM bootstrap — runs after the first frame so a slow or failed
/// init can never leave the app stuck on a blank launch screen.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.instance.init();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }
}

class MuntajatExhibitionApp extends StatefulWidget {
  const MuntajatExhibitionApp({super.key});

  @override
  State<MuntajatExhibitionApp> createState() => _MuntajatExhibitionAppState();
}

class _MuntajatExhibitionAppState extends State<MuntajatExhibitionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Rebuild when the OS light/dark setting changes (matters for "system" mode)…
    WidgetsBinding.instance.addObserver(this);
    // …and when the user picks a mode in-app.
    AppThemeController.modeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppThemeController.modeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the effective brightness BEFORE building, so every AppColors
    // getter read during this frame serves the correct (light/dark) palette.
    AppThemeController.resolve(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocalizations.localeNotifier,
      builder: (context, currentLocale, _) {
        final isArabic = currentLocale.languageCode == 'ar';
        return MaterialApp(
          title: 'Muntajat HUB',
          debugShowCheckedModeBanner: false,
          navigatorKey: PushService.navigatorKey,
          theme: AppTheme.theme,
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

