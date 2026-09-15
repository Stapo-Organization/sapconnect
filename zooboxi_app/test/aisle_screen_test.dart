import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/presentation/aisle_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/stub_cart.dart';

/// «الممرّ» and «الطبقات» — one payload, two pages.
///
/// A species root walks as an aisle: the sign, the department strip, one row
/// of three per department, and «الكل» that goes INTO a department that has
/// departments of its own but to a plain listing for a leaf. A department
/// stacks as shelves. Both read the payload the store actually sends.

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}
  @override
  Future<void> flush() async {}
  @override
  void dispose() {}
}

/// A card the way the store sends one.
Map<String, dynamic> _pj(int id, String name, double price, {bool cut = true}) => {
      'id': id,
      'name': name,
      'item_code': 'P$id',
      'price': price,
      'image': 'https://x/$id.png',
      'cutout': cut ? 'https://x/cut-$id.png' : null,
      'stock_status': 'instock',
    };

Map<String, dynamic> _cat(int id, String name, int count, {String icon = '', String? image}) => {
      'id': id,
      'slug': 'c$id',
      'name': name,
      'count': count,
      'icon': icon,
      'image': image,
      'children': const [],
    };

/// The cats root, shaped exactly like `GET /catalog/aisle/107`.
final Map<String, dynamic> _catsJson = {
  'node': _cat(107, 'قطط', 2238, icon: '🐱', image: 'https://x/cat.webp'),
  'parent': null,
  'root': null,
  'bestsellers': [
    _pj(1, 'سنال أظرف كريمي', 7),
    _pj(2, 'زولكس مكافآت دجاج', 0.95),
    _pj(3, 'زولكس مكافآت تونة', 0.95),
  ],
  'rows': [
    {
      ..._cat(108, 'طعام', 436, image: 'https://x/food.png'),
      'has_children': true,
      'products': [_pj(11, 'فيلاين قو حليب', 3.75), _pj(12, 'برنسيس معلبات', 3.85), _pj(13, 'بايو كيتن', 25)],
    },
    {
      ..._cat(235, 'رمل القطط', 61, image: 'https://x/litter.png'),
      'has_children': false,
      'products': [_pj(21, 'سينيور غاتو رمل', 28), _pj(22, 'ليندو كات رمل', 14)],
    },
  ],
};

/// The food department, shaped like `GET /catalog/aisle/108`.
final Map<String, dynamic> _foodJson = {
  'node': _cat(108, 'طعام', 530, image: 'https://x/food.png'),
  'parent': _cat(107, 'قطط', 2238, icon: '🐱'),
  'root': _cat(107, 'قطط', 2238, icon: '🐱'),
  'bestsellers': [_pj(31, 'د. كلاودرز بيست سيلكشن', 8.75)],
  'rows': [
    {
      ..._cat(109, 'الطعام الجاف', 87),
      'has_children': false,
      'products': [_pj(41, 'سوليد جولد فت آز', 60), _pj(42, 'أبلاوز جاف دجاج', 19), _pj(43, 'جوسيرا سينيور', 42, cut: false)],
    },
    {
      ..._cat(128, 'الطعام الرطب', 382),
      'has_children': false,
      'products': [_pj(51, 'برنسيس دجاج وأرز', 3.85)],
    },
  ],
};

late LocalStore _store;
final List<String> _visited = [];

Widget _host(Map<String, Aisle> aisles, String start) {
  final router = GoRouter(
    initialLocation: '/aisle/$start',
    routes: [
      GoRoute(
        path: '/aisle/:key',
        builder: (_, state) => AisleScreen(
          aisleKey: state.pathParameters['key']!,
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: '/listing',
        builder: (_, state) {
          _visited.add(state.uri.toString());
          return Scaffold(body: Text('LISTING ${state.uri.queryParameters['title']}'));
        },
      ),
      GoRoute(path: '/search', builder: (_, _) => const Scaffold(body: Text('SEARCH'))),
    ],
  );
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(_store),
      eventsBufferProvider.overrideWithValue(_SilentEvents()),
      cartRepositoryProvider.overrideWithValue(StubCartRepository()),
      for (final entry in aisles.entries)
        aisleProvider(entry.key).overrideWithValue(AsyncValue.data(entry.value)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ar'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light(const Locale('ar')),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  setUp(_visited.clear);

  test('the payload parses, and a root knows it is a species', () {
    final cats = Aisle.fromJson(_catsJson);
    expect(cats.isSpecies, isTrue);
    expect(cats.species.name, 'قطط');
    expect(cats.rows.map((r) => r.node.name), ['طعام', 'رمل القطط']);
    expect(cats.rows.first.hasChildren, isTrue);
    expect(cats.rows.last.hasChildren, isFalse);
    expect(cats.rows.first.products.length, 3);
    expect(cats.bestsellers.first.cutout, 'https://x/cut-1.png');

    final food = Aisle.fromJson(_foodJson);
    expect(food.isSpecies, isFalse);
    expect(food.species.name, 'قطط', reason: 'a department belongs to the animal above it');
    expect(food.rows.first.products.last.cutout, isNull);
  });

  testWidgets('a species walks as an aisle: sign, strip, bestsellers, rows', (tester) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host({'107': Aisle.fromJson(_catsJson)}, '107'));
    await tester.pumpAndSettle();

    expect(find.text('ممرّ'), findsOneWidget);
    expect(find.text('قطط'), findsOneWidget);
    expect(find.text('2238 منتجًا · قسمان'), findsOneWidget);
    // The strip: «الكل» and one chip per row.
    expect(find.text('الكل'), findsNWidgets(1 + 2), reason: 'the strip chip and each row\'s own link');
    expect(find.text('الأكثر مبيعًا'), findsOneWidget);
    expect(find.text('سنال أظرف كريمي'), findsOneWidget);
    // Each row names its department, its size, and its three products.
    expect(find.text('طعام'), findsNWidgets(2), reason: 'the strip chip and the row header');
    expect(find.text('436 منتجًا'), findsOneWidget);
    expect(find.text('فيلاين قو حليب'), findsOneWidget);
    expect(find.text('سينيور غاتو رمل'), findsOneWidget);
  });

  testWidgets('«الكل» walks into a department with children and lists a leaf', (tester) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host({
      '107': Aisle.fromJson(_catsJson),
      '108': Aisle.fromJson(_foodJson),
    }, '107'));
    await tester.pumpAndSettle();

    // The leaf: a listing. (`.first` is the strip chip, which glides.)
    await tester.tap(find.text('رمل القطط').last);
    await tester.pumpAndSettle();
    expect(find.text('LISTING رمل القطط'), findsOneWidget);
    expect(_visited.single, contains('category=c235'));

    // The department with children: its own aisle, as shelves.
    await tester.pumpWidget(_host({
      '107': Aisle.fromJson(_catsJson),
      '108': Aisle.fromJson(_foodJson),
    }, '107'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('436 منتجًا'));
    await tester.pumpAndSettle();
    expect(find.text('الطعام الجاف'), findsOneWidget);
    expect(find.text('الطعام الرطب'), findsOneWidget);
    expect(find.text('LISTING طعام'), findsNothing);
  });

  testWidgets('a department stacks as shelves under its own sign', (tester) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host({'108': Aisle.fromJson(_foodJson)}, '108'));
    await tester.pumpAndSettle();

    expect(find.text('ممرّ'), findsNothing, reason: 'the kicker belongs to the species page');
    expect(find.text('قطط'), findsOneWidget, reason: 'the animal above it is named');
    expect(find.text('طعام'), findsOneWidget);
    expect(find.text('530 منتجًا · قسمان'), findsOneWidget);
    expect(find.text('الأكثر مبيعًا في طعام'), findsOneWidget);
    expect(find.text('الطعام الجاف'), findsOneWidget);
    expect(find.text('87 منتجًا'), findsOneWidget);
    expect(find.text('سوليد جولد فت آز'), findsOneWidget);
    expect(find.text('جوسيرا سينيور'), findsOneWidget, reason: 'a product with no cut-out still stands on the shelf');
  });
}
