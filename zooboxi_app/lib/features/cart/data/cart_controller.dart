import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
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

/// Unit count for the tab badge. Kept as its own provider so the badge
/// rebuilds without every cart change rebuilding the whole shell.
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartControllerProvider).value?.count ?? 0,
);

/// The free-delivery gap, but only while it is still worth nudging about:
/// there is a basket, the threshold is on, and it hasn't been cleared yet.
///
/// Derived rather than read inline on Home so the storefront rebuilds when the
/// *nudge* changes, not on every optimistic quantity tap — and so it reads the
/// cart the shell already keeps warm instead of asking for a fresh one.
final cartFreeShippingNudgeProvider = Provider<FreeShipping?>((ref) {
  final cart = ref.watch(cartControllerProvider).value;
  if (cart == null || cart.isEmpty) return null;
  final freeShipping = cart.freeShipping;
  if (!freeShipping.isActive || freeShipping.qualified) return null;
  return freeShipping;
});
