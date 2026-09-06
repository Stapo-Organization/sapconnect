import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/location_controller.dart';
import '../providers.dart';

/// Which storefront the customer is browsing — the app's two top tabs.
enum Shelf {
  /// The 2-hour dark store: only what the nearest open express branch holds.
  express('express'),

  /// The full store: everything that can reach this address at all.
  all('all');

  const Shelf(this.wire);

  /// The value the `X-ZB-Shelf` header carries.
  final String wire;
}

/// The selected shelf, derived from where the customer stands and what they
/// last chose.
///
/// Express is a place, not a setting: it exists only while the customer is
/// inside an express zone. So the state is *derived* — location changes
/// rebuild it — and the customer's own choice is remembered on top: someone
/// who prefers browsing the full store keeps it, and someone who loses
/// express by moving is put back on it when they return.
class ShelfController extends Notifier<Shelf> {
  @override
  Shelf build() {
    if (!expressAvailable) return Shelf.all;
    return ref.read(localStoreProvider).shelf == Shelf.all.wire ? Shelf.all : Shelf.express;
  }

  /// Whether the express tab is open where the customer stands. The server's
  /// location resolver decided this when the address was set — the same
  /// authority the cart's promises come from.
  bool get expressAvailable =>
      ref.watch(locationProvider.select((s) => s.location.deliveryType)) == 'express';

  /// Switches the storefront. A tap on the dimmed express tab is the caller's
  /// problem to explain; this just refuses it.
  void select(Shelf shelf) {
    if (shelf == state) return;
    if (shelf == Shelf.express && !expressAvailable) return;
    state = shelf;
    ref.read(localStoreProvider).setShelf(shelf.wire);
    // The whole catalogue speaks through this header: every open list, rail
    // and count now describes another shelf.
    ref.read(catalogRevisionProvider.notifier).bump();
  }
}

final shelfProvider = NotifierProvider<ShelfController, Shelf>(ShelfController.new);

/// Whether the express storefront exists at the current address — what the
/// dimmed tab and its explanation hang off.
final expressAvailableProvider = Provider<bool>(
  (ref) => ref.watch(locationProvider.select((s) => s.location.deliveryType)) == 'express',
);
