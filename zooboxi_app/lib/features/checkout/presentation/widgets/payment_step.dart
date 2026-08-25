import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/checkout_models.dart';

/// Step three: how it gets paid for, plus the note for the driver.
///
/// The methods are whatever WooCommerce actually reports as available — the
/// app never hardcodes a gateway, so one being switched off on the store is a
/// row disappearing here rather than a failed order.
class CheckoutPaymentStep extends StatelessWidget {
  const CheckoutPaymentStep({
    super.key,
    required this.methods,
    required this.selectedId,
    required this.onSelect,
    required this.notes,
  });

  final List<PaymentMethod> methods;
  final String? selectedId;
  final ValueChanged<PaymentMethod> onSelect;
  final TextEditingController notes;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Text(l.checkoutPaymentTitle, style: context.tt.titleLarge),
        Gap.h16,

        if (methods.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.checkoutPaymentEmpty,
                  style: context.tt.titleSmall?.copyWith(color: cs.error),
                ),
                Gap.h4,
                Text(l.checkoutPaymentEmptyHint, style: context.tt.bodySmall),
              ],
            ),
          )
        else
          for (final method in methods) ...[
            _MethodTile(
              method: method,
              selected: method.id == selectedId,
              onTap: () {
                Haptics.selection();
                onSelect(method);
              },
            ),
            Gap.h12,
          ],

        Gap.h8,
        TextField(
          controller: notes,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: l.checkoutNotesLabel,
            hintText: l.checkoutNotesHint,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return AnimatedContainer(
      duration: context.motion(Motion.select),
      curve: Motion.decelerate,
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer.withValues(alpha: 0.30) : cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: PressScale(
        onTap: onTap,
        haptic: null,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? cs.primary : cs.outline,
              ),
              Gap.w12,
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(ZbTokens.rSm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  method.isOnline
                      ? Icons.credit_card_rounded
                      : Icons.payments_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.label, style: context.tt.titleSmall),
                    if ((method.sub ?? '').isNotEmpty) ...[
                      Gap.h4,
                      Text(
                        method.sub!,
                        style: context.tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
