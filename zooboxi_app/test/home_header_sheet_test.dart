import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/home_header.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

/// The header's address row, which answers the only two questions a customer
/// has before they start shopping: where is this going, and when does it land.
/// Drawn at the narrowest phone the store sees and with a long district, in
/// both themes.
///
/// A *design* golden — refresh with
/// `flutter test test/home_header_sheet_test.dart --update-goldens`.

class _At extends LocationController {
  _At(this._district, this._label);

  final String _district;
  final String? _label;

  @override
  LocationState build() => LocationState(
    location: ZbLocation(
      lat: 24.74,
      lng: 46.66,
      city: 'الرياض',
      district: _district,
      label: _label,
      deliveryType: 'express',
      warehouseCode: 'RUH010',
      setAt: DateTime(2026, 9, 10, 18),
    ),
  );
}

const _express = CatalogScope(
  tier: 'express',
  note: '',
  shelf: 'express',
  label: 'خلال ساعتين',
  expressHours: ExpressHours(openMinutes: 540, closeMinutes: 1440),
  expressAvailable: true,
);

late LocalStore _store;

Widget _panel(String caption, Brightness brightness, String district, String? label) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark(const Locale('ar'))
      : AppTheme.light(const Locale('ar'));
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(_store),
      cartRepositoryProvider.overrideWithValue(StubCartRepository()),
      locationProvider.overrideWith(() => _At(district, label)),
    ],
    child: Theme(
      data: theme,
      child: Builder(
        builder: (context) => Material(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, top: 10),
                child: Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Tajawal',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const HomeHeader(scope: _express),
              ),
            ],
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

  testWidgets('home header sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The arrival hour is computed from the clock, so a golden taken at the
    // wall clock is a golden that fails a minute later. Pinned to a Thursday
    // evening inside the branch's hours.
    await withClock(Clock.fixed(DateTime(2026, 9, 10, 19, 20)), () async {
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
                _panel('حي قصير · ٣٦٠pt', Brightness.light, 'الملقا', null),
                const SizedBox(height: 8),
                _panel(
                  'حي طويل · عنوان مسمّى',
                  Brightness.light,
                  'حي الملك عبدالله الشمالي',
                  'البيت',
                ),
                const SizedBox(height: 8),
                _panel('داكن · حي طويل', Brightness.dark, 'حي الملك عبدالله الشمالي', null),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_header_sheet.png'),
      );
    });
  });
}
