import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/delivery/delivery_eta.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/haptics.dart';
import '../../../../../core/widgets/zb_image.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/catalog_models.dart';
import '../../../../catalog/data/product_models.dart';
import '../promise_header.dart';
import 'price_cut_rail.dart';

/// Clearance as a torn-off ticket.
///
/// The band above the price tags used to be a wash of the sale colour. Now it
/// is an object: a ticket in wine and rose, perforated from its stub, with the
/// biggest real discount on a starburst sticker and — on the stub — the one
/// deadline the branch actually keeps, the hour it closes. Two of the cleared
/// products spill out of the corner; the whole rail of tags follows beneath.
class ClearanceTicket extends StatefulWidget {
  const ClearanceTicket({
    super.key,
    required this.title,
    required this.products,
    this.onAdd,
    this.onSeeAll,
    this.hours,
    this.spill = const [],
    this.now,
  });

  final String title;
  final List<ProductCard> products;
  final Future<bool> Function(ProductCard product)? onAdd;
  final VoidCallback? onSeeAll;

  /// The express branch's hours — the stub counts down to closing.
  final ExpressHours? hours;

  /// Cut-out product art, when the server composed a clearance slide; the
  /// products' own photos otherwise.
  final List<String> spill;

  /// Fixed by the sheet tests; the wall clock everywhere else.
  final DateTime? now;

  static const double height = 168;
  static const double stubWidth = 88;

  static const Color wine = Color(0xFF2A0716);
  static const Color berry = Color(0xFF9E0F35);
  static const Color rose = Color(0xFFE8305A);
  static const Color pink = Color(0xFFFF5E7A);

  @override
  State<ClearanceTicket> createState() => _ClearanceTicketState();
}

class _ClearanceTicketState extends State<ClearanceTicket> {
  Timer? _tick;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    if (widget.now == null) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();
    final pct = widget.products.fold<int>(0, (best, p) => math.max(best, p.discountPercent));
    final page = Theme.of(context).scaffoldBackgroundColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: ClearanceTicket.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: ClearanceTicket.berry.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: -8,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Main(
                            title: widget.title,
                            products: widget.products,
                            spill: widget.spill,
                            onTap: widget.onSeeAll,
                          ),
                        ),
                        SizedBox(
                          width: 2,
                          height: ClearanceTicket.height,
                          child: CustomPaint(
                            painter: DashPainter(color: Colors.white.withValues(alpha: 0.55), dash: 6, gap: 5),
                          ),
                        ),
                        _Stub(now: _now, hours: widget.hours),
                      ],
                    ),
                  ),
                ),
                // The two notches the stub tears along.
                PositionedDirectional(end: ClearanceTicket.stubWidth - 8, top: -9, child: _Notch(color: page)),
                PositionedDirectional(end: ClearanceTicket.stubWidth - 8, bottom: -9, child: _Notch(color: page)),
                if (pct > 0)
                  PositionedDirectional(
                    end: ClearanceTicket.stubWidth + 14,
                    top: -14,
                    child: _Burst(percent: pct),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        PriceCutRail(products: widget.products, zone: 'clearance', onAdd: widget.onAdd),
      ],
    );
  }
}

class _Main extends StatelessWidget {
  const _Main({required this.title, required this.products, required this.spill, required this.onTap});

  final String title;
  final List<ProductCard> products;
  final List<String> spill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = context.tt;

    return ClipRRect(
      borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(22)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  Haptics.light();
                  onTap!();
                },
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [ClearanceTicket.wine, ClearanceTicket.berry, ClearanceTicket.rose],
                stops: [0, 0.45, 1],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const AlignmentDirectional(-0.7, 0.6),
                        radius: 0.75,
                        colors: [ClearanceTicket.pink.withValues(alpha: 0.7), ClearanceTicket.pink.withValues(alpha: 0)],
                        stops: const [0, 0.7],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 16,
                  top: 14,
                  end: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 9, 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 12, color: ClearanceTicket.berry),
                            Gap.w4,
                            Text(
                              l.ticketKicker,
                              style: tt.labelSmall?.copyWith(color: ClearanceTicket.berry, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.ticketSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(ZbTokens.rPill),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.ticketCta,
                              style: tt.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                            Gap.w4,
                            Icon(
                              context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(end: 4, bottom: -8, child: _Spill(products: products, art: spill)),
                for (final s in const [(0.86, 0.16, 12.0), (0.62, 0.30, 7.0), (0.74, 0.08, 5.0)])
                  PositionedDirectional(
                    end: 120 * (1 - s.$1) + 20,
                    top: ClearanceTicket.height * s.$2,
                    child: CustomPaint(size: Size(s.$3, s.$3), painter: _SparkPainter()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two products tumbling out of the end corner — the server's cut-outs when
/// it has them, the photos on small white plates when it has not.
class _Spill extends StatelessWidget {
  const _Spill({required this.products, required this.art});

  final List<ProductCard> products;
  final List<String> art;

  @override
  Widget build(BuildContext context) {
    final cut = art.take(2).toList();
    final rtl = context.isRtl;
    final tilt = rtl ? -1.0 : 1.0;

    Widget photo(String url, double size, double degrees, {bool plate = false}) {
      final image = plate
          ? Container(
              width: size,
              height: size,
              padding: EdgeInsets.all(size * 0.08),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 10))],
              ),
              child: ZbImage(url: url, backgroundColor: Colors.white),
            )
          : SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: size * 0.1,
                    right: size * 0.1,
                    bottom: -2,
                    height: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: RadialGradient(colors: [Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0)]),
                      ),
                    ),
                  ),
                  Positioned.fill(child: ZbImage(url: url, backgroundColor: Colors.transparent)),
                ],
              ),
            );
      return Transform.rotate(angle: tilt * degrees * math.pi / 180, child: image);
    }

    final items = <Widget>[];
    if (cut.isNotEmpty) {
      items.add(photo(cut[0], 108, -10));
      if (cut.length > 1) items.add(Positioned(left: rtl ? null : 70, right: rtl ? 70 : null, bottom: -6, child: photo(cut[1], 72, 16)));
    } else {
      final photos = products.where((p) => (p.image ?? '').isNotEmpty).take(2).toList();
      if (photos.isEmpty) return const SizedBox.shrink();
      items.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: photo(photos[0].image!, 78, -8, plate: true)));
      if (photos.length > 1) {
        items.add(Positioned(left: rtl ? null : 56, right: rtl ? 56 : null, bottom: 0, child: photo(photos[1].image!, 56, 12, plate: true)));
      }
    }

    return SizedBox(
      width: 150,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomEnd,
        children: items,
      ),
    );
  }
}

/// The stub: the hour the branch closes, on small flip tiles.
class _Stub extends StatelessWidget {
  const _Stub({required this.now, required this.hours});

  final DateTime now;
  final ExpressHours? hours;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = context.tt;
    final locale = Localizations.localeOf(context).languageCode;
    final open = isExpressOpen(now, hours);
    final left = hours == null || !open ? null : timeUntilExpressClose(now, hours);

    final muted = tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w800);

    return ClipRRect(
      borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(22)),
      child: Container(
        width: ClearanceTicket.stubWidth,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A0A1C), Color(0xFF22040F)],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (left != null) ...[
              Text(l.ticketClosesIn, textAlign: TextAlign.center, maxLines: 2, style: muted),
              const SizedBox(height: 6),
              _Stacked(hours: left.inHours.clamp(0, 99), minutes: left.inMinutes.remainder(60)),
              const SizedBox(height: 6),
              Text(l.ticketUnits, style: muted?.copyWith(color: Colors.white.withValues(alpha: 0.55))),
            ] else if (hours != null) ...[
              Text(l.promiseOpensLabel, style: muted),
              const SizedBox(height: 4),
              Text(
                Fmt.clockShort(timeOfDayToday(hours!.openMinutes, now: now), locale),
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ] else
              Icon(Icons.sell_rounded, color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

/// Hours over minutes, two tiles each — the stub is too narrow for a line.
class _Stacked extends StatelessWidget {
  const _Stacked({required this.hours, required this.minutes});

  final int hours;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    Widget pair(int value) {
      final s = value.toString().padLeft(2, '0');
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_SmallTile(s[0]), const SizedBox(width: 3), _SmallTile(s[1])],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [pair(hours), const SizedBox(height: 4), pair(minutes)],
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile(this.digit);

  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 23,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2F2E), Color(0xFF151918)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              digit,
              style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 13, height: 1, color: Colors.white),
            ),
          ),
          Positioned(top: 11.5, left: 0, right: 0, height: 1, child: ColoredBox(color: Colors.black.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// «حتى 45%» on a starburst — white rim, amber face, tilted like a sticker.
class _Burst extends StatelessWidget {
  const _Burst({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Transform.rotate(
      angle: (context.isRtl ? -8 : 8) * math.pi / 180,
      child: SizedBox(
        width: 66,
        height: 66,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _BurstPainter(rim: true)),
            const Padding(padding: EdgeInsets.all(3), child: CustomPaint(painter: _BurstPainter(rim: false))),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l.ticketUpTo,
                  style: context.tt.labelSmall?.copyWith(color: const Color(0xFF5A3A00), fontWeight: FontWeight.w900, fontSize: 9, height: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  '$percent%',
                  style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, height: 1, color: Color(0xFF5A3A00)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.rim});

  final bool rim;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path();
    const points = 24;
    for (var i = 0; i < points * 2; i++) {
      final a = i * math.pi / points - math.pi / 2;
      final rr = i.isEven ? r : r * 0.82;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    final paint = Paint();
    if (rim) {
      paint.color = Colors.white;
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE070), Color(0xFFF4BE2C)],
      ).createShader(Offset.zero & size);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.rim != rim;
}

/// A four-point sparkle.
class _SparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w * 0.6, h * 0.4)
      ..lineTo(w, h / 2)
      ..lineTo(w * 0.6, h * 0.6)
      ..lineTo(w / 2, h)
      ..lineTo(w * 0.4, h * 0.6)
      ..lineTo(0, h / 2)
      ..lineTo(w * 0.4, h * 0.4)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFD1DA));
  }

  @override
  bool shouldRepaint(_SparkPainter old) => false;
}
