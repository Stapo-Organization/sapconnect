import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import 'live_tracking.dart';
import 'order_models.dart';

/// The live state of a hosted payment, as the server sees it.
typedef OrderPaymentStatus = ({String status, bool isPaid});

class OrdersRepository {
  OrdersRepository(this._api);

  final ApiClient _api;

  Future<OrdersPage> orders({int page = 1}) async =>
      OrdersPage.fromJson(asMap(await _api.get('/orders', query: {'page': page})));

  Future<OrderDetail> order(int id) async =>
      OrderDetail.fromJson(asMap(await _api.get('/orders/$id')));

  /// Refills the cart from a past order. The result carries the fresh cart
  /// *and* the lines that could not be restocked.
  Future<ReorderResult> reorder(int id) async =>
      ReorderResult.fromJson(asMap(await _api.post('/orders/$id/reorder')));

  /// Where the courier is right now, or null when this order has none.
  ///
  /// Cheap enough to poll: the store answers from a few-seconds cache and only
  /// reaches sapconnect when that has expired.
  Future<LiveTracking?> liveTracking(int id) async =>
      LiveTracking.maybe(await _api.get('/orders/$id/live-tracking'));

  /// Hands back the hosted payment page URL. The order key gates it, so a
  /// guest who placed the order can pay without an account.
  Future<String?> paymentUrl(int orderId, String orderKey) async {
    final data = asMap(await _api.post('/orders/$orderId/pay', query: {'key': orderKey}));
    return asStringOrNull(data['payment_url']);
  }

  /// Polled while the customer is on the hosted payment page.
  Future<OrderPaymentStatus> paymentStatus(int orderId, String orderKey) async {
    final data = asMap(await _api.get('/orders/$orderId/status', query: {'key': orderKey}));
    return (status: asString(data['status']), isPaid: asBool(data['is_paid']));
  }
}

final ordersRepositoryProvider =
    Provider<OrdersRepository>((ref) => OrdersRepository(ref.watch(apiClientProvider)));

/// First page of the order history. Guests have none — the provider resolves
/// empty rather than firing a call that would 401.
final ordersProvider = FutureProvider.autoDispose<OrdersPage>((ref) {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    return Future.value(const OrdersPage());
  }
  return ref.watch(ordersRepositoryProvider).orders();
});

final orderDetailProvider = FutureProvider.autoDispose.family<OrderDetail, int>(
  (ref, id) => ref.watch(ordersRepositoryProvider).order(id),
);

/// The courier's live position, re-read on a timer for as long as anyone is
/// looking at it.
///
/// The cadence is the payload's own business: a courier riding toward the door
/// is worth ten seconds, a courier not yet found is worth twenty, an express
/// order that has not called one yet is worth a lazy minute, and a delivered
/// order is worth nothing at all — so the loop simply ends. The provider is
/// autoDispose, so leaving the screen ends the polling with it.
///
/// The one rule underneath all of it: a failure is never read as "no courier".
/// The most likely moment for the store to time out is the moment the delivery
/// completes, and giving up then would deny the customer the very screen they
/// waited for.
final liveTrackingProvider = StreamProvider.autoDispose.family<LiveTracking?, int>((ref, id) async* {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    yield null;
    return;
  }

  final repo = ref.watch(ordersRepositoryProvider);

  // `async*` only notices disposal at its next yield, so without this the
  // provider would run one more delay and one more request after the customer
  // has left the screen.
  var alive = true;
  ref.onDispose(() => alive = false);

  LiveTracking? last;
  var emptyPolls = 0;

  while (alive) {
    LiveTracking? tracking;
    var failed = false;

    try {
      tracking = await repo.liveTracking(id);
      last = tracking;
      emptyPolls = tracking == null ? emptyPolls + 1 : 0;
    } on ApiException catch (e) {
      // Signed out, not ours, or gone: polling harder will not help.
      if (e.type == ApiErrorType.unauthorized ||
          e.type == ApiErrorType.forbidden ||
          e.type == ApiErrorType.notFound) {
        yield null;
        return;
      }
      // Anything else is weather. Keep showing the last known position — an
      // error where the map was is a worse answer than a dot a few seconds old.
      tracking = last;
      failed = true;
    } catch (_) {
      tracking = last;
      failed = true;
    }

    if (!alive) return;
    yield tracking;

    if (tracking != null && !tracking.isLive) return;

    // An order that keeps answering "no courier" is one the branch has not
    // dispatched. Back off to a lazy watch rather than hammering, but never
    // stop: they may call one while this screen is open.
    await Future<void>.delayed(switch ((failed, tracking?.phase)) {
      (true, _) => const Duration(seconds: 30),
      (_, null) => Duration(seconds: emptyPolls > 3 ? 60 : 20),
      (_, LivePhase.searching) => const Duration(seconds: 20),
      (_, LivePhase.assigned) => const Duration(seconds: 15),
      _ => const Duration(seconds: 10),
    });
  }
});
