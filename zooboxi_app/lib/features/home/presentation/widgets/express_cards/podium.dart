import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../core/widgets/zb_image.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// «الأكثر طلبًا على إكسبريس» as a podium.
///
/// A ranking read down is a chart; a ranking read across, with the winner
/// raised on the tallest block and wearing the gold ring, is a ceremony. The
/// branch's top three stand on gold, silver and bronze, and the one button
/// under them adds all three — the basket a new customer of this branch is
/// most likely to want, in one tap.
class Podium extends ConsumerStatefulWidget {
  const Podium({
    super.key,
    required this.title,
    required this.products,
    this.onAdd,
    this.onSeeAll,
    this.zone,
  });

  final String title;

  /// At least three; the first three are the podium.
  final List<ProductCard> products;
  final Future<bool> Function(ProductCard product)? onAdd;
  final VoidCallback? onSeeAll;
  final String? zone;

  /// Whether there are enough products for a podium at all.
  static bool fits(List<ProductCard> products) => products.length >= 3;

  @override
  ConsumerState<Podium> createState() => _PodiumState();
}

class _PodiumState extends ConsumerState<Podium> {
  bool _adding = false;

  Future<void> _addAll(List<ProductCard> top) async {
    final add = widget.onAdd;
    if (add == null || _adding) return;
    Haptics.light();
    setState(() => _adding = true);
    try {
      for (final product in top) {
        if (!product.inStock) continue;
        final ok = await add(product);
        if (!ok) break;
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Podium.fits(widget.products)) return const SizedBox.shrink();
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final top = widget.products.take(3).toList();
    final total = top.where((p) => p.inStock).fold<double>(0, (sum, p) => sum + p.price);
    final canAdd = widget.onAdd != null && top.any((p) => p.inStock);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: widget.title,
          leading: SectionMark(pair: context.zb.badgeTrending, icon: Icons.emoji_events_rounded),
          onSeeAll: widget.onSeeAll,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.08),
                  blurRadius: 28,
                  spreadRadius: -12,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 10, child: _Step(rank: 2, product: top[1], onAdd: widget.onAdd, zone: widget.zone)),
                    Gap.w8,
                    Expanded(flex: 12, child: _Step(rank: 1, product: top[0], onAdd: widget.onAdd, zone: widget.zone)),
                    Gap.w8,
                    Expanded(flex: 10, child: _Step(rank: 3, product: top[2], onAdd: widget.onAdd, zone: widget.zone)),
                  ],
                ),
                // The floor the three blocks stand on.
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: context.isDark
                          ? [cs.surfaceContainerHighest, cs.surfaceContainerHigh]
                          : const [Color(0xFFD9DEDC), Color(0xFFC6CDCA)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, spreadRadius: -6, offset: const Offset(0, 6)),
                    ],
                  ),
                ),
                if (canAdd) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(ZbTokens.rPill),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        onTap: _adding ? null : () => _addAll(top),
                        child: Ink(
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(ZbTokens.rPill),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [ZbTokens.tealDark, ZbTokens.tealDeep],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ZbTokens.tealDeep.withValues(alpha: 0.55),
                                blurRadius: 16,
                                spreadRadius: -6,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _adding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                      Gap.w6,
                                      Text(
                                        '${l.podiumAddAll} · ${Fmt.number(total, locale: locale)} $riyalSymbol',
                                        style: context.tt.labelLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One product on its block: the ring, the medal, the name, the price, the
/// step it stands on.
class _Step extends ConsumerWidget {
  const _Step({required this.rank, required this.product, required this.onAdd, required this.zone});

  final int rank;
  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = rank == 1;
    final metal = _Metal.of(rank);
    final ring = first ? 96.0 : 74.0;

    return Semantics(
      button: true,
      label: product.name,
      child: PressScale(
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        haptic: Haptics.light,
        onTap: () => openProduct(context, ref, product, zone: zone),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Ring(product: product, size: ring, metal: metal, crown: first),
            const SizedBox(height: 8),
            SizedBox(
              height: context.nameLine * 2,
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: first ? null : 12.5),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: first ? context.priceLargeLine : context.priceLine,
              child: Center(
                child: InlinePrice(
                  product: product,
                  compare: false,
                  style: first ? context.tt.titleLarge : context.tt.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: switch (rank) { 1 => 52.0, 2 => 34.0, _ => 26.0 },
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [metal.stepLight, metal.stepDark],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.9), offset: const Offset(0, 1), blurRadius: 0, spreadRadius: -1),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: switch (rank) { 1 => 22.0, 2 => 16.0, _ => 14.0 },
                  height: 1,
                  color: metal.stepInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo on a white disc inside a conic metal ring, the medal on its
/// shoulder, the crown over the winner.
class _Ring extends StatelessWidget {
  const _Ring({required this.product, required this.size, required this.metal, required this.crown});

  final ProductCard product;
  final double size;
  final _Metal metal;
  final bool crown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  startAngle: 3.5,
                  colors: metal.ring,
                ),
                boxShadow: crown
                    ? [BoxShadow(color: metal.ring[1].withValues(alpha: 0.8), blurRadius: 24, spreadRadius: -10, offset: const Offset(0, 12))]
                    : null,
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(0, -0.4),
                    colors: [Colors.white, Color(0xFFF1F4F1)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x14000000), blurRadius: 12, spreadRadius: -6, offset: Offset(0, -6)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.all(size * 0.08),
                  child: ZbImage(url: product.image, backgroundColor: Colors.transparent),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: -6,
            end: -4,
            child: Container(
              width: crown ? 28 : 24,
              height: crown ? 28 : 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [metal.medalLight, metal.medalDark],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Text(
                '${metal.rank}',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: crown ? 13 : 12,
                  height: 1,
                  color: metal.medalInk,
                ),
              ),
            ),
          ),
          if (crown)
            Positioned(
              top: -19,
              left: 0,
              right: 0,
              child: Center(
                child: CustomPaint(size: const Size(26, 20), painter: _CrownPainter()),
              ),
            ),
        ],
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.08, h * 0.85)
      ..lineTo(w * 0.15, h * 0.3)
      ..lineTo(w * 0.38, h * 0.55)
      ..lineTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.62, h * 0.55)
      ..lineTo(w * 0.85, h * 0.3)
      ..lineTo(w * 0.92, h * 0.85)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFFBD268));
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFFD9A441)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.8, w * 0.84, h * 0.15), const Radius.circular(1)),
      Paint()..color = const Color(0xFFD9A441),
    );
  }

  @override
  bool shouldRepaint(_CrownPainter old) => false;
}

/// Gold, silver, bronze — a ring, a medal and a step each.
class _Metal {
  const _Metal({
    required this.rank,
    required this.ring,
    required this.medalLight,
    required this.medalDark,
    required this.medalInk,
    required this.stepLight,
    required this.stepDark,
    required this.stepInk,
  });

  final int rank;
  final List<Color> ring;
  final Color medalLight;
  final Color medalDark;
  final Color medalInk;
  final Color stepLight;
  final Color stepDark;
  final Color stepInk;

  static _Metal of(int rank) => switch (rank) {
        1 => const _Metal(
            rank: 1,
            ring: [Color(0xFFFBD268), Color(0xFFE9B36A), Color(0xFFFFF2C2), Color(0xFFD9A441), Color(0xFFFBD268)],
            medalLight: Color(0xFFFBD268),
            medalDark: Color(0xFFD9A441),
            medalInk: Color(0xFF5A3A00),
            stepLight: Color(0xFFFFE9A8),
            stepDark: Color(0xFFF4C752),
            stepInk: Color(0xFF8A5510),
          ),
        2 => const _Metal(
            rank: 2,
            ring: [Color(0xFFD9DEDC), Color(0xFFAEB6B3), Color(0xFFF3F5F4), Color(0xFFB9C0BD), Color(0xFFD9DEDC)],
            medalLight: Color(0xFFC9D0CD),
            medalDark: Color(0xFF8F9995),
            medalInk: Colors.white,
            stepLight: Color(0xFFEDF0EF),
            stepDark: Color(0xFFDDE2E0),
            stepInk: Color(0xFF7C8783),
          ),
        _ => const _Metal(
            rank: 3,
            ring: [Color(0xFFE49859), Color(0xFFB8743B), Color(0xFFF4C9A0), Color(0xFFC58348), Color(0xFFE49859)],
            medalLight: Color(0xFFE49859),
            medalDark: Color(0xFFB8743B),
            medalInk: Colors.white,
            stepLight: Color(0xFFF7DDC7),
            stepDark: Color(0xFFE9BE9C),
            stepInk: Color(0xFF8A5510),
          ),
      };
}
