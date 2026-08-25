import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../account/data/account_repository.dart';
import '../../catalog/data/product_models.dart';

/// The set of wishlisted product ids, kept separate from the product lists
/// themselves.
///
/// Cards arrive from a dozen endpoints, each carrying its own `wishlisted`
/// flag; if the heart read that flag, tapping it on the home rail would leave
/// the same product un-hearted on the search screen. One shared set means
/// every card showing that product flips at once.
class WishlistController extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    // A wishlist belongs to an account; signing out empties it locally too.
    final authed = ref.watch(sessionProvider.select((s) => s.isAuthenticated));
    if (!authed) return const {};
    Future.microtask(load);
    return const {};
  }

  Future<void> load() async {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    try {
      final products = await ref.read(accountRepositoryProvider).wishlist();
      state = products.map((e) => e.id).toSet();
    } catch (_) {
      // Non-fatal: hearts simply stay as the server last told us.
    }
  }

  /// Seeds ids from any payload that carries the flag, so hearts are correct
  /// on first paint instead of popping in after a round trip.
  void seedFrom(Iterable<ProductCard> cards) {
    final wishlisted = cards.where((c) => c.wishlisted).map((c) => c.id).toSet();
    if (wishlisted.isEmpty || wishlisted.every(state.contains)) return;
    state = {...state, ...wishlisted};
  }

  bool contains(int productId) => state.contains(productId);

  /// Flips the heart immediately and reconciles with the server. Returns the
  /// resulting state so the caller can pick the right toast.
  Future<bool> toggle(int productId) async {
    final wasWishlisted = state.contains(productId);
    state = wasWishlisted
        ? (state.toSet()..remove(productId))
        : (state.toSet()..add(productId));

    try {
      final result = await ref.read(accountRepositoryProvider).toggleWishlist(productId);
      state = result.wishlisted
          ? (state.toSet()..add(productId))
          : (state.toSet()..remove(productId));
      return result.wishlisted;
    } catch (e) {
      state = wasWishlisted
          ? (state.toSet()..add(productId))
          : (state.toSet()..remove(productId));
      rethrow;
    }
  }
}

final wishlistControllerProvider =
    NotifierProvider<WishlistController, Set<int>>(WishlistController.new);

/// Whether one specific product is wishlisted — lets a card rebuild alone
/// instead of every card on the screen.
final isWishlistedProvider = Provider.family<bool, int>(
  (ref, productId) => ref.watch(wishlistControllerProvider).contains(productId),
);

/// The wishlist screen's product list.
///
/// Deliberately *not* watching the id set: un-hearting an item should remove
/// it from the list instantly, which the screen does by filtering against the
/// set — re-fetching the whole list on every heart tap anywhere in the app
/// would be a network call per tap.
final wishlistProductsProvider =
    FutureProvider.autoDispose<List<ProductCard>>((ref) async {
  if (!ref.watch(sessionProvider).isAuthenticated) return const [];
  final products = await ref.watch(accountRepositoryProvider).wishlist();
  ref.read(wishlistControllerProvider.notifier).seedFrom(products);
  return products;
});
