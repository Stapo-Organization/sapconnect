import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../data/order_models.dart';

/// The order's status, coloured by what it means to the customer rather than
/// by WooCommerce's internal state machine: green once it is moving, amber
/// while it waits on them, muted once it is over.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.order, this.compact = false});

  final OrderSummary order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = order.statusLabel;
    if (label == null || label.isEmpty) return const SizedBox.shrink();

    final (fg, bg) = orderStatusColors(context, order.status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        label,
        style: (compact ? context.tt.labelSmall : context.tt.labelMedium)?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

/// What an order's state looks like: its ink and its ground.
///
/// Public because the orders list paints the same meaning twice — as this pill,
/// and as the rail down the card's reading edge — and two switch statements
/// over WooCommerce statuses would drift apart the first time one gained a
/// status the other did not.
(Color fg, Color bg) orderStatusColors(BuildContext context, String status) {
  final cs = context.cs;
  final zb = context.zb;

  return switch (status) {
    'completed' => (zb.success, zb.success.withValues(alpha: 0.13)),
    // Out for delivery is the furthest an order gets before it is over, so
    // it carries the same colour as "ready" but at full container strength.
    'zb-out-for-delivery' => (cs.primary, cs.primary.withValues(alpha: 0.20)),
    'zb-ready' => (cs.primary, cs.primary.withValues(alpha: 0.13)),
    'processing' => (cs.primary, cs.primary.withValues(alpha: 0.10)),
    'pending' || 'on-hold' => (zb.warning, zb.warning.withValues(alpha: 0.15)),
    'failed' || 'cancelled' || 'refunded' => (cs.error, cs.errorContainer.withValues(alpha: 0.5)),
    _ => (cs.onSurfaceVariant, cs.surfaceContainerHigh),
  };
}
