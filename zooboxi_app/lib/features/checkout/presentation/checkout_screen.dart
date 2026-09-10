import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/location/location_controller.dart';
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
import 'widgets/address_picker.dart';
import 'widgets/payment_step.dart';
import 'widgets/review_step.dart';

/// Checkout, on one page.
///
/// It was three steps behind one header — address, review, payment — and they
/// are not three decisions. The address changes the shipments, the shipments
/// change the total, the total is what is being paid; walking a customer
/// through them one at a time made each re-price look like a new page instead
/// of a consequence, and put two taps between someone and an order they had
/// already decided to place. Now it reads top to bottom and the address is a
/// card that opens a picker.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

/// Which address checkout should open on.
///
/// Two rules, and the order matters. **Never** an address this basket cannot
/// be sent to: the app choosing one for them is exactly how an إكسبريس order
/// ends up outside its branch's zone without anyone deciding to send it there,
/// and the quantities were quoted against that branch's shelf. Then, among the
/// ones that work, the address the whole shop has been quoting — the header
/// said «يوصلك في العمل», the stock and the ETA were computed for it, so
/// checkout opening on «المنزل» would be the app changing its mind at the till.
///
/// Null means nothing here can take this basket, which is a real answer: the
/// page says so and the button refuses rather than picking something wrong.
@visibleForTesting
String? preselectedAddressId({
  required List<Address> addresses,
  required Address? defaultAddress,
  required String? activeId,
}) {
  final servable = [for (final address in addresses) if (address.serves) address];
  if (servable.isEmpty) return null;

  final quoted =
      activeId == null ? null : servable.where((a) => a.id == activeId).firstOrNull;
  final fallback =
      defaultAddress != null && defaultAddress.serves ? defaultAddress : servable.first;

  return (quoted ?? fallback).id;
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notes = TextEditingController();

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
      appBar: AppBar(title: Text(l.checkoutTitle)),
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

  // ── The page ─────────────────────────────────────────────────────────

  Widget _body(CheckoutReview review) {
    _syncSelection(review);

    return CheckoutBody(
      review: review,
      address: _resolvedAddress(review),
      changedNotice: _changedNotice,
      onChangeAddress: () => unawaited(_pickAddress(review)),
      payment: CheckoutPaymentSection(
        methods: review.paymentMethods,
        selectedId: _paymentId,
        onSelect: (method) => setState(() => _paymentId = method.id),
        notes: _notes,
      ),
    );
  }

  /// The address detour: a sheet over the page rather than a step behind it.
  Future<void> _pickAddress(CheckoutReview review) async {
    Haptics.selection();
    final result = await showAddressPicker(
      context,
      addresses: review.addresses,
      draft: _draftAddress,
      selectedId: _addressId,
      draftSelected: _draftAddress != null && _addressId == null,
    );
    if (result == null || !mounted) return;

    if (result.isNew) {
      await _openEditor();
      return;
    }

    final chosen = result.address!;
    setState(() {
      if (chosen.isSaved) {
        _addressId = chosen.id;
        _draftAddress = null;
        _draftFromPending = false;
      } else {
        _addressId = null;
      }
    });
    // The basket is re-priced at the destination, so a new address means new
    // shipments and a new total — read them before the customer pays for the
    // old ones.
    ref.invalidate(checkoutReviewProvider);
  }

  /// Keeps the selection valid against whatever the server just sent — a
  /// deleted address or a retired gateway must not survive as a stale id.
  void _syncSelection(CheckoutReview review) {
    if (_draftAddress == null &&
        (_addressId == null ||
            !review.addresses.any((a) => a.id == _addressId))) {
      _addressId = preselectedAddressId(
        addresses: review.addresses,
        defaultAddress: review.defaultAddress,
        activeId: ref.read(locationProvider).location.addressId,
      );
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

    final address = _resolvedAddress(review);
    final blocked = address != null && !address.serves;
    final ready = address != null && !blocked && method != null;

    final label = method?.isOnline == true
        ? l.checkoutPayNow
        : l.checkoutPlaceOrder;

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
                      ...[
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
    unawaited(_place());
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
        // One page, so there is nowhere to send them back to — the banner
        // rides at the top of what they are already looking at.
        setState(() => _changedNotice = message);
        AppToast.info(context, l.checkoutCartChangedTitle);

      case CheckoutErrors.cartEmpty:
        AppToast.error(context, message);
        unawaited(ref.read(cartControllerProvider.notifier).refresh());
        context.pop();

      case CheckoutErrors.gatewayUnavailable:
        // The gateway went away between the page loading and the tap. Re-read
        // the methods so the row that no longer exists stops being offered.
        ref.invalidate(checkoutReviewProvider);
        AppToast.error(context, message);

      default:
        // An address the server refused is one the app should stop holding —
        // re-reading tells us whether it is gone, or merely out of zone.
        if (CheckoutErrors.addressCodes.contains(error.code)) {
          ref.invalidate(checkoutReviewProvider);
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
