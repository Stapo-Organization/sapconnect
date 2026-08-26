import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/account_models.dart';
import '../../account/data/addresses_controller.dart';
import '../../account/presentation/address_editor_screen.dart';
import '../../cart/data/cart_controller.dart';
import '../data/checkout_models.dart';
import '../data/checkout_repository.dart';
import 'widgets/address_step.dart';
import 'widgets/checkout_steps.dart';
import 'widgets/payment_step.dart';
import 'widgets/review_step.dart';

/// Checkout: address → review → payment, on one screen.
///
/// One screen rather than three routes because the three answers are one
/// decision — the address changes the shipments, the shipments change the
/// total, the total is what is being paid. Splitting them across routes makes
/// each re-price look like a new page instead of a consequence.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notes = TextEditingController();

  CheckoutStep _step = CheckoutStep.address;
  String? _addressId;
  Address? _draftAddress;

  /// True while [_draftAddress] is the address the customer pinned during the
  /// welcome journey — it stays on the device until an order actually carries
  /// it, so a cancelled checkout doesn't throw it away.
  bool _draftFromPending = false;
  String? _paymentId;
  bool _placing = false;
  bool _tracked = false;

  /// The server's own wording when it re-priced the basket at the delivery
  /// address and something moved.
  String? _changedNotice;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final review = ref.watch(checkoutReviewProvider);

    if (review.hasValue && !_tracked) {
      _tracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.track(const ZbEvent(type: ZbEvents.beginCheckout, zone: 'checkout'));
        }
      });
    }

    // A coupon applied on the review step changes the totals *and* the
    // shipments, and only `GET /checkout` knows the new ones. Skipped while
    // placing: the server empties the cart on success, and re-reading a review
    // for an order that already exists would flash an error over the receipt.
    ref.listen(cartControllerProvider, (previous, next) {
      if (_placing || previous?.value == null || next.value == null) return;
      if (identical(previous!.value, next.value)) return;
      ref.invalidate(checkoutReviewProvider);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l.checkoutTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: CheckoutStepsHeader(
            current: _step,
            onTapStep: _placing ? null : (step) => setState(() => _step = step),
          ),
        ),
      ),
      body: review.hasValue
          ? _body(review.requireValue)
          : review.hasError
              ? ErrorState(
                  error: review.error,
                  onRetry: () => ref.invalidate(checkoutReviewProvider),
                )
              : const _CheckoutSkeleton(),
      bottomNavigationBar: review.hasValue ? _bar(review.requireValue) : null,
    );
  }

  // ── Steps ────────────────────────────────────────────────────────────

  Widget _body(CheckoutReview review) {
    _syncSelection(review);
    final address = _resolvedAddress(review);

    return switch (_step) {
      CheckoutStep.address => CheckoutAddressStep(
          addresses: review.addresses,
          selectedId: _addressId,
          draft: _draftAddress,
          onSelect: (value) => setState(() {
            _addressId = value.id;
            _draftAddress = null;
            _draftFromPending = false;
          }),
          onSelectDraft: () => setState(() => _addressId = null),
          onNew: () => _openEditor(),
          onEdit: (value) => _openEditor(initial: value),
        ),
      CheckoutStep.review => CheckoutReviewStep(
          review: review,
          address: address,
          changedNotice: _changedNotice,
          onChangeAddress: () => setState(() => _step = CheckoutStep.address),
        ),
      CheckoutStep.payment => CheckoutPaymentStep(
          methods: review.paymentMethods,
          selectedId: _paymentId,
          onSelect: (method) => setState(() => _paymentId = method.id),
          notes: _notes,
        ),
    };
  }

  /// Keeps the selection valid against whatever the server just sent — a
  /// deleted address or a retired gateway must not survive as a stale id.
  void _syncSelection(CheckoutReview review) {
    if (_draftAddress == null &&
        (_addressId == null ||
            !review.addresses.any((a) => a.id == _addressId))) {
      _addressId = review.defaultAddress?.id;
    }
    if (_paymentId == null ||
        !review.paymentMethods.any((m) => m.id == _paymentId)) {
      _paymentId = review.paymentMethods.firstOrNull?.id;
    }
  }

  Address? _resolvedAddress(CheckoutReview review) {
    if (_draftAddress != null) return _draftAddress;
    for (final address in review.addresses) {
      if (address.id == _addressId) return address;
    }
    return null;
  }

  Future<void> _openEditor({Address? initial}) async {
    final store = ref.read(localStoreProvider);
    // An address pinned during the welcome journey has been waiting for this
    // moment: the customer finds it already typed out and only has to say who
    // is receiving it.
    final pending = initial == null ? store.pendingAddress : null;
    final seed = initial ?? (pending == null ? null : Address.fromJson(pending));

    final draft = await showAddressEditor(
      context,
      initial: seed,
      // "Don't save this one" is only a meaningful choice for a new address;
      // an entry already in the book is being edited, not opted out of.
      showSaveToggle: seed == null || !seed.isSaved,
    );
    if (draft == null || !mounted) return;

    if (!draft.save) {
      setState(() {
        _draftAddress = draft.address;
        _draftFromPending = pending != null;
        _addressId = null;
      });
      return;
    }

    try {
      final saved =
          await ref.read(addressesControllerProvider.notifier).save(draft.address);
      // It lives in the book now; a second copy on the device would come back
      // as a duplicate at the next checkout.
      if (pending != null) await store.setPendingAddress(null);
      if (!mounted) return;
      setState(() {
        _draftAddress = null;
        _draftFromPending = false;
        _addressId = saved.id;
      });
      // The book the review screen renders comes from GET /checkout, so it
      // has to be re-read for the new entry to appear.
      ref.invalidate(checkoutReviewProvider);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(context, e));
    }
  }

  // ── The bar ──────────────────────────────────────────────────────────

  Widget _bar(CheckoutReview review) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final method = review.paymentMethods
        .where((m) => m.id == _paymentId)
        .firstOrNull;

    final ready = switch (_step) {
      CheckoutStep.address => _addressId != null || _draftAddress != null,
      CheckoutStep.review => true,
      CheckoutStep.payment => method != null,
    };

    final label = switch (_step) {
      CheckoutStep.address || CheckoutStep.review => l.actionContinue,
      CheckoutStep.payment =>
        method?.isOnline == true ? l.checkoutPayNow : l.checkoutPlaceOrder,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton(
            onPressed: ready && !_placing ? _advance : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            child: _placing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: cs.onPrimary,
                        ),
                      ),
                      Gap.w12,
                      Text(l.checkoutPlacing),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label),
                      if (_step == CheckoutStep.payment) ...[
                        Gap.w8,
                        Container(
                          width: 1,
                          height: 16,
                          color: cs.onPrimary.withValues(alpha: 0.32),
                        ),
                        Gap.w8,
                        Text(Fmt.price(review.totals.total, locale: locale)),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _advance() {
    Haptics.light();
    switch (_step) {
      case CheckoutStep.address:
        setState(() => _step = CheckoutStep.review);
      case CheckoutStep.review:
        setState(() {
          _changedNotice = null;
          _step = CheckoutStep.payment;
        });
      case CheckoutStep.payment:
        unawaited(_place());
    }
  }

  // ── Placing the order ────────────────────────────────────────────────

  Future<void> _place() async {
    final l = L.of(context);
    final review = ref.read(checkoutReviewProvider).value;
    final payment = _paymentId;
    if (review == null || payment == null || _placing) return;

    setState(() => _placing = true);
    try {
      final order = await ref.read(checkoutRepositoryProvider).place(
            addressId: _draftAddress == null ? _addressId : null,
            address: _draftAddress,
            saveAddress: false,
            paymentMethod: payment,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );

      // The pinned address has done its job — an order carries it now, so it
      // must not be offered again at the next checkout.
      if (_draftFromPending) {
        await ref.read(localStoreProvider).setPendingAddress(null);
      }

      // The server emptied the cart; the badge must agree before the customer
      // lands anywhere that shows it.
      await ref.read(cartControllerProvider.notifier).refresh();
      if (!mounted) return;

      await Haptics.success();
      if (!mounted) return;

      final placed = order.withPromise(review.promise);
      context.pushReplacement(
        placed.paymentRequired ? '/checkout/pay' : '/checkout/done',
        extra: placed,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _handleFailure(e, l);
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      AppToast.error(context, errorMessage(context, e));
    }
  }

  /// A refusal at this point is never just a toast: each code has a step the
  /// customer has to be standing on to fix it.
  void _handleFailure(ApiException error, L l) {
    final message = errorMessage(context, error);
    Haptics.warning();

    switch (error.code) {
      case CheckoutErrors.cartChanged:
        // The basket was re-priced at the delivery address and moved. Take the
        // fresh cart the refusal carried, and send them back to look at it.
        final fresh = cartFromChangedError(error);
        if (fresh != null) {
          ref.read(cartControllerProvider.notifier).applyServerCart(fresh);
        }
        ref.invalidate(checkoutReviewProvider);
        setState(() {
          _changedNotice = message;
          _step = CheckoutStep.review;
        });
        AppToast.info(context, l.checkoutCartChangedTitle);

      case CheckoutErrors.cartEmpty:
        AppToast.error(context, message);
        unawaited(ref.read(cartControllerProvider.notifier).refresh());
        context.pop();

      case CheckoutErrors.gatewayUnavailable:
        ref.invalidate(checkoutReviewProvider);
        setState(() => _step = CheckoutStep.payment);
        AppToast.error(context, message);

      default:
        if (CheckoutErrors.addressCodes.contains(error.code)) {
          setState(() => _step = CheckoutStep.address);
        }
        AppToast.error(context, message);
    }
  }
}

class _CheckoutSkeleton extends StatelessWidget {
  const _CheckoutSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const SkeletonBox(width: 180, height: 22, radius: ZbTokens.rXs),
            Gap.h16,
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(width: double.infinity, height: 120, radius: ZbTokens.rLg),
              Gap.h12,
            ],
          ],
        ),
      );
}
