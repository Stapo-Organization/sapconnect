import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/shelf/shelf_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';

/// إكسبريس and زوبكسي are two shops with a basket each, and the one on screen
/// must be the one the tab belongs to. The store owns the move; this covers
/// what the app owes it — ask only when there is something to move, ask once
/// however fast the tabs are tapped, never blank a basket on a failed ask, and
/// never let a basket be put away in silence.

/// A little store that behaves like the real one: it keeps ONE live basket
/// plus whatever is stashed beside it, and aligns to the shelf the app says it
/// is browsing — which it reads the same way the server does, from the request
/// rather than from a name the app chose.
class _Repo implements CartRepository {
  _Repo({this.shelf = '', this.count = 0, Map<String, int>? waiting, this.fails = false})
      : waiting = {...?waiting};

  /// Resolved lazily so the repo can read the container it is installed in.
  late String Function() browsing;

  String shelf;
  int count;
  final Map<String, int> waiting;
  bool fails;

  int aligns = 0;
  int fetches = 0;

  String get _other => shelf == 'express' ? 'all' : 'express';

  CartData get snapshot {
    final other = shelf.isEmpty
        ? (waiting.keys.isEmpty ? '' : waiting.keys.first)
        : _other;
    return CartData(
      count: count,
      basket: CartBasket(
        shelf: shelf,
        otherShelf: other,
        otherCount: other.isEmpty ? 0 : (waiting[other] ?? 0),
      ),
    );
  }

  @override
  Future<({CartData cart, BasketMove? move})> alignBasket() async {
    aligns++;
    if (fails) throw StateError('the store said no');

    final target = browsing();
    // The store's own guards: already there, or nothing on either side.
    if (shelf == target || (shelf.isEmpty && (waiting[target] ?? 0) == 0)) {
      return (cart: snapshot, move: null);
    }

    final from = shelf;
    final stashed = count;
    if (from.isNotEmpty && count > 0) waiting[from] = count;
    final restored = waiting.remove(target) ?? 0;
    shelf = target;
    count = restored;

    return (
      cart: snapshot,
      move: BasketMove(
        to: target,
        from: from,
        auto: true,
        restored: restored,
        stashed: stashed,
        notices: stashed > 0
            ? const [CartNotice(type: 'notice', text: 'حفظنا سلتك')]
            : const [],
      ),
    );
  }

  @override
  Future<CartData> fetch() async {
    fetches++;
    return snapshot;
  }

  @override
  Future<CartData> addItem({
    required int productId,
    int? variationId,
    int quantity = 1,
    Map<String, String>? attributes,
  }) async => snapshot;

  @override
  Future<CartData> switchBasket(String shelf) async => snapshot;

  @override
  Future<CartData> setQuantity(String key, int quantity) async => snapshot;

  @override
  Future<CartData> removeItem(String key) async => snapshot;

  @override
  Future<CartData> applyCoupon(String code) async => snapshot;

  @override
  Future<CartData> removeCoupon(String code) async => snapshot;
}

Future<ProviderContainer> _container(_Repo repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
      cartRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  repo.browsing = () => container.read(shelfProvider).wire;
  return container;
}

void main() {
  group('when the basket is asked to move', () {
    test('it is not, when it is already on the shelf being browsed', () async {
      final repo = _Repo(shelf: 'all', count: 2);
      final container = await _container(repo);
      await container.read(cartControllerProvider.future);

      expect(
        await container.read(cartControllerProvider.notifier).alignToShelf('all'),
        isNull,
      );
      expect(repo.aligns, 0, reason: 'no round trip for a basket already in place');
    });

    test('it is not, when there is no basket here and none waiting there', () async {
      final repo = _Repo();
      final container = await _container(repo);
      await container.read(cartControllerProvider.future);

      await container.read(cartControllerProvider.notifier).alignToShelf('express');
      expect(repo.aligns, 0, reason: 'two empty baskets have nothing to swap');
    });

    test('it is, when a basket is waiting on the shelf being opened', () async {
      // Nothing in the cart, three lines waiting under زوبكسي — the shelf this
      // container is browsing, which is what the store aligns to.
      final repo = _Repo(waiting: {'all': 3});
      final container = await _container(repo);
      await container.read(cartControllerProvider.future);

      await container.read(cartControllerProvider.notifier).alignToShelf('all');
      expect(repo.aligns, 1);
      expect(container.read(cartControllerProvider).value?.count, 3);
    });

    test('it is, when the basket belongs to the other storefront', () async {
      final repo = _Repo(shelf: 'express', count: 4);
      final container = await _container(repo);
      await container.read(cartControllerProvider.future);

      await container.read(cartControllerProvider.notifier).alignToShelf('all');
      expect(repo.aligns, 1);
      expect(repo.waiting['express'], 4, reason: 'kept, not discarded');
    });

    test('a refused move leaves the basket the customer was looking at', () async {
      final repo = _Repo(shelf: 'express', count: 4, fails: true);
      final container = await _container(repo);
      await container.read(cartControllerProvider.future);

      expect(
        await container.read(cartControllerProvider.notifier).alignToShelf('all'),
        isNull,
      );
      expect(container.read(cartControllerProvider).value?.count, 4);
      expect(container.read(cartControllerProvider).hasError, isFalse);
    });
  });

  group('when the tab moves', () {
    /// Opens on زوبكسي with an إكسبريس basket — the exact state the owner
    /// described — and walks the two tabs.
    Future<(ProviderContainer, _Repo)> open() async {
      final repo = _Repo(shelf: 'express', count: 4);
      final container = await _container(repo);
      await container.read(cartControllerProvider.future);
      container.read(basketFollowsShelfProvider);
      container.read(servedExpressProvider.notifier).report(true);
      await Future<void>.delayed(Duration.zero);
      return (container, repo);
    }

    test('the basket the app opens with is the one the tab belongs to', () async {
      final (container, repo) = await open();
      // The startup alignment: the tab says زوبكسي, so the إكسبريس basket is
      // put away rather than being carried under the wrong sign.
      expect(repo.shelf, 'all');
      expect(repo.waiting['express'], 4);
      expect(container.read(cartCountProvider), 0);
    });

    test('crossing to the other shop brings that shop\'s basket back whole', () async {
      final (container, repo) = await open();

      container.read(shelfProvider.notifier).select(Shelf.express);
      await Future<void>.delayed(Duration.zero);

      expect(repo.shelf, 'express');
      expect(container.read(cartCountProvider), 4, reason: 'all four lines returned');
      expect(repo.waiting, isEmpty);
    });

    test('and crossing back puts it away again — the two never mix', () async {
      final (container, repo) = await open();

      container.read(shelfProvider.notifier).select(Shelf.express);
      await Future<void>.delayed(Duration.zero);
      container.read(shelfProvider.notifier).select(Shelf.all);
      await Future<void>.delayed(Duration.zero);

      expect(repo.shelf, 'all');
      expect(repo.waiting['express'], 4);
      expect(container.read(cartCountProvider), 0);
    });

    test('tapping the shelf already open asks the store nothing', () async {
      final (container, repo) = await open();
      final before = repo.aligns;

      container.read(shelfProvider.notifier).select(Shelf.all);
      await Future<void>.delayed(Duration.zero);

      expect(repo.aligns, before);
    });

    test('a basket put away is announced, never in silence', () async {
      final (container, _) = await open();
      expect(container.read(basketMoveProvider)?.stashed, 4);
      expect(container.read(basketMoveProvider)?.notices, isNotEmpty);
    });
  });

  group('what the customer is told', () {
    test('a move that carried nothing is not worth interrupting anyone', () async {
      final container = await _container(_Repo());
      container.read(basketMoveProvider.notifier).post(
            const BasketMove(to: 'all', from: 'express'),
          );
      expect(container.read(basketMoveProvider), isNull);
    });

    test('a basket that was put away is announced once', () async {
      final container = await _container(_Repo());
      container.read(basketMoveProvider.notifier).post(
            const BasketMove(to: 'all', from: 'express', stashed: 3),
          );
      expect(container.read(basketMoveProvider)?.stashed, 3);

      container.read(basketMoveProvider.notifier).clear();
      expect(container.read(basketMoveProvider), isNull);
    });
  });

  group('what the store said it did', () {
    test('«nothing moved» is not a move', () {
      expect(BasketMove.maybe(const {'moved': false, 'to': 'all'}), isNull);
      expect(BasketMove.maybe(null), isNull);
      expect(BasketMove.maybe(const <String, dynamic>{}), isNull);
    });

    test('a move carries what it moved, and the sentences that explain it', () {
      final move = BasketMove.maybe(
        const {
          'moved': true,
          'to': 'all',
          'from': 'express',
          'auto': true,
          'restored': 2,
          'stashed': 3,
          'lost': 1,
        },
        notices: const [CartNotice(type: 'notice', text: 'حفظنا ٣ أصناف')],
      );
      expect(move, isNotNull);
      expect(move!.to, 'all');
      expect(move.from, 'express');
      expect(move.auto, isTrue);
      expect(move.restored, 2);
      expect(move.stashed, 3);
      expect(move.lost, 1);
      expect(move.isQuiet, isFalse);
      expect(move.notices.single.text, 'حفظنا ٣ أصناف');
    });

    test('a store too old to say anything moves nothing worth saying', () {
      final move = BasketMove.maybe(const {'to': 'all', 'restored': 0});
      expect(move, isNotNull);
      expect(move!.isQuiet, isTrue);
    });
  });
}
