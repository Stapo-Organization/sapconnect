import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/shelf_tabs.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

/// The two shop signs, each wearing what its own basket holds — drawn in the
/// real Arabic face, in both themes, in every state the pair can be in.
///
/// A *design* golden — refresh with
/// `flutter test test/shelf_tabs_sheet_test.dart --update-goldens`.

const _hours = ExpressHours(openMinutes: 540, closeMinutes: 1440);

late LocalStore _store;

Widget _row(String caption, Brightness brightness, CartData cart) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark(const Locale('ar'))
      : AppTheme.light(const Locale('ar'));
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(_store),
      cartRepositoryProvider.overrideWithValue(StubCartRepository(cart)),
    ],
    child: Theme(
      data: theme,
      child: Builder(
        // Material, not ColoredBox: the signs are InkWells and in the app
        // they sit on a Scaffold.
        builder: (context) => Material(
          color: theme.scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Tajawal',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: true),
                  child: const ShelfTabs(hours: _hours, expressAvailable: true),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadBrandFonts();
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  testWidgets('shelf tabs sheet', (tester) async {
    tester.view.physicalSize = const Size(393, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: ColoredBox(
          color: const Color(0xFFEFEFEF),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _row('كلتاهما فارغة', Brightness.light,
                  const CartData(basket: CartBasket.none)),
              const SizedBox(height: 6),
              _row('سلة زوبكسي حيّة، وإكسبريس تنتظر', Brightness.light,
                  const CartData(
                    count: 3,
                    basket: CartBasket(
                      shelf: 'all',
                      otherShelf: 'express',
                      otherCount: 2,
                      otherUnits: 5,
                    ),
                  )),
              const SizedBox(height: 6),
              _row('سلة إكسبريس حيّة وحدها', Brightness.light,
                  const CartData(
                    count: 12,
                    basket: CartBasket(shelf: 'express', otherShelf: 'all'),
                  )),
              const SizedBox(height: 6),
              _row('السلة فارغة وزوبكسي تنتظر', Brightness.dark,
                  const CartData(
                    basket: CartBasket(
                      otherShelf: 'all',
                      otherCount: 4,
                      otherUnits: 7,
                    ),
                  )),
              const SizedBox(height: 6),
              _row('كلتاهما بأرقام، داكن', Brightness.dark,
                  const CartData(
                    count: 3,
                    basket: CartBasket(
                      shelf: 'all',
                      otherShelf: 'express',
                      otherCount: 2,
                      otherUnits: 9,
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shelf_tabs_sheet.png'),
    );
  });
}
