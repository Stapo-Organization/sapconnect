import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/shelf/shelf_controller.dart';
import '../../loyalty/data/loyalty_models.dart';
import '../../loyalty/data/loyalty_repository.dart';
import 'cart_models.dart';
import 'cart_repository.dart';

/// What an add attempt actually did. [added] is the honest answer: the line
/// exists in the returned cart. A 200 whose cart lacks the product — the
/// fulfilment guard trims what can't reach this location — is NOT an add.
typedef AddResult = ({bool added, List<CartNotice> notices});

/// The server owns the cart; this controller owns *responsiveness*.
///
/// A quantity tap must move the number now, not in 300ms — but the server is
/// the only thing that knows whether the extra unit actually reaches this
/// customer. So taps apply locally, coalesce for [_debounce], then post once;
/// if the server disagrees, its answer replaces the optimistic state and its
/// notice is surfaced rather than swallowed.
///
/// Every network call runs through one serial queue. The WC session is a
/// single blob: two concurrent requests each load it, and whichever saves
/// last resurrects what the other deleted — and even without that, adopting
/// responses out of order replays an old cart over a newer one. One request
/// in flight at a time removes both failure modes at the root.
class CartController extends AsyncNotifier<CartData> {
  static const Duration _debounce = Duration(milliseconds: 400);

  /// The tail of the serial queue. Errors are contained per-op, so one failed
  /// call never poisons the chain for the next.
  Future<void> _chain = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final run = _chain.then((_) => op());
    _chain = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Adopts a server cart, re-applying any quantity the customer has tapped
  /// since that request was posted — server truth for the lines, the
  /// customer's newer intent for the numbers still in flight.
  void _adopt(CartData cart, {bool collect = true}) {
    var next = cart;
    _targetQty.forEach((key, qty) => next = next.withItemQty(key, qty));
    state = AsyncValue.data(next);
    // `add` hands its notices straight back to the toast; collecting them
    // here as well would show the same message twice.
    if (collect) _collect(cart.notices);
  }

  /// Replaces whatever optimism is on screen with the server's actual cart —
  /// the recovery move after a failed write, instead of restoring a stale
  /// snapshot that may predate other successful changes.
  Future<void> _adoptTruth() async {
    try {
      _adopt(await ref.read(cartRepositoryProvider).fetch());
    } catch (_) {
      // Leave the screen as is; the next successful call resyncs.
    }
  }

  final Map<String, Timer> _pending = {};

  /// The last quantity the customer asked for per line, so a rapid ++ ++ ++
  /// posts once with the final number instead of three times.
  final Map<String, int> _targetQty = {};

  /// Notices from the last server round-trip that a screen has not shown yet.
  /// Drained by the cart screen so a cap message can't be missed.
  final List<CartNotice> _undelivered = [];

  @override
  Future<CartData> build() async {
    // Signing in merges the guest basket server-side; the location decides
    // what is even reachable. Either changing means re-reading the cart.
    ref.watch(sessionProvider.select((s) => s.status));
    ref.watch(locationProvider.select((s) => s.location.warehouseCode));

    ref.onDispose(() {
      for (final timer in _pending.values) {
        timer.cancel();
      }
      _pending.clear();
    });

    return ref.read(cartRepositoryProvider).fetch();
  }

  CartData get _current => state.value ?? CartData.empty;

  /// Pulls notices the UI hasn't shown yet, clearing them so they show once.
  List<CartNotice> drainNotices() {
    if (_undelivered.isEmpty) return const [];
    final drained = List<CartNotice>.from(_undelivered);
    _undelivered.clear();
    return drained;
  }

  Future<void> refresh() async {
    try {
      final result = await _serial(() => ref.read(cartRepositoryProvider).fetch());
      _adopt(result);
    } catch (e, st) {
      // A failed refresh must not blank a cart the customer is looking at.
      if (!state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  /// Adopts a cart the server handed back outside the usual read path.
  ///
  /// `cart_changed` at checkout is the case: the refusal *carries* the freshly
  /// re-priced basket, so taking it here saves a round trip and — more to the
  /// point — guarantees the customer is shown exactly the cart the server
  /// refused to charge for, not a second fetch that might differ again.
  void applyServerCart(CartData cart) {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    _targetQty.clear();
    state = AsyncValue.data(cart);
    _collect(cart.notices);
  }

  /// Adds to the cart. Throws [ApiException] on a refused request; a request
  /// the server accepted but whose cart came back WITHOUT the product (the
  /// fulfilment guard trimmed it for this location) returns `added: false`
  /// with the server's notice — so no caller can celebrate an add that never
  /// happened.
  /// Swaps the basket for the other storefront's, then adopts the server's
  /// answer. The basket left behind waits on the server.
  Future<void> switchBasket(String shelf) async {
    final result = await _serial(
      () => ref.read(cartRepositoryProvider).switchBasket(shelf),
    );
    _targetQty.clear();
    // Notices ARE collected here: a line that went out of stock while the
    // basket waited comes back as one, and a basket that quietly returns
    // shorter than it left is the one thing this feature must not do.
    _adopt(result);
  }

  /// Puts the basket on the shelf now being browsed, and reports what moved.
  ///
  /// إكسبريس and زوبكسي are two shops with a basket each. Whichever one is on
  /// screen must be the one the tab belongs to, or the customer is carrying
  /// the other shop's bag: their count is wrong, their free-delivery line is
  /// the other store's, and every line they add is a question instead of an
  /// add. So the basket follows them.
  ///
  /// The store is asked to align to the shelf IT is serving this request as,
  /// not to a name the app chooses — after closing time an إكسبريس tab is
  /// زوبكسي, and only the store knows that. Failure is silent on purpose: an
  /// alignment that could not happen leaves the basket exactly where it was,
  /// and the add path still raises its own question if it matters.
  Future<BasketMove?> alignToShelf(String shelf) async {
    if (shelf.isEmpty) return null;
    try {
      return await _serial(() async {
        // Judged INSIDE the queue, so a tap made while another alignment was
        // in flight reads the basket that call left behind rather than the
        // one it found. Tapping across and back costs one round trip, not two.
        final basket = _current.basket;
        if (basket.shelf == shelf) return null;
        final waiting = basket.otherShelf == shelf && basket.otherCount > 0;
        // Nothing here and nothing waiting there: there is no basket to move.
        // The label is left alone too — an empty basket belongs to nobody, and
        // the first line added names the shelf it was added on.
        if (basket.shelf.isEmpty && !waiting) return null;

        final result = await ref.read(cartRepositoryProvider).alignBasket();
        _targetQty.clear();
        // Not collected: these notices are handed to the caller so they are
        // spoken NOW, next to the badge that just changed, instead of waiting
        // for the customer to open the cart screen and find out then.
        _adopt(result.cart, collect: false);
        return result.move;
      });
    } catch (_) {
      return null;
    }
  }

  Future<AddResult> add({
    required int productId,
    int? variationId,
    int quantity = 1,
    Map<String, String>? attributes,
  }) async {
    final result = await _serial(
      () => ref.read(cartRepositoryProvider).addItem(
            productId: productId,
            variationId: variationId,
            quantity: quantity,
            attributes: attributes,
          ),
    );
    _adopt(result, collect: false);
    final added = result.items.any(
      (item) =>
          item.productId == productId &&
          (variationId == null || item.variationId == variationId) &&
          item.qty > 0,
    );
    return (added: added, notices: result.notices);
  }

  /// Optimistic quantity change. Returns immediately; the network settles later.
  void setQuantity(String key, int quantity) {
    final snapshot = _current;
    final item = snapshot.items.where((e) => e.key == key).firstOrNull;
    if (item == null) return;

    final cap = item.maxReachable;
    final clamped = cap == null ? quantity : quantity.clamp(1, cap < 1 ? 1 : cap);
    if (clamped == item.qty && !_pending.containsKey(key)) return;

    _targetQty[key] = clamped;
    state = AsyncValue.data(snapshot.withItemQty(key, clamped));

    _pending[key]?.cancel();
    _pending[key] = Timer(_debounce, () => _flushQuantity(key));
  }

  Future<void> _flushQuantity(String key) async {
    _pending.remove(key);
    try {
      final result = await _serial(() async {
        // Read the target inside the queue slot: taps that landed while an
        // earlier call held the queue collapse into this one post.
        final target = _targetQty[key];
        if (target == null) return null;
        final posted = await ref.read(cartRepositoryProvider).setQuantity(key, target);
        // Only clear if the customer hasn't tapped again meanwhile.
        if (_targetQty[key] == target) _targetQty.remove(key);
        return posted;
      });
      if (result != null) _adopt(result);
    } on ApiException catch (e) {
      // The truth, not a stale snapshot: rolling back to a capture from
      // before this burst would also erase every OTHER change that landed
      // since — which is exactly how "added items vanish" looked.
      _targetQty.remove(key);
      await _adoptTruth();
      _collect([
        CartNotice(type: 'error', text: e.messageAr ?? e.messageEn ?? ''),
      ]);
    } catch (_) {
      _targetQty.remove(key);
      await _adoptTruth();
    }
  }

  Future<void> remove(String key) async {
    _pending.remove(key)?.cancel();
    _targetQty.remove(key);

    state = AsyncValue.data(_current.withoutItem(key));
    try {
      final result = await _serial(() => ref.read(cartRepositoryProvider).removeItem(key));
      _adopt(result);
    } catch (_) {
      await _adoptTruth();
      rethrow;
    }
  }

  /// Carries an active reward into the basket.
  ///
  /// It runs through the *same* serial queue as every other cart write, and
  /// adopts the cart the server hands back — a gift line is the server's to
  /// add, at the server's price, and splicing a zero-price line locally would
  /// be a promise the checkout could refuse to keep.
  Future<Grant> claimGrant(int grantId) async {
    final result =
        await _serial(() => ref.read(loyaltyRepositoryProvider).claim(grantId));
    _adopt(result.cart);
    return result.grant;
  }

  /// Releases a claim — which is what removing a gift line means. The grant
  /// goes back to `active` and can be used on another basket.
  Future<Grant> releaseGrant(int grantId) async {
    final result =
        await _serial(() => ref.read(loyaltyRepositoryProvider).unclaim(grantId));
    _adopt(result.cart);
    return result.grant;
  }

  Future<void> applyCoupon(String code) async {
    final result = await _serial(() => ref.read(cartRepositoryProvider).applyCoupon(code));
    _adopt(result);
  }

  Future<void> removeCoupon(String code) async {
    final result = await _serial(() => ref.read(cartRepositoryProvider).removeCoupon(code));
    _adopt(result);
  }

  void _collect(List<CartNotice> notices) {
    for (final notice in notices) {
      if (notice.text.trim().isEmpty) continue;
      _undelivered.add(notice);
    }
  }
}

final cartControllerProvider =
    AsyncNotifierProvider<CartController, CartData>(CartController.new);

/// The last basket move nobody has said out loud yet.
///
/// A move the customer did not press a button for has to be announced beside
/// the badge it changed, and only a widget can do that — so the alignment
/// leaves its sentence here and the shell speaks it.
class BasketMoveInbox extends Notifier<BasketMove?> {
  @override
  BasketMove? build() => null;

  /// Quiet moves are dropped: two empty baskets swapping places is not news.
  void post(BasketMove? move) {
    if (move == null || move.isQuiet) return;
    state = move;
  }

  void clear() {
    if (state != null) state = null;
  }
}

final basketMoveProvider =
    NotifierProvider<BasketMoveInbox, BasketMove?>(BasketMoveInbox.new);

/// Keeps the live basket on the storefront being browsed.
///
/// The tab is the customer saying which shop they are in; the basket is what
/// they are carrying in it. This is the one wire between the two, so no caller
/// has to remember to move the basket — the cart screen's banner, the sheet an
/// add raises and a plain tab tap all end up here.
///
/// Held alive by the shell. It watches nothing and therefore never rebuilds:
/// the listener is the whole body.
final basketFollowsShelfProvider = Provider<void>((ref) {
  Future<void> align(Shelf shelf) async {
    try {
      final move =
          await ref.read(cartControllerProvider.notifier).alignToShelf(shelf.wire);
      ref.read(basketMoveProvider.notifier).post(move);
    } catch (_) {
      // The scope went away mid-flight, or the store refused. Either way the
      // basket is where it was and nothing here is worth crashing a tab tap.
    }
  }

  ref.listen<Shelf>(shelfProvider, (previous, next) {
    if (previous == next) return;
    unawaited(align(next));
  });

  // And once at the start. Without this the app opens on إكسبريس carrying
  // whatever basket it was left with — a زوبكسي count on an إكسبريس badge,
  // which is the whole complaint. It waits for the first cart because an
  // alignment judged against no cart at all can only decide to do nothing.
  unawaited(() async {
    try {
      await ref.read(cartControllerProvider.future);
    } catch (_) {
      return; // No cart to align; the next successful read brings one.
    }
    await align(ref.read(shelfProvider));
  }());
});

/// Unit count for the tab badge. Kept as its own provider so the badge
/// rebuilds without every cart change rebuilding the whole shell.
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartControllerProvider).value?.count ?? 0,
);

/// What each storefront's basket is holding, in pieces.
///
/// إكسبريس and زوبكسي each keep a basket; only one of them is live at a time
/// and the other waits on the server. The two shop signs show both, so a
/// customer can see what is in the shop they are not standing in — which is
/// the whole reason for keeping it.
///
/// A record, so a cart answer that moved neither number leaves both signs
/// alone: every cart response decodes fresh objects.
typedef ShelfBaskets = ({int express, int all});

final shelfBasketsProvider = Provider<ShelfBaskets>((ref) {
  final cart = ref.watch(cartControllerProvider).value;
  if (cart == null) return (express: 0, all: 0);
  final basket = cart.basket;

  // The live basket is counted by the cart itself; the waiting one by the
  // stash. An empty cart belongs to neither shelf, and then `otherShelf` names
  // whichever side still has something waiting.
  var express = basket.shelf == Shelf.express.wire ? cart.count : 0;
  var all = basket.shelf == Shelf.all.wire ? cart.count : 0;
  if (basket.otherShelf == Shelf.express.wire && basket.shelf != Shelf.express.wire) {
    express = basket.otherPieces;
  }
  if (basket.otherShelf == Shelf.all.wire && basket.shelf != Shelf.all.wire) {
    all = basket.otherPieces;
  }
  return (express: express, all: all);
});

/// The two numbers the pinned إكسبريس basket bar shows.
///
/// A value, so a cart answer that moved neither of them leaves the bar — and
/// the shell it rides in — untouched. Every basket response decodes fresh
/// objects; without this the bar would rebuild on each optimistic tap.
class CartGlance {
  const CartGlance({required this.count, required this.subtotal});

  final int count;
  final double subtotal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartGlance &&
          other.count == count &&
          other.subtotal == subtotal;

  @override
  int get hashCode => Object.hash(count, subtotal);
}

final cartGlanceProvider = Provider<CartGlance>((ref) {
  final cart = ref.watch(cartControllerProvider).value;
  return CartGlance(
    count: cart?.count ?? 0,
    subtotal: cart?.totals.subtotal ?? 0,
  );
});

/// What this basket earns once it is delivered. Its own provider so the
/// totals line can move without the whole cart screen rebuilding, and so a
/// store with the program switched off simply reports zero.
final cartPawsToEarnProvider = Provider<int>(
  (ref) => ref.watch(cartControllerProvider).value?.loyalty.pawsToEarn ?? 0,
);

/// The free-delivery gap, but only while it is still worth nudging about:
/// there is a basket, the threshold is on, and it hasn't been cleared yet.
///
/// Derived rather than read inline on Home so the storefront rebuilds when the
/// *nudge* changes, not on every optimistic quantity tap — and so it reads the
/// cart the shell already keeps warm instead of asking for a fresh one.
/// The free-delivery line the home nudge should draw, and which shelf it is
/// about — null when there is nothing to nudge toward.
typedef FreeShippingNudge = ({FreeShipping line, bool express});

final cartFreeShippingNudgeProvider = Provider<FreeShippingNudge?>((ref) {
  final cart = ref.watch(cartControllerProvider).value;
  if (cart == null || cart.isEmpty) return null;
  // An express basket measures itself against its own, reachable line. The
  // national threshold would tell a 36 ﷼ basket it is 164 ﷼ away — a number
  // that switches the nudge off rather than on.
  final shelf = cart.basket.effectiveShelf.isNotEmpty ? cart.basket.effectiveShelf : cart.basket.shelf;
  final express = shelf == 'express';
  final line = cart.freeShipping.forShelf(shelf);
  if (!line.isActive || line.qualified) return null;
  return (line: line, express: express && !identical(line, cart.freeShipping));
});
