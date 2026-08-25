import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../motion/motion.dart';
import '../utils/haptics.dart';

/// Compact −/+ control.
///
/// [max] is the number the *server* says can reach this customer, so the minus
/// and plus disable at real boundaries rather than at an optimistic guess. At
/// quantity 1 the minus becomes a delete affordance, which is how people
/// actually remove the last unit.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max,
    this.min = 1,
    this.onRemove,
    this.busy = false,
    this.dense = false,
    this.stretch = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int? max;
  final int min;

  /// When provided, pressing minus at [min] removes the line instead.
  final VoidCallback? onRemove;
  final bool busy;
  final bool dense;

  /// Fills the width it is given, pushing the two buttons to the edges. Used
  /// on a product card, where the stepper replaces a full-width add pill and
  /// must occupy exactly the same footprint.
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final cap = max;
    final canIncrease = !busy && (cap == null || value < cap);
    final canDecrease = !busy && (value > min || onRemove != null);
    final atFloor = value <= min;

    final size = dense ? 30.0 : 34.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            stretch ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          _StepButton(
            icon: atFloor && onRemove != null
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            size: size,
            enabled: canDecrease,
            danger: atFloor && onRemove != null,
            onTap: () {
              if (atFloor) {
                onRemove?.call();
              } else {
                onChanged(value - 1);
              }
            },
          ),
          SizedBox(
            width: dense ? 30 : 38,
            child: busy
                ? Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                    ),
                  )
                : Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            size: size,
            enabled: canIncrease,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final double size;
  final bool enabled;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final foreground = !enabled
        ? cs.onSurfaceVariant.withValues(alpha: 0.35)
        : (danger ? cs.error : cs.onSurface);

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: enabled ? cs.surface : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  Haptics.selection();
                  onTap();
                }
              : null,
          child: Icon(icon, size: 17, color: foreground),
        ),
      ),
    );
  }
}

/// The circular "+" that lives on a product card until the item is in the
/// cart, at which point the card swaps it for a full [QtyStepper].
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onTap, this.enabled = true, this.busy = false});

  final VoidCallback onTap;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return AnimatedContainer(
      duration: Motion.select,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: enabled ? cs.primary : cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled && !busy ? onTap : null,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                )
              : Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: enabled ? cs.onPrimary : cs.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}
