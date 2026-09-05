import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import 'loyalty_art.dart';

/// A reward this customer already holds, drawn as a ticket: the stub carries
/// the sticker on its wash, the perforation is real, and the body says which
/// of three states it is in.
///
/// Three states, three sentences: waiting on a delivery, ready to carry into
/// the cart, or already in it. The waiting state is the important one — the
/// program's whole promise is "on delivery", and a card that hid that would be
/// the first place the promise looked like a trick.
class GrantCard extends StatelessWidget {
  const GrantCard({
    super.key,
    required this.grant,
    this.onUse,
    this.onRemove,
    this.busy = false,
  });

  final Grant grant;

  /// Claims it into the cart. Null hides the action (a pending grant).
  final Future<void> Function()? onUse;

  /// Releases the claim. Null when it isn't in the cart.
  final Future<void> Function()? onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;
    final reward = grant.reward;
    final pendingOrder = grant.activatesOnOrder;
    final hue = rewardKindHue(context, reward.kind);

    final status = grant.isPending
        ? (pendingOrder == null ? l.rewardPending : l.rewardPendingOrder(pendingOrder.number))
        : (grant.expiresAt != null ? l.rewardExpires(Fmt.dateShort(grant.expiresAt!, locale)) : null);

    return ClipPath(
      clipper: _TicketClipper(notchRadius: 9, stubWidth: 104, rtl: context.isRtl),
      child: Container(
        color: cs.surface,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: grant.isClaimed ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(ZbTokens.rXl),
                ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The stub.
                  Container(
                    width: 104,
                    decoration: BoxDecoration(gradient: rewardKindWash(context, reward.kind)),
                    alignment: Alignment.center,
                    child: RewardSticker(kind: reward.kind, size: 60),
                  ),
                  // The perforation.
                  const _Perforation(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            rewardKindLabel(l, reward.kind),
                            style: context.tt.labelSmall?.copyWith(color: hue, fontWeight: FontWeight.w800),
                          ),
                          Gap.h4,
                          Text(
                            reward.title,
                            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (status != null) ...[
                            Gap.h4,
                            Row(
                              children: [
                                FamilyMarkIcon(
                                  grant.isPending ? FamilyMark.clock : FamilyMark.check,
                                  size: 15,
                                  color: grant.isPending ? null : zb.success,
                                ),
                                Gap.w4,
                                Expanded(
                                  child: Text(
                                    status,
                                    style: context.tt.labelSmall?.copyWith(
                                      color: grant.isPending
                                          ? (context.isDark ? zb.warning : const Color(0xFF8A5510))
                                          : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (onUse != null || onRemove != null) ...[
                            Gap.h8,
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : grant.isClaimed
                                      ? TextButton.icon(
                                          onPressed: onRemove == null ? null : () => onRemove!(),
                                          icon: const Icon(Icons.close_rounded, size: 16),
                                          label: Text(l.rewardRemove),
                                          style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                                        )
                                      : FilledButton(
                                          onPressed: onUse == null ? null : () => onUse!(),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: hue,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(0, 38),
                                            padding: const EdgeInsets.symmetric(horizontal: 18),
                                          ),
                                          child: Text(l.rewardUseInCart),
                                        ),
                            ),
                          ] else if (grant.isClaimed) ...[
                            Gap.h8,
                            Row(
                              children: [
                                FamilyMarkIcon(FamilyMark.check, size: 15, color: cs.primary),
                                Gap.w4,
                                Text(
                                  l.rewardInCart,
                                  style: context.tt.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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

/// A dashed vertical line where the stub tears off.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => CustomPaint(
        // Width only: the stretch in the row sets the height, and an infinite
        // preferred height would poison IntrinsicHeight above it.
        size: const Size(1, 0),
        painter: _PerforationPainter(context.cs.outlineVariant),
      );
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    // Leave room for the notches at both ends.
    for (var y = 14.0; y < size.height - 12; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter old) => old.color != color;
}

/// The ticket silhouette: rounded corners and two half-circle notches where
/// the stub meets the body. Direction-aware — the stub is on the start edge.
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({required this.notchRadius, required this.stubWidth, required this.rtl});

  final double notchRadius;
  final double stubWidth;
  final bool rtl;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(ZbTokens.rXl)));
    final x = rtl ? size.width - stubWidth : stubWidth;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: notchRadius))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: notchRadius));
    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  bool shouldReclip(covariant _TicketClipper old) =>
      old.notchRadius != notchRadius || old.stubWidth != stubWidth || old.rtl != rtl;
}
