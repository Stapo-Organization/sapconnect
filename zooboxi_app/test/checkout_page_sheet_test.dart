import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/account/data/account_models.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/checkout/data/checkout_models.dart';
import 'package:zooboxi_app/features/checkout/presentation/widgets/payment_step.dart';
import 'package:zooboxi_app/features/checkout/presentation/widgets/review_step.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';

/// Checkout, on one page: where it goes, what is in it, how it is paid for.
///
/// A *design* golden — refresh with
/// `flutter test test/checkout_page_sheet_test.dart --update-goldens`.

const _items = [
  CartItem(
    key: 'a',
    productId: 1,
    name: 'رويال كانين طعام جاف للقطط البالغة ٢ كجم',
    qty: 2,
    unitPrice: 89,
    lineTotal: 178,
  ),
  CartItem(
    key: 'b',
    productId: 2,
    name: 'رمل كلامبينغ برائحة اللافندر ١٠ لتر',
    qty: 1,
    unitPrice: 42,
    lineTotal: 42,
  ),
];

const _methods = [
  PaymentMethod(id: 'cod', label: 'الدفع عند الاستلام', sub: 'ادفع نقداً أو بالشبكة عند وصول طلبك'),
  PaymentMethod(id: 'myfatoorah', label: 'بطاقة مدى أو ائتمانية', sub: 'دفع آمن عبر ماي فاتورة'),
];

Address _address({bool serves = true, String reason = ''}) => Address(
      id: 'home',
      label: 'البيت',
      name: 'محمد المهجوب',
      phone: '0500000000',
      city: 'الرياض',
      district: 'حي الملقا',
      addressLine: 'شارع أنس بن مالك، مبنى ١٢',
      serves: serves,
      servesReason: reason,
      isDefault: true,
    );

CheckoutReview _review() => CheckoutReview(
      items: _items,
      totals: const CartTotals(subtotal: 220, shipping: 25, total: 245),
      paymentMethods: _methods,
      addresses: [_address()],
    );

Widget _panel(String caption, Brightness brightness, Address? address) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark(const Locale('ar'))
      : AppTheme.light(const Locale('ar'));
  return Expanded(
    child: Theme(
      data: theme,
      child: Builder(
        builder: (context) => Material(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, top: 8, bottom: 2),
                child: Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Tajawal',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: true),
                  child: CheckoutBody(
                    review: _review(),
                    address: address,
                    onChangeAddress: () {},
                    payment: CheckoutPaymentSection(
                      methods: _methods,
                      selectedId: 'cod',
                      onSelect: (_) {},
                      notes: TextEditingController(),
                    ),
                  ),
                ),
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
    await initializeDateFormatting();
  });

  testWidgets('checkout page sheet', (tester) async {
    tester.view.physicalSize = const Size(786, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: ColoredBox(
            color: const Color(0xFFEFEFEF),
            child: Row(
              children: [
                _panel('فاتح · عنوان صالح', Brightness.light, _address()),
                _panel(
                  'داكن · عنوان خارج النطاق',
                  Brightness.dark,
                  _address(serves: false, reason: 'out_of_zone'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/checkout_page_sheet.png'),
    );
  });
}
