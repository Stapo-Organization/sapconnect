import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../core/widgets/product_card_metrics.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../core/widgets/sparkles.dart';
import '../../../../../core/widgets/zb_image.dart';
import '../../../../../core/widgets/paw_wallpaper.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_models.dart';
import 'card_form.dart';

/// «الأكثر طلبًا على إكسبريس» as a stage.
///
/// A ranking read down is a chart; a ranking read across, with the winner
/// raised on the tallest block under the brightest light, is a ceremony. The
/// three stand on a night-teal stage — three spotlight cones from above, a
/// glossy floor, a few sparkles over the winner — each product floating free
/// of its white card, with a real shadow under it, on a gold, silver or
/// bronze block. One gold button under them adds all three.
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

  static const Color stageTop = Color(0xFF0F4457);
  static const Color stageMid = Color(0xFF07344A);
  static const Color stageDeep = Color(0xFF041B24);
  static const Color gold = Color(0xFFFBD268);
  static const Color goldDeep = Color(0xFFF4BE2C);
  static const Color goldInk = Color(0xFF3A2600);

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
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: ProductCardMetrics.maxTextScale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZbTokens.rXl),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Podium.stageTop, Podium.stageMid, Podium.stageDeep],
                  stops: [0, 0.45, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Podium.stageDeep.withValues(alpha: 0.5),
                    blurRadius: 32,
                    spreadRadius: -10,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned.fill(child: PawWallpaper(opacity: 0.06)),
                  const Positioned.fill(child: CustomPaint(painter: _StagePainter())),
                  const Positioned.fill(child: SparkleField(sparkles: _stageSparkles, twinkle: true)),
                  // The lit top edge every object on the page has.
                  Positioned(top: 0, left: 0, right: 0, height: 1, child: ColoredBox(color: Colors.white.withValues(alpha: 0.18))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 30, 12, 14),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(flex: 10, child: _Step(rank: 2, product: top[1], zone: widget.zone)),
                            Gap.w8,
                            Expanded(flex: 12, child: _Step(rank: 1, product: top[0], zone: widget.zone)),
                            Gap.w8,
                            Expanded(flex: 10, child: _Step(rank: 3, product: top[2], zone: widget.zone)),
                          ],
                        ),
                        // The floor: glossy, lit from above, dark at the edges.
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF123A47), Color(0xFF2C6273), Color(0xFF123A47)],
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(height: 1, color: Colors.white.withValues(alpha: 0.35)),
                          ),
                        ),
                        if (canAdd) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            button: true,
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(ZbTokens.rPill),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(ZbTokens.rPill),
                                onTap: _adding ? null : () => _addAll(top),
                                child: Ink(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(ZbTokens.rPill),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFFFFE9A8), Podium.goldDeep],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Podium.goldDeep.withValues(alpha: 0.55),
                                        blurRadius: 18,
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
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Podium.goldInk),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.add_rounded, size: 18, color: Podium.goldInk),
                                              Gap.w6,
                                              Text(
                                                '${l.podiumAddAll} · ${Fmt.number(total, locale: locale)} $riyalSymbol',
                                                style: context.tt.labelLarge?.copyWith(
                                                  color: Podium.goldInk,
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A few points of light over the winner — gold and white, drifting.
const List<SparkleSpec> _stageSparkles = [
  SparkleSpec(dx: 0.50, dy: 0.05, size: 10, color: Podium.gold),
  SparkleSpec(dx: 0.40, dy: 0.13, size: 6, color: Colors.white, delay: Duration(milliseconds: 300)),
  SparkleSpec(dx: 0.61, dy: 0.10, size: 7, color: Podium.gold, delay: Duration(milliseconds: 650), rotation: 0.5),
  SparkleSpec(dx: 0.16, dy: 0.24, size: 5, color: Colors.white, delay: Duration(milliseconds: 900)),
  SparkleSpec(dx: 0.86, dy: 0.20, size: 6, color: Colors.white, delay: Duration(milliseconds: 450)),
];

/// Three spotlight cones from above the stage, the middle one brightest.
class _StagePainter extends CustomPainter {
  const _StagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    for (final (x, alpha, r) in [(0.17, 0.09, 150.0), (0.50, 0.16, 190.0), (0.83, 0.09, 150.0)]) {
      final center = Offset(w * x, -40);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: alpha), Colors.white.withValues(alpha: 0)],
          stops: const [0, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }
    // A warm glow low on the floor, under the gold block.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [Podium.gold.withValues(alpha: 0.18), Podium.gold.withValues(alpha: 0)],
      ).createShader(Rect.fromCenter(center: Offset(w / 2, size.height - 70), width: 260, height: 120));
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_StagePainter old) => false;
}

/// One product on its block: the art floating under its light, the name,
/// the price on a white chip, the block it stands on.
class _Step extends ConsumerWidget {
  const _Step({required this.rank, required this.product, required this.zone});

  final int rank;
  final ProductCard product;
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = rank == 1;
    final metal = _Metal.of(rank);
    final tt = context.tt;

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
            _Art(product: product, metal: metal, height: first ? 116 : 90),
            const SizedBox(height: 8),
            SizedBox(
              height: context.nameLine * 2,
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: first ? null : 12.5,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 1))],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: InlinePrice(
                product: product,
                compare: false,
                color: ZbTokens.ink,
                style: first ? tt.titleSmall : tt.labelLarge,
              ),
            ),
            const SizedBox(height: 10),
            _Block(rank: rank, metal: metal),
          ],
        ),
      ),
    );
  }
}

/// The product under its light: floating and free when the store cut it
/// out, mounted on a white disc in a metal ring when it did not. The winner
/// wears the crown and stands in a gold halo.
class _Art extends StatelessWidget {
  const _Art({required this.product, required this.metal, required this.height});

  final ProductCard product;
  final _Metal metal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final first = metal.rank == 1;
    final cut = product.cutout;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: height,
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (first)
                Positioned(
                  bottom: -20,
                  child: Container(
                    width: w + 20,
                    height: w + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Podium.gold.withValues(alpha: 0.30), Podium.gold.withValues(alpha: 0)],
                        stops: const [0, 0.75],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: w * 0.7,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0)]),
                  ),
                ),
              ),
              if (cut != null && cut.isNotEmpty)
                Positioned(
                  bottom: 6,
                  child: FloatingProduct(url: cut, width: w - 6, height: height - 12, shadow: 0.45, drop: 6),
                )
              else
                Positioned(bottom: 4, child: _Ring(product: product, size: height - 12, metal: metal)),
              PositionedDirectional(top: 0, end: 2, child: _Medal(metal: metal, size: first ? 28 : 24)),
              if (first)
                Positioned(
                  top: -16,
                  left: 0,
                  right: 0,
                  child: Center(child: CustomPaint(size: const Size(28, 22), painter: _CrownPainter())),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The photo on a white disc inside a conic metal ring — the fallback for a
/// product the store has no cut-out of yet.
class _Ring extends StatelessWidget {
  const _Ring({required this.product, required this.size, required this.metal});

  final ProductCard product;
  final double size;
  final _Metal metal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(startAngle: 3.5, colors: metal.ring),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: Alignment(0, -0.4), colors: [Colors.white, Color(0xFFF1F4F1)]),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: ZbImage(url: product.image, backgroundColor: Colors.transparent),
        ),
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.metal, required this.size});

  final _Metal metal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [metal.medalLight, metal.medalDark],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(
        '${metal.rank}',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: size * 0.46,
          height: 1,
          color: metal.medalInk,
        ),
      ),
    );
  }
}

/// The block: a lit top face and a metal front carrying the rank.
class _Block extends StatelessWidget {
  const _Block({required this.rank, required this.metal});

  final int rank;
  final _Metal metal;

  @override
  Widget build(BuildContext context) {
    final front = switch (rank) { 1 => 46.0, 2 => 30.0, _ => 22.0 };
    return Column(
      children: [
        Container(
          height: 7,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            gradient: LinearGradient(colors: [metal.topLight, metal.topDark]),
          ),
        ),
        Container(
          height: front,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [metal.frontLight, metal.frontDark],
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 6))],
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: switch (rank) { 1 => 24.0, 2 => 16.0, _ => 13.0 },
              height: 1,
              color: metal.frontInk,
              shadows: [Shadow(color: Colors.white.withValues(alpha: 0.35), offset: const Offset(0, 1))],
            ),
          ),
        ),
      ],
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
    canvas.drawShadow(body, Colors.black, 4, true);
    canvas.drawPath(body, Paint()..color = Podium.gold);
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
    // Three jewels.
    for (final (x, c) in [(0.27, const Color(0xFFE5484D)), (0.5, const Color(0xFF23DEBB)), (0.73, const Color(0xFFE5484D))]) {
      canvas.drawCircle(Offset(w * x, h * 0.66), 1.6, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_CrownPainter old) => false;
}

/// Gold, silver, bronze — a ring, a medal, and a block with a lit top face.
class _Metal {
  const _Metal({
    required this.rank,
    required this.ring,
    required this.medalLight,
    required this.medalDark,
    required this.medalInk,
    required this.topLight,
    required this.topDark,
    required this.frontLight,
    required this.frontDark,
    required this.frontInk,
  });

  final int rank;
  final List<Color> ring;
  final Color medalLight;
  final Color medalDark;
  final Color medalInk;
  final Color topLight;
  final Color topDark;
  final Color frontLight;
  final Color frontDark;
  final Color frontInk;

  static _Metal of(int rank) => switch (rank) {
        1 => const _Metal(
            rank: 1,
            ring: [Color(0xFFFBD268), Color(0xFFE9B36A), Color(0xFFFFF2C2), Color(0xFFD9A441), Color(0xFFFBD268)],
            medalLight: Color(0xFFFBD268),
            medalDark: Color(0xFFD9A441),
            medalInk: Color(0xFF5A3A00),
            topLight: Color(0xFFFFF1C4),
            topDark: Color(0xFFFBD268),
            frontLight: Color(0xFFF4C752),
            frontDark: Color(0xFFC98A25),
            frontInk: Color(0xFF5A3A00),
          ),
        2 => const _Metal(
            rank: 2,
            ring: [Color(0xFFD9DEDC), Color(0xFFAEB6B3), Color(0xFFF3F5F4), Color(0xFFB9C0BD), Color(0xFFD9DEDC)],
            medalLight: Color(0xFFDDE2E0),
            medalDark: Color(0xFF8F9995),
            medalInk: Color(0xFF2C3E2D),
            topLight: Color(0xFFF3F5F4),
            topDark: Color(0xFFC9D0CD),
            frontLight: Color(0xFFB9C0BD),
            frontDark: Color(0xFF7C8783),
            frontInk: Color(0xFF1F2A28),
          ),
        _ => const _Metal(
            rank: 3,
            ring: [Color(0xFFE49859), Color(0xFFB8743B), Color(0xFFF4C9A0), Color(0xFFC58348), Color(0xFFE49859)],
            medalLight: Color(0xFFE9B08A),
            medalDark: Color(0xFFB8743B),
            medalInk: Colors.white,
            topLight: Color(0xFFF4C9A0),
            topDark: Color(0xFFD9A06A),
            frontLight: Color(0xFFC58348),
            frontDark: Color(0xFF8A5510),
            frontInk: Color(0xFF3A2200),
          ),
      };
}
