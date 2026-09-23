import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/shelf/shelf_controller.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';

/// «الاستراحة» between rails on the زوبكسي shelf, when إكسبريس is open for
/// this address: the animal runs across a teal card with the one fact that
/// makes إكسبريس worth a tap — it arrives in two hours. Tapping switches the
/// storefront. Shown once per page, only while the branch is serving.
class ExpressInterlude extends ConsumerWidget {
  const ExpressInterlude({super.key});

  static const double _runner = 62;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final rtl = context.isRtl;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 10),
      // The runner and its speed lines sit outside the pressable card: its
      // ink clips to the corners, and the runner breaks out over the edge.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PressScale(
            borderRadius: BorderRadius.circular(ZbTokens.rXl),
            onTap: () {
              Haptics.selection();
              ref.read(shelfProvider.notifier).select(Shelf.express);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: context.isDark ? ZbTokens.tealContainerDark : ZbTokens.teal,
                borderRadius: BorderRadius.circular(ZbTokens.rXl),
              ),
              child: Padding(
                // The runner's lane, at the far end.
                padding: const EdgeInsetsDirectional.only(end: 128),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.expressInterludeTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.25),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l.expressInterludeBody,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: ZbTokens.cream, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 16, color: ZbTokens.expressFg),
                          const SizedBox(width: 4),
                          Text(
                            l.expressInterludeCta,
                            style: const TextStyle(color: ZbTokens.tealDeep, fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            // Speed lines behind the runner, then the runner breaking out of
            // the card's top edge.
            for (final (dy, width, alpha) in const [(34.0, 22.0, 0.55), (46.0, 14.0, 0.4), (58.0, 26.0, 0.5)])
              PositionedDirectional(
                end: 98,
                top: dy,
                child: Container(
                  width: width,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            PositionedDirectional(
              end: 4,
              top: -18,
              child: Companion(ZbPose.run, fallback: ZbCast.dog, height: _runner, idle: ZbIdle.hop, flip: !rtl),
            ),
        ],
      ),
    );
  }
}
