import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/brand/data/brand_activation.dart';
import 'package:zooboxi_app/features/brand/presentation/widgets/brand_activation_widgets.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/presentation/widgets/cart_brand_help.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/pets/data/care_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// «تفعيل البراندات» A + C (owner's pick, 2026-09-24): the brand answers a
/// search first, the customer's own brands lead the home page under the
/// official-distributor seal, and the cart knows the brand's lines — the
/// substitute, the bigger pack, more of the basket's brand. These check the
/// payloads land on the models the way the store sends them, and that each
/// surface says what it promises.

const _inaba = {
  'code': '199',
  'slug': 'inaba',
  'name': 'INABA',
  'logo': null,
  'count': 121,
  'accent': '#F39200',
  'accent_dark': '#E2001A',
  'official': true,
  'tagline': 'المكافأة اليابانية التي تُلعق',
  'country': 'اليابان',
  'founded': '1958',
  'lines': ['تشورو', 'داشي ديلايت', ''],
  'images': [],
};

Map<String, dynamic> _card(int id, String name, {double price = 11.73}) =>
    {'id': id, 'name': name, 'item_code': 'C$id', 'price': price};

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

late LocalStore _store;

Widget _host(Widget child) => ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(_store),
        eventsBufferProvider.overrideWithValue(_SilentEvents()),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(child));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  group('payloads', () {
    test('a brand summary carries its identity and folds blanks away', () {
      final brand = BrandSummary.fromJson({..._inaba, 'tagline': ' ', 'last_product': 'تشورو', 'bought': 4});
      expect(brand.accentDark, '#E2001A');
      expect(brand.official, isTrue);
      expect(brand.tagline, isNull, reason: 'a blank line is no line');
      expect(brand.country, 'اليابان');
      expect(brand.lines, ['تشورو', 'داشي ديلايت'], reason: 'an empty line name is dropped');
      expect(brand.lastProduct, 'تشورو');
      expect(brand.bought, 4);
      expect(BrandSummary.maybe({'name': 'no slug'}), isNull);
    });

    test('the search names the brand above its suggestions', () {
      final result = SuggestResult.fromJson({
        'brand': _inaba,
        'suggestions': [
          {'id': 1, 'name': 'تشورو', 'price': 11.73},
        ],
      });
      expect(result.brand?.slug, 'inaba');
      expect(result.suggestions.single.id, 1);
      expect(SuggestResult.fromJson({'suggestions': []}).isEmpty, isTrue);
    });

    test('the home feed brings the customer\'s own brands', () {
      final feed = HomeFeed.fromJson({
        'my_brands': [_inaba, {'slug': ''}],
      });
      expect(feed.myBrands.single.name, 'INABA');
      expect(HomePayload.fromJson({'brands_total': 74}).brandsTotal, 74);
    });

    test('the cart help keeps only lines with something to say, and finds the best pack', () {
      final help = CartBrandHelp.fromJson({
        'lines': {
          'a': {
            'substitute': {'product': _card(7, 'تشورو جيلي'), 'same_price': true},
          },
          'b': {
            'upgrade': {
              'brand': _inaba,
              'mode': 'unit',
              'product': _card(9, 'تشورو 50×14', price: 101.27),
              'big': {'label': '50 × 14 جم', 'each': 2.03},
              'small': {'label': '4 × 14 جم', 'each': 2.93, 'id': 3},
              'saving': 31,
            },
          },
          'c': {},
        },
        'complete': {
          'brand': _inaba,
          'products': [_card(11, 'رول'), _card(12, 'جوسي')],
        },
      });
      expect(help.lines.keys, unorderedEquals(['a', 'b']));
      expect(help.lines['a']!.substitute!.id, 7);
      expect(help.lines['a']!.samePrice, isTrue);
      expect(help.bestUpgrade!.key, 'b');
      expect(help.bestUpgrade!.value.saving, 31);
      expect(help.bestUpgrade!.brand!.accent, '#F39200');
      expect(help.brand!.slug, 'inaba');
      expect(help.complete, hasLength(2));
      expect(CartBrandHelp.fromJson({'lines': [], 'complete': null}).lines, isEmpty,
          reason: 'PHP sends an empty object as a list');
    });

    test('a pet\'s brands pair each brand with its gauge line', () {
      final brands = PetBrand.listFrom([
        {
          'brand': _inaba,
          'supply': {
            'product': _card(5, 'تشورو دجاج'),
            'kind': 'treat',
            'qty_last': 2,
            'cycle_days': 7,
            'days_left': 4,
            'status': 'soon',
          },
        },
        {'brand': _inaba, 'supply': null},
      ]);
      expect(brands, hasLength(1));
      expect(brands.single.supply.daysLeft, 4);
    });
  });

  group('surfaces', () {
    testWidgets('the brand answers a search: identity, seal, lines, follow and its shop', (tester) async {
      await _pump(tester, BrandSearchCard(brand: BrandSummary.fromJson(_inaba), express: true));
      expect(find.text('INABA'), findsWidgets);
      expect(find.text('اليابان · منذ 1958'), findsOneWidget);
      expect(find.text('من الموزّع الرسمي'), findsOneWidget);
      expect(find.text('خطوط INABA الجاهزة خلال ساعتين'), findsOneWidget);
      expect(find.text('تشورو'), findsOneWidget);
      expect(find.text('تابِع'), findsOneWidget);
      expect(find.text('ادخل متجر INABA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«براندات لولو» names the pet and draws each brand in its colours', (tester) async {
      final brands = [
        BrandSummary.fromJson(_inaba),
        BrandSummary.fromJson({..._inaba, 'slug': 'kit-cat', 'name': 'Kit Cat', 'accent': '#E5007E', 'lines': []}),
      ];
      await _pump(tester, MyBrandsRow(brands: brands, petName: 'لولو'));
      expect(find.text('براندات لولو'), findsOneWidget);
      expect(find.text('من طلباتك'), findsOneWidget);
      expect(find.byType(MyBrandCard), findsWidgets);
      expect(find.text('تشورو · داشي ديلايت'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wall stands under the seal with the shelf\'s full count', (tester) async {
      final brands = [for (var i = 0; i < 12; i++) BrandSummary.fromJson({..._inaba, 'slug': 'b$i', 'name': 'B$i'})];
      await _pump(tester, BrandWall(brands: brands, total: 74));
      expect(find.text('كل البراندات'), findsOneWidget);
      expect(find.text('أصلي 100٪ — من الموزّع الرسمي مباشرة'), findsOneWidget);
      expect(find.textContaining('74'), findsOneWidget);
      expect(find.byType(BrandWallTile), findsNWidgets(9), reason: 'the wall shows the biggest nine');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a line the shelf cannot send offers the same line to swap in', (tester) async {
      final item = CartItem.fromJson({
        'key': 'k1',
        'product_id': 3,
        'name': 'تشورو تونا',
        'qty': 2,
        'max_reachable': 0,
        'unit_price': 11.73,
        'line_total': 23.46,
      });
      final help = CartLineHelp.fromJson({
        'substitute': {'product': _card(7, 'تشورو جيلي دجاج'), 'same_price': true},
      });
      await _pump(tester, CartSubstituteRow(item: item, help: help, express: true));
      expect(find.text('تشورو تونا نفد في إكسبريس'), findsOneWidget);
      expect(find.text('البديل من نفس الخط · نفس السعر'), findsOneWidget);
      expect(find.text('تشورو جيلي دجاج'), findsOneWidget);
      expect(find.text('استبدل'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
