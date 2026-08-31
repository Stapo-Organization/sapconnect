import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/zooboxi_tokens.dart';
import '../icons/zb_icons.dart';
import 'anchors.dart';

/// The product that was just added, thrown to the cart tab.
///
/// The arc is the whole point: a straight line reads as a UI transition, a
/// lifted curve reads as an object being tossed into a box. It lands exactly
/// on the cart glyph, which is already bumping its badge — the two together
/// answer "where did that go?" without a toast.
///
/// Returns silently when there is nothing to fly to (no tab bar on screen) or
/// when the customer has asked for less motion.
void flyToCart(
  BuildContext context, {
  required Rect from,
  ImageProvider? image,
}) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
  final target = cartAnchorRect();
  if (target == null) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingItem(
      from: from.center,
      to: target.center,
      image: image,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

/// The artwork for a thrown thumbnail. Null for a product with no photo — the
/// flight falls back to the box glyph rather than to a broken image.
ImageProvider? productThumbnail(String? url) =>
    url == null || url.isEmpty ? null : CachedNetworkImageProvider(url);

class _FlyingItem extends StatefulWidget {
  const _FlyingItem({
    required this.from,
    required this.to,
    required this.onDone,
    this.image,
  });

  final Offset from;
  final Offset to;
  final ImageProvider? image;
  final VoidCallback onDone;

  static const double side = 30;

  @override
  State<_FlyingItem> createState() => _FlyingItemState();
}

class _FlyingItemState extends State<_FlyingItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });

  /// Lifted well above the straight line so the throw has an arc even when the
  /// two points are nearly level — a card in the bottom row of a grid.
  late final Offset _control = Offset(
    (widget.from.dx + widget.to.dx) / 2,
    math.min(widget.from.dy, widget.to.dy) - 120,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _at(double t) {
    final u = 1 - t;
    return widget.from * (u * u) + _control * (2 * u * t) + widget.to * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    const side = _FlyingItem.side;
    final image = widget.image;

    // Positioned has to stay the outermost widget: the overlay lays its
    // entries out in a Stack, and anything wrapped around it applies parent
    // data the Stack cannot read.
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInCubic.transform(_c.value);
        final at = _at(t);
        final scale = 1 - 0.65 * t;
        // Only the tail fades: a thumbnail that dims for the whole flight
        // reads as a bug, not as an arrival.
        final opacity = t < 0.8 ? 1.0 : (1 - t) / 0.2;
        return Positioned(
          left: at.dx - side / 2,
          top: at.dy - side / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: image == null ? ZbTokens.logoTeal : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? const Center(
                child: ZbIcon(
                  ZbIconKind.plusBox,
                  size: 20,
                  fill: 1,
                  ink: Colors.white,
                ),
              )
            : Image(image: image, fit: BoxFit.cover),
      ),
    );
  }
}
