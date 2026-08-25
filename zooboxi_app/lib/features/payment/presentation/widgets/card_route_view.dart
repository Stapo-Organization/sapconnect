import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../checkout/data/checkout_models.dart';
import '../../data/payment_service.dart';
import 'card_payment_panel.dart';

/// The card screen: what is owed, the gateway's form, and the way out to the
/// wallets. The escape hatch is a quiet text button on purpose — it is a
/// fallback, not a competing choice.
class CardRouteView extends StatelessWidget {
  const CardRouteView({
    super.key,
    required this.order,
    required this.config,
    required this.errorText,
    required this.busy,
    required this.onResult,
    required this.onAttempt,
    required this.onUseOtherMethods,
  });

  final PlacedOrder order;
  final PaymentConfig config;
  final String? errorText;
  final bool busy;
  final void Function(CardPaymentResult result) onResult;
  final VoidCallback onAttempt;
  final VoidCallback onUseOtherMethods;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          l.paymentAmountDue,
          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Gap.h4,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                Fmt.price(config.amount, locale: locale),
                style: context.tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
              ),
              child: Text(
                l.successOrderNumber(order.orderNumber),
                textDirection: TextDirection.ltr,
                style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        Gap.h24,
        CardPaymentPanel(
          config: config,
          onResult: onResult,
          onAttempt: onAttempt,
          errorText: errorText,
          busy: busy,
        ),
        Gap.h24,
        Row(
          children: [
            Expanded(child: Divider(color: cs.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l.actionOr,
                style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Expanded(child: Divider(color: cs.outlineVariant)),
          ],
        ),
        Gap.h8,
        TextButton(
          onPressed: busy ? null : onUseOtherMethods,
          child: Text(l.paymentOtherMethods, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
