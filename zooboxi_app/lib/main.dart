import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/providers.dart';
import 'core/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warmed up before the first frame so every settings read — language,
  // theme, saved delivery location — is synchronous and nothing flashes the
  // wrong locale on launch.
  final prefs = await SharedPreferences.getInstance();

  // Pre-warms the liquid-glass shaders so the tab bar's first frame is glass,
  // not a stutter while they compile.
  await LiquidGlassWidgets.initialize();

  // Firebase (analytics + push) — before the first frame so the launch itself
  // is measured. A build without the platform config files simply runs
  // without it; PushService and AnalyticsService both check `Firebase.apps`.
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (error) {
    if (kDebugMode) debugPrint('[firebase] not configured: $error');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))],
      child: const ZooboxiApp(),
    ),
  );
}
