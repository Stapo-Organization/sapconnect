import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/network/api_exception.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/cart/presentation/add_to_cart.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// إكسبريس and زوبكسي are two shops, and an order is one or the other. The
/// rule lives on the server — this covers what the app owes it: never turn the
/// refusal into an error message, ask the question instead, and only move the
/// basket when the customer says so.

const _product = ProductCard(id: 42, name: 'رمل قطط', price: 39);

const _defaultConflict = {
  'shelf': 'express',
  'other_shelf': 'all',
  'other_count': 2,
  'started': true,
};

const _expressBasket = CartBasket(
  shelf: 'express',
  otherShelf: 'all',
  otherCount: 2,
);

class _Repo implements CartRepository {
  _Repo({this.conflict = true, this.conflictData = _defaultConflict});

  final Map<String, Object?> conflictData;

  /// The server refuses the first add: the basket is the other storefront's.
  bool conflict;

  int adds = 0;
  final List<String> switches = [];

  @override
  Future<CartData> addItem({
    required int productId,
    int? variationId,
    int quantity = 1,
    Map<String, String>? attributes,
  }) async {
    adds++;
    if (conflict) {
      throw ApiException(
        type: ApiErrorType.validation,
        code: 'shelf_conflict',
        statusCode: 409,
        messageAr: 'سلتك من متجر آخر',
        data: conflictData,
      );
    }
    return const CartData(
      items: [CartItem(key: 'k', productId: 42, name: 'رمل قطط', qty: 1, unitPrice: 39, lineTotal: 39)],
      count: 1,
      basket: CartBasket(shelf: 'all', otherShelf: 'express', otherCount: 3),
    );
  }

  @override
  Future<CartData> switchBasket(String shelf) async {
    switches.add(shelf);
    conflict = false;
    return const CartData(basket: CartBasket(shelf: 'all', otherShelf: 'express', otherCount: 3));
  }

  @override
  Future<CartData> fetch() async => const CartData(basket: _expressBasket);

  @override
  Future<CartData> setQuantity(String key, int quantity) async => fetch();

  @override
  Future<CartData> removeItem(String key) async => fetch();

  @override
  Future<CartData> applyCoupon(String code) async => fetch();

  @override
  Future<CartData> removeCoupon(String code) async => fetch();
}

Future<_Repo> _pump(
  WidgetTester tester, {
  bool conflict = true,
  Map<String, Object?> conflictData = _defaultConflict,
}) async {
  final repo = _Repo(conflict: conflict, conflictData: conflictData);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore(prefs)),
        cartRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => addToCart(context, ref, product: _product, quiet: true),
                child: const Text('أضف'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a basket from the other store is a question, not an error',
      (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('أضف'));
    await tester.pumpAndSettle();

    // The refusal never reaches the customer as a failure.
    expect(find.text('تنتقل إلى سلة زوبكسي؟'), findsOneWidget);
    expect(find.textContaining('سلتك الحالية من متجر إكسبريس'), findsOneWidget);
    // And it says what is waiting on the other side, in Arabic that agrees
    // with the number: two products are «منتجان», not «2 منتج».
    expect(find.textContaining('منتجان'), findsOneWidget);
    expect(repo.switches, isEmpty, reason: 'nothing moves until they say so');
  });

  testWidgets('cancelling leaves the basket exactly where it was',
      (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('أضف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(repo.switches, isEmpty);
    expect(repo.adds, 1, reason: 'the add was not retried behind their back');
  });

  testWidgets('accepting swaps the basket and completes the add', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('أضف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('افتح سلة زوبكسي'));
    await tester.pumpAndSettle();

    expect(repo.switches, ['all'], reason: 'moved to the storefront being browsed');
    expect(repo.adds, 2, reason: 'the product the customer asked for lands');
    // The success haptic pauses between its two taps, and the toast dismisses
    // itself three seconds later: both outlive the tree unless drained.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('an ordinary add still just adds', (tester) async {
    final repo = await _pump(tester, conflict: false);

    await tester.tap(find.text('أضف'));
    await tester.pumpAndSettle();

    expect(repo.adds, 1);
    expect(repo.switches, isEmpty);
    expect(find.text('تنتقل إلى سلة زوبكسي؟'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a product from the other store, with no basket yet, says so',
      (tester) async {
    // The customer is on the إكسبريس tab and taps something only the main
    // warehouse holds — from a wishlist, a barcode, a shared link. There is
    // no basket to leave, so the sentence must not claim there is one.
    final repo = await _pump(
      tester,
      conflictData: const {
        'shelf': 'express',
        'other_shelf': 'all',
        'other_count': 0,
        'started': false,
      },
    );

    await tester.tap(find.text('أضف'));
    await tester.pumpAndSettle();

    expect(find.text('هذا المنتج من متجر زوبكسي، والطلب الواحد يكون من متجر واحد.'),
        findsOneWidget);
    expect(find.textContaining('سلتك الحالية'), findsNothing);

    await tester.tap(find.text('افتح سلة زوبكسي'));
    await tester.pumpAndSettle();
    expect(repo.switches, ['all']);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  group('the basket names the shop it belongs to', () {
    test('a basket and a shop that agree is not a mismatch', () {
      const basket = CartBasket(shelf: 'express', effectiveShelf: 'express');
      expect(basket.mismatched, isFalse);
    });

    test('a زوبكسي basket while the store serves إكسبريس is', () {
      const basket = CartBasket(shelf: 'all', effectiveShelf: 'express');
      expect(basket.mismatched, isTrue);
    });

    test('an empty basket disagrees with nothing', () {
      // No basket yet: the honest sentence is «this product is from the other
      // store», not «your basket is».
      const basket = CartBasket(shelf: '', effectiveShelf: 'express');
      expect(basket.mismatched, isFalse);
    });

    test('a store that never spoke is never contradicted', () {
      // An older store build sends no effective_shelf. Reading its silence as
      // a disagreement would put a warning on every cart in the field.
      const basket = CartBasket(shelf: 'express');
      expect(basket.mismatched, isFalse);
    });

    test('a store that never spoke is assumed able to serve', () {
      final basket = CartBasket.fromJson(const {
        'shelf': 'express',
        'other_shelf': 'all',
        'other_count': 2,
      });
      expect(basket.otherServes, isTrue);
      expect(basket.effectiveShelf, '');
      expect(basket.otherSince, isNull);
    });

    test('the wait is read as a moment, not a number', () {
      final basket = CartBasket.fromJson({
        'shelf': 'express',
        'other_shelf': 'all',
        'other_count': 2,
        'other_serves': false,
        'other_since': 1757000000,
      });
      expect(basket.otherServes, isFalse);
      expect(basket.otherSince, DateTime.fromMillisecondsSinceEpoch(1757000000 * 1000));
    });

    test('a nonsense stamp is no stamp at all', () {
      final basket = CartBasket.fromJson(const {'shelf': 'all', 'other_since': 0});
      expect(basket.otherSince, isNull);
    });
  });

  /// Home listens for this and nothing else about the basket. Every answer
  /// from the server decodes a fresh instance, so without value equality the
  /// whole storefront rebuilt on a quantity tap that never moved the bar.
  group('the free-delivery bar is a value', () {
    test('two bars at the same point are the same bar', () {
      const a = FreeShipping(min: 200, remaining: 40);
      const b = FreeShipping(min: 200, remaining: 40);
      expect(FreeShipping.fromJson(const {'min': 200, 'remaining': 40}), a);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a bar that moved is a different bar', () {
      expect(const FreeShipping(min: 200, remaining: 40),
          isNot(const FreeShipping(min: 200, remaining: 25)));
      expect(const FreeShipping(min: 200, remaining: 0, qualified: true),
          isNot(const FreeShipping(min: 200, remaining: 0)));
    });
  });
}
