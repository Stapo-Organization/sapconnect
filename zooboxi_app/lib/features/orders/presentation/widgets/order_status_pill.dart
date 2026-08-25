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

    final cs = context.cs;
    final zb = context.zb;

    final (fg, bg) = switch (order.status) {
      'completed' => (zb.success, zb.success.withValues(alpha: 0.13)),
      'zb-ready' => (cs.primary, cs.primary.withValues(alpha: 0.13)),
      'processing' => (cs.primary, cs.primary.withValues(alpha: 0.10)),
      'pending' || 'on-hold' => (zb.warning, zb.warning.withValues(alpha: 0.15)),
      'failed' || 'cancelled' || 'refunded' => (cs.error, cs.errorContainer.withValues(alpha: 0.5)),
      _ => (cs.onSurfaceVariant, cs.surfaceContainerHigh),
    };

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
