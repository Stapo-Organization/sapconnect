import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/motion.dart';
import '../core/session/session_controller.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/account/presentation/address_book_screen.dart';
import '../features/account/presentation/buy_again_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/catalog/data/catalog_models.dart';
import '../features/catalog/data/product_models.dart';
import '../features/catalog/presentation/categories_screen.dart';
import '../features/catalog/presentation/listing_screen.dart';
import '../features/checkout/data/checkout_models.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/checkout/presentation/success_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/orders/presentation/order_detail_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/payment/presentation/payment_screen.dart';
import '../features/product/presentation/product_screen.dart';
import '../features/search/presentation/scanner_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/wishlist/presentation/wishlist_screen.dart';
import 'shell/main_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Bridges Riverpod's session state into go_router's refresh mechanism.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<SessionState>(sessionProvider, (_, _) => notifyListeners());
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>(_RouterNotifier.new);

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    // Auth deliberately does NOT gate navigation. This is a storefront: a
    // guest browses, searches and fills a basket exactly like a customer.
    // Sign-in is asked for in a sheet at the moment it's actually needed, and
    // the interrupted action resumes — so there is no redirect here beyond
    // holding on the splash until the keychain has been read.
    redirect: (context, state) {
      final ready = ref.read(sessionProvider).isReady;
      final onSplash = state.matchedLocation == '/splash';
      if (!ready) return onSplash ? null : '/splash';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),

      GoRoute(
        path: '/product/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(
          state.pageKey,
          ProductScreen(
            productId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            // The card that was tapped, so the page can paint its image,
            // name and price before the detail request lands.
            preview: state.extra is ProductCard ? state.extra! as ProductCard : null,
          ),
        ),
      ),
      GoRoute(
        path: '/listing',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(
          state.pageKey,
          ListingScreen(
            title: state.uri.queryParameters['title'] ?? '',
            query: state.extra is ListingQuery
                ? state.extra! as ListingQuery
                : ListingQuery.fromJson(state.uri.queryParameters),
          ),
        ),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(state.pageKey, const SearchScreen()),
      ),
      GoRoute(
        path: '/scan',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => slideUpPage(state.pageKey, const ScannerScreen()),
      ),
      GoRoute(
        path: '/wishlist',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(state.pageKey, const WishlistScreen()),
      ),
      GoRoute(
        path: '/orders',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(state.pageKey, const OrdersScreen()),
      ),
      GoRoute(
        path: '/orders/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(
          state.pageKey,
          OrderDetailScreen(
            orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: '/addresses',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(state.pageKey, const AddressBookScreen()),
      ),
      GoRoute(
        path: '/buy-again',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(state.pageKey, const BuyAgainScreen()),
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => slideUpPage(state.pageKey, const CheckoutScreen()),
      ),
      // Both of these are reached with a PlacedOrder in `extra` — the order is
      // already real, so if the object is missing (a cold deep link) the only
      // honest destination is the order history.
      GoRoute(
        path: '/checkout/pay',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (_, state) => state.extra is PlacedOrder ? null : '/orders',
        pageBuilder: (_, state) => slideUpPage(
          state.pageKey,
          PaymentScreen(order: state.extra! as PlacedOrder),
        ),
      ),
      GoRoute(
        path: '/checkout/done',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (_, state) => state.extra is PlacedOrder ? null : '/orders',
        pageBuilder: (_, state) => slideUpPage(
          state.pageKey,
          CheckoutSuccessScreen(order: state.extra! as PlacedOrder),
        ),
      ),

      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/cart', builder: (_, _) => const CartScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/account', builder: (_, _) => const AccountScreen())],
          ),
        ],
      ),
    ],
  );
});
