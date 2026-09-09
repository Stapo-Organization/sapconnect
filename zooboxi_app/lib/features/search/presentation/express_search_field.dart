import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/motion/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import 'search_transition.dart';

/// The search field إكسبريس leads with.
///
/// On the زوبكسي shelf the header keeps a round button, because the strip
/// under the address is worth more as a shop window than as an empty input.
/// إكسبريس has no window to protect — nobody browses a dark store — and the
/// customer arrives knowing roughly what they want. So here the field is the
/// first thing on the page, full width, and its hint keeps naming things people
/// actually type: a brand, a bag of litter, a pouch.
///
/// It shares the button's hero tag, so tapping it still *becomes* the search
/// screen's field rather than jumping to it.
class SearchHeroField extends StatefulWidget {
  const SearchHeroField({super.key, required this.branch});

  final int branch;

  @override
  State<SearchHeroField> createState() => _SearchHeroFieldState();
}

class _SearchHeroFieldState extends State<SearchHeroField> {
  Timer? _rotate;
  int _hint = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One example every few seconds. A hint that changes is read as a
    // suggestion; one that never does is read as furniture. Reduce Motion
    // leaves it on the first example — still a suggestion, no movement.
    _rotate?.cancel();
    if (!context.reduceMotion) {
      _rotate = Timer.periodic(const Duration(milliseconds: 3200), (_) {
        if (mounted) setState(() => _hint = (_hint + 1) % 4);
      });
    }
  }

  @override
  void dispose() {
    _rotate?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    final examples = [
      l.expressSearchHint1,
      l.expressSearchHint2,
      l.expressSearchHint3,
      l.expressSearchHint4,
    ];

    return HeroMode(
      enabled: TickerMode.valuesOf(context).enabled,
      child: Hero(
        tag: searchHeroTagFor(widget.branch),
        createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
        flightShuttleBuilder: searchFlightShuttle,
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label: l.searchTitle,
            child: InkWell(
              onTap: () {
                Haptics.light();
                context.push('/search');
              },
              child: SizedBox(
                height: 46,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
                  child: Row(
                    children: [
                      ZbIcon(ZbIconKind.search, size: 20, ink: cs.onSurfaceVariant),
                      Gap.w10,
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: context.motion(Motion.enter),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.35),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Text(
                            l.expressSearchPrefix(examples[_hint]),
                            key: ValueKey(_hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                      ZbIcon(ZbIconKind.scan, size: 18, ink: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
