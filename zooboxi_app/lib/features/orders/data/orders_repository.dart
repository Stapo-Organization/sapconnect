import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../cart/data/cart_models.dart';
import 'order_models.dart';

class OrdersRepository {
  OrdersRepository(this._api);

  final ApiClient _api;

  Future<OrdersPage> orders({int page = 1}) async =>
      OrdersPage.fromJson(asMap(await _api.get('/orders', query: {'page': page})));

  Future<OrderDetail> order(int id) async =>
      OrderDetail.fromJson(asMap(await _api.get('/orders/$id')));

  /// Refills the cart from a past order and returns the new cart.
  Future<CartData> reorder(int id) async =>
      CartData.fromJson(asMap(await _api.post('/orders/$id/reorder')));

  /// Hands back the hosted payment page URL. The order key gates it, so a
  /// guest who placed the order can pay without an account.
  Future<String?> paymentUrl(int orderId, String orderKey) async {
    final data = asMap(await _api.post('/orders/$orderId/pay', query: {'key': orderKey}));
    return asStringOrNull(data['payment_url']);
  }

  /// Polled while the customer is on the hosted payment page.
  Future<({String status, bool isPaid})> paymentStatus(int orderId, String orderKey) async {
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
