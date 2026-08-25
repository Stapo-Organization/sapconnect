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
import '../data/native_payment_flow.dart';
import '../data/payment_service.dart';
import 'widgets/card_payment_panel.dart';
import 'widgets/card_route_view.dart';
import 'widgets/payment_status_view.dart';

/// Paying for an order that already exists.
///
/// Two routes to the same place. The **card** route keeps the customer here:
/// the gateway's own SDK draws the fields, runs 3-D Secure in-app, and hands
/// back an invoice id. The **hosted** route opens the gateway's page in a
/// browser tab, which is what Apple Pay and mada's challenge flow need, and
/// then watches the order.
///
/// Neither route lets the app decide anything. An invoice id is a claim; the
/// server checks it against the order it priced and answers. Until it says
/// paid, nothing is paid — which is exactly why the card route ends in a
/// verification loop rather than in a success screen.
///
/// Every timer here is owned by the state and cancelled in [dispose].
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.order});

  final PlacedOrder order;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

/// Which route the screen is on.
enum _Route { preparing, card, hosted }

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with WidgetsBindingObserver {
  /// 40 × 3s ≈ two minutes on the hosted page. Gateways settle in seconds;
  /// past this the honest answer is "we don't know yet", not a spinner that
  /// never ends.
  static const int _maxPolls = 40;
  static const Duration _interval = Duration(seconds: 3);

  /// Owns the SDK bring-up and the post-payment verification, including its
  /// retry timer. Disposed with the screen.
  late final NativePaymentFlow _native =
      NativePaymentFlow(ref.read(paymentServiceProvider));

  Timer? _poll;
  int _polls = 0;
  bool _checking = false;
  bool _settled = false;

  _Route _route = _Route.preparing;
  PaymentConfig? _config;

  /// Shown above the card form when the *server* refused a verification.
  String? _cardError;
  bool _verifying = false;

  /// Explains why the hosted page opened when the card form was expected.
  String? _hostedNotice;

  PaymentPhase _phase = PaymentPhase.opening;
  String? _error;
  String? _url;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _poll = null;
    _native.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the gateway tab is the single most likely moment for
    // the answer to have changed — ask immediately rather than waiting out
    // the rest of the interval.
    if (state == AppLifecycleState.resumed &&
        _route == _Route.hosted &&
        _phase == PaymentPhase.waiting) {
      unawaited(_check());
    }
  }

  // ── Choosing a route ─────────────────────────────────────────────────

  Future<void> _prepare() async {
    final service = ref.read(paymentServiceProvider);
    PaymentConfig config;
    try {
      config = await service.config(
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
      // An order that does not exist cannot be paid on any route.
      if (e.code == PaymentErrors.orderNotFound || e.type == ApiErrorType.notFound) {
        _fail(errorMessage(context, e));
        return;
      }
      // Everything else — the gateway being down, a dropped request — still
      // has a way through: the hosted page.
      await _startHosted(notice: L.of(context).paymentHostedFallback);
      return;
    } catch (_) {
      if (!mounted) return;
      await _startHosted(notice: L.of(context).paymentHostedFallback);
      return;
    }

    if (!mounted) return;
    if (!config.supportsNativeCard || config.token.isEmpty) {
      await _startHosted(notice: L.of(context).paymentHostedFallback);
      return;
    }

    try {
      await _native.initSdk(config);
    } catch (_) {
      if (!mounted) return;
      await _startHosted(notice: L.of(context).paymentHostedFallback);
      return;
    }

    if (!mounted) return;
    setState(() {
      _config = config;
      _route = _Route.card;
    });
  }

  // ── Card route ───────────────────────────────────────────────────────

  Future<void> _onCardResult(CardPaymentResult result) async {
    final invoice = result.invoiceId;
    final l = L.of(context);

    if (invoice == null || invoice.isEmpty) {
      // The panel is already showing the SDK's own message.
      return;
    }

    // A result that came with an error still gets one question: MyFatoorah
    // mints the invoice before the 3-D Secure step, so a lost reply after a
    // successful challenge would otherwise read as a decline.
    setState(() {
      _verifying = true;
      _cardError = null;
    });
    final paid = await _native.verify(
      orderId: widget.order.orderId,
      orderKey: widget.order.orderKey,
      invoiceId: invoice,
      attempts: result.error == null ? NativePaymentFlow.maxAttempts : 1,
    );
    if (!mounted || _settled) return;
    setState(() => _verifying = false);

    if (paid) {
      _succeed();
      return;
    }
    Haptics.warning();
    setState(() => _cardError = result.error ?? l.paymentFailedHint);
  }

  /// A new card attempt has begun — whatever we said about the last one is
  /// no longer true.
  void _clearCardError() {
    if (_cardError != null) setState(() => _cardError = null);
  }

  // ── Hosted route ─────────────────────────────────────────────────────

  Future<void> _startHosted({String? notice}) async {
    if (!mounted) return;
    setState(() {
      _route = _Route.hosted;
      _hostedNotice = notice ?? _hostedNotice;
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

  Future<void> _retryHosted() async {
    Haptics.light();
    final url = _url;
    if (url == null) {
      await _startHosted();
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
    if (!opened) await _startHosted();
  }

  // ── Endings ──────────────────────────────────────────────────────────

  void _succeed() {
    if (_settled) return;
    _settled = true;
    _poll?.cancel();
    _poll = null;
    _native.dispose();
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
      _route = _Route.hosted;
      _phase = PaymentPhase.failed;
      _error = message;
    });
  }

  void _openOrder() {
    _poll?.cancel();
    _poll = null;
    _native.dispose();
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
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    switch (_route) {
      case _Route.preparing:
        return const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        );

      case _Route.hosted:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: PaymentStatusView(
            phase: _phase,
            orderNumber: widget.order.orderNumber,
            message: _error,
            notice: _phase == PaymentPhase.failed ? null : _hostedNotice,
            onRetry: _retryHosted,
            onOpenOrder: _openOrder,
          ),
        );

      case _Route.card:
        return CardRouteView(
          order: widget.order,
          config: _config!,
          errorText: _cardError,
          busy: _verifying,
          onResult: (result) => unawaited(_onCardResult(result)),
          onAttempt: _clearCardError,
          onUseOtherMethods: () => unawaited(_startHosted()),
        );
    }
  }
}
