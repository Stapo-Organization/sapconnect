import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
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

/// What the server hands the app so it can run the gateway's own SDK.
///
/// Note what is *not* here: nothing that can move money on its own. The token
/// opens a one-payment session against an invoice the server already priced,
/// and [reference] is the string the server will verify the resulting invoice
/// against — so a tampered amount or a foreign invoice simply fails to verify.
@immutable
class PaymentConfig {
  const PaymentConfig({
    required this.gateway,
    required this.token,
    required this.country,
    required this.environment,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.reference,
    this.applePay = false,
  });

  /// `myfatoorah` today. Anything else means "no native path — use the page".
  final String gateway;
  final String token;

  /// ISO-3 country the merchant account lives in, e.g. `SAU`.
  final String country;

  /// `live` or `test`.
  final String environment;

  final int orderId;
  final double amount;
  final String currency;

  /// The `customerReference` the payment must carry. The server verifies by it.
  final String reference;

  /// True once the merchant's Apple Pay chain is live end to end (Apple
  /// merchant id + certificate + MyFatoorah vendor activation + the app's
  /// entitlement). Flipped server-side so no release is needed on the day.
  final bool applePay;

  bool get isLive => environment.toLowerCase() == 'live';
  bool get supportsNativeCard => gateway.toLowerCase() == 'myfatoorah';

  factory PaymentConfig.fromJson(Map<String, dynamic> json) => PaymentConfig(
        gateway: asString(json['gateway']),
        token: asString(json['token']),
        country: asString(json['country'], fallback: 'SAU'),
        environment: asString(json['env'], fallback: 'test'),
        orderId: asInt(json['order_id']),
        amount: asDouble(json['amount']),
        currency: asString(json['currency'], fallback: 'SAR'),
        reference: asString(json['reference']),
        applePay: asBool(json['apple_pay']),
      );
}

/// The server's verdict on a native attempt.
typedef PaymentVerification = ({bool isPaid, String status});

/// Error codes the payment endpoints raise on top of the checkout ones.
abstract final class PaymentErrors {
  /// The invoice the app reported does not belong to this order. Never retry
  /// a mismatch — it is the one answer that means "this did not happen".
  static const verifyMismatch = 'verify_mismatch';
  static const orderNotFound = 'order_not_found';
}

/// Payment transport.
///
/// Two ways to pay, one authority. The native SDK collects the card and clears
/// 3-D Secure in-app; the hosted page in a browser tab carries the wallets. In
/// both cases the app's word for "paid" is worth nothing — it asks the server,
/// which was told by the gateway. That is the whole design: the app can start a
/// payment, it can never assert one.
///
/// The service is transport only. The *waiting* — its timers, its budget, its
/// cancellation — belongs to the screen, because a poll that outlives the
/// widget that started it is a leak with a network bill attached.
class PaymentService {
  PaymentService(this._api, this._orders);

  final ApiClient _api;
  final OrdersRepository _orders;

  // ── Native card ──────────────────────────────────────────────────────

  /// What this order needs to be paid through the gateway's SDK.
  ///
  /// Throws [ApiException] with `already_paid` (a happy ending in an error's
  /// clothes), `gateway_unavailable` (fall back to the hosted page) or
  /// `order_not_found`.
  Future<PaymentConfig> config({required int orderId, required String orderKey}) async {
    final data = asMap(
      await _api.post('/payments/config', body: {'order_id': orderId, 'key': orderKey}),
    );
    return PaymentConfig.fromJson(data);
  }

  /// Asks the server whether the invoice the SDK just produced actually paid
  /// this order. `verify_mismatch` means it did not, and never will.
  Future<PaymentVerification> verify({
    required int orderId,
    required String orderKey,
    required String invoiceId,
  }) async {
    final data = asMap(
      await _api.post('/payments/verify', body: {
        'order_id': orderId,
        'key': orderKey,
        'invoice_id': invoiceId,
      }),
    );
    return (isPaid: asBool(data['is_paid']), status: asString(data['status']));
  }

  // ── Hosted page ──────────────────────────────────────────────────────

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
  ///
  /// A custom tab rather than a WebView is what makes wallets work: Apple Pay
  /// and mada 3-D Secure both need the real Safari/Chrome context.
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

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(
    ref.watch(apiClientProvider),
    ref.watch(ordersRepositoryProvider),
  ),
);
