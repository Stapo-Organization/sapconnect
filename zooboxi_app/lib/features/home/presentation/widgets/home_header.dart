import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../location/presentation/location_sheet.dart';

/// The home header: who we're delivering to, and the two things a customer
/// reaches for first — search and their saved list.
///
/// [onCanvas] renders it for the hero canvas — the deep colored panel the
/// header fuses with — so every stroke turns light and the search field stays
/// a bright, obvious well on top of the color.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, this.onCanvas = false});

  final bool onCanvas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(sessionProvider).user;
    final fg = onCanvas ? _canvasFg(context) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LogoSticker(),
              Gap.w10,
              // The chip stays Expanded, so the sticker's fixed width is the
              // only thing it gives up.
              Expanded(child: LocationChip(onCanvas: onCanvas)),
              IconButton(
                onPressed: () {
                  Haptics.light();
                  context.push('/wishlist');
                },
                icon: Icon(Icons.favorite_border_rounded, color: fg),
                tooltip: l.wishlistTitle,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8, top: 4, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    user == null ? l.homeGreeting : '${l.homeGreeting.split(' ').first} ${user.firstName}',
                    style: context.tt.headlineSmall?.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PromiseLine(onCanvas: onCanvas),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
            child: _SearchBar(
              onCanvas: onCanvas,
              onTap: () => context.push('/search'),
              onScan: () => context.push('/scan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The logo, sitting on the header as a small printed sticker. Decor, not a
/// control — it has no tap target on purpose.
class _LogoSticker extends StatelessWidget {
  const _LogoSticker();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.92) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // The sticker is height-driven; the aspect gives the Row a finite width
      // instead of the asset's intrinsic 1400px.
      child: const AspectRatio(
        aspectRatio: 1400 / 1204,
        child: Image(
          image: AssetImage('assets/brand/logo_full.png'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Foreground for header strokes sitting on the hero canvas — always light,
/// because every canvas color is deep by design.
Color _canvasFg(BuildContext context) =>
    context.isDark ? ZbTokens.inkDark : Colors.white;

/// A tap target that *looks* like a field but pushes the search screen — so
/// the keyboard and the suggestion list belong to one screen instead of
/// half-opening over the home feed.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap, required this.onScan, this.onCanvas = false});

  final VoidCallback onTap;
  final VoidCallback onScan;
  final bool onCanvas;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    // On the canvas the field is the one bright object — a white well in
    // light theme, the raised surface in dark. Off-canvas it stays subtle.
    final fill = onCanvas
        ? (context.isDark ? cs.surfaceContainerHigh : Colors.white)
        : cs.surfaceContainerHigh;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      clipBehavior: Clip.antiAlias,
      elevation: onCanvas ? 1.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: InkWell(
        onTap: () {
          Haptics.light();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 2, bottom: 2),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              Gap.w12,
              Expanded(
                child: Text(
                  l.searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              IconButton(
                onPressed: () {
                  Haptics.light();
                  onScan();
                },
                icon: Icon(Icons.qr_code_scanner_rounded, size: 20, color: cs.primary),
                tooltip: l.searchScan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
