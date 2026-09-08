import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/motion/motion.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/zb_image.dart';
import '../../features/orders/data/live_tracking.dart';
import '../../features/orders/data/order_models.dart';
import '../../features/orders/data/orders_repository.dart';
import '../../features/orders/presentation/widgets/live_tracking_card.dart';
import '../../l10n/app_localizations.dart';
import '../theme/zb_colors.dart';
import '../theme/zooboxi_tokens.dart';

/// «طلبك الآن» — the order you are waiting on, riding above the tab bar.
///
/// A customer who has just bought something keeps shopping, and the thing they
/// most want to know is not on any of the four tabs. So the order comes to
/// them: a second slab of the same glass as the menu, docked over it, carrying
/// the one sentence that matters and the minutes left. Tapping it opens the
/// whole thing — map, courier, timeline — without leaving the shop.
///
/// It shows nothing at all when there is nothing to wait on, which is most of
/// the time. That is the point: it must be free when it is empty.
class LiveOrderBar extends ConsumerWidget {
  const LiveOrderBar({super.key});

  static const double _sideMargin = 14;
  static const double _radius = 22;
  static const double barHeight = 58;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The route is read first, on purpose. On an order's own page the bar is a
    // summary of what already fills the screen, and subscribing anyway would
    // put a second poller on the same order beside the page's own.
    final path = GoRouterState.of(context).uri.path;
    final onAnOrderPage = path.startsWith('/orders/');

    if (onAnOrderPage) return const SizedBox(width: double.infinity);

    final active = ref.watch(activeOrderProvider).value;

    // AnimatedSize rather than a plain conditional: the bar arriving under the
    // customer's thumb mid-scroll should push the menu down, not appear on top
    // of what they were reading.
    return AnimatedSize(
      duration: context.motion(Motion.select),
      curve: Motion.emphasized,
      alignment: Alignment.bottomCenter,
      // AnimatedSwitcher inside, so the bar fades rather than blinking out
      // while AnimatedSize collapses the space it leaves behind.
      child: AnimatedSwitcher(
        duration: context.motion(Motion.select),
        child: active == null
            ? const SizedBox(key: ValueKey('none'), width: double.infinity)
            : _Bar(key: ValueKey(active.order.id), active: active),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.active});

  final ActiveOrder active;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final dark = context.isDark;
    final tone = _tone(context, active);

    return Semantics(
      button: true,
      label: _headline(context, active),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: LiveOrderBar._sideMargin,
            end: LiveOrderBar._sideMargin,
            bottom: 8,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LiveOrderBar._radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.30 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: GlassContainer(
              shape: const LiquidRoundedSuperellipse(borderRadius: LiveOrderBar._radius),
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: LiquidGlassSettings(
                // The same barely-there tint as the menu below it, so the two
                // read as one piece of glass rather than two materials stacked.
                glassColor: dark
                    ? ZbTokens.graphiteRaised.withValues(alpha: 0.24)
                    : cs.surface.withValues(alpha: 0.20),
                blur: 11,
              ),
              // No splash: the menu below made the same call, and for the same
              // reason — a ripple on frosted glass reads as a smudge.
              child: InkWell(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                onTap: () {
                  Haptics.light();
                  _openSheet(context, active);
                },
                child: SizedBox(
                  height: LiveOrderBar.barHeight,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
                        child: Row(
                          children: [
                            _Glyph(active: active, tone: tone),
                            Gap.w12,
                            Expanded(child: _Lines(active: active)),
                            Gap.w8,
                            _Trailing(active: active, tone: tone),
                          ],
                        ),
                      ),
                      // A hairline of progress along the bottom lip. It is the
                      // cheapest honest answer to "how far along is this" — no
                      // words, no space, readable at a glance.
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: 0,
                        child: _ProgressLip(progress: liveOrderProgress(active), tone: tone),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.active});

  final ActiveOrder active;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headline(context, active),
          style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${l.liveBarOrderNo(active.order.number)} · '
          '${l.liveBarItems(active.order.itemsCount)} · '
          '${Fmt.price(active.order.total, locale: locale)}',
          style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The minutes when we have them, the first product's photo when we do not.
///
/// A thumbnail is a better right-hand anchor than a chevron: it tells the
/// customer *which* order this is at a glance, which is the question a bar with
/// no arrival time cannot otherwise answer.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.active, required this.tone});

  final ActiveOrder active;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final eta = active.tracking?.etaMinutes;

    if (eta != null && eta <= 120) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(ZbTokens.rPill)),
        child: Text(
          eta <= 0 ? l.liveTrackEtaNow : l.liveTrackEta(eta),
          style: context.tt.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
    }

    final image = active.order.itemsPreview.isEmpty ? null : active.order.itemsPreview.first.image;

    if (image == null) {
      return Icon(Icons.expand_less_rounded, size: 20, color: context.cs.onSurfaceVariant);
    }

    return SizedBox(
      width: 38,
      height: 38,
      child: ZbImage(url: image, fit: BoxFit.cover, radius: BorderRadius.circular(ZbTokens.rSm)),
    );
  }
}

/// A pulse while anything is moving, still once it is not.
class _Glyph extends StatefulWidget {
  const _Glyph({required this.active, required this.tone});

  final ActiveOrder active;
  final Color tone;

  @override
  State<_Glyph> createState() => _GlyphState();
}

class _GlyphState extends State<_Glyph> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (widget.active.tracking?.phase) {
      LivePhase.searching => Icons.radar_rounded,
      LivePhase.assigned => Icons.storefront_rounded,
      LivePhase.inTransit => Icons.two_wheeler_rounded,
      LivePhase.delivered => Icons.check_rounded,
      LivePhase.failed => Icons.error_outline_rounded,
      null => Icons.inventory_2_rounded,
    };

    final core = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: widget.tone, shape: BoxShape.circle),
      child: Icon(icon, size: 17, color: Colors.white),
    );

    if (!_c.isAnimating) return core;

    // The halo repaints every frame; the glass behind it must not.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_c.value);
          return SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32 + 18 * t,
                  height: 32 + 18 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.tone.withValues(alpha: 0.20 * (1 - t)),
                  ),
                ),
                ?child,
              ],
            ),
          );
        },
        child: core,
      ),
    );
  }
}

class _ProgressLip extends StatelessWidget {
  const _ProgressLip({required this.progress, required this.tone});

  final double progress;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: context.motion(Motion.select),
          curve: Motion.emphasized,
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: math.max(value, 0.04),
            child: ColoredBox(color: tone.withValues(alpha: 0.85)),
          ),
        ),
      ),
    );
  }
}

/* ── The expanded view ──────────────────────────────────────────── */

void _openSheet(BuildContext context, ActiveOrder active) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _Sheet(orderId: active.order.id, initial: active),
  );
}

/// The whole order, without leaving the shop.
///
/// It watches the same feed the bar does, so a courier assigned while the sheet
/// is open appears here — the customer opened it precisely because they wanted
/// to keep looking.
///
/// But it is pinned to the order it was opened for. The feed answers "the order
/// you are waiting on", and that can become a DIFFERENT order mid-gesture — a
/// second express order placed, or this one completing. Following it would swap
/// the contents under the customer's finger while every button still pointed at
/// the first order.
class _Sheet extends ConsumerWidget {
  const _Sheet({required this.orderId, required this.initial});

  final int orderId;
  final ActiveOrder initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final feed = ref.watch(activeOrderProvider).value;

    // Fresh news about THIS order, or nothing. `initial` is only the opening
    // frame — leaning on it after the feed has moved on would leave a delivered
    // order reading "on the way" for as long as the sheet stayed open.
    final fresh = feed?.order.id == orderId ? feed : null;
    final finished = feed != null && fresh == null;
    final active = fresh ?? initial;
    final tracking = active.tracking;

    return DraggableScrollableSheet(
      initialChildSize: tracking?.hasMap == true ? 0.72 : 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ZbTokens.rXl)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + MediaQuery.paddingOf(context).bottom),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                ),
              ),
            ),
            Gap.h16,
            Row(
              children: [
                Expanded(child: Text(l.liveBarTitle, style: context.tt.titleMedium)),
                Text(
                  l.liveBarOrderNo(active.order.number),
                  style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            Gap.h12,

            if (finished)
              // The order left the live feed while this was open. Say so
              // plainly rather than showing a courier who has already gone.
              _Finished(orderId: orderId)
            else if (tracking != null)
              LiveTrackingCard(tracking: tracking, orderId: orderId)
            else
              _Preparing(active: active),

            Gap.h12,
            _Items(order: active.order),
            Gap.h16,

            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.of(context).push('/orders/$orderId');
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: Text(l.liveBarOpen),
            ),
          ],
        ),
      ),
    );
  }
}

/// The order finished while the sheet was open — delivered, or cancelled. The
/// receipt is the honest next screen, so the sheet points at it.
class _Finished extends StatelessWidget {
  const _Finished({required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final zb = context.zb;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: zb.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: zb.success.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: zb.success, size: 26),
          Gap.w12,
          Expanded(child: Text(l.liveTrackDelivered, style: context.tt.titleSmall)),
        ],
      ),
    );
  }
}

/// Before a courier exists there is no map to draw, so the sheet says the true
/// thing plainly rather than showing an empty frame.
class _Preparing extends StatelessWidget {
  const _Preparing({required this.active});

  final ActiveOrder active;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tone = _tone(context, active);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          _Glyph(active: active, tone: tone),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_headline(context, active), style: context.tt.titleSmall),
                Gap.h4,
                Text(
                  active.order.statusLabel ?? '',
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final preview = order.itemsPreview;
    if (preview.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: preview.length,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, i) => SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            children: [
              Positioned.fill(
                child: ZbImage(
                  url: preview[i].image,
                  fit: BoxFit.cover,
                  radius: BorderRadius.circular(ZbTokens.rSm),
                ),
              ),
              if (preview[i].qty > 1)
                PositionedDirectional(
                  end: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: context.cs.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(ZbTokens.rPill),
                    ),
                    child: Text('${preview[i].qty}', style: context.tt.labelSmall),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ── Shared wording, colour and progress ────────────────────────── */

String _headline(BuildContext context, ActiveOrder active) {
  final l = L.of(context);
  final tracking = active.tracking;

  if (tracking != null) return liveStatusLine(context, tracking);

  return active.order.status == 'zb-ready' ? l.liveBarReady : l.liveBarPreparing;
}

Color _tone(BuildContext context, ActiveOrder active) {
  final phase = active.tracking?.phase;
  if (phase == null) return context.cs.primary;
  return livePhaseColor(context, phase);
}

/// How far along, as a fraction. Preparation is deliberately given the first
/// third: a customer who has waited ten minutes for a box to be packed has not
/// made no progress, and a bar stuck at zero says they have.
@visibleForTesting
double liveOrderProgress(ActiveOrder active) => switch (active.tracking?.phase) {
  LivePhase.searching => 0.4,
  LivePhase.assigned => 0.6,
  LivePhase.inTransit => 0.85,
  LivePhase.delivered => 1,
  LivePhase.failed => 1,
  null => active.order.status == 'zb-ready' ? 0.3 : 0.15,
};
