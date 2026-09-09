import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/shelf/shelf_controller.dart';
import '../../core/shelf/shelf_identity.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme/zb_colors.dart';
import '../theme/zooboxi_tokens.dart';

/// The basket, kept in sight while shopping إكسبريس.
///
/// On زوبكسي the basket is a destination: you browse, you collect, you go to
/// it when you are done. On a two-hour shelf it is the running total of an
/// errand — every delivery app keeps it pinned for exactly that reason, and
/// its absence is most of why إكسبريس still read as a store.
///
/// Only on إكسبريس, and only with something in it. It rides above the menu in
/// the shell's own slot, so `Scaffold` folds its height into every page's
/// bottom padding and no screen has to know it exists.
class ExpressCartBar extends ConsumerWidget {
  const ExpressCartBar({super.key});

  static const double barHeight = 56;

  /// Whether the bar belongs on screen at all.
  ///
  /// Pulled out of `build` because it is the whole behaviour: on the basket's
  /// own page — or in the middle of paying for it — the bar would be a button
  /// back to where you are standing, and on زوبكسي it would blur the one
  /// difference the two storefronts are meant to have.
  @visibleForTesting
  static bool shows({
    required bool express,
    required String path,
    required int count,
  }) =>
      express &&
      count > 0 &&
      !(path == '/cart' || path.startsWith('/checkout'));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartGlance glance = ref.watch(cartGlanceProvider);
    final bool show = shows(
      express: ref.watch(resolvedShelfProvider) == Shelf.express,
      path: GoRouterState.of(context).uri.path,
      count: glance.count,
    );

    return AnimatedSize(
      duration: context.motion(Motion.enter),
      curve: Motion.emphasized,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: context.motion(Motion.enter),
        switchInCurve: Motion.emphasized,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: show
            ? _Bar(key: const ValueKey('basket'), glance: glance)
            : const SizedBox(key: ValueKey('none'), width: double.infinity),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.glance});

  final CartGlance glance;

  @override
  Widget build(BuildContext context) {
    final L l = L.of(context);
    final String locale = Localizations.localeOf(context).languageCode;
    final ShelfIdentity identity = ShelfIdentity.of(context, Shelf.express);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          onTap: () {
            Haptics.light();
            context.push('/cart');
          },
          child: Ink(
            height: ExpressCartBar.barHeight,
            decoration: BoxDecoration(
              gradient: identity.ribbon,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              boxShadow: [
                BoxShadow(
                  color: identity.accent.withValues(alpha: 0.34),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
            child: Row(
              children: [
                // The count as a counter, not as a sentence: a number in a
                // disc is read at a glance and needs no plural in any
                // language.
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: identity.onRibbon.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    Fmt.number(glance.count, locale: locale, decimals: 0),
                    style: context.tt.labelLarge?.copyWith(
                      color: identity.onRibbon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Gap.w10,
                Expanded(
                  child: Text(
                    l.cartTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleMedium?.copyWith(
                      color: identity.onRibbon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  Fmt.price(glance.subtotal, locale: locale, decimals: 0),
                  style: context.tt.titleMedium?.copyWith(
                    color: identity.onRibbon,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Gap.w4,
                Icon(
                  context.isRtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: identity.onRibbon.withValues(alpha: 0.9),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar alone, without the router or the basket behind it — so a sheet or
/// a test can draw exactly what the customer sees.
class ExpressCartBarPreview extends StatelessWidget {
  const ExpressCartBarPreview({super.key, required this.glance});

  final CartGlance glance;

  @override
  Widget build(BuildContext context) => _Bar(glance: glance);
}
