import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/characters/characters.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/onboarding/presentation/splash/splash_plan.dart';
import 'package:zooboxi_app/features/onboarding/presentation/splash/splash_stage.dart';
import 'package:zooboxi_app/features/onboarding/presentation/splash_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The splash plays over the navigator and uncovers the screen the boot route
/// sent the app to. What is locked here: which story plays for whom, that the
/// story ends and comes down on its own, and that the app underneath keeps
/// its route (the stage must never re-parent the navigator).

class _StubSession extends SessionController {
  @override
  Future<void> restore() async {}
}

Finder _assetImage(String name) => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == name,
      description: 'Image($name)',
    );

Future<(ProviderContainer, GoRouter)> _boot(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool still = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = LocalStore(await SharedPreferences.getInstance());
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/onboarding', builder: (_, _) => const Scaffold(body: Text('WELCOME'))),
    ],
  );
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        sessionProvider.overrideWith(_StubSession.new),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(
            locale: const Locale('ar'),
            theme: AppTheme.light(const Locale('ar')),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: still),
              child: SplashStage(child: child!),
            ),
          );
        },
      ),
    ),
  );
  return (container, router);
}

/// Pumps through the intro, the hand-off and the exit, frame by frame.
Future<void> _playThrough(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('first launch: the burst, then the welcome journey uncovered', (tester) async {
    final (container, router) = await _boot(tester);
    await tester.pump();

    expect(container.read(splashPlanProvider), isA<BurstPlan>());
    // The first frame is the launch picture: the whole logo, launch size.
    final logo = tester.widgetList<Image>(_assetImage(SplashFrame.logo)).first;
    expect(logo.width, SplashFrame.logoWidth);

    await _playThrough(tester);

    expect(tester.takeException(), isNull);
    expect(container.read(splashControllerProvider).phase, SplashPhase.gone);
    expect(container.read(splashControllerProvider).flyToSign, isFalse);
    expect(router.state.matchedLocation, '/onboarding');
    expect(find.text('WELCOME'), findsOneWidget);
  });

  testWidgets('a returning customer is greeted by their own animal, by name', (tester) async {
    final (container, router) = await _boot(
      tester,
      prefs: {
        'settings.onboarded.v2': true,
        'splash.companion': '{"cast":"cat","name":"لولو"}',
      },
    );
    await tester.pump();
    expect(container.read(splashPlanProvider), isA<HelloPlan>());

    // Mid-intro: the waving cat and its name are up.
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_assetImage(stickerAsset('cat-wave')), findsOneWidget);
    expect(find.text('لولو بانتظارك'), findsOneWidget);

    await _playThrough(tester);
    expect(tester.takeException(), isNull);
    expect(container.read(splashControllerProvider).phase, SplashPhase.gone);
    expect(container.read(splashControllerProvider).flyToSign, isTrue);
    expect(router.state.matchedLocation, '/home');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a single-pose species greets with its one drawing', (tester) async {
    final (container, _) = await _boot(
      tester,
      prefs: {
        'settings.onboarded.v2': true,
        'splash.companion': '{"cast":"budgie","name":""}',
      },
    );
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_assetImage(stickerAsset('budgie')), findsOneWidget);
    expect(find.text('أهلاً من جديد'), findsOneWidget);
    await _playThrough(tester);
    expect(container.read(splashControllerProvider).phase, SplashPhase.gone);
  });

  testWidgets('Reduce Motion: the launch picture, then a plain fade', (tester) async {
    final (container, router) = await _boot(
      tester,
      prefs: {'splash.companion': '{"cast":"dog","name":"كوكي"}'},
      still: true,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SplashBackdrop), findsWidgets);
    expect(_assetImage(stickerAsset('dog-wave')), findsNothing);
    await _playThrough(tester);
    expect(container.read(splashControllerProvider).phase, SplashPhase.gone);
    expect(router.state.matchedLocation, '/onboarding');
  });

  test('an unreadable or unknown companion falls back to the burst', () {
    expect(SplashCompanion.fromJson(null), isNull);
    expect(SplashCompanion.fromJson({'cast': 'dragon'}), isNull);
    expect(
      SplashCompanion.fromJson({'cast': 'dog', 'name': ' كوكي '}),
      const SplashCompanion(cast: ZbCast.dog, name: 'كوكي'),
    );
  });
}
