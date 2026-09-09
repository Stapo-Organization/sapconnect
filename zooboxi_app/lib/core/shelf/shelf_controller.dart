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

  /// The shelf the server says it served, or null when it named none.
  ///
  /// `auto` and `''` are deliberately null rather than a guess: they mean the
  /// request carried no tab at all (the website, a build older than the tabs),
  /// and inventing an answer there would be the app telling itself a story.
  static Shelf? fromWire(String? wire) => switch (wire) {
        'express' => Shelf.express,
        'all' => Shelf.all,
        _ => null,
      };
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
    if (!_savedAddressOffersExpress) return Shelf.all;
    return ref.read(localStoreProvider).shelf == Shelf.all.wire ? Shelf.all : Shelf.express;
  }

  /// Whether the saved address was in an open express zone **when it was
  /// chosen**. That is all there is at startup, before any payload has landed,
  /// so it decides the shelf the app opens on — but it is a snapshot of a
  /// moving thing and must never be the last word: see [select].
  bool get _savedAddressOffersExpress =>
      ref.watch(locationProvider.select((s) => s.location.deliveryType)) == 'express';

  /// Switches the storefront. A tap on the dimmed express tab is the caller's
  /// problem to explain; this just refuses it.
  ///
  /// It deliberately does **not** touch the basket. Moving a basket between
  /// storefronts empties the cart, hands every claimed gift back and drops the
  /// restored side's coupons — a real decision, and one the customer already
  /// makes explicitly from the cart screen or from the sheet an add raises. A
  /// tab tap is a glance at the other shop, and a glance must never cost
  /// someone the twelve lines they had collected.
  ///
  /// What the tab tap DOES owe them is honesty about which basket they are
  /// carrying while they browse — that is the cart screen's banner, fed by the
  /// server's own `effective_shelf`.
  void select(Shelf shelf) {
    if (shelf == state) return;
    // Read, not watch, and from [expressAvailableProvider] rather than the
    // saved address: the delivery type was decided the moment that address was
    // picked and does not know the branch has opened since. Asking the snapshot
    // here is what left a lit إكسبريس tab dead to the touch all morning —
    // resolved at 11pm against a shut branch, refusing every tap until the
    // customer re-picked the same address.
    if (shelf == Shelf.express && !ref.read(expressAvailableProvider)) return;
    state = shelf;
    ref.read(localStoreProvider).setShelf(shelf.wire);
    // The server's last answer described the shelf being left. Drop it instead
    // of replacing it with a guess: until the next /home says what was really
    // served, [resolvedShelfProvider] falls back to what was just asked for.
    ref.read(effectiveShelfProvider.notifier).report(null);
    // Only the shelf moved — not the city, not the language. Everything
    // shelf-scoped re-reads; everything else keeps what it already had.
    ref.read(shelfRevisionProvider.notifier).bump();
  }
}

/// The shelf the **server** last said it served, or null before it has said.
///
/// إكسبريس is a place and a time: outside the branch's hours the store answers
/// an إكسبريس request with the زوبكسي shelf — same catalogue, same basket,
/// same promise — and says so in `scope.shelf`. Until the app read that, it
/// kept the ember chrome, the two-hour clock and the express cache key over a
/// shop that was quietly زوبكسي, and a line added there joined a زوبكسي
/// basket that already had زوبكسي products in it.
///
/// This notifier watches and reads **nothing**. That is load-bearing: it is
/// read from `apiClientProvider`'s closures, and a provider with dependencies
/// there would close a cycle. Every write comes from outside — the `/home`
/// listener, a cart response, a location change — never from a build.
class EffectiveShelf extends Notifier<Shelf?> {
  @override
  Shelf? build() => null;

  void report(Shelf? shelf) {
    if (shelf != state) state = shelf;
  }
}

final effectiveShelfProvider =
    NotifierProvider<EffectiveShelf, Shelf?>(EffectiveShelf.new);

/// The shelf the app should actually behave as: the server's answer when it
/// has given one, and the customer's own request until then.
///
/// This is what paints the chrome, keys the caches and names the promise.
/// [shelfProvider] stays the *request* — it alone fills `X-ZB-Shelf`, because
/// a header carrying the downgraded answer would pin the app to زوبكسي and it
/// could never ask for إكسبريس again.
final resolvedShelfProvider = Provider<Shelf>(
  (ref) => ref.watch(effectiveShelfProvider) ?? ref.watch(shelfProvider),
);

final shelfProvider = NotifierProvider<ShelfController, Shelf>(ShelfController.new);

/// Whether the store says إكسبريس serves this address **now**, or null before
/// it has said anything.
///
/// Express is not a property of an address, it is a property of an address at
/// a moment: the branch keeps hours, and the resolver drops it the minute the
/// shutter comes down. The saved delivery type therefore ages — and it was the
/// only thing the app asked. Every `/home` carries the live answer in
/// `scope.express_available`; this is where it lands.
///
/// Like [EffectiveShelf] this notifier watches and reads **nothing**, so it
/// stays safe to consult from anywhere.
class ServedExpress extends Notifier<bool?> {
  @override
  bool? build() => null;

  void report(bool? available) {
    if (available != state) state = available;
  }
}

final servedExpressProvider =
    NotifierProvider<ServedExpress, bool?>(ServedExpress.new);

/// Whether the express storefront exists here right now — what the dimmed tab,
/// its explanation and [ShelfController.select] all hang off.
///
/// The store's own answer when it has given one; the saved address until then.
final expressAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(servedExpressProvider) ??
      (ref.watch(locationProvider.select((s) => s.location.deliveryType)) ==
          'express'),
);
