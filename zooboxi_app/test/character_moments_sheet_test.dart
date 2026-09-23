// Review sheet for the characters' moments — regenerate with
//   flutter test test/character_moments_sheet_test.dart --update-goldens
// and LOOK at test/goldens/character_moments_sheet.png before shipping a change
// to a scene: placement is the whole point of these, and no assertion sees it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/characters/scenes.dart';
import 'package:zooboxi_app/core/network/api_exception.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/core/widgets/empty_state.dart';
import 'package:zooboxi_app/core/widgets/error_state.dart';
import 'package:zooboxi_app/core/widgets/rail.dart';
import 'package:zooboxi_app/core/widgets/section_header.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_interlude.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/cart/presentation/widgets/free_shipping_bar.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/checkout/data/checkout_models.dart';
import 'package:zooboxi_app/features/checkout/presentation/success_screen.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_asleep_band.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}

  @override
  Future<void> flush() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _w = 393.0;
const _h = 800.0;

Widget _panel(String label, Widget child, {Color? bg}) => SizedBox(
      width: _w,
      height: _h + 28,
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Center(
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
            ),
          ),
          Container(width: _w, height: _h, color: bg ?? const Color(0xFFF8F9F7), child: child),
        ],
      ),
    );

void main() {
  setUpAll(loadBrandFonts);

  testWidgets('character moments sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    const cols = 5;
    const rows = 3;
    tester.view.physicalSize = const Size(_w * cols * 1.5, (_h + 28) * rows * 1.5);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);

    final panels = <Widget>[
      _panel(
        'المفضّلة',
        const EmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'مفضّلتك تنتظر أول قلب',
          message: 'اضغط ♥ على أي منتج يعجبك، ونحفظه لك هنا لين ترجع له.',
          actionLabel: 'ابدأ التسوق',
          onAction: _noop,
          scene: WishlistScene(),
        ),
      ),
      _panel(
        'السلة',
        const EmptyState(
          icon: Icons.shopping_bag_rounded,
          title: 'الصحن فاضي… والسلة كمان',
          message: 'أضف ما يحتاجه صديقك الأليف وسنوصله إليك.',
          actionLabel: 'ابدأ التسوق',
          onAction: _noop,
          scene: CartScene(),
        ),
      ),
      _panel(
        'بحث بلا نتائج',
        const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'لا توجد نتائج',
          message: 'جرّب كلمة أقصر أو تصفّح الأقسام.',
          scene: SearchScene(query: 'كيتي ليتر'),
        ),
      ),
      _panel(
        'طلباتي',
        const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'لا توجد طلبات بعد',
          message: 'أول طلب لك سيظهر هنا مع تتبّع لحظي.',
          actionLabel: 'ابدأ التسوق',
          onAction: _noop,
          scene: OrdersScene(),
        ),
      ),
      _panel(
        'فارغة عامة — إطلالة',
        const EmptyState(
          icon: Icons.card_giftcard_rounded,
          title: 'لا مكافآت بعد',
          message: 'اجمع المخالب مع كل طلب واستبدلها هنا.',
          mascot: true,
        ),
      ),
      _panel('بدون إنترنت', const ErrorState(error: ApiException(type: ApiErrorType.network), onRetry: _noop)),
      _panel(
        'شريط التوصيل المجاني',
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              FreeShippingBar(freeShipping: FreeShipping(min: 150, remaining: 32), runner: true),
              SizedBox(height: 24),
              FreeShippingBar(freeShipping: FreeShipping(min: 150, qualified: true), runner: true),
            ],
          ),
        ),
      ),
      _panel(
        'إكسبريس بعد الدوام',
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ExpressAsleepBand(
              hours: const ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
              now: DateTime(2026, 9, 23, 23, 40),
            ),
          ),
        ),
      ),
      _panel(
        'تم الطلب',
        const CheckoutSuccessScreen(
          order: PlacedOrder(orderId: 1, orderNumber: 'ZB-32579', orderKey: 'k', status: 'processing', total: 127.8),
        ),
      ),
      _panel(
        'رف الرئيسية — قيلولة',
        const ShelfLook(
          endCard: true,
          nap: true,
          child: Padding(
            padding: EdgeInsets.only(top: 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ProductRailView(
                title: 'الأكثر طلباً',
                products: _products,
                onSeeAll: _noop,
                animate: false,
              ),
            ),
          ),
        ),
      ),
      _panel(
        'نهاية الشريط — إطلالة',
        const Padding(
          padding: EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(height: 290, child: RailEndCard(width: 150, onTap: _noop, peek: true)),
          ),
        ),
      ),
      _panel(
        'استراحة — إكسبريس',
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Align(alignment: Alignment.topCenter, child: ExpressInterlude()),
        ),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          eventsBufferProvider.overrideWithValue(_SilentEvents()),
          cartRepositoryProvider.overrideWithValue(StubCartRepository()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          theme: AppTheme.light(const Locale('ar')),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFFDDE2DD),
            body: Wrap(children: panels),
          ),
        ),
      ),
    );

    // Asset images decode off the fake clock.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/character_moments_sheet.png'));
  });
}

void _noop() {}

const _products = [
  ProductCard(id: 1, name: 'أبلاوز ظرف تونة للقطط 70 غ', image: null, price: 4.95),
  ProductCard(id: 2, name: 'ويلنس كور أكل جاف للقطط', image: null, price: 89),
  ProductCard(id: 3, name: 'إينابا تشورو مكافأة سائلة', image: null, price: 9.5),
];
