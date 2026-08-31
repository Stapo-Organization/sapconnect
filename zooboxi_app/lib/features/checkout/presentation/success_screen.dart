import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/motion/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/mascot_peek.dart';
import '../../../core/widgets/sparkles.dart';
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
                  // The receipt block is a card so the mascots have an edge to
                  // peek over — the screen had no card of its own.
                  MascotPeek(
                    widthFactor: 0.70,
                    maxWidth: 280,
                    delay: const Duration(milliseconds: 520),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 18),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? cs.surfaceContainerLow
                            : ZbTokens.creamLogo,
                        borderRadius: BorderRadius.circular(ZbTokens.rXl),
                      ),
                      child: Column(
                        children: [
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
                            Gap.h16,
                            PromiseRecap(promise: order.promise),
                          ],
                        ],
                      ),
                    ),
                  ),
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

/// The order, packed and then confirmed.
///
/// The check is not the first thing that happens: the box closes its lid
/// first. That is the actual event — the order was *packed* — and it buys the
/// confirmation a beat of anticipation instead of a mark that is simply
/// already there. The check, the paw and the confetti follow it.
class _SuccessMark extends StatefulWidget {
  const _SuccessMark();

  @override
  State<_SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<_SuccessMark>
    with SingleTickerProviderStateMixin {
  /// The whole sequence: 700ms of packing, then the confirmation.
  static const Duration _total = Duration(milliseconds: 1400);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.reduceMotion) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;
    final still = context.reduceMotion;

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

    final paw = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: cs.surface,
        shape: BoxShape.circle,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ZbIcon(ZbIconKind.paw, size: 21, fill: 1, ink: zb.sale),
    );

    return SizedBox(
      width: _burstSide,
      height: _burstSide,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = still ? 1.0 : _c.value;

          final lid = 1 - Curves.easeOutBack.transform(_seg(t, 0, 0.5));
          // A short settle as the flaps meet — the box lands its own lid.
          final land = math.sin(math.pi * _seg(t, 0.42, 0.58));
          final boxOpacity = 1 - _seg(t, 0.56, 0.64);

          final appear = _seg(t, 0.5, 0.8);
          final checkScale = 0.6 + 0.4 * Curves.easeOutBack.transform(appear);
          final pawIn = _seg(t, 0.73, 0.95);

          return Stack(
            alignment: Alignment.center,
            children: [
              const SparkleField(sparkles: _successSparkles, twinkle: true),
              if (boxOpacity > 0)
                Opacity(
                  opacity: boxOpacity.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(
                      1 + 0.06 * land,
                      1 - 0.08 * land,
                      1,
                    ),
                    child: ZbIcon(
                      ZbIconKind.cart,
                      size: 120,
                      fill: 1,
                      lidOpen: lid.clamp(0.0, 1.0),
                      smile: 1,
                    ),
                  ),
                ),
              Opacity(
                opacity: _seg(t, 0.5, 0.67),
                child: Transform.scale(scale: checkScale, child: mark),
              ),
              PositionedDirectional(
                bottom: (_burstSide - 116) / 2 + 2,
                end: (_burstSide - 120) / 2 + 2,
                child: Opacity(
                  opacity: pawIn,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - Curves.easeOut.transform(pawIn))),
                    child: paw,
                  ),
                ),
              ),
            ],
          );
        },
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
      // Scaled down rather than wrapped or clipped: an order number that
      // ellipsises is worse than one a hair smaller, and the card it now sits
      // in leaves less room than the bare screen did.
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
      ),
    );
  }
}

/// The check circle plus its confetti halo. Bigger than the mark so the
/// sparkles orbit it instead of landing on it.
const double _burstSide = 190;

const List<SparkleSpec> _successSparkles = [
  SparkleSpec(dx: 0.10, dy: 0.26, size: 14, color: ZbTokens.sparkAmber, delay: Duration(milliseconds: 780)),
  SparkleSpec(dx: 0.50, dy: 0.04, size: 11, color: ZbTokens.logoTeal, delay: Duration(milliseconds: 850), rotation: 0.4),
  SparkleSpec(dx: 0.90, dy: 0.20, size: 18, color: ZbTokens.logoCoral, delay: Duration(milliseconds: 920)),
  SparkleSpec(dx: 0.04, dy: 0.66, size: 9, color: ZbTokens.logoTeal, delay: Duration(milliseconds: 990)),
  SparkleSpec(dx: 0.96, dy: 0.62, size: 12, color: ZbTokens.sparkAmber, delay: Duration(milliseconds: 1050), rotation: 0.3),
  SparkleSpec(dx: 0.24, dy: 0.94, size: 20, color: ZbTokens.logoCoral, delay: Duration(milliseconds: 1120)),
  SparkleSpec(dx: 0.74, dy: 0.96, size: 10, color: ZbTokens.sparkAmber, delay: Duration(milliseconds: 1180)),
];
