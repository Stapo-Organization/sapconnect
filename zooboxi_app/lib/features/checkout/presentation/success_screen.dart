import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../data/checkout_models.dart';
import 'widgets/promise_recap.dart';

/// The moment the order lands.
///
/// It exists to do three things and nothing else: confirm, give the order
/// number, and repeat the dated promise. The `purchase` event fires here —
/// once — because this is the first point at which the order is real from the
/// customer's side as well as the server's.
class CheckoutSuccessScreen extends ConsumerStatefulWidget {
  const CheckoutSuccessScreen({super.key, required this.order});

  final PlacedOrder order;

  @override
  ConsumerState<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends ConsumerState<CheckoutSuccessScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(eventsBufferProvider).track(
          ZbEvent(
            type: ZbEvents.purchase,
            zone: 'checkout',
            payload: {
              'order_id': widget.order.orderId,
              'total': widget.order.total,
            },
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) => Haptics.success());
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final order = widget.order;

    return Scaffold(
      // No back arrow: the order exists, and the screen behind it is a
      // checkout that can no longer be completed.
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Center(child: _SuccessMark()),
                  Gap.h24,
                  Text(
                    l.successTitle,
                    style: context.tt.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Gap.h8,
                  Text(
                    l.successSubtitle,
                    style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  Gap.h20,
                  Center(
                    child: _OrderChip(
                      number: order.orderNumber,
                      total: Fmt.price(order.total, locale: locale),
                    ),
                  ),
                  if (!order.paymentRequired && order.paymentMethod == 'cod') ...[
                    Gap.h12,
                    Center(
                      child: Text(
                        l.successCodNote,
                        style: context.tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                  if (!order.promise.isEmpty) ...[
                    Gap.h24,
                    PromiseRecap(promise: order.promise),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Haptics.light();
                      context.pushReplacement('/orders/${order.orderId}');
                    },
                    icon: const Icon(Icons.local_shipping_outlined, size: 20),
                    label: Text(l.successTrack),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                  Gap.h8,
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(l.successKeepShopping),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A check that draws itself, with a paw that lands a beat later.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;
    final still = MediaQuery.disableAnimationsOf(context);

    final mark = Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        gradient: zb.brandGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, size: 54, color: Colors.white),
    );

    final paw = PositionedDirectional(
      bottom: 2,
      end: 2,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.surface,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Icon(Icons.pets_rounded, size: 19, color: zb.sale),
      ),
    );

    if (still) {
      return SizedBox(
        width: 120,
        height: 116,
        child: Stack(alignment: Alignment.center, children: [mark, paw]),
      );
    }

    return SizedBox(
      width: 120,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          mark
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 420.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 240.ms),
          paw
              .animate()
              .fadeIn(delay: 320.ms, duration: 260.ms)
              .moveY(begin: 10, end: 0, delay: 320.ms, duration: 300.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _OrderChip extends StatelessWidget {
  const _OrderChip({required this.number, required this.total});

  final String number;
  final String total;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.successOrderNumber(number),
            style: context.tt.titleSmall,
            textDirection: TextDirection.ltr,
          ),
          Gap.w12,
          Container(width: 1, height: 16, color: cs.outlineVariant),
          Gap.w12,
          Text(
            total,
            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
