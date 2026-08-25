import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import 'cart_models.dart';
import 'cart_repository.dart';

/// The server owns the cart; this controller owns *responsiveness*.
///
/// A quantity tap must move the number now, not in 300ms — but the server is
/// the only thing that knows whether the extra unit actually reaches this
/// customer. So taps apply locally, coalesce for [_debounce], then post once;
/// if the server disagrees, its answer replaces the optimistic state and its
/// notice is surfaced rather than swallowed.
class CartController extends AsyncNotifier<CartData> {
  static const Duration _debounce = Duration(milliseconds: 400);

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
      state = AsyncValue.data(await ref.read(cartRepositoryProvider).fetch());
    } catch (e, st) {
      // A failed refresh must not blank a cart the customer is looking at.
      if (!state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  /// Adds to the cart and returns the notices the server raised (usually
  /// empty). Throws [ApiException] so the caller can show the real reason.
  Future<List<CartNotice>> add({
    required int productId,
    int? variationId,
    int quantity = 1,
    Map<String, String>? attributes,
  }) async {
    final result = await ref.read(cartRepositoryProvider).addItem(
          productId: productId,
          variationId: variationId,
          quantity: quantity,
          attributes: attributes,
        );
    state = AsyncValue.data(result);
    return result.notices;
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
    _pending[key] = Timer(_debounce, () => _flushQuantity(key, snapshot));
  }

  Future<void> _flushQuantity(String key, CartData rollbackTo) async {
    _pending.remove(key);
    final target = _targetQty.remove(key);
    if (target == null) return;

    try {
      final result = await ref.read(cartRepositoryProvider).setQuantity(key, target);
      state = AsyncValue.data(result);
      _collect(result.notices);
    } on ApiException catch (e) {
      // Roll back to what the customer saw before this burst of taps, and
      // surface why — silently reverting a number is worse than an error.
      state = AsyncValue.data(rollbackTo);
      _collect([
        CartNotice(type: 'error', text: e.messageAr ?? e.messageEn ?? ''),
      ]);
    } catch (_) {
      state = AsyncValue.data(rollbackTo);
    }
  }

  Future<void> remove(String key) async {
    final snapshot = _current;
    _pending.remove(key)?.cancel();
    _targetQty.remove(key);

    state = AsyncValue.data(snapshot.withoutItem(key));
    try {
      final result = await ref.read(cartRepositoryProvider).removeItem(key);
      state = AsyncValue.data(result);
      _collect(result.notices);
    } catch (_) {
      state = AsyncValue.data(snapshot);
      rethrow;
    }
  }

  Future<void> applyCoupon(String code) async {
    final result = await ref.read(cartRepositoryProvider).applyCoupon(code);
    state = AsyncValue.data(result);
    _collect(result.notices);
  }

  Future<void> removeCoupon(String code) async {
    final result = await ref.read(cartRepositoryProvider).removeCoupon(code);
    state = AsyncValue.data(result);
    _collect(result.notices);
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
