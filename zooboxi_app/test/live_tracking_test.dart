import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/orders/data/live_tracking.dart';
import 'package:zooboxi_app/features/orders/presentation/widgets/courier_search_glyph.dart';
import 'package:zooboxi_app/features/orders/presentation/widgets/live_tracking_card.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// «تتبّع مندوبك» — the panel a customer watches while someone rides toward
/// their door. These lock the three things it must never get wrong: the
/// sentence it says, the language it says it in, and the phone number it stops
/// showing once the courier is done.

Widget _host(Widget child, {Locale locale = const Locale('ar')}) => MaterialApp(
      locale: locale,
      theme: AppTheme.light(locale),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

LiveTracking _tracking({
  String phase = 'in_transit',
  String status = 'DELIVERING',
  Map<String, dynamic>? courier,
  double? distanceKm = 2.2,
  int? etaMinutes = 6,
  List<String> proof = const [],
  bool active = true,
  String? assignmentDeadline,
  String? courierSeenAt,
}) =>
    LiveTracking.fromJson({
      'phase': phase,
      'active': active,
      'status': status,
      'status_label': 'من الخادم',
      'carrier_label': 'مرسول',
      'number': '357415601',
      'courier': courier ??
          {'name': 'FAHAD MIAH', 'phone': '0555555555', 'lat': 24.755, 'lng': 46.664},
      'pickup': {'lat': 24.7493638, 'lng': 46.6678227, 'label': 'فرع الملك فهد'},
      'dropoff': {'lat': 24.76, 'lng': 46.66},
      'distance_km': distanceKm,
      'eta_minutes': etaMinutes,
      'steps': [
        {'key': 'requested', 'label': 'طلبنا مندوباً', 'at': '2026-09-08T18:41:52+03:00', 'done': true},
        {'key': 'assigned', 'label': 'تم تعيين المندوب', 'at': '2026-09-08T18:44:00+03:00', 'done': true},
        {'key': 'picked_up', 'label': 'استلم طلبك من الفرع', 'at': '2026-09-08T18:52:00+03:00', 'done': true},
        {'key': 'delivered', 'label': 'وصل إليك', 'at': null, 'done': false},
      ],
      'assignment_deadline': assignmentDeadline,
      'proof_images': proof,
      'tracking_url': 'https://mrsool.co/t/abc',
      'requested_at': '2026-09-08T18:41:52+03:00',
      'updated_at': '2026-09-08T18:55:00+03:00',
      'courier_seen_at': courierSeenAt,
    });

LiveTracking _trackingWithStep() => LiveTracking.fromJson({
      'phase': 'in_transit',
      'status': 'DELIVERING',
      'steps': [
        {'key': 'teleported', 'label': 'محطة جديدة', 'at': null, 'done': false},
      ],
    });

Widget _clock(Duration left) => _host(
      Center(
        child: CourierCountdown(
          // `clock.now()` rather than DateTime.now(): inside a widget test the
          // framework's clock is the one `tester.pump(Duration)` moves, and the
          // countdown reads the same one.
          deadline: clock.now().add(left),
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting());

  group('parsing', () {
    test('a payload with no phase is not a courier at all', () {
      expect(LiveTracking.maybe(null), isNull);
      expect(LiveTracking.maybe(<String, dynamic>{}), isNull);
      expect(LiveTracking.maybe({'active': true}), isNull);
    });

    test('an unknown phase falls back to searching rather than throwing', () {
      final t = LiveTracking.fromJson({'phase': 'teleporting'});
      expect(t.phase, LivePhase.searching);
      expect(t.isLive, isTrue);
    });

    test('a null island dropoff is treated as no dropoff', () {
      // 0,0 is what a missing coordinate looks like once it has been through a
      // (float) cast. Framing a map on it would put the courier in the Atlantic.
      final t = LiveTracking.fromJson({
        'phase': 'in_transit',
        'dropoff': {'lat': 0, 'lng': 0},
        'courier': {'lat': 24.7, 'lng': 46.6},
      });
      expect(t.dropoff, isNull);
      expect(t.hasMap, isFalse);
    });

    test('the map only draws once there is a courier AND a door', () {
      expect(_tracking().hasMap, isTrue);
      expect(_tracking(courier: const {'name': 'FAHAD'}).hasMap, isFalse);
    });

    test('a courier at Null Island has no position at all', () {
      // A courier whose app has not got a GPS fix yet reports 0,0. Believing it
      // puts him in the Atlantic and turns the arrival estimate into days.
      final t = LiveTracking.fromJson({
        'phase': 'in_transit',
        'courier': {'name': 'FAHAD', 'lat': 0, 'lng': 0},
        'dropoff': {'lat': 24.76, 'lng': 46.66},
      });
      expect(t.courier.hasPosition, isFalse);
      expect(t.hasMap, isFalse);
    });

    test('delivered and failed both stop the polling', () {
      expect(LiveTracking.fromJson({'phase': 'delivered'}).isLive, isFalse);
      expect(LiveTracking.fromJson({'phase': 'failed'}).isLive, isFalse);
      expect(LiveTracking.fromJson({'phase': 'assigned'}).isLive, isTrue);
    });
  });

  group('the courier\'s WhatsApp number', () {
    // `tel:` dials anything; wa.me refuses everything that is not an
    // international number, and refuses it AFTER the customer has left the app.
    test('a local Saudi number becomes an international one', () {
      expect(whatsappNumber('0555555555'), '966555555555');
      expect(whatsappNumber('055 555 5555'), '966555555555');
      expect(whatsappNumber('555555555'), '966555555555');
    });

    test('a number that is already international is left alone', () {
      expect(whatsappNumber('+966555555555'), '966555555555');
      expect(whatsappNumber('00966555555555'), '966555555555');
      expect(whatsappNumber('966555555555'), '966555555555');
      // Country code AND trunk zero, both written out — a shape people really
      // type, and one wa.me rejects after the customer has left the app.
      expect(whatsappNumber('+966 055 555 5555'), '966555555555');
    });

    test('a number that could not be dialled offers no button at all', () {
      expect(whatsappNumber(''), isNull);
      expect(whatsappNumber('----'), isNull);
      expect(whatsappNumber('12345'), isNull, reason: 'an extension, not a mobile');
      expect(whatsappNumber('9665555555555555555'), isNull);
    });
  });

  group('the courier countdown', () {
    /// The one clock on screen, as the customer reads it.
    String clockText(WidgetTester tester) =>
        tester.widget<Text>(find.byType(Text).first).data!;

    testWidgets('it ticks down by the second', (tester) async {
      await tester.pumpWidget(_clock(const Duration(minutes: 14)));
      await tester.pump();

      expect(clockText(tester), '14:00');

      await tester.pump(const Duration(seconds: 1));
      expect(clockText(tester), '13:59');

      await tester.pump(const Duration(seconds: 59));
      expect(clockText(tester), '13:00');
    });

    testWidgets('it never runs negative — it admits we are still looking',
        (tester) async {
      // A clock that keeps counting past its own promise is a clock that lies.
      await tester.pumpWidget(_clock(const Duration(seconds: 2)));
      await tester.pump();

      expect(clockText(tester), '0:02');

      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('-'), findsNothing);
      expect(find.text('نواصل البحث عن مندوب لك'), findsOneWidget);
    });

    testWidgets('a deadline already gone shows the honest line at once',
        (tester) async {
      await tester.pumpWidget(_clock(const Duration(seconds: -30)));
      await tester.pump();

      expect(find.text('نواصل البحث عن مندوب لك'), findsOneWidget);
    });
  });

  group('the card', () {
    testWidgets('says where the courier is, in Arabic, with the minutes',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(tracking: _tracking())));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('مندوبك في الطريق إليك'), findsOneWidget);
      expect(find.text('تقريباً 6 دقيقة'), findsOneWidget);
      expect(find.text('FAHAD MIAH'), findsOneWidget);
      // Both ways of reaching him, as round buttons — so the name keeps the
      // width a wide «اتصل بالمندوب» used to take from it.
      expect(find.byTooltip('اتصل بالمندوب'), findsOneWidget);
      expect(find.byTooltip('واتساب المندوب'), findsOneWidget);

      // The server's own sentence is a fallback, not the wording on screen.
      expect(find.text('من الخادم'), findsNothing);
    });

    testWidgets('an English reader gets English, not the server Arabic',
        (tester) async {
      await tester.pumpWidget(
        _host(LiveTrackingCard(tracking: _tracking()), locale: const Locale('en')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Your courier is on the way to you'), findsOneWidget);
      expect(find.text('About 6 min'), findsOneWidget);
      expect(find.text('من الخادم'), findsNothing);
    });

    testWidgets('a status this build has never heard of still speaks the reader\'s language',
        (tester) async {
      // The server's own sentence is always Arabic, so leaning on it would hand
      // an English reader Arabic the day Mrsool invents a status. The phase is
      // always known — use it.
      await tester.pumpWidget(
        _host(
          LiveTrackingCard(tracking: _tracking(status: 'BEAMED_UP')),
          locale: const Locale('en'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Your courier is on the way to you'), findsOneWidget);
      expect(find.text('من الخادم'), findsNothing);
    });

    testWidgets('an unknown STEP keeps the server wording rather than a blank row',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(tracking: _trackingWithStep())));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('محطة جديدة'), findsOneWidget);
    });

    testWidgets('the courier at the door reads "now", not "0 minutes"',
        (tester) async {
      await tester.pumpWidget(
        _host(LiveTrackingCard(
          tracking: _tracking(status: 'DROPOFF_ARRIVED', etaMinutes: 0, distanceKm: 0.05),
        )),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('مندوبك وصل عندك'), findsOneWidget);
      expect(find.text('على بابك الآن'), findsOneWidget);
    });

    testWidgets('a delivered order shows no ETA, no distance and no phone',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(
        tracking: _tracking(
          phase: 'delivered',
          status: 'DELIVERED',
          active: false,
          etaMinutes: null,
          distanceKm: null,
          courier: const {'name': null, 'phone': null, 'lat': null, 'lng': null},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('تم تسليم طلبك'), findsOneWidget);
      expect(find.byTooltip('اتصل بالمندوب'), findsNothing);
      expect(find.byTooltip('واتساب المندوب'), findsNothing);
      expect(find.textContaining('تقريباً'), findsNothing);
      expect(find.textContaining('يبعد عنك'), findsNothing);
    });

    testWidgets('a courier who never came says so, and offers a way out',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(
        tracking: _tracking(
          phase: 'failed',
          status: 'EXPIRED',
          active: false,
          etaMinutes: null,
          distanceKm: null,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('لم نجد مندوباً متاحاً'), findsOneWidget);
      expect(find.text('تواصل معنا وسنعيد المحاولة.'), findsOneWidget);
    });

    testWidgets('while we are still looking, the card promises nothing',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(
        tracking: _tracking(
          phase: 'searching',
          status: 'COURIER_PENDING',
          etaMinutes: null,
          distanceKm: null,
          courier: const {},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('جارٍ تحديد مندوب توصيل لطلبك'), findsOneWidget);
      expect(find.textContaining('تقريباً'), findsNothing);
      expect(find.byTooltip('اتصل بالمندوب'), findsNothing);
    });

    testWidgets('an absurd arrival estimate is withheld, not displayed',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(
        tracking: _tracking(etaMinutes: 15300, distanceKm: 5600),
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('تقريباً'), findsNothing);
    });

    testWidgets('before pickup the card never claims a distance to your door',
        (tester) async {
      // The courier is riding to the branch, not to you. "300 m away" then is
      // true of the map and false of the sentence.
      await tester.pumpWidget(_host(LiveTrackingCard(
        tracking: _tracking(
          phase: 'assigned',
          status: 'COURIER_ASSIGNED',
          etaMinutes: null,
          distanceKm: null,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('مندوبك في طريقه للفرع'), findsOneWidget);
      expect(find.textContaining('يبعد عنك'), findsNothing);
      expect(find.textContaining('تقريباً'), findsNothing);
    });

    testWidgets('while we look, the card counts down instead of promising an arrival',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(
        tracking: _tracking(
          phase: 'searching',
          status: 'COURIER_PENDING',
          etaMinutes: null,
          distanceKm: null,
          courier: const {},
          assignmentDeadline: '2999-01-01T00:00:00+03:00',
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('جارٍ تحديد مندوب توصيل لطلبك'), findsOneWidget);
      expect(find.text('نبحث بين المندوبين القريبين. ننبّهك فور تحديد المندوب.'), findsOneWidget);
      expect(find.textContaining('تقريباً'), findsNothing);
      expect(find.textContaining('يبعد عنك'), findsNothing);
    });

    testWidgets('the four steps read as a journey with their real times',
        (tester) async {
      await tester.pumpWidget(_host(LiveTrackingCard(tracking: _tracking())));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('طلبنا مندوباً'), findsOneWidget);
      expect(find.text('تم تعيين المندوب'), findsOneWidget);
      expect(find.text('استلم طلبك من الفرع'), findsOneWidget);
      expect(find.text('وصل إليك'), findsOneWidget);
    });
  });

  group('a courier whose dot has stopped moving', () {
    // Mrsool stamps the position at the last status EVENT, not from a live GPS
    // feed, so for most of the ride the dot is where he WAS. Twenty minutes of
    // a still marker with nothing said is what reads as broken tracking.
    Future<void> pumpSeenAt(WidgetTester tester, DateTime seen, {double? km}) =>
        withClock(Clock.fixed(DateTime(2026, 9, 10, 19, 30)), () async {
          await tester.pumpWidget(
            _host(
              LiveTrackingCard(
                tracking: _tracking(
                  distanceKm: km,
                  courierSeenAt: seen.toIso8601String(),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
        });

    testWidgets('it says when he was last seen instead of saying nothing',
        (tester) async {
      await pumpSeenAt(tester, DateTime(2026, 9, 10, 19, 10));
      expect(find.textContaining('آخر موقع للمندوب'), findsOneWidget);
    });

    testWidgets('a fresh fix says nothing of the sort', (tester) async {
      await pumpSeenAt(tester, DateTime(2026, 9, 10, 19, 29), km: 1.2);
      expect(find.textContaining('آخر موقع للمندوب'), findsNothing);
    });

    testWidgets('and the distance still wins when we have one', (tester) async {
      // A fix old enough to explain, but a distance the store still vouches
      // for: the measurement is the more useful of the two sentences.
      await pumpSeenAt(tester, DateTime(2026, 9, 10, 19, 10), km: 1.2);
      expect(find.textContaining('آخر موقع للمندوب'), findsNothing);
    });

    testWidgets('and the dot is not drawn where he no longer is', (tester) async {
      // The complaint that started this: a courier marker parked on the branch
      // half an hour after he left it. No fix we believe, no dot.
      await pumpSeenAt(tester, DateTime(2026, 9, 10, 19, 10));
      expect(find.byKey(courierDotKey), findsNothing);
    });

    testWidgets('a fresh fix still gets its dot', (tester) async {
      await pumpSeenAt(tester, DateTime(2026, 9, 10, 19, 29), km: 1.2);
      expect(find.byKey(courierDotKey), findsOneWidget);
    });

    test('a stale position is not a position, and is not framed as one', () {
      withClock(Clock.fixed(DateTime(2026, 9, 10, 19, 30)), () {
        final stale = _tracking(
          courierSeenAt: DateTime(2026, 9, 10, 19, 10).toIso8601String(),
        );
        expect(stale.courierIsWhereWeSay, isFalse);
        expect(mapPoints(stale).length, 2, reason: 'branch and door, no phantom');

        final fresh = _tracking(
          courierSeenAt: DateTime(2026, 9, 10, 19, 29).toIso8601String(),
        );
        expect(fresh.courierIsWhereWeSay, isTrue);
        expect(mapPoints(fresh).length, 3);
      });
    });

    test('a store too old to say is believed, exactly as before', () {
      withClock(Clock.fixed(DateTime(2026, 9, 10, 19, 30)), () {
        expect(_tracking().courierIsWhereWeSay, isTrue);
      });
    });

    test('a store too old to say is never guessed at', () {
      final t = LiveTracking.maybe({
        'phase': 'in_transit',
        'status': 'DELIVERING',
        'courier': {'lat': 24.7, 'lng': 46.6},
      });
      expect(t!.courierSeenAt, isNull);
    });
  });
}
