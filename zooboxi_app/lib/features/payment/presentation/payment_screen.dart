import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../checkout/data/checkout_models.dart';
import '../../checkout/data/checkout_repository.dart';
import '../data/payment_service.dart';
import 'widgets/payment_status_view.dart';

/// Waiting on the gateway.
///
/// The app cannot know whether money moved — only the server, told by the
/// gateway's callback, knows that. So this screen opens the hosted page and
/// then simply watches the order, from the instant the tab launches rather
/// than from whenever the customer happens to come back: a wallet payment can
/// settle while the tab is still on screen.
///
/// Every timer here is owned by the state and cancelled in [dispose].
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.order});

  final PlacedOrder order;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with WidgetsBindingObserver {
  /// 40 × 3s ≈ two minutes. Gateways settle in seconds; past this the honest
  /// answer is "we don't know yet", not a spinner that never ends.
  static const int _maxPolls = 40;
  static const Duration _interval = Duration(seconds: 3);

  Timer? _poll;
  int _polls = 0;
  bool _checking = false;
  bool _settled = false;

  PaymentPhase _phase = PaymentPhase.opening;
  String? _error;
  String? _url;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _poll = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the gateway tab is the single most likely moment for
    // the answer to have changed — ask immediately rather than waiting out
    // the rest of the interval.
    if (state == AppLifecycleState.resumed && _phase == PaymentPhase.waiting) {
      unawaited(_check());
    }
  }

  // ── Flow ─────────────────────────────────────────────────────────────

  Future<void> _start() async {
    setState(() {
      _phase = PaymentPhase.opening;
      _error = null;
    });

    final service = ref.read(paymentServiceProvider);
    String? url;
    try {
      url = await service.sessionUrl(
        orderId: widget.order.orderId,
        orderKey: widget.order.orderKey,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // `already_paid` is a happy ending wearing an error's clothes: the
      // gateway's callback beat us to it.
      if (e.code == CheckoutErrors.alreadyPaid) {
        _succeed();
        return;
      }
      _fail(errorMessage(context, e));
      return;
    } catch (e) {
      if (!mounted) return;
      _fail(errorMessage(context, e));
      return;
    }

    if (!mounted) return;
    if (url == null) {
      _fail(L.of(context).paymentFailedHint);
      return;
    }

    _url = url;
    setState(() => _phase = PaymentPhase.waiting);
    _startPolling();

    final opened = await service.openGatewayPage(context, url);
    if (!mounted || _settled) return;
    if (!opened) _fail(L.of(context).paymentFailedHint);
  }

  void _startPolling() {
    _poll?.cancel();
    _polls = 0;
    _poll = Timer.periodic(_interval, (_) => unawaited(_check()));
  }

  Future<void> _check() async {
    if (_checking || _settled || !mounted) return;
    _checking = true;
    try {
      final outcome = await ref.read(paymentServiceProvider).check(
            orderId: widget.order.orderId,
            orderKey: widget.order.orderKey,
          );
      if (!mounted || _settled) return;
      switch (outcome) {
        case PaymentOutcome.paid:
          _succeed();
        case PaymentOutcome.failed:
          _fail(L.of(context).paymentFailedHint);
        case PaymentOutcome.pending:
          _polls += 1;
          if (_polls >= _maxPolls) _fail(L.of(context).paymentFailedHint);
      }
    } catch (_) {
      // A dropped request mid-poll is normal while apps are switching; it
      // still costs a tick, so a dead network can't poll forever either.
      _polls += 1;
      if (mounted && !_settled && _polls >= _maxPolls) {
        _fail(L.of(context).paymentFailedHint);
      }
    } finally {
      _checking = false;
    }
  }

  void _succeed() {
    if (_settled) return;
    _settled = true;
    _poll?.cancel();
    _poll = null;
    unawaited(Haptics.success());
    if (!mounted) return;
    context.pushReplacement('/checkout/done', extra: widget.order);
  }

  void _fail(String message) {
    if (_settled) return;
    _poll?.cancel();
    _poll = null;
    Haptics.warning();
    if (!mounted) return;
    setState(() {
      _phase = PaymentPhase.failed;
      _error = message;
    });
  }

  Future<void> _retry() async {
    Haptics.light();
    final url = _url;
    if (url == null) {
      await _start();
      return;
    }
    // The gateway session is still valid — reopening beats minting a second
    // one, which some gateways treat as a duplicate attempt.
    setState(() {
      _phase = PaymentPhase.waiting;
      _error = null;
    });
    _startPolling();
    final opened = await ref.read(paymentServiceProvider).openGatewayPage(context, url);
    if (!mounted || _settled) return;
    if (!opened) await _start();
  }

  void _openOrder() {
    _poll?.cancel();
    _poll = null;
    _settled = true;
    context.pushReplacement('/orders/${widget.order.orderId}');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return PopScope(
      // The order already exists. Backing out must land on it, not on a
      // checkout that can no longer be completed.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openOrder();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.paymentTitle),
          leading: IconButton(
            onPressed: _openOrder,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: PaymentStatusView(
              phase: _phase,
              orderNumber: widget.order.orderNumber,
              message: _error,
              onRetry: _retry,
              onOpenOrder: _openOrder,
            ),
          ),
        ),
      ),
    );
  }
}
