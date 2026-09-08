import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/settings/app_settings.dart';
import 'location/location_controller.dart';
import 'network/api_client.dart';
import 'session/session_controller.dart';
import 'shelf/shelf_controller.dart';
import 'storage/local_store.dart';
import 'storage/secure_store.dart';

/// Overridden in `main()` with the warmed-up SharedPreferences instance, so
/// every read below is synchronous and no screen has to await storage.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden in main()'),
);

final secureStoreProvider = Provider<SecureStore>((ref) => const SecureStore());

/// Bumped whenever something invalidates *all* catalog reads — a language
/// switch or a delivery-location change. Catalog providers watch it, so one
/// bump refreshes every list, rail and product page at once.
class CatalogRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final catalogRevisionProvider =
    NotifierProvider<CatalogRevision, int>(CatalogRevision.new);

/// Bumped when only the **shelf** moved.
///
/// Separate from [catalogRevisionProvider] on purpose. A location or language
/// change makes every cached body wrong, including the ones the customer is
/// not looking at. A shelf change is narrower: what a product costs and what
/// it is called are the same in both shops — only availability, the delivery
/// promise and which products exist at all differ. So this refreshes the
/// shelf-scoped reads (listings, product pages, rails) and leaves categories
/// and brands to switch to their own per-shelf entry instead of refetching.
class ShelfRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final shelfRevisionProvider =
    NotifierProvider<ShelfRevision, int>(ShelfRevision.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    store: ref.watch(localStoreProvider),
    readToken: () => ref.read(sessionProvider).token,
    readGuestId: () => ref.read(sessionProvider).guestId,
    readLocationHeaders: () => ref.read(locationProvider).location.headersMap(),
    readLanguageCode: () => ref.read(appSettingsProvider).languageCode,
    // The REQUEST, not the answer. If this ever carried the effective shelf,
    // an after-hours downgrade to زوبكسي would be echoed straight back as the
    // customer's ask and the app could never request إكسبريس again.
    readShelf: () => ref.read(shelfProvider).wire,
    // The ANSWER, for the cache key only — so a body served as زوبكسي can
    // never be replayed later under the إكسبريس tab. Both stay `ref.read`
    // closures, and `effectiveShelfProvider` must stay dependency-free, or
    // this line closes a provider cycle.
    readEffectiveShelf: () {
      final Shelf? served = ref.read(effectiveShelfProvider);
      final Shelf shelf = served ?? ref.read(shelfProvider);
      return shelf.wire;
    },
    onAuthRequired: () => ref.read(sessionProvider.notifier).onServerRejectedToken(),
  );
});
