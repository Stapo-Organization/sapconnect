import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../orders/data/orders_repository.dart';

/// How a hosted payment attempt ended.
enum PaymentOutcome { paid, pending, failed }

/// Hosted-payment handoff.
///
/// Phase one deliberately keeps every payment credential on the server: the
/// app asks for a payment URL, opens it in an in-app browser tab, then polls
/// the order until the gateway's own callback has marked it paid. No card
/// data, no merchant keys and no SDK ever enter the app — which is also what
/// keeps PCI scope off the mobile build.
///
/// A custom tab (rather than a WebView) is what makes wallets work: Apple Pay
/// and mada 3-D Secure both need the real Safari/Chrome context.
class PaymentService {
  PaymentService(this._orders);

  final OrdersRepository _orders;

  /// How long to keep asking before handing the customer back to the order
  /// screen with a "we're confirming" state. Gateways settle in seconds, but
  /// a stalled poll must never hang the UI forever.
  static const Duration _pollTimeout = Duration(minutes: 3);
  static const Duration _pollInterval = Duration(seconds: 3);

  /// Opens the gateway page and waits for the order to settle.
  Future<PaymentOutcome> pay({
    required BuildContext context,
    required int orderId,
    required String orderKey,
  }) async {
    final url = await _orders.paymentUrl(orderId, orderKey);
    if (url == null || url.isEmpty) return PaymentOutcome.failed;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return PaymentOutcome.failed;

    if (!context.mounted) return PaymentOutcome.pending;
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
    } catch (_) {
      return PaymentOutcome.failed;
    }

    return pollUntilPaid(orderId: orderId, orderKey: orderKey);
  }

  /// Polls `GET /orders/{id}/status` until the gateway's callback lands.
  ///
  /// The app is never the authority on whether money moved — the gateway tells
  /// the server, and the server tells us. Polling is the honest way to observe
  /// that without the app ever asserting a payment succeeded.
  Future<PaymentOutcome> pollUntilPaid({
    required int orderId,
    required String orderKey,
    Duration timeout = _pollTimeout,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final status = await _orders.paymentStatus(orderId, orderKey);
        if (status.isPaid) return PaymentOutcome.paid;
        if (status.status == 'failed' || status.status == 'cancelled') {
          return PaymentOutcome.failed;
        }
      } catch (_) {
        // A dropped request mid-poll is normal while the customer is switching
        // apps; keep trying until the deadline.
      }
      await Future<void>.delayed(_pollInterval);
    }
    return PaymentOutcome.pending;
  }
}

final paymentServiceProvider =
    Provider<PaymentService>((ref) => PaymentService(ref.watch(ordersRepositoryProvider)));
