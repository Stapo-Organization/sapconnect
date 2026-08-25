import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../orders/data/orders_repository.dart';

/// How a hosted payment attempt looks from the app's side.
enum PaymentOutcome {
  /// The gateway's callback reached the server and the order is paid.
  paid,

  /// Nothing has landed yet — keep watching.
  pending,

  /// The gateway said no, or the order was cancelled.
  failed,
}

/// Hosted-payment handoff.
///
/// Phase one deliberately keeps every payment credential on the server: the
/// app asks for a payment URL, opens it in an in-app browser tab, then watches
/// the order until the gateway's own callback has marked it paid. No card
/// data, no merchant keys and no SDK ever enter the app — which is also what
/// keeps PCI scope off the mobile build.
///
/// A custom tab (rather than a WebView) is what makes wallets work: Apple Pay
/// and mada 3-D Secure both need the real Safari/Chrome context.
///
/// The service is transport only. The *waiting* — its timer, its budget, its
/// cancellation — belongs to the screen, because a poll that outlives the
/// widget that started it is a leak with a network bill attached.
class PaymentService {
  PaymentService(this._orders);

  final OrdersRepository _orders;

  /// Asks the gateway for a session and returns its hosted page.
  /// Throws [ApiException] on `already_paid` / `gateway_unavailable`.
  Future<String?> sessionUrl({required int orderId, required String orderKey}) async {
    final url = await _orders.paymentUrl(orderId, orderKey);
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    return (uri != null && uri.hasScheme) ? url : null;
  }

  /// Opens the hosted page in a tab styled like the app. Returns false when no
  /// browser could take it.
  Future<bool> openGatewayPage(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;

    final cs = context.cs;
    try {
      await launchUrl(
        uri,
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(toolbarColor: cs.surface),
          showTitle: true,
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: cs.surface,
          preferredControlTintColor: cs.primary,
          barCollapsingEnabled: false,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One read of `GET /orders/{id}/status`.
  ///
  /// The app is never the authority on whether money moved — the gateway tells
  /// the server, and the server tells us. Asking is the only honest way to
  /// observe that without the app ever asserting a payment succeeded.
  Future<PaymentOutcome> check({required int orderId, required String orderKey}) async {
    final status = await _orders.paymentStatus(orderId, orderKey);
    if (status.isPaid) return PaymentOutcome.paid;
    if (status.status == 'failed' || status.status == 'cancelled') {
      return PaymentOutcome.failed;
    }
    return PaymentOutcome.pending;
  }
}

final paymentServiceProvider =
    Provider<PaymentService>((ref) => PaymentService(ref.watch(ordersRepositoryProvider)));
