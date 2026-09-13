import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/zb_image.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/catalog_models.dart';

/// «تحتاج الآن؟» as four coloured pockets.
///
/// A two-hour order is placed by need — the litter ran out, the pouches are
/// gone — so the needs get the biggest tiles on the page, each in its own
/// colour with a lit pocket in the corner the way a shelf bin is lit from
/// inside. Four is the whole row a thumb can read at once; anything past four
/// waits in a line of chips beneath.
class NeedPockets extends StatelessWidget {
  const NeedPockets({super.key, required this.items});

  final List<NeedNavItem> items;

  static const double tileHeight = 118;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final pockets = items.take(4).toList();
    final rest = items.skip(4).toList();
    final rows = <List<NeedNavItem>>[
      for (var i = 0; i < pockets.length; i += 2) pockets.sublist(i, (i + 2).clamp(0, pockets.length)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.homeNeedsTitle,
                  style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const _ShelfPill(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) Gap.h12,
                Row(
                  children: [
                    Expanded(child: _Pocket(item: rows[r][0])),
                    Gap.w12,
                    Expanded(
                      child: rows[r].length > 1 ? _Pocket(item: rows[r][1]) : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (rest.isNotEmpty) ...[
          Gap.h12,
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: rest.length,
              separatorBuilder: (_, _) => Gap.w8,
              itemBuilder: (context, index) => _Chip(item: rest[index]),
            ),
          ),
        ],
      ],
    );
  }

  /// The icon a need wears — shared with the store's need row.
  static IconData icon(String key) => switch (key) {
        'dry' => Icons.grain_rounded,
        'wet' => Icons.soup_kitchen_rounded,
        'litter' => Icons.inventory_2_rounded,
        'treats' => Icons.cookie_rounded,
        'health' => Icons.favorite_rounded,
        'toys' => Icons.toys_rounded,
        'clean' => Icons.soap_rounded,
        'food' => Icons.restaurant_rounded,
        'supplies' => Icons.category_rounded,
        _ => Icons.category_rounded,
      };

  /// Each need keeps one colour pair so the grid reads at a glance. Deep,
  /// saturated — these are the tiles that make the page colourful.
  static NeedPaint paintOf(String key) => switch (key) {
        'dry' || 'food' => const NeedPaint(Color(0xFFFFB86B), Color(0xFFE5893F)),
        'wet' => const NeedPaint(Color(0xFF5DAEA7), Color(0xFF2D7A79)),
        'litter' => const NeedPaint(Color(0xFF2D7A79), Color(0xFF174847)),
        'treats' => const NeedPaint(Color(0xFFFFE070), Color(0xFFF0B62A), ink: Color(0xFF5A3A00)),
        'health' => const NeedPaint(Color(0xFFF49076), Color(0xFFC85A47)),
        'clean' => const NeedPaint(Color(0xFF7FB9D6), Color(0xFF3E7FA6)),
        'toys' => const NeedPaint(Color(0xFF8C7BE0), Color(0xFF5B43B0)),
        _ => const NeedPaint(Color(0xFF6B7A8F), Color(0xFF3E4A5C)),
      };
}

/// A need's two colours and the ink that reads on them.
class NeedPaint {
  const NeedPaint(this.light, this.dark, {this.ink = Colors.white});

  final Color light;
  final Color dark;
  final Color ink;
}

class _Pocket extends StatelessWidget {
  const _Pocket({required this.item});

  final NeedNavItem item;

  @override
  Widget build(BuildContext context) {
    final paint = NeedPockets.paintOf(item.key);
    final ink = paint.ink;
    final onLight = ink != Colors.white;

    return Semantics(
      button: true,
      label: item.name,
      child: PressScale(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(
          Uri(
            path: '/listing',
            queryParameters: {'category': item.slug, 'title': item.name},
          ).toString(),
        ),
        child: Container(
          height: NeedPockets.tileHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [paint.light, paint.dark],
            ),
            boxShadow: [
              BoxShadow(
                color: paint.dark.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: -14,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // The lit pocket, and the thing that lives in it.
              PositionedDirectional(
                end: -34,
                bottom: -46,
                child: Container(
                  width: 160,
                  height: 118,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: onLight ? 0.35 : 0.18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // The need's most wanted products, floating out of the pocket
              // — real things to reach for. A white plate with the best
              // seller's photo stands in until the cut-outs exist, the glyph
              // only for a store that sent no photo at all.
              if (item.cutouts.isNotEmpty)
                PositionedDirectional(end: 0, bottom: 0, child: _Floating(urls: item.cutouts))
              else if ((item.image ?? '').isNotEmpty)
                PositionedDirectional(
                  end: 10,
                  bottom: -6,
                  child: Transform.rotate(
                    angle: (context.isRtl ? 8 : -8) * math.pi / 180,
                    child: Container(
                      width: 78,
                      height: 78,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 10)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 2, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: ZbImage(url: item.image, backgroundColor: Colors.white, radius: BorderRadius.circular(9)),
                    ),
                  ),
                )
              else
                PositionedDirectional(
                  end: 12,
                  bottom: 8,
                  child: Icon(
                    NeedPockets.icon(item.key),
                    size: 54,
                    color: ink.withValues(alpha: onLight ? 0.8 : 0.95),
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 8)),
                    ],
                  ),
                ),
              // The lit top edge every tile has, so it reads as a thing and
              // not as a flat fill.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.35)),
              ),
              PositionedDirectional(
                start: 14,
                top: 12,
                end: item.cutouts.isNotEmpty ? 96 : 86,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    shadows: onLight
                        ? null
                        : [Shadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 12,
                bottom: 12,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    size: 18,
                    color: paint.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two or three cut-out products tumbling out of the pocket: the best
/// seller in front and largest, the others leaning behind it, each with the
/// soft shadow a real object throws on a shelf.
class _Floating extends StatelessWidget {
  const _Floating({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final rtl = context.isRtl;
    return SizedBox(
      width: 112,
      height: NeedPockets.tileHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (urls.length > 2)
            PositionedDirectional(end: 44, top: 4, child: _Cut(url: urls[2], width: 48, height: 48, degrees: rtl ? -12 : 12)),
          if (urls.length > 1)
            PositionedDirectional(end: 58, bottom: 10, child: _Cut(url: urls[1], width: 58, height: 64, degrees: rtl ? 10 : -10)),
          PositionedDirectional(end: 4, bottom: 0, child: _Cut(url: urls[0], width: 82, height: 90, degrees: rtl ? -5 : 5)),
        ],
      ),
    );
  }
}

/// One cut-out with a real shadow: the same picture, turned to a dark
/// silhouette and blurred, sits a few points below it.
class _Cut extends StatelessWidget {
  const _Cut({required this.url, required this.width, required this.height, required this.degrees});

  final String url;
  final double width;
  final double height;
  final double degrees;

  @override
  Widget build(BuildContext context) {
    final picture = ZbImage(url: url, backgroundColor: Colors.transparent);
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: const Offset(0, 8),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.38), BlendMode.srcIn),
                  child: picture,
                ),
              ),
            ),
            picture,
          ],
        ),
      ),
    );
  }
}

/// «على رفّ إكسبريس الآن» — a live dot and the reason these four are here.
class _ShelfPill extends StatelessWidget {
  const _ShelfPill();

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final live = context.zb.success;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 4, 10, 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: live,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: live.withValues(alpha: 0.25), spreadRadius: 2)],
            ),
          ),
          Gap.w6,
          Text(
            L.of(context).needsOnShelf,
            style: context.tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item});

  final NeedNavItem item;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final paint = NeedPockets.paintOf(item.key);
    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rPill),
      onTap: () => context.push(
        Uri(
          path: '/listing',
          queryParameters: {'category': item.slug, 'title': item.name},
        ).toString(),
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 14, 0),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(NeedPockets.icon(item.key), size: 16, color: paint.dark),
            Gap.w6,
            Text(
              item.name,
              style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
