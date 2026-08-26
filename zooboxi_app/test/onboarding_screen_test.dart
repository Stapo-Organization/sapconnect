import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/settings/app_settings.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/notifications/notify_permission.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The welcome journey is the only screen every customer sees exactly once, so
/// the things that must never regress are: both languages offered and the
/// choice switching the app on the spot, the three steps actually walking
/// forward, and the last step marking the journey done — because a flag that
/// doesn't stick means the store greets a returning customer as a stranger.

const Key _homeKey = Key('test-home');

late LocalStore _store;

/// A device that already knows where it is — the upgrade install, which must
/// be congratulated rather than asked again.
class _PresetLocation extends LocationController {
  @override
  LocationState build() => const LocationState(
        location: ZbLocation(
          city: 'الرياض',
          district: 'النرجس',
          promiseLabel: 'خلال ساعتين',
        ),
      );
}

/// Mirrors `ZooboxiApp`: the locale the settings controller holds is what the
/// whole tree is localized with. Without that wiring the language cards would
/// only be tested against a fixture instead of against the real switch.
class _Host extends ConsumerWidget {
  const _Host({required this.router, required this.textScale});

  final GoRouter router;
  final double textScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      routerConfig: router,
      locale: settings.locale,
      theme: AppTheme.light(settings.effectiveLocale),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  bool locationKnown = false,
  Size size = const Size(900, 2000),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(_store),
        if (locationKnown) locationProvider.overrideWith(_PresetLocation.new),
      ],
      child: _Host(
        textScale: textScale,
        router: GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(key: _homeKey, body: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Stands in for the iOS side of `zb/notify` and records what was asked.
/// Without a handler the reply lands outside the test's fake clock, so the
/// button would spin forever — the platform has to be faked, not absent.
List<String> _mockNotifyChannel(bool granted) {
  const channel = MethodChannel('zb/notify');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final asked = <String>[];

  messenger.setMockMethodCallHandler(channel, (call) async {
    asked.add(call.method);
    return call.method == 'request' ? granted : 'undetermined';
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return asked;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Pinned rather than left to the host platform: the point of the first
    // test is the *switch*, which needs a known starting language.
    SharedPreferences.setMockInitialValues({'settings.locale': 'ar'});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  testWidgets('the welcome step offers both languages and switches on the spot',
      (tester) async {
    await _pump(tester);

    expect(find.text('حيّاك الله في زوبوكسي'), findsOneWidget);
    expect(find.text('بأي لغة تحب نخدمك؟'), findsOneWidget);
    expect(find.text('يلا نبدأ'), findsOneWidget);
    // A language is always written in its own language — that is the one pair
    // of strings on this screen that must never be translated.
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await _tap(tester, 'English');

    expect(find.text('Welcome to Zooboxi'), findsOneWidget);
    expect(find.text("Let's go"), findsOneWidget);
    expect(find.text('حيّاك الله في زوبوكسي'), findsNothing);
    expect(find.text('العربية'), findsOneWidget, reason: 'the cards stay in their own script');
    expect(find.text('English'), findsOneWidget);
    expect(_store.localeCode, 'en', reason: 'the choice is persisted, not just painted');

    await _tap(tester, 'العربية');

    expect(find.text('حيّاك الله في زوبوكسي'), findsOneWidget);
    expect(_store.localeCode, 'ar');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the journey walks welcome → location → notifications', (tester) async {
    await _pump(tester);

    await _tap(tester, 'يلا نبدأ');

    expect(find.text('وين نوصّلك؟'), findsOneWidget);
    expect(find.text('حدد موقعي على الخريطة'), findsOneWidget);
    expect(find.text('أختار مدينتي بنفسي'), findsOneWidget);

    await _tap(tester, 'لاحقًا');

    expect(find.text('خلّك أول من يعرف'), findsOneWidget);
    expect(find.text('فعّل الإشعارات'), findsOneWidget);
    expect(find.text('طلبك في الطريق 🚚'), findsOneWidget, reason: 'the ask is shown, not described');
    expect(_store.hasSeenWelcome, isFalse, reason: 'nothing is marked until the last step');
    expect(tester.takeException(), isNull);
  });

  testWidgets('«لاحقًا» on the last step marks the journey done and opens the store',
      (tester) async {
    await _pump(tester);
    await _tap(tester, 'يلا نبدأ');
    await _tap(tester, 'لاحقًا');
    await _tap(tester, 'لاحقًا');

    expect(_store.hasSeenWelcome, isTrue);
    expect(find.byKey(_homeKey), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // "No" is a valid answer: it must open the store exactly like "yes" does,
  // and it must be asked over the channel the app delegate actually answers.
  for (final granted in const [true, false]) {
    testWidgets('the notification step finishes on granted=$granted', (tester) async {
      final asked = _mockNotifyChannel(granted);

      await _pump(tester);
      await _tap(tester, 'يلا نبدأ');
      await _tap(tester, 'لاحقًا');
      await _tap(tester, 'فعّل الإشعارات');

      expect(asked, ['request'], reason: 'asked once, on zb/notify');
      expect(_store.hasSeenWelcome, isTrue);
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a device that already has a location is confirmed, not re-asked',
      (tester) async {
    await _pump(tester, locationKnown: true);
    await _tap(tester, 'يلا نبدأ');

    expect(find.text('وصلناك!'), findsOneWidget);
    expect(find.text('النرجس، الرياض'), findsOneWidget);
    expect(find.text('خلال ساعتين'), findsOneWidget);
    expect(find.text('استمرار'), findsOneWidget);
    expect(find.text('حدد موقعي على الخريطة'), findsNothing, reason: 'we already know');

    await _tap(tester, 'استمرار');

    expect(find.text('خلّك أول من يعرف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Three fixed-height pills carrying live copy in two languages on the
  // smallest phone the store supports — exactly the shape that clips when
  // someone turns their font size up.
  for (final scale in const [1.0, 1.3]) {
    for (final code in const ['ar', 'en']) {
      testWidgets('all three steps survive a small screen at scale $scale, $code',
          (tester) async {
        SharedPreferences.setMockInitialValues({'settings.locale': code});
        _store = LocalStore(await SharedPreferences.getInstance());

        await _pump(tester, size: const Size(320, 640), textScale: scale);
        expect(tester.takeException(), isNull);

        await _tap(tester, code == 'ar' ? 'يلا نبدأ' : "Let's go");
        expect(tester.takeException(), isNull);

        await _tap(tester, code == 'ar' ? 'لاحقًا' : 'Later');
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('the permission wrapper answers instead of throwing without a platform',
      () async {
    expect(await NotifyPermission.request(), isFalse);
    expect(await NotifyPermission.status(), 'undetermined');
  });
}
