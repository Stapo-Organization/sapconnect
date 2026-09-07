import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/events_buffer.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/envelope.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/shelf/shelf_controller.dart';
import '../../catalog/data/product_models.dart';
import '../data/cart_controller.dart';
import '../data/cart_models.dart';

/// The one add-to-cart path in the app.
///
/// Every entry point — a rail card, a grid card, the product page's pinned bar
/// — goes through here, so the confirmation, the haptic, the analytics event
/// and the handling of a server notice are identical everywhere. A capped
/// quantity or a split shipment surfaces the *server's* wording, because it is
/// the only thing that knows what actually happened.
Future<bool> addToCart(
  BuildContext context,
  WidgetRef ref, {
  required ProductCard product,
  int? variationId,
  int quantity = 1,
  Map<String, String>? attributes,
  String? zone,
  // Card surfaces morph their own control into the stepper — that IS the
  // confirmation, so they skip the generic success toast. Server notices
  // (a capped quantity, a split) still surface: only the server knows those.
  bool quiet = false,
}) async {
  try {
    return await _post(
      context,
      ref,
      product: product,
      variationId: variationId,
      quantity: quantity,
      attributes: attributes,
      zone: zone,
      quiet: quiet,
    );
  } on ApiException catch (e) {
    // Not a failure — a question. The basket belongs to the other storefront,
    // and only the customer can say whether to move to it.
    if (e.code != 'shelf_conflict' || !context.mounted) rethrow;
    final basket = CartBasket.fromJson(asMap(e.data));
    final moved = await _offerSwitch(context, ref, basket);
    if (!moved || !context.mounted) return false;
    try {
      return await _post(
        context,
        ref,
        product: product,
        variationId: variationId,
        quantity: quantity,
        attributes: attributes,
        zone: zone,
        quiet: quiet,
      );
    } catch (e) {
      // The second attempt is the customer's last: a failure here has to be
      // said out loud, not thrown into a future nobody is holding.
      if (!context.mounted) return false;
      Haptics.warning();
      AppToast.error(context, errorMessage(context, e));
      return false;
    }
  } catch (e) {
    if (!context.mounted) return false;
    Haptics.warning();
    AppToast.error(context, errorMessage(context, e));
    return false;
  }
}

/// Asks whether to leave the current basket for the other storefront's, and
/// makes the swap when the answer is yes.
///
/// The wording carries the two things that decide the answer: what is in the
/// basket being left — which is kept, not discarded — and what is waiting in
/// the one being opened.
Future<bool> _offerSwitch(BuildContext context, WidgetRef ref, CartBasket basket) async {
  final l = L.of(context);
  final target = basket.otherShelf;
  if (target.isEmpty) return false;

  final leaving = _shelfName(l, basket.shelf);
  final entering = _shelfName(l, target);
  final confirmed = await showZbSheet<bool>(
        context,
        builder: (sheet) => BottomSheetScaffold(
          title: l.cartSwitchTitle(entering),
          subtitle: !basket.started
              // No basket yet: the product is simply from the other shop.
              ? l.cartSwitchBodyEmpty(entering)
              : basket.otherHasItems
                  ? l.cartSwitchBodyWaiting(leaving, entering, basket.otherCount)
                  : l.cartSwitchBody(leaving, entering),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(l.cartSwitchConfirm(entering)),
              ),
              Gap.h8,
              TextButton(
                onPressed: () => Navigator.of(sheet).pop(false),
                child: Text(l.actionCancel),
              ),
              Gap.h8,
            ],
          ),
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) return false;

  try {
    await ref.read(cartControllerProvider.notifier).switchBasket(target);
    // The tab follows the basket. They are shopping the other store now — and
    // the add that follows carries the shelf header, so leaving the tab behind
    // would have the server refuse the very product they just said yes to.
    ref
        .read(shelfProvider.notifier)
        .select(target == 'express' ? Shelf.express : Shelf.all);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    AppToast.error(context, errorMessage(context, e));
    return false;
  }
}

/// «إكسبريس» / «زوبكسي» — the storefront as the customer knows it.
String _shelfName(L l, String shelf) =>
    shelf == 'express' ? l.shelfExpressTab : l.shelfAllTab;

Future<bool> _post(
  BuildContext context,
  WidgetRef ref, {
  required ProductCard product,
  int? variationId,
  int quantity = 1,
  Map<String, String>? attributes,
  String? zone,
  bool quiet = false,
}) async {
  final l = L.of(context);
  {
    final result = await ref.read(cartControllerProvider.notifier).add(
          productId: product.id,
          variationId: variationId,
          quantity: quantity,
          attributes: attributes,
        );
    final notice =
        result.notices.where((n) => n.text.trim().isNotEmpty).firstOrNull;

    // A 200 whose cart came back without the product is a refusal wearing a
    // success code — the fulfilment guard trimmed it for this location. Say
    // so with the server's own words, and report failure so the card takes
    // its optimistic claim back.
    if (!result.added) {
      if (!context.mounted) return false;
      Haptics.warning();
      AppToast.error(context, notice?.text ?? l.cartItemUnreachable);
      return false;
    }

    ref.track(ZbEvent(
      type: ZbEvents.addToCart,
      itemCode: product.itemCode,
      zone: zone,
      payload: {'quantity': quantity},
    ));

    await Haptics.success();
    if (!context.mounted) return true;

    if (notice != null) {
      if (notice.isError) {
        AppToast.error(context, notice.text);
      } else {
        AppToast.info(context, notice.text);
      }
    } else if (!quiet) {
      AppToast.success(context, l.pdpAddedToCart);
    }
    return true;
  }
}
