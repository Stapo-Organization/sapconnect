import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/app/shell/live_order_bar.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';
import 'package:zooboxi_app/features/orders/data/live_tracking.dart';

/// «طلبك الآن» — the bar above the tab bar.
///
/// The widget itself is glass over a router and a polling provider, so these
/// lock the part that decides what it SAYS: which order counts as the one you
/// are waiting on, and how far along the lip should be filled.

ActiveOrder? _active({
  String status = 'processing',
  Map<String, dynamic>? tracking,
}) =>
    ActiveOrder.maybe({
      'order': {
        'id': 32700,
        'number': '32700',
        'status': status,
        'status_label': 'قيد التجهيز',
        'total': 128.5,
        'items_count': 3,
        'delivery_type': 'express',
        'items_preview': [
          {'name': 'اكانا', 'image': 'https://x/1.jpg', 'qty': 2},
        ],
      },
      'tracking': tracking,
    });

/// Pumps the bar exactly as the shell does: in the bottom slot, in Arabic.
Future<void> _pumpBar(WidgetTester tester, ActiveOrder active) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: LiveOrderBarPreview(active: active),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => initializeDateFormatting());

  group('what counts as an active order', () {
    test('no order at all is not an active order', () {
      expect(ActiveOrder.maybe(null), isNull);
      expect(ActiveOrder.maybe(<String, dynamic>{}), isNull);
      expect(ActiveOrder.maybe({'tracking': {'phase': 'in_transit'}}), isNull);
    });

    test('an order being prepared is active, with no courier yet', () {
      final a = _active()!;
      expect(a.hasCourier, isFalse);
      expect(a.isLive, isTrue);
      expect(a.order.itemsCount, 3);
      expect(a.order.itemsPreview.single.qty, 2);
    });

    test('an order with a courier carries the whole tracking payload', () {
      final a = _active(status: 'zb-out-for-delivery', tracking: {
        'phase': 'in_transit',
        'status': 'DELIVERING',
        'eta_minutes': 7,
        'courier': {'name': 'FAHAD', 'lat': 24.75, 'lng': 46.66},
        'dropoff': {'lat': 24.76, 'lng': 46.66},
      })!;

      expect(a.hasCourier, isTrue);
      expect(a.isLive, isTrue);
      expect(a.tracking!.etaMinutes, 7);
      expect(a.tracking!.hasMap, isTrue);
    });

    test('a delivered courier is no longer something to wait on', () {
      final a = _active(tracking: {'phase': 'delivered'})!;
      expect(a.hasCourier, isTrue);
      expect(a.isLive, isFalse);
    });
  });

  group('the bar, laid out in Arabic', () {
    testWidgets('reads right to left: the order, then the words, then the time',
        (tester) async {
      await _pumpBar(
        tester,
        _active(status: 'zb-out-for-delivery', tracking: {
          'phase': 'in_transit',
          'status': 'DELIVERING',
          'eta_minutes': 8,
        })!,
      );

      final leading = tester.getCenter(find.byKey(LiveOrderBarPreview.leadingKey));
      final lines = tester.getCenter(find.text('مندوبك في الطريق إليك'));
      final trailing = tester.getCenter(find.text('تقريباً 8 دقيقة'));

      // Arabic reads right to left, so the thing you bought sits on the right
      // and the arrival time on the left. Getting this backwards is the single
      // most visible way an RTL layout can be wrong.
      expect(leading.dx, greaterThan(lines.dx));
      expect(lines.dx, greaterThan(trailing.dx));
    });

    testWidgets('the money is written once, with one riyal sign', (tester) async {
      await _pumpBar(tester, _active()!);

      final subtitle = tester.widget<Text>(
        find.textContaining('32700').first,
      );
      final text = subtitle.data!;

      expect('\u{E900}'.allMatches(text).length, 1, reason: text);
      expect(text, contains('128٫5'));
    });

    testWidgets('it offers something to pull, and opens on a flick', (tester) async {
      await _pumpBar(tester, _active()!);

      expect(find.byKey(LiveOrderBarPreview.grabberKey), findsOneWidget);

      await tester.fling(find.byKey(LiveOrderBarPreview.grabberKey), const Offset(0, -60), 900);
      // Not pumpAndSettle: the phase glyph pulses forever by design while an
      // order is live, so there is no still frame to settle on.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('طلبك الآن'), findsOneWidget);
    });
  });

  group('the progress lip', () {
    double at({String status = 'processing', String? phase}) => liveOrderProgress(
          _active(status: status, tracking: phase == null ? null : {'phase': phase})!,
        );

    test('a box being packed has made SOME progress', () {
      // A bar pinned at zero tells a customer who has waited ten minutes that
      // nothing has happened. Something has: the branch started.
      expect(at(), greaterThan(0));
      expect(at(), lessThan(at(status: 'zb-ready')));
    });

    test('it only ever moves forward through the journey', () {
      final journey = [
        at(),
        at(status: 'zb-ready'),
        at(status: 'zb-ready', phase: 'searching'),
        at(status: 'zb-ready', phase: 'assigned'),
        at(status: 'zb-out-for-delivery', phase: 'in_transit'),
        at(status: 'zb-out-for-delivery', phase: 'delivered'),
      ];

      for (var i = 1; i < journey.length; i++) {
        expect(journey[i], greaterThan(journey[i - 1]), reason: 'step $i went backwards');
      }
    });

    test('it never leaves the track', () {
      for (final p in [null, 'searching', 'assigned', 'in_transit', 'delivered', 'failed']) {
        final v = at(phase: p);
        expect(v, inInclusiveRange(0, 1));
      }
    });

    test('a courier who never came still closes the bar out', () {
      // Failure is an ending too — a lip left half full would read as "still
      // coming" for an order that is not.
      expect(at(phase: 'failed'), 1);
    });
  });
}
