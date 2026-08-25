import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/order_models.dart';

/// The order's progress, top to bottom.
///
/// `done` is the server's word — it comes from the real `_zb_status_*_at`
/// stamps the branch writes, not from parsing a status string here. The first
/// step that is *not* done is the current one, and it gets a quiet pulse: the
/// only animated thing on the screen is the thing that is still happening.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.steps});

  final List<OrderTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final currentIndex = steps.indexWhere((s) => !s.done);

    return Column(
      children: [
        for (final (index, step) in steps.indexed)
          _TimelineRow(
            step: step,
            current: index == currentIndex,
            isLast: index == steps.length - 1,
            nextDone: index + 1 < steps.length && steps[index + 1].done,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.current,
    required this.isLast,
    required this.nextDone,
  });

  final OrderTimelineStep step;
  final bool current;
  final bool isLast;
  final bool nextDone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;
    final at = step.at;

    final active = step.done || current;
    final color = step.done
        ? zb.success
        : current
            ? cs.primary
            : cs.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _Marker(done: step.done, current: current, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: nextDone ? zb.success : cs.outlineVariant,
                  ),
                ),
            ],
          ),
          Gap.w12,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                  if (at != null) ...[
                    Gap.h4,
                    Text(
                      Fmt.dayTime(at, locale),
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatefulWidget {
  const _Marker({required this.done, required this.current, required this.color});

  final bool done;
  final bool current;
  final Color color;

  @override
  State<_Marker> createState() => _MarkerState();
}

class _MarkerState extends State<_Marker> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // Not initState: the pulse is suppressed under Reduce Motion, and reading
  // MediaQuery is only legal once dependencies are in place.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Marker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.current && !MediaQuery.disableAnimationsOf(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.done || widget.current
            ? widget.color
            : context.cs.surfaceContainerHigh,
        border: widget.done || widget.current
            ? null
            : Border.all(color: context.cs.outlineVariant, width: 2),
      ),
      child: widget.done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );

    if (!widget.current) return dot;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 22 + 12 * t,
                height: 22 + 12 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1 - t) * 0.28),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: dot,
    );
  }
}
