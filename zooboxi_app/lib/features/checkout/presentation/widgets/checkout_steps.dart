import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../l10n/app_localizations.dart';

/// The three moments of a checkout, in order.
enum CheckoutStep { address, review, payment }

/// The step header.
///
/// Three dots and two rails rather than a progress bar: a customer needs to
/// know how many decisions are left, and a bar that fills from 33% to 66%
/// answers a question nobody asked.
class CheckoutStepsHeader extends StatelessWidget {
  const CheckoutStepsHeader({super.key, required this.current, this.onTapStep});

  final CheckoutStep current;

  /// Only completed steps are tappable — going back to change an address is
  /// normal; skipping ahead past one is not.
  final ValueChanged<CheckoutStep>? onTapStep;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    final labels = {
      CheckoutStep.address: l.checkoutStepAddress,
      CheckoutStep.review: l.checkoutStepReview,
      CheckoutStep.payment: l.checkoutStepPayment,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          for (final (index, step) in CheckoutStep.values.indexed) ...[
            if (index > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: step.index <= current.index
                      ? cs.primary
                      : cs.outlineVariant,
                ),
              ),
            _StepDot(
              index: index,
              label: labels[step]!,
              done: step.index < current.index,
              active: step == current,
              onTap: step.index < current.index && onTapStep != null
                  ? () => onTapStep!(step)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final filled = done || active;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: context.motion(Motion.select),
            curve: Motion.decelerate,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? cs.primary : cs.surfaceContainerHigh,
              border: Border.all(
                color: active ? cs.primary : Colors.transparent,
                width: 2.4,
              ),
            ),
            alignment: Alignment.center,
            child: done
                ? Icon(Icons.check_rounded, size: 15, color: cs.onPrimary)
                : Text(
                    '${index + 1}',
                    style: context.tt.labelSmall?.copyWith(
                      color: filled ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          Gap.h4,
          Text(
            label,
            style: context.tt.labelSmall?.copyWith(
              color: active ? cs.primary : cs.onSurfaceVariant,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
