import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/app/shell/live_order_bar.dart';
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
