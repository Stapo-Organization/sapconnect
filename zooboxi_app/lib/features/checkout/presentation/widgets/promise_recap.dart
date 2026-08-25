import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/delivery_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/checkout_models.dart';

/// The dated promise, repeated at the moment of payment and again on the
/// receipt.
///
/// A split order is stated plainly rather than buried: the customer is about
/// to pay once for something that arrives twice, and finding that out from the
/// doorbell is how a good order becomes a complaint.
class PromiseRecap extends StatelessWidget {
  const PromiseRecap({super.key, required this.promise, this.dense = false});

  final DeliveryPromise promise;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (promise.isEmpty) return const SizedBox.shrink();

    final l = L.of(context);
    final cs = context.cs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: EdgeInsets.all(dense ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: 17, color: cs.primary),
              Gap.w8,
              Text(l.checkoutPromiseTitle, style: context.tt.titleSmall),
            ],
          ),
          if (promise.isSplit) ...[
            Gap.h4,
            Text(
              l.checkoutPromiseSplit,
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          Gap.h12,
          for (final (index, line) in promise.lines.indexed) ...[
            if (index > 0) Gap.h8,
            _PromiseRow(line: line),
          ],
        ],
      ),
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({required this.line});

  final PromiseLine line;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final pair = context.zb.tier(line.tier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: pair.bg,
            borderRadius: BorderRadius.circular(ZbTokens.rXs),
          ),
          alignment: Alignment.center,
          child: Icon(tierIcon(line.tier), size: 15, color: pair.fg),
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((line.label ?? '').isNotEmpty)
                Text(
                  line.label!,
                  style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              if ((line.when ?? '').isNotEmpty)
                Text(
                  line.when!,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
