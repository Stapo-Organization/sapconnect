import 'package:flutter/widgets.dart';

/// Places on screen that an animation needs to fly *to*.
///
/// A fly-to-cart has to end on the cart tab, and the only widget that knows
/// where the cart tab is, is the tab bar. Rather than thread a key through
/// every screen that can add to a basket, the bar publishes its glyph here.

/// Attached to the cart tab's glyph by the tab bar. Null-safe by design: when
/// the bar is not mounted (a full-screen flow, a test harness) the animation
/// simply does not play.
final GlobalKey cartTabAnchorKey = GlobalKey(debugLabel: 'zb-cart-anchor');

/// The cart glyph's box in global coordinates, or null when there is nothing
/// laid out to fly to.
Rect? cartAnchorRect() {
  final context = cartTabAnchorKey.currentContext;
  if (context == null) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}
