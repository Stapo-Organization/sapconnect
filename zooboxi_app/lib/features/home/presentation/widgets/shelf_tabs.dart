import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/shelf/shelf_controller.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';

/// The two storefronts, as tabs above everything else.
///
/// إكسبريس is the 2-hour dark store; زوبكسي is the whole catalogue. Inside an
/// express zone both are open and a sliding thumb marks the one being
/// browsed. Outside one, the express tab stays visible but dimmed — the
/// customer should learn the fast store *exists* — and tapping it explains
/// why it is closed here instead of doing nothing.
class ShelfTabs extends ConsumerWidget {
  const ShelfTabs({super.key, this.onCanvas = false});

  /// True when the tabs sit on the hero's deep-coloured canvas.
  final bool onCanvas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final shelf = ref.watch(shelfProvider);
    final expressOpen = ref.watch(expressAvailableProvider);
    final still = context.reduceMotion;

    final cs = context.cs;
    final track = onCanvas
        ? Colors.black.withValues(alpha: 0.18)
        : cs.surfaceContainerHigh;
    final thumb = onCanvas
        ? (context.isDark ? ZbTokens.graphiteHighest : Colors.white)
        : (context.isDark ? ZbTokens.graphiteHighest : Colors.white);

    // In RTL the first child sits on the right — إكسبريس leads.
    final expressSelected = shelf == Shelf.express;
    final align = expressSelected
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;

    void pick(Shelf target) {
      if (target == Shelf.express && !expressOpen) {
        Haptics.warning();
        AppToast.info(context, l.shelfExpressClosed);
        return;
      }
      if (target == shelf) return;
      Haptics.selection();
      ref.read(shelfProvider.notifier).select(target);
    }

    return Semantics(
      container: true,
      label: l.shelfTabsLabel,
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: align,
              duration: still ? Duration.zero : Motion.select,
              curve: Motion.emphasized,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumb,
                    borderRadius: BorderRadius.circular(ZbTokens.rPill),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _Tab(
                    label: l.shelfExpressTab,
                    icon: Icons.bolt_rounded,
                    selected: expressSelected,
                    enabled: expressOpen,
                    accent: context.isDark ? ZbTokens.expressFgDark : ZbTokens.expressFg,
                    onCanvas: onCanvas,
                    onTap: () => pick(Shelf.express),
                  ),
                ),
                Expanded(
                  child: _Tab(
                    label: l.shelfAllTab,
                    icon: Icons.storefront_rounded,
                    selected: !expressSelected,
                    enabled: true,
                    accent: context.isDark ? ZbTokens.tealOnDark : ZbTokens.tealDeep,
                    onCanvas: onCanvas,
                    onTap: () => pick(Shelf.all),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.accent,
    required this.onCanvas,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;

  /// False = the storefront does not exist here; the tab dims but stays
  /// tappable so it can explain itself.
  final bool enabled;
  final Color accent;
  final bool onCanvas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final resting = onCanvas
        ? (context.isDark ? ZbTokens.inkDark : Colors.white).withValues(alpha: 0.85)
        : cs.onSurfaceVariant;
    final color = selected ? accent : resting;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        child: Opacity(
          opacity: enabled ? 1 : 0.42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              Gap.w4,
              AnimatedDefaultTextStyle(
                duration: context.motion(Motion.select),
                style: (context.tt.labelLarge ?? const TextStyle()).copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
