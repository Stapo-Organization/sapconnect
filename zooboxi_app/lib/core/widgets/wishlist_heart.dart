import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/auth/presentation/auth_sheet.dart';
import '../../features/wishlist/data/wishlist_controller.dart';
import '../../l10n/app_localizations.dart';
import '../icons/zb_icons.dart';
import '../motion/motion.dart';
import '../session/session_controller.dart';
import '../utils/haptics.dart';
import 'app_toast.dart';
import 'sparkles.dart';

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
  static const Duration _onFor = Duration(milliseconds: 520);
  static const Duration _offFor = Duration(milliseconds: 220);

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: _onFor,
  );

  /// Which way the last tap went — hearting something is a small celebration,
  /// un-hearting it is not.
  bool _celebrating = false;

  /// A pop that lands past 1 and settles back, rather than a linear grow: the
  /// heart has to feel *pressed*.
  late final Animation<double> _onScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.6, end: 1.25).chain(CurveTween(curve: Curves.easeOut)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 62,
    ),
  ]).animate(_pop);

  late final Animation<double> _offScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeInOut));

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

    final saved = ref.read(wishlistControllerProvider);
    final turningOn =
        !(saved.contains(widget.productId) || (widget.seeded && saved.isEmpty));

    Haptics.light();
    if (!context.reduceMotion) {
      setState(() => _celebrating = turningOn);
      _pop.duration = turningOn ? _onFor : _offFor;
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
          child: AnimatedBuilder(
            animation: _pop,
            builder: (context, _) {
              final bursting =
                  _celebrating && _pop.isAnimating && _pop.value < 0.85;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: _celebrating ? _onScale.value : _offScale.value,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: wishlisted ? 1.0 : 0.0),
                      duration: context.motion(Motion.select),
                      builder: (context, fill, _) => ZbIcon(
                        ZbIconKind.heart,
                        size: widget.size * 0.56,
                        fill: fill,
                        ink: Color.lerp(
                          cs.onSurfaceVariant,
                          resolveZbInk(context),
                          fill,
                        ),
                      ),
                    ),
                  ),
                  if (bursting)
                    Positioned(
                      left: -widget.size * 0.18,
                      top: -widget.size * 0.18,
                      width: widget.size * 1.36,
                      height: widget.size * 1.36,
                      child: const SparkleField(sparkles: _heartBurst),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Four sparkles thrown off the heart the moment it fills.
const List<SparkleSpec> _heartBurst = [
  SparkleSpec(dx: 0.04, dy: 0.20, size: 7, color: ZbTokens.sparkAmber),
  SparkleSpec(
    dx: 0.92,
    dy: 0.10,
    size: 5.5,
    color: ZbTokens.logoTeal,
    delay: Duration(milliseconds: 50),
    rotation: 0.4,
  ),
  SparkleSpec(
    dx: 0.96,
    dy: 0.80,
    size: 8,
    color: ZbTokens.logoCoral,
    delay: Duration(milliseconds: 100),
  ),
  SparkleSpec(
    dx: 0.14,
    dy: 0.92,
    size: 6,
    color: ZbTokens.sparkAmber,
    delay: Duration(milliseconds: 150),
    rotation: 0.3,
  ),
];
