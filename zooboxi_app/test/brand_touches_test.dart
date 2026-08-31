import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/core/widgets/empty_state.dart';
import 'package:zooboxi_app/core/widgets/mascot_peek.dart';
import 'package:zooboxi_app/core/widgets/sparkles.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/features/checkout/data/checkout_models.dart';
import 'package:zooboxi_app/features/checkout/presentation/success_screen.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/home_header.dart';
import 'package:zooboxi_app/features/onboarding/presentation/splash_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The logo touches are decorative, so nothing here asserts pixels. What it
/// locks is that each touch is actually *mounted* — a missing asset path or a
/// dropped flag would otherwise ship silently, since no test would fail and
/// no screen would break.

const String _logo = 'assets/brand/logo_full.png';

late LocalStore _store;

/// The keychain is a platform channel, and the splash's first act is to read
/// it. Stubbing `restore` keeps the screen under test instead of the plugin.
class _StubSession extends SessionController {
  @override
  Future<void> restore() async {}
}

/// The success screen fires `purchase` on mount; the buffer is stubbed so the
/// test doesn't queue a network flush.
class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

Finder _assetImage(String name) => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == name,
      description: 'Image($name)',
    );

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  const locale = Locale('ar');
  return ProviderScope(
    overrides: [localStoreProvider.overrideWithValue(_store)],
    child: MaterialApp(
      locale: locale,
      theme: brightness == Brightness.dark ? AppTheme.dark(locale) : AppTheme.light(locale),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  group('Sparkle', () {
    for (final size in [8.0, 24.0]) {
      testWidgets('paints at ${size.toInt()}pt', (tester) async {
        await tester.pumpWidget(
          _host(const Center(child: Sparkle(size: 8, color: Colors.amber))),
        );
        await tester.pumpWidget(
          _host(Center(child: Sparkle(size: size, color: Colors.teal, rotation: 0.4))),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(Sparkle), findsOneWidget);
      });
    }

    testWidgets('a field places every spec and stays untappable', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            height: 200,
            child: SparkleField(
              twinkle: true,
              sparkles: [
                SparkleSpec(dx: 0.1, dy: 0.2, size: 12, color: Colors.amber),
                SparkleSpec(dx: 0.9, dy: 0.8, size: 16, color: Colors.teal),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Sparkle), findsNWidgets(2));
      expect(find.byType(IgnorePointer), findsWidgets);
    });
  });

  group('EmptyState mascot', () {
    testWidgets('renders the peek image on a card', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.shopping_bag_rounded,
            title: 'فاضية',
            message: 'ابدأ التسوق',
            mascot: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MascotPeek), findsOneWidget);
      expect(_assetImage(MascotPeek.asset), findsOneWidget);
      expect(find.text('فاضية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card scrolls rather than overflowing a short screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'ما عندك طلبات',
            message: 'أول طلب يبدأ من هنا',
            actionLabel: 'تسوّق',
            mascot: true,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MascotPeek), findsOneWidget);
    });

    testWidgets('compact ignores the mascot — there is no room for it', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'ما فيه نتائج',
            message: 'جرّب كلمة ثانية',
            mascot: true,
            compact: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MascotPeek), findsNothing);
      expect(_assetImage(MascotPeek.asset), findsNothing);
      expect(find.text('ما فيه نتائج'), findsOneWidget);
    });

    testWidgets('the dark card fill is the surface, not cream', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.shopping_bag_rounded,
            title: 'فاضية',
            message: 'ابدأ التسوق',
            mascot: true,
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MascotPeek), findsOneWidget);
    });

    testWidgets('off by default', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'المفضلة فاضية',
            message: 'أضف منتجات',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MascotPeek), findsNothing);
    });
  });

  group('HomeHeader logo sticker', () {
    for (final onCanvas in [false, true]) {
      // 360pt is the narrowest phone the store sees; the sticker must not
      // squeeze the location chip off the row there.
      for (final width in [360.0, 900.0]) {
        testWidgets('renders at ${width.toInt()}pt with onCanvas=$onCanvas',
            (tester) async {
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_host(HomeHeader(onCanvas: onCanvas)));
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(_assetImage(_logo), findsOneWidget);
        });
      }
    }
  });

  testWidgets('checkout success bursts sparkles and peeks over the receipt',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(_store),
          eventsBufferProvider.overrideWithValue(_SilentEvents()),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          theme: AppTheme.light(const Locale('ar')),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const CheckoutSuccessScreen(
            order: PlacedOrder(
              orderId: 1,
              orderNumber: 'ZB-1',
              orderKey: 'k',
              status: 'processing',
              total: 120,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SparkleField), findsOneWidget);
    expect(_assetImage(MascotPeek.asset), findsOneWidget);
  });

  testWidgets('the splash shows the full logo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(_store),
          sessionProvider.overrideWith(_StubSession.new),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          theme: AppTheme.light(const Locale('ar')),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
              GoRoute(
                path: '/onboarding',
                builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_assetImage(_logo), findsOneWidget);
    expect(find.byType(SparkleField), findsOneWidget);

    // Drains the minimum-splash timer so the boot hand-off doesn't outlive
    // the test.
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
