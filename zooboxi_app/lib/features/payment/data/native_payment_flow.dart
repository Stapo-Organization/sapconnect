import 'dart:async';

import 'package:myfatoorah_flutter/myfatoorah_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../checkout/data/checkout_repository.dart';
import 'payment_service.dart';

/// The native-card half of a payment: bringing the gateway's SDK up, and then
/// asking the server whether the invoice it produced actually paid the order.
///
/// This is deliberately *not* in the screen even though it retries on a timer.
/// The rule that matters is ownership, not location: the screen creates one of
/// these and calls [dispose] with its own, so nothing here can outlive the
/// widget that started it. What it buys is that the screen holds one object to
/// cancel instead of a timer, a completer and a flag.
class NativePaymentFlow {
  NativePaymentFlow(this._service);

  final PaymentService _service;

  /// `MFSDK.init` configures the plugin process-wide, so it runs once per
  /// credential set. Re-running it for every order would reset an SDK that
  /// may already be mid-session.
  static String? _sdkSignature;

  Timer? _delay;
  Completer<void>? _gate;
  bool _disposed = false;

  /// How long the gateway gets to catch up after the card itself cleared.
  /// Four tries across six seconds: MyFatoorah normally settles inside one.
  static const int maxAttempts = 4;
  static const Duration gap = Duration(seconds: 2);

  Future<void> initSdk(PaymentConfig config) async {
    final signature = '${config.token}|${config.country}|${config.environment}';
    if (_sdkSignature == signature) return;
    await MFSDK.init(
      config.token,
      config.country,
      config.isLive ? MFEnvironment.LIVE : MFEnvironment.TEST,
    );
    _sdkSignature = signature;
  }

  /// Asks the server whether [invoiceId] paid this order, and keeps asking
  /// while it is still settling.
  ///
  /// Three answers end it early. `is_paid` and `already_paid` are yes. A
  /// `verify_mismatch` is the one refusal that means "this did not happen" —
  /// retrying it only spends the customer's time on an answer that cannot
  /// change. A dropped request, by contrast, costs an attempt and no more.
  Future<bool> verify({
    required int orderId,
    required String orderKey,
    required String invoiceId,
    int attempts = maxAttempts,
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      if (_disposed) return false;
      try {
        final result = await _service.verify(
          orderId: orderId,
          orderKey: orderKey,
          invoiceId: invoiceId,
        );
        if (_disposed) return false;
        if (result.isPaid) return true;
        if (result.status == 'failed' || result.status == 'cancelled') return false;
      } on ApiException catch (e) {
        if (_disposed) return false;
        if (e.code == CheckoutErrors.alreadyPaid) return true;
        if (e.code == PaymentErrors.verifyMismatch) return false;
      } catch (_) {
        if (_disposed) return false;
      }
      if (attempt < attempts) await _wait(gap);
    }
    return false;
  }

  /// A cancellable pause. [dispose] completes the gate as well as cancelling
  /// the timer, so a torn-down flow never leaves an async frame suspended.
  Future<void> _wait(Duration duration) {
    _delay?.cancel();
    final gate = Completer<void>();
    _gate = gate;
    _delay = Timer(duration, () {
      if (!gate.isCompleted) gate.complete();
    });
    return gate.future;
  }

  void dispose() {
    _disposed = true;
    _delay?.cancel();
    _delay = null;
    if (_gate?.isCompleted == false) _gate!.complete();
    _gate = null;
  }
}
