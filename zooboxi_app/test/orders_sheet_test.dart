import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/orders/data/live_tracking.dart';
import 'package:zooboxi_app/features/orders/data/order_models.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/features/orders/data/orders_repository.dart';
import 'package:zooboxi_app/features/orders/presentation/orders_screen.dart';
import 'package:zooboxi_app/features/orders/presentation/widgets/order_card.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';

/// «طلباتي», as the customer sees it.
///
/// A *design* golden: every state one row can be in, drawn at phone width in
/// the real Arabic face, light and dark. The list used to be four identical
/// receipts, so what this sheet is really guarding is that the states stay
/// *different* — a live order must not be able to drift into looking like a
/// cancelled one.
///
/// Refresh with
/// `flutter test test/orders_sheet_test.dart --update-goldens`.

ThemeData _theme(bool dark) =>
    dark ? AppTheme.dark(const Locale('ar')) : AppTheme.light(const Locale('ar'));

/// A fixed evening, so the dates on the sheet do not age with the wall clock.
final _now = DateTime(2026, 9, 8, 22, 32);

OrderSummary _order({
  required String number,
  required String status,
  required String label,
  double total = 148.5,
  int items = 3,
  int photos = 3,
  int? lines,
  String? payment = 'cod',
  bool paid = true,
  String? delivery = 'express',
  bool canReorder = false,
  Duration ago = const Duration(hours: 2),
}) =>
    OrderSummary(
      id: int.parse(number),
      number: number,
      orderKey: 'wc_order_$number',
      date: _now.subtract(ago),
      status: status,
      statusLabel: label,
      total: total,
      isPaid: paid,
      paymentMethod: payment,
      deliveryType: delivery,
      itemsCount: items,
      itemsLines: lines ?? items,
      canReorder: canReorder,
      itemsPreview: [
        for (var i = 0; i < photos; i++)
          // Empty URLs on purpose: ZbImage draws its paw without touching the
          // network, which makes the STACK judgeable even though the
          // photography is not.
          const OrderItemPreview(name: 'سنال أظرف كريمي بالدجاج 5×15 غ', image: ''),
      ],
    );

LiveTracking _live() => LiveTracking.fromJson({
      'phase': 'in_transit',
      'active': true,
      'status': 'DELIVERING',
      'courier': {'name': 'هيثم أحمد', 'phone': '+966510297288'},
      'distance_km': 3.8,
      'eta_minutes': 11,
    });

Widget _row(String caption, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              caption,
              style: const TextStyle(fontSize: 10, fontFamily: 'Tajawal'),
            ),
          ),
          child,
        ],
      ),
    );

List<Widget> _cards() => [
      _row(
        'live · express',
        OrderCard(
          order: _order(number: '32665', status: 'zb-out-for-delivery', label: 'في الطريق إليك', total: 6, items: 6, photos: 1, lines: 1),
          live: _live(),
        ),
      ),
      _row(
        'preparing',
        OrderCard(
          order: _order(number: '32664', status: 'processing', label: 'قيد التجهيز', total: 212, items: 6, photos: 3, lines: 4),
        ),
      ),
      _row(
        'awaiting payment',
        OrderCard(
          order: _order(
            number: '32621',
            status: 'pending',
            label: 'بانتظار الدفع',
            total: 89.9,
            items: 2,
            photos: 2,
            payment: 'myfatoorah',
            paid: false,
            delivery: 'same_day',
            ago: const Duration(days: 2),
          ),
        ),
      ),
      _row(
        'completed · reorder',
        OrderCard(
          order: _order(
            number: '32480',
            status: 'completed',
            label: 'مكتمل',
            total: 1240.25,
            items: 12,
            canReorder: true,
            delivery: 'shipping',
            ago: const Duration(days: 41),
          ),
        ),
      ),
      _row(
        'cancelled',
        OrderCard(
          order: _order(
            number: '32101',
            status: 'cancelled',
            label: 'ملغى',
            total: 64,
            items: 1,
            photos: 1,
            canReorder: true,
            delivery: '',
            ago: const Duration(days: 96),
          ),
        ),
      ),
    ];

/// A history that spans two months, so the page has to draw its landmarks.
class _Repo implements OrdersRepository {
  @override
  Future<OrdersPage> orders({int page = 1, String? status}) async => OrdersPage(
        orders: [
          _order(number: '32665', status: 'zb-out-for-delivery', label: 'في الطريق إليك', total: 35.75, items: 1, photos: 1),
          _order(number: '32664', status: 'processing', label: 'قيد التجهيز', total: 212, items: 6, lines: 4),
          _order(
            number: '32621',
            status: 'pending',
            label: 'بانتظار الدفع',
            total: 89.9,
            items: 2,
            photos: 2,
            payment: 'myfatoorah',
            paid: false,
            delivery: 'same_day',
            ago: const Duration(days: 2),
          ),
          _order(
            number: '32480',
            status: 'completed',
            label: 'مكتمل',
            total: 1240.25,
            items: 12,
            canReorder: true,
            delivery: 'shipping',
            ago: const Duration(days: 41),
          ),
        ],
        total: 4,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await loadBrandFonts();
  });

  testWidgets('orders sheet', (tester) async {
    tester.view.physicalSize = const Size(880, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget column(bool dark, double scale) => Theme(
          data: _theme(dark),
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: Container(
                width: 393,
                color: _theme(dark).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(children: _cards()),
              ),
            ),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        debugShowCheckedModeBanner: false,
        theme: _theme(false),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                column(false, 1.0),
                column(true, 1.0),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/orders_sheet.png'),
    );
  });

  testWidgets('orders screen', (tester) async {
    tester.view.physicalSize = const Size(393, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(_Repo()),
          isAuthenticatedProvider.overrideWithValue(true),
          activeOrderProvider.overrideWith(
            (ref) => Stream.value([ActiveOrder(
              order: _order(
                number: '32665',
                status: 'zb-out-for-delivery',
                label: 'في الطريق إليك',
                total: 35.75,
                items: 1,
                photos: 1,
              ),
              tracking: _live(),
            )]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
          theme: _theme(false),
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar')],
          home: const OrdersScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/orders_screen.png'),
    );
  });
}
