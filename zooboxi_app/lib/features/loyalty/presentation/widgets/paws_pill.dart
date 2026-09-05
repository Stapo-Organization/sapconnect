import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import 'loyalty_art.dart';

/// The wallet as a chip: the paw coin and a number.
///
/// Balances are tabular — a figure that shifts its own width as it counts up
/// reads as a glitch, and this number appears in five places that must all
/// agree at a glance. The coin is always the coin, on every ground: it is an
/// object the customer owns, not an icon that takes the surface's colour.
class PawsPill extends StatelessWidget {
  const PawsPill({
    super.key,
    required this.paws,
    this.compact = false,
    this.onTap,
    this.foreground,
    this.background,
    this.showUnit = true,
  });

  final int paws;
  final bool compact;
  final VoidCallback? onTap;

  /// Overrides for a coloured surface (a tier card's own ground).
  final Color? foreground;
  final Color? background;

  /// False for the tightest slots, where the coin alone carries the unit.
  final bool showUnit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final dark = context.isDark;
    final fg = foreground ?? (dark ? ZbTokens.amberOnDark : const Color(0xFF8A5F08));
    final bg = background ??
        (dark ? ZbTokens.amberContainerDark : const Color(0xFFFCEFCF));

    final pill = Container(
      padding: EdgeInsetsDirectional.only(
        start: compact ? 5 : 6,
        end: compact ? 9 : 11,
        top: compact ? 3 : 4,
        bottom: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        border: Border.all(
          color: (foreground ?? ZbTokens.amber).withValues(alpha: dark ? 0.28 : 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PawCoin(size: compact ? 17 : 21),
          SizedBox(width: compact ? 5 : 7),
          Text(
            Fmt.number(paws, locale: locale, decimals: 0),
            style: (compact ? context.tt.labelMedium : context.tt.titleSmall)?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (showUnit) ...[
            const SizedBox(width: 4),
            Text(
              l.pawsUnit,
              style: (compact ? context.tt.labelSmall : context.tt.labelMedium)?.copyWith(
                color: fg.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZbTokens.rPill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, splashColor: cs.primary.withValues(alpha: 0.1), child: pill),
    );
  }
}

/// The tier's name on a small coloured chip, in the tier's own two hues.
///
/// The colours arrive from the store so the app and the web account page never
/// disagree about what «ذهبي» looks like — but a missing or malformed hex
/// falls back to the brand rather than to grey.
class TierChip extends StatelessWidget {
  const TierChip({
    super.key,
    required this.label,
    this.c1,
    this.c2,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final String? c1;
  final String? c2;
  final bool compact;
  final VoidCallback? onTap;

  /// The two tier hues, resolved with a brand fallback.
  static (Color, Color) colorsOf(BuildContext context, String? c1, String? c2) {
    final start = hexColor(c1) ?? context.cs.primary;
    final end = hexColor(c2) ?? hexColor(c1) ?? ZbTokens.tealDark;
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    final (start, end) = colorsOf(context, c1, c2);

    final chip = Container(
      padding: EdgeInsetsDirectional.only(
        start: compact ? 7 : 9,
        end: compact ? 10 : 12,
        top: compact ? 4 : 6,
        bottom: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [start, end],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        boxShadow: [
          BoxShadow(color: end.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            style: (compact ? context.tt.labelSmall : context.tt.labelMedium)?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZbTokens.rPill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: chip),
    );
  }
}
