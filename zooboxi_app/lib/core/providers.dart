import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/settings/app_settings.dart';
import 'location/location_controller.dart';
import 'network/api_client.dart';
import 'session/session_controller.dart';
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

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    store: ref.watch(localStoreProvider),
    readToken: () => ref.read(sessionProvider).token,
    readGuestId: () => ref.read(sessionProvider).guestId,
    readLocationHeaders: () => ref.read(locationProvider).location.headersMap(),
    readLanguageCode: () => ref.read(appSettingsProvider).languageCode,
    onAuthRequired: () => ref.read(sessionProvider.notifier).onServerRejectedToken(),
  );
});
