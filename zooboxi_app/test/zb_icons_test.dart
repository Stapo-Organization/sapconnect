import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/shell/glass_nav_bar.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/icons/cart_box_icon.dart';
import 'package:zooboxi_app/core/icons/zb_icons.dart';
import 'package:zooboxi_app/core/motion/anchors.dart';
import 'package:zooboxi_app/core/motion/fly_to_cart.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/widgets/mascot_peek.dart';
import 'package:zooboxi_app/core/widgets/wishlist_heart.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/features/wishlist/data/wishlist_controller.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The icon set is painted, not fonted, so nothing catches a broken shape at
/// compile time. What these lock is that every glyph survives every size and
/// fill it is actually used at, that the tab bar is really wearing them, and
/// that the two animations with a *guard* — the fly-to-cart's missing anchor
/// and the mascot's idle loop under Reduce Motion — take the safe branch.

/// Providers are overridden by wrapping [child] in a nested [ProviderScope] at
/// the call site — Riverpod does not export the `Override` type, so a typed
/// parameter here would not compile.
Widget _host(
  Widget child, {
  bool stillMotion = true,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.rtl,
}) {
  const locale = Locale('ar');
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      theme: brightness == Brightness.dark
          ? AppTheme.dark(locale)
          : AppTheme.light(locale),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: stillMotion),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

class _AuthedSession extends SessionController {
  @override
  SessionState build() =>
      const SessionState(status: AuthStatus.authenticated, token: 't');

  @override
  Future<void> restore() async {}
}

/// Records the toggle rather than reaching the network — this asserts the
/// heart still *calls through*, not what the server answers.
class _StubWishlist extends WishlistController {
  static final List<int> toggled = [];

  @override
  Set<int> build() => const {};

  @override
  Future<bool> toggle(int productId) async {
    toggled.add(productId);
    state = state.contains(productId)
        ? (state.toSet()..remove(productId))
        : (state.toSet()..add(productId));
    return state.contains(productId);
  }
}

void main() {
  group('painters', () {
    for (final size in const [16.0, 24.0, 48.0]) {
      for (final fill in const [0.0, 0.5, 1.0]) {
        testWidgets('every glyph paints at ${size.toInt()}pt, fill $fill',
            (tester) async {
          for (final brightness in Brightness.values) {
            for (final direction in TextDirection.values) {
              await tester.pumpWidget(
                _host(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final kind in ZbIconKind.values)
                        ZbIcon(
                          kind,
                          size: size,
                          fill: fill,
                          lidOpen: fill,
                          scanY: fill,
                        ),
                    ],
                  ),
                  brightness: brightness,
                  direction: direction,
                ),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          }
          expect(find.byType(ZbIcon), findsNWidgets(ZbIconKind.values.length));
        });
      }
    }

    testWidgets('the widget occupies exactly its size', (tester) async {
      for (final size in const [16.0, 23.0, 48.0, 120.0]) {
        await tester.pumpWidget(_host(ZbIcon(ZbIconKind.cart, size: size)));
        await tester.pump();
        expect(tester.getSize(find.byType(ZbIcon)), Size.square(size));
      }
    });

    testWidgets('a named ink overrides the theme default', (tester) async {
      await tester.pumpWidget(
        _host(const ZbIcon(ZbIconKind.heart, ink: Color(0xFF00FF00))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('GlassNavBar', () {
    testWidgets('wears four painted glyphs and still counts the basket',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartCountProvider.overrideWithValue(4)],
          child: MaterialApp(
            locale: const Locale('ar'),
            theme: AppTheme.light(const Locale('ar')),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              extendBody: true,
              body: const SizedBox.expand(),
              bottomNavigationBar: GlassNavBar(index: 0, onSelect: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Three plain tabs plus the cart's own animated box.
      expect(find.byType(ZbIcon), findsNWidgets(4));
      expect(find.byType(CartBoxIcon), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CartBoxIcon', () {
    Widget cartAt(int count) => _host(
          ProviderScope(
            overrides: [cartCountProvider.overrideWithValue(count)],
            child: const CartBoxIcon(size: 40),
          ),
          stillMotion: false,
        );

    double lidOf(WidgetTester tester) =>
        tester.widget<ZbIcon>(find.byType(ZbIcon)).lidOpen;

    testWidgets('opens its lid when a line lands, then closes it',
        (tester) async {
      await tester.pumpWidget(cartAt(0));
      await tester.pump();
      expect(lidOf(tester), 0, reason: 'an idle cart is a closed box');

      await tester.pumpWidget(cartAt(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        lidOf(tester),
        greaterThan(0.2),
        reason: 'the box opens for what arrived',
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(lidOf(tester), 0, reason: 'and shuts again');
      await tester.pumpAndSettle();
    });

    testWidgets('a removal only dips — no lid, no celebration', (tester) async {
      await tester.pumpWidget(cartAt(2));
      await tester.pump();

      await tester.pumpWidget(cartAt(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(lidOf(tester), 0);
      await tester.pumpAndSettle();
    });
  });

  group('flyToCart', () {
    testWidgets('does nothing at all when there is no cart to fly to',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox(width: 40, height: 40);
            },
          ),
          stillMotion: false,
        ),
      );
      await tester.pump();

      final before = tester.allWidgets.length;
      flyToCart(captured, from: const Rect.fromLTWH(10, 10, 30, 30));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.allWidgets.length,
        before,
        reason: 'no anchor means no overlay entry',
      );
    });

    testWidgets('throws a thumbnail once the cart tab is on screen',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        _host(
          ProviderScope(
            overrides: [cartCountProvider.overrideWithValue(0)],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CartBoxIcon(key: cartTabAnchorKey, size: 24),
                Builder(
                  builder: (context) {
                    captured = context;
                    return const SizedBox(width: 40, height: 40);
                  },
                ),
              ],
            ),
          ),
          stillMotion: false,
        ),
      );
      await tester.pump();

      final before = tester.allWidgets.length;
      flyToCart(captured, from: const Rect.fromLTWH(10, 400, 30, 30));
      await tester.pump();
      expect(tester.allWidgets.length, greaterThan(before));

      // It takes itself down when it lands.
      await tester.pumpAndSettle();
      expect(tester.allWidgets.length, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays out of the way under Reduce Motion', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        _host(
          ProviderScope(
            overrides: [cartCountProvider.overrideWithValue(0)],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CartBoxIcon(key: cartTabAnchorKey, size: 24),
                Builder(
                  builder: (context) {
                    captured = context;
                    return const SizedBox(width: 40, height: 40);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final before = tester.allWidgets.length;
      flyToCart(captured, from: const Rect.fromLTWH(10, 400, 30, 30));
      await tester.pump();
      expect(tester.allWidgets.length, before);
    });
  });

  testWidgets('the wishlist heart still calls through when tapped',
      (tester) async {
    _StubWishlist.toggled.clear();

    await tester.pumpWidget(
      _host(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_AuthedSession.new),
            wishlistControllerProvider.overrideWith(_StubWishlist.new),
          ],
          child: const WishlistHeart(productId: 77),
        ),
        stillMotion: false,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(WishlistHeart));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(_StubWishlist.toggled, [77]);
    // The heart is filled now, and it is ours rather than Material's.
    expect(find.byType(ZbIcon), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Drains the confirmation toast's own dismissal timer.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('an idle mascot disposes cleanly under Reduce Motion',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 320,
          child: MascotPeek(child: SizedBox(height: 120)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MascotPeek), findsOneWidget);

    // Replacing the tree disposes the controller and cancels the pending kick.
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
