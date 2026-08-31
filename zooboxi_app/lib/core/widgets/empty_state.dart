import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import 'mascot_peek.dart';

/// The illustrated empty state.
///
/// Empty is a normal outcome in a pet store — an untouched wishlist, a filter
/// with no matches — so it gets a warm, drawn moment rather than a shrug. The
/// paw motif ties every empty screen in the app together.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.mascot = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  /// Puts the state on a cream card with the logo's dog and cat peeking over
  /// its top edge. Reserved for the screens a customer *expected* to have
  /// something on them — cart, wishlist, orders, search results. Ignored when
  /// [compact], which has no room for it.
  final bool mascot;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;
    final size = compact ? 108.0 : 148.0;

    final illustration = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Halo(size: size, color: cs.primary, opacity: 0.06),
          _Halo(size: size * 0.74, color: cs.primary, opacity: 0.10),
          Container(
            width: compact ? 54 : 70,
            height: compact ? 54 : 70,
            decoration: BoxDecoration(
              gradient: zb.brandGradient,
              borderRadius: BorderRadius.circular(compact ? 18 : 24),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: compact ? 26 : 32),
          ),
          PositionedDirectional(
            top: compact ? 8 : 14,
            end: compact ? 10 : 16,
            child: Icon(
              Icons.pets_rounded,
              size: compact ? 13 : 17,
              color: zb.sale.withValues(alpha: 0.55),
            ),
          ),
          PositionedDirectional(
            bottom: compact ? 14 : 22,
            start: compact ? 6 : 10,
            child: Icon(
              Icons.pets_rounded,
              size: compact ? 9 : 12,
              color: cs.primary.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        illustration,
        SizedBox(height: compact ? 14 : 22),
        Text(title, style: context.tt.titleMedium, textAlign: TextAlign.center),
        Gap.h8,
        Text(
          message,
          style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          Gap.h24,
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    final still = MediaQuery.disableAnimationsOf(context);
    final body = still
        ? content
        : content
            .animate()
            .fadeIn(duration: 320.ms, curve: Curves.easeOut)
            .moveY(begin: 12, end: 0, duration: 320.ms, curve: Curves.easeOut);

    if (!mascot || compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: body,
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: MascotPeek(
          delay: const Duration(milliseconds: 260),
          child: Container(
            width: double.infinity,
            // Extra top padding leaves the illustration clear of the heads.
            padding: const EdgeInsets.fromLTRB(20, 34, 20, 20),
            decoration: BoxDecoration(
              color: context.isDark ? cs.surfaceContainerHigh : ZbTokens.creamLogo,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );
}
