import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/product_models.dart';
import '../data/cart_controller.dart';

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
  final l = L.of(context);
  try {
    final notices = await ref.read(cartControllerProvider.notifier).add(
          productId: product.id,
          variationId: variationId,
          quantity: quantity,
          attributes: attributes,
        );

    ref.track(ZbEvent(
      type: ZbEvents.addToCart,
      itemCode: product.itemCode,
      zone: zone,
      payload: {'quantity': quantity},
    ));

    await Haptics.success();
    if (!context.mounted) return true;

    final notice = notices.where((n) => n.text.trim().isNotEmpty).firstOrNull;
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
  } catch (e) {
    if (!context.mounted) return false;
    Haptics.warning();
    AppToast.error(context, errorMessage(context, e));
    return false;
  }
}
