import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/haptics.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../data/loyalty_models.dart';

/// Reorder a supply line: the same product, the same pack, the same quantity
/// as last time — one tap, because that is the whole promise of the gauge.
///
/// A variable product with no chosen pack cannot be added blind, so it opens
/// the product instead; that is the honest fallback, not a failure.
Future<void> orderSupplyItem(
  BuildContext context,
  WidgetRef ref,
  SupplyItem item, {
  required String zone,
}) async {
  ref.read(eventsBufferProvider).track(
        ZbEvent(
          type: ZbEvents.supplyAction,
          zone: zone,
          payload: {'product_id': item.product.id, 'action': 'order'},
        ),
      );

  if (item.product.isVariable && item.variationId <= 0) {
    Haptics.light();
    await context.push<void>('/product/${item.product.id}', extra: item.product);
    return;
  }

  await addToCart(
    context,
    ref,
    product: item.product,
    variationId: item.variationId > 0 ? item.variationId : null,
    quantity: item.qtyLast,
    zone: zone,
  );
}
