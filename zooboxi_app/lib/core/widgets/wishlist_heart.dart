import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/zb_colors.dart';
import '../../features/auth/presentation/auth_sheet.dart';
import '../../features/wishlist/data/wishlist_controller.dart';
import '../../l10n/app_localizations.dart';
import '../motion/motion.dart';
import '../session/session_controller.dart';
import '../utils/haptics.dart';
import 'app_toast.dart';

/// The heart on a product card and product page.
///
/// State comes from the shared wishlist set, never from the card's own flag,
/// so hearting a product on the home rail also fills its heart in search
/// results. A guest tapping it gets the sign-in sheet rather than a silent
/// failure — the tap is the intent, and it completes after they sign in.
class WishlistHeart extends ConsumerStatefulWidget {
  const WishlistHeart({
    super.key,
    required this.productId,
    this.seeded = false,
    this.size = 34,
    this.onSurface = false,
  });

  final int productId;

  /// The `wishlisted` flag from the payload that supplied this card, used
  /// until the shared set has been loaded.
  final bool seeded;

  final double size;

  /// True when the heart sits on a plain surface (product page) rather than
  /// floating over an image, which changes its backing.
  final bool onSurface;

  @override
  ConsumerState<WishlistHeart> createState() => _WishlistHeartState();
}

class _WishlistHeartState extends ConsumerState<WishlistHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final l = L.of(context);
    final authed = ref.read(sessionProvider).isAuthenticated;
    if (!authed) {
      final signedIn = await showAuthSheet(context, reason: l.authRequiredWishlist);
      if (!signedIn || !mounted) return;
    }

    Haptics.light();
    if (!context.reduceMotion) {
      unawaited(_pop.forward(from: 0));
    }

    try {
      final nowWishlisted =
          await ref.read(wishlistControllerProvider.notifier).toggle(widget.productId);
      if (!mounted) return;
      AppToast.info(context, nowWishlisted ? l.wishlistAdded : l.wishlistRemoved);
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, L.of(context).errUnknown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;
    final saved = ref.watch(wishlistControllerProvider);
    // Until the shared set has loaded, trust the flag on the payload that
    // supplied this card — otherwise every heart blinks off then back on.
    final wishlisted =
        saved.contains(widget.productId) || (widget.seeded && saved.isEmpty);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Material(
        color: widget.onSurface
            ? cs.surfaceContainerHigh
            : cs.surface.withValues(alpha: 0.86),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _toggle,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.28).animate(
              CurvedAnimation(
                parent: _pop,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
            ),
            child: AnimatedSwitcher(
              duration: Motion.select,
              child: Icon(
                wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(wishlisted),
                size: widget.size * 0.52,
                color: wishlisted ? zb.sale : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
