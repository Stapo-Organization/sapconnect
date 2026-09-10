import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/widgets/empty_state.dart';
import 'package:zooboxi_app/features/notifications/data/push_repository.dart';
import 'package:zooboxi_app/features/notifications/presentation/inbox_screen.dart';
import 'package:zooboxi_app/features/orders/data/order_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// «صندوق الإشعارات», and the two models the store answers it with.
///
/// The parsing group is the load-bearing half: the inbox is the only place a
/// «هادئ» message is ever seen, so a `quiet` flag that failed to coerce would
/// silently turn the whole point of the screen off — and a rating that parsed
/// out of range would put six stars on a delivery.

/// A store that answers from memory, and remembers what it was told.
class _StubPush implements PushRepository {
  _StubPush({this.items = const [], this.unread = 0});

  final List<InboxItem> items;
  final int unread;

  /// Every `markRead` call, in order. An empty list is the store's own
  /// shorthand for "all of them".
  final List<List<int>> reads = [];

  @override
  Future<InboxPage> inbox({int limit = 30}) async => (items: items, unread: unread);

  @override
  Future<int> markRead(List<int> ids) async {
    reads.add(ids);
    return ids.isEmpty ? items.length : ids.length;
  }

  @override
  Future<WaitlistState> waitlist(int productId) async =>
      (restock: false, price: false);

  @override
  Future<WaitlistState> watch({required int productId, required String kind}) async =>
      (restock: kind == 'restock', price: kind == 'price');

  @override
  Future<WaitlistState> unwatch({required int productId, String kind = ''}) async =>
      (restock: false, price: false);

  @override
  Future<PushPreferences> register({
    required String token,
    required String platform,
    required String appVersion,
    required String locale,
  }) async => PushPreferences.all;

  @override
  Future<void> unregister(String token) async {}

  @override
  Future<void> opened(int msg) async {}

  @override
  Future<PushPreferences> preferences({String? token}) async => PushPreferences.all;

  @override
  Future<PushPreferences> save(PushPreferences preferences) async => preferences;

  @override
  Future<void> registerLiveActivity({
    required int orderId,
    required String activityToken,
    required String deviceToken,
  }) async {}

  @override
  Future<void> endLiveActivity({required int orderId}) async {}
}

InboxItem _item({
  required int id,
  String title = 'طلبك في الطريق',
  String body = 'الكابتن انطلق نحوك.',
  String topic = 'orders',
  String? route,
  bool quiet = false,
  bool read = false,
  Duration ago = const Duration(minutes: 5),
}) =>
    InboxItem(
      id: id,
      title: title,
      body: body,
      topic: topic,
      route: route,
      quiet: quiet,
      read: read,
      at: DateTime.now().subtract(ago),
    );

/// The pushed route, so a tap can be proved to have gone somewhere.
String? pushed;

Future<void> _pump(WidgetTester tester, _StubPush store) async {
  pushed = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pushRepositoryProvider.overrideWithValue(store)],
      child: MaterialApp.router(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const InboxScreen()),
            GoRoute(
              path: '/orders/:id',
              builder: (_, state) {
                pushed = state.uri.toString();
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ],
        ),
      ),
    ),
  );
  // One frame to mount, one for the provider's future to land.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('InboxItem', () {
    test('reads the store\'s shape, loose types and all', () {
      final item = InboxItem.fromJson({
        'id': '18',
        'topic': 'offers',
        'tier': 'nice_to_know',
        'source': 'campaign',
        'title': 'نزل سعر طعام لونا',
        'body': 'خصم 15٪ لمدة يومين',
        'route': '/product/4120',
        'image': null,
        'quiet': 1,
        'at': '2026-09-10T18:30:00+03:00',
        'read': 'no',
      });

      expect(item.id, 18);
      expect(item.topic, 'offers');
      expect(item.quiet, isTrue);
      expect(item.read, isFalse);
      expect(item.hasRoute, isTrue);
      expect(item.at, isNotNull);
    });

    test('an external or missing route is not a destination', () {
      expect(InboxItem.fromJson(const {'id': 1}).hasRoute, isFalse);
      expect(
        InboxItem.fromJson(const {'id': 1, 'route': 'https://zooboxi.com'}).hasRoute,
        isFalse,
      );
    });

    test('copyWith only ever moves the read flag', () {
      final item = _item(id: 3, quiet: true).copyWith(read: true);
      expect(item.read, isTrue);
      expect(item.quiet, isTrue);
      expect(item.id, 3);
    });
  });

  group('OrderRating', () {
    test('parses stars and comment', () {
      final rating = OrderRating.maybe({'stars': '4', 'comment': 'وصل بسرعة'});
      expect(rating?.stars, 4);
      expect(rating?.comment, 'وصل بسرعة');
    });

    test('an absent or impossible rating is no rating at all', () {
      expect(OrderRating.maybe(null), isNull);
      expect(OrderRating.maybe(const <String, dynamic>{}), isNull);
      expect(OrderRating.maybe(const {'stars': 0}), isNull);
      expect(OrderRating.maybe(const {'stars': 6}), isNull);
    });

    test('rides on the order summary', () {
      final summary = OrderSummary.fromJson(const {
        'id': 32579,
        'number': '32579',
        'status': 'completed',
        'rating': {'stars': 5, 'comment': ''},
      });
      expect(summary.rating?.stars, 5);
      expect(summary.rating?.comment, isEmpty);
      expect(
        OrderSummary.fromJson(const {'id': 1, 'number': '1', 'status': 'completed'})
            .rating,
        isNull,
      );
    });
  });

  group('InboxScreen', () {
    testWidgets('draws every message, with the quiet ones marked', (tester) async {
      final store = _StubPush(
        items: [
          _item(id: 1, title: 'طلبك في الطريق'),
          _item(id: 2, title: 'نزل سعر طعام لونا', topic: 'offers', quiet: true, read: true),
        ],
        unread: 1,
      );
      await _pump(tester, store);

      expect(tester.takeException(), isNull);
      expect(find.text('طلبك في الطريق'), findsOneWidget);
      expect(find.text('نزل سعر طعام لونا'), findsOneWidget);
      // The topic each message belongs to, in the words the settings screen
      // uses for the switch that would stop it.
      expect(find.text('تحديثات الطلب'), findsOneWidget);
      expect(find.text('العروض والتخفيضات'), findsOneWidget);
      // The «هادئ» marker, and the one line that explains what it means.
      expect(find.text('هادئ'), findsOneWidget);
      expect(find.text(L.of(tester.element(find.byType(InboxScreen))).inboxQuietNote),
          findsOneWidget);
    });

    testWidgets('an unread title is the bolder one', (tester) async {
      await _pump(
        tester,
        _StubPush(
          items: [
            _item(id: 1, title: 'جديد'),
            _item(id: 2, title: 'مقروء', read: true),
          ],
          unread: 1,
        ),
      );

      final unread = tester.widget<Text>(find.text('جديد'));
      final read = tester.widget<Text>(find.text('مقروء'));
      expect(unread.style?.fontWeight, FontWeight.w800);
      expect(read.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('a tap marks it read at once and follows the route',
        (tester) async {
      final store = _StubPush(
        items: [_item(id: 7, route: '/orders/32579')],
        unread: 1,
      );
      await _pump(tester, store);

      await tester.tap(find.text('طلبك في الطريق'));
      await tester.pump();

      // Marked before the store was asked, not after it answered.
      expect(store.reads, [
        [7],
      ]);
      await tester.pumpAndSettle();
      expect(pushed, '/orders/32579');
    });

    testWidgets('«قرأت الكل» sends the store its own shorthand', (tester) async {
      final store = _StubPush(items: [_item(id: 1), _item(id: 2)], unread: 2);
      await _pump(tester, store);

      await tester.tap(find.text('قرأت الكل'));
      await tester.pump();
      await tester.pump();

      expect(store.reads, [<int>[]]);
    });

    testWidgets('nothing to show is a state, not a blank screen', (tester) async {
      await _pump(tester, _StubPush());

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('لا إشعارات بعد'), findsOneWidget);
      // Nothing unread, so nothing to mark.
      expect(find.text('قرأت الكل'), findsNothing);
    });
  });
}
