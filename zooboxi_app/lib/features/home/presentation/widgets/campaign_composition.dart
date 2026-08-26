import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/zb_image.dart';

/// The painted surface a composed campaign sits on.
///
/// Campaign artwork arrives as a photograph, not as a finished banner: the
/// copy is drawn by the app on top of a brand panel. Keeping the panel's
/// colours in one place is what stops a hero slide and a banner from being
/// two different-looking products.
@immutable
class CampaignPanel {
  const CampaignPanel({required this.gradient, required this.fg, required this.muted});

  final LinearGradient gradient;

  /// Foreground for copy laid over [gradient].
  final Color fg;
  final Color muted;

  static CampaignPanel of(BuildContext context, {String? campaignType}) {
    final dark = context.isDark;
    final clearance = campaignType == 'clearance';
    final colors = clearance
        ? (dark
            ? const [ZbTokens.coralContainerDark, ZbTokens.graphiteHigh]
            : const [ZbTokens.coralDark, ZbTokens.coral])
        : (dark
            ? const [ZbTokens.tealContainerDark, ZbTokens.graphiteHigh]
            : const [ZbTokens.tealDeep, ZbTokens.tealDark]);
    final fg = dark ? ZbTokens.inkDark : Colors.white;

    return CampaignPanel(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: colors,
      ),
      fg: fg,
      muted: fg.withValues(alpha: 0.82),
    );
  }

  /// A scrim under the copy column, fading out before it reaches the artwork.
  ///
  /// The panel gradient lightens toward its far end and the photo bleeds back
  /// toward the middle, so the copy can end up over whatever the creative
  /// happens to be. This holds the headline at a readable contrast in both
  /// themes without dulling the whole card.
  LinearGradient get copyScrim => LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [
          Colors.black.withValues(alpha: 0.22),
          Colors.black.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0, 0.6, 1],
      );

  /// Chip fill for a pill sitting on the panel.
  Color get chipFill => fg.withValues(alpha: 0.16);
}

/// Copy on the reading side, artwork on the far side, one soft fade between.
///
/// Merchandising art is a photograph of a product, not a finished banner: crop
/// it to a 4:1 strip and the copy baked into it lands half off the card. So the
/// app composes instead — the panel is painted, the photo bleeds off the END
/// edge and dissolves into it, and every word is live text that respects the
/// theme, the reading direction and the text scale.
class CampaignComposition extends StatelessWidget {
  const CampaignComposition({
    super.key,
    required this.panel,
    required this.copy,
    this.art,
    this.artFactor = 0.46,
    this.copyFactor = 0.60,
    this.padding = const EdgeInsetsDirectional.only(start: 16, end: 12, top: 14, bottom: 14),
  });

  final CampaignPanel panel;
  final Widget copy;
  final String? art;

  /// Share of the width the artwork covers, and the share the copy is allowed
  /// to run into. They overlap on purpose — the fade lives in that overlap.
  final double artFactor;
  final double copyFactor;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final blend = panel.gradient.colors.last;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: panel.gradient)),
        if (art != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: artFactor,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ZbImage(url: art, fit: BoxFit.cover, backgroundColor: Colors.transparent),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [blend, blend.withValues(alpha: 0)],
                        stops: const [0, 0.62],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        DecoratedBox(decoration: BoxDecoration(gradient: panel.copyScrim)),
        Padding(
          padding: padding,
          child: FractionallySizedBox(
            widthFactor: art == null ? 1 : copyFactor,
            alignment: AlignmentDirectional.centerStart,
            child: copy,
          ),
        ),
      ],
    );
  }
}
