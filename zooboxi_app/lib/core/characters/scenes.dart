import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'characters.dart';
import 'companion.dart';
import 'props.dart';

/// The illustrated moments for empty screens. Each one is a small stage: the
/// customer's own animal in the pose that says what to do next, standing on a
/// soft contact shadow, with at most one prop. Laid out by reading direction,
/// so the animal leads from the start edge in Arabic and in English alike.

/// The one-line wash behind a scene — a light disc or arch in a brand tint.
Color _wash(BuildContext context, Color light) =>
    context.isDark ? context.cs.surfaceContainerHigh : light;

/// Mirrors a sticker drawn facing left so it faces the end edge in any
/// reading direction.
bool _faceEnd(BuildContext context) => !context.isRtl;

/// «المفضّلة» empty: the animal, delighted, with a glossy heart floating off.
class WishlistScene extends StatelessWidget {
  const WishlistScene({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 224,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 18,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _wash(context, ZbTokens.coralTintSoft),
              ),
            ),
          ),
          const Positioned(bottom: -8, child: ZbGround(width: 180, height: 20)),
          const Positioned(
            bottom: 0,
            child: Companion(
              ZbPose.wow,
              height: 190,
              delay: Duration(milliseconds: 120),
            ),
          ),
          PositionedDirectional(
            top: 16,
            end: 10,
            child: ZbSticker.prop(
              ZbProp.heart,
              width: 66,
              idle: ZbIdle.float,
              delay: const Duration(milliseconds: 360),
            ),
          ),
          PositionedDirectional(
            top: 6,
            start: 18,
            child: ZbSticker.prop(
              ZbProp.hearts,
              width: 42,
              delay: const Duration(milliseconds: 480),
            ),
          ),
        ],
      ),
    );
  }
}

/// «السلة» empty: an empty food bowl, and the animal sitting beside it.
class CartScene extends StatelessWidget {
  const CartScene({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 214,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 14,
            child: Container(
              width: 250,
              height: 188,
              decoration: BoxDecoration(
                color: _wash(context, ZbTokens.tealTintSoft),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(125),
                  bottom: Radius.circular(24),
                ),
              ),
            ),
          ),
          const Positioned(bottom: -8, child: ZbGround(width: 250, height: 20)),
          const PositionedDirectional(
            bottom: 0,
            end: 30,
            child: EmptyBowl(width: 124),
          ),
          PositionedDirectional(
            bottom: 0,
            start: 26,
            child: Companion(
              ZbPose.sitUp,
              fallback: ZbCast.dog,
              height: 186,
              flip: _faceEnd(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A search with no results: the animal points at what was searched.
class SearchScene extends StatelessWidget {
  const SearchScene({super.key, this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    final q = query?.trim() ?? '';
    return SizedBox(
      width: 300,
      height: 206,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const PositionedDirectional(
            bottom: -8,
            start: 10,
            child: ZbGround(width: 150, height: 18),
          ),
          PositionedDirectional(
            bottom: 0,
            start: 6,
            child: Companion(
              ZbPose.point,
              fallback: ZbCast.dog,
              height: 196,
              flip: _faceEnd(context),
            ),
          ),
          if (q.isNotEmpty)
            PositionedDirectional(top: 52, end: 0, child: _QueryPill(query: q)),
        ],
      ),
    );
  }
}

class _QueryPill extends StatelessWidget {
  const _QueryPill({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.titleSmall?.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: ZbTokens.coral,
                decorationThickness: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «طلباتي» empty: the animal presents what the first order will look like —
/// a ghost of the tracking card.
class OrdersScene extends StatelessWidget {
  const OrdersScene({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 214,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const PositionedDirectional(top: 12, end: 0, child: _GhostTracking()),
          const PositionedDirectional(
            bottom: -8,
            start: 14,
            child: ZbGround(width: 150, height: 18),
          ),
          PositionedDirectional(
            bottom: 0,
            start: 4,
            child: Companion(
              ZbPose.present,
              height: 204,
              flip: _faceEnd(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostTracking extends StatelessWidget {
  const _GhostTracking();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final steps = [
      l.ordersGhostPlaced,
      l.ordersGhostPacking,
      l.ordersGhostOnWay,
      l.ordersGhostArrived,
    ];
    return Container(
      width: 158,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.ordersGhostTitle,
            style: context.tt.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < steps.length; i++)
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == 0 ? cs.primary : cs.outlineVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    steps[i],
                    style: context.tt.bodySmall?.copyWith(
                      color: i == 0 ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The generic empty moment: the animal peeking over the top edge of the
/// card that holds the message. Replaces the old crop of the logo — the logo
/// is never cut up; the characters are drawn to peek.
class PeekOverCard extends StatelessWidget {
  const PeekOverCard({
    super.key,
    required this.child,
    this.height = 96,
    this.delay = const Duration(milliseconds: 220),
  });

  final Widget child;
  final double height;
  final Duration delay;

  /// How much of the peek hides behind the card: its paws grip the edge.
  static const double tuck = 0.16;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(top: height * (1 - tuck)),
          child: child,
        ),
        Companion(
          ZbPose.peek,
          height: height,
          idle: ZbIdle.breathe,
          delay: delay,
        ),
      ],
    );
  }
}
