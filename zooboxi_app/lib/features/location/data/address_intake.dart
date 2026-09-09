import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_controller.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../account/data/account_models.dart';
import '../../account/data/addresses_controller.dart';

/// How keeping a freshly pinned address ended.
enum AddressIntake {
  /// Kept where it belongs, and the shop is now delivering to it.
  applied,

  /// The server refused to keep it. The device did — the address is not lost,
  /// and checkout will still find it — but nothing may claim it was saved.
  refused,
}

/// Takes an address the customer just pinned, keeps it, and delivers to it.
///
/// One path, shared by every screen that can produce a pin: the location
/// sheet, the drift sheet, checkout. The rules it enforces are the ones that
/// were expensive to learn:
///
///  * a signed-in customer's address goes in their book; a guest's goes on
///    the device, where checkout and the next sign-in both look for it;
///  * a refused save must never cost the customer the address — the device
///    keeps it, and it must **not** keep the id of the entry the server did
///    not update, or the order would go to that address's old pin;
///  * editing the address we are already delivering to is the book's own
///    business — [AddressesController.save] moves the point with it, so
///    resolving again here would only spend a second round trip.
///
/// Every notifier is read before the first await: the sheet that started this
/// can be swiped away mid-flight, and the address must survive that.
Future<AddressIntake> adoptAddress(WidgetRef ref, Address address) async {
  final loggedIn = ref.read(sessionProvider).isAuthenticated;
  final book = ref.read(addressesControllerProvider.notifier);
  final store = ref.read(localStoreProvider);
  final location = ref.read(locationProvider.notifier);
  final activeId = ref.read(locationProvider).location.addressId;

  Address? stored;
  var refused = false;
  if (loggedIn) {
    try {
      stored = await book.save(address);
    } catch (_) {
      refused = true;
    }
  }

  if (stored == null) {
    await store.setPendingAddress(address.toJson());
  }

  final lat = stored?.lat ?? address.lat;
  final lng = stored?.lng ?? address.lng;
  final alreadyMoved = stored != null && stored.id == activeId;
  if (lat != null && lng != null && !alreadyMoved) {
    await location.resolve(
      lat,
      lng,
      addressId: stored?.id,
      label: stored?.label ?? address.label,
    );
  }

  return refused ? AddressIntake.refused : AddressIntake.applied;
}
