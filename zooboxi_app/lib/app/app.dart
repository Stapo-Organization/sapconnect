import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/events_buffer.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';

class ZooboxiApp extends ConsumerStatefulWidget {
  const ZooboxiApp({super.key});

  @override
  ConsumerState<ZooboxiApp> createState() => _ZooboxiAppState();
}

class _ZooboxiAppState extends ConsumerState<ZooboxiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding is the last reliable moment to ship queued behaviour —
    // the process may not come back.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ref.read(eventsBufferProvider).flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(routerProvider);
    final locale = settings.effectiveLocale;

    return MaterialApp.router(
      onGenerateTitle: (context) => L.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.themeMode,
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      locale: settings.locale,
      // Arabic first: a device set to an unsupported language lands on the
      // product's primary language rather than on English.
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: L.localizationsDelegates,
      builder: (context, child) {
        // Clamp text scaling: commerce cards have fixed geometry, and beyond
        // ~1.3 the price and the add button start colliding.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
