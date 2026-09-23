import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/characters/characters.dart';
import '../../../core/characters/companion.dart';
import '../../../core/notifications/notify_permission.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../../pets/data/household.dart';
import '../../loyalty/presentation/widgets/loyalty_art.dart';
import '../../loyalty/presentation/widgets/scratch_card_view.dart';
import '../../orders/data/orders_repository.dart';
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
  /// Whether this phone is still worth asking. Hidden by default: a customer
  /// who has already granted the permission must not be asked for it again,
  /// and the answer only arrives a frame or two after the screen does.
  bool _offerNotify = false;
  bool _asking = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Haptics.success();
      // «طلباتي» is imperative paging, not a provider — this is how it learns
      // that the order the customer just placed exists. After the frame:
      // writing to a provider during initState is a build-phase mutation.
      if (mounted) ref.read(ordersRevisionProvider.notifier).bump();
    });
    // The order just moved the wallet and may have minted a card; whatever the
    // family hub had cached is now stale.
    invalidateLoyalty(ref);
    // And the live bar above the tab bar exists for exactly this moment. Its
    // idle cadence is two minutes; without this the customer walks back into
    // the shop and waits up to that long to see the thing they just bought.
    ref.invalidate(activeOrderProvider);

    // The one moment the question answers itself: there is now an order to
    // follow, so «نبلّغك بحالة طلبك؟» is about something concrete rather than
    // about notifications in the abstract — which is how the welcome journey
    // used to lose it.
    unawaited(_readPermission());
  }

  Future<void> _readPermission() async {
    String status;
    try {
      status = await NotifyPermission.status();
    } catch (_) {
      // No channel, no offer. Never a broken card.
      return;
    }
    if (!mounted) return;
    // 'provisional' means notifications are already arriving quietly; asking
    // is how they start ringing. 'undetermined' means iOS has not been asked
    // at all. Anything else — granted, denied — has nothing left to ask.
    if (status == 'provisional' || status == 'undetermined') {
      setState(() => _offerNotify = true);
    }
  }

  /// The full prompt, and then the token the store needs to use it.
  ///
  /// The card goes away either way: iOS shows that dialog once, and a card
  /// that stays after a refusal is a card that will never be tapped.
  Future<void> _askNotify() async {
    Haptics.light();
    setState(() => _asking = true);
    var granted = false;
    try {
      granted = await NotifyPermission.request();
    } catch (_) {
      // Treated as a no.
    }
    if (!mounted) return;
    setState(() {
      _offerNotify = false;
      _asking = false;
    });
    if (!granted) return;
    try {
      await ref.read(pushServiceProvider).refreshRegistration();
    } catch (_) {
      // A device the store did not hear about re-registers on next launch.
    }
    await Haptics.success();
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
                  const Center(child: _Celebration()),
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
                  // The card lands *between* the confirmation and the
                  // receipt: it is the reward for the order that just
                  // happened, and burying it under the totals would make it
                  // look like an ad. Nothing about it blocks the flow — the
                  // tracking button below works whether or not it is rubbed.
                  if (order.scratchCard != null) ...[
                    ScratchCardView(card: order.scratchCard!, compact: true),
                    Gap.h16,
                  ],
                  // The one sentence that keeps the program honest at the
                  // moment it matters most: nothing lands until the box does.
                  if (order.pawsToEarn > 0) ...[
                    _DeliveryNote(
                      paws: Fmt.number(order.pawsToEarn, locale: locale, decimals: 0),
                      withMission: order.scratchCard != null,
                      subscription: order.subscriptionOrder,
                    ),
                    Gap.h24,
                  ],
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
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
                  if (_offerNotify) ...[
                    Gap.h16,
                    _NotifyCard(busy: _asking, onAsk: () => unawaited(_askNotify())),
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


/// «نبلّغك بحالة طلبك؟» — asked here, and only here.
///
/// Deliberately quiet: a tonal button under the receipt, not a second
/// confirmation competing with the one the screen exists for. A customer who
/// ignores it still gets everything the order promised.
class _NotifyCard extends StatelessWidget {
  const _NotifyCard({required this.busy, required this.onAsk});

  final bool busy;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active_outlined, size: 20, color: cs.primary),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.successNotifyTitle,
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Gap.h4,
                    Text(
                      l.successNotifyBody,
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h12,
          FilledButton.tonal(
            onPressed: busy ? null : onAsk,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(l.successNotifyAction),
          ),
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

class _DeliveryNote extends StatelessWidget {
  const _DeliveryNote({required this.paws, required this.withMission, this.subscription = false});

  final String paws;
  final bool withMission;

  /// This basket delivered a subscription — say what that adds.
  final bool subscription;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.isDark ? ZbTokens.amberContainerDark : ZbTokens.amberTint,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
      ),
      child: Row(
        children: [
          const PawCoin(size: 30),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.successPawsNote(paws),
                  style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (withMission)
                  Text(
                    l.successMissionNote,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                if (subscription)
                  Text(
                    l.successSubscriptionNote,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The order is in: the family celebrates. The customer's own animals when we
/// know them (two at most), otherwise the logo's pair, the cat and the dog,
/// under a burst of confetti drawn in the same hand.
class _Celebration extends ConsumerWidget {
  const _Celebration();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(householdProvider);
    final cast = <ZbCast>[
      for (final species in household.species) ?castForSpecies(species),
    ].take(2).toList();
    if (cast.isEmpty) cast.addAll(const [ZbCast.dog, ZbCast.cat]);

    return SizedBox(
      width: 300,
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(top: 0, child: ZbSticker.prop(ZbProp.confetti, width: 270)),
          const Positioned(bottom: -8, child: ZbGround(width: 240, height: 22)),
          if (cast.length == 2) ...[
            PositionedDirectional(
              bottom: 0,
              start: 38,
              child: Companion(ZbPose.celebrate, cast: cast[0], height: 200, idle: ZbIdle.hop,
                  delay: const Duration(milliseconds: 180)),
            ),
            PositionedDirectional(
              bottom: 0,
              end: 38,
              child: Companion(ZbPose.celebrate, cast: cast[1], height: 190,
                  delay: const Duration(milliseconds: 300)),
            ),
          ] else
            Positioned(
              bottom: 0,
              child: Companion(ZbPose.celebrate, cast: cast[0], height: 206, idle: ZbIdle.hop,
                  delay: const Duration(milliseconds: 180)),
            ),
        ],
      ),
    );
  }
}
