import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/data/cart_controller.dart';

/// Checkout — placeholder for this phase.
///
/// The contract, models and repository for `GET /checkout` and
/// `POST /checkout` are all in place (`checkout_repository.dart`); what is
/// missing is the address picker, the map pin and the payment handoff, which
/// land with the payment work. Until then this screen is honest about it and
/// reassures the customer that nothing in their basket was lost.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cart = ref.watch(cartControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l.checkoutTitle)),
      body: Column(
        children: [
          Expanded(
            child: EmptyState(
              icon: Icons.shopping_bag_rounded,
              title: l.checkoutSoon,
              message: l.checkoutSoonHint,
              actionLabel: l.actionClose,
              onAction: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (cart != null && !cart.isEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cs.surface,
                    borderRadius: BorderRadius.circular(ZbTokens.rMd),
                    border: Border.all(color: context.cs.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.cartItems(cart.count),
                          style: context.tt.bodyMedium
                              ?.copyWith(color: context.cs.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        Fmt.price(cart.totals.total, locale: locale),
                        style: context.tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
