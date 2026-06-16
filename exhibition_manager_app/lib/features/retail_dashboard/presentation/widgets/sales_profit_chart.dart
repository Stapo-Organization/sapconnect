import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_card.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/retail_models.dart';

/// Interactive sales (bars) + profit (smooth line + area) chart. Drag across it
/// to scrub: the readout, a vertical guide, the highlighted bar and the profit
/// marker all follow your finger. Sales & profit share one axis so the gap reads
/// as margin. Hand-drawn — no chart dependency.
class SalesProfitChart extends StatefulWidget {
  final SalesProfitTrend trend;
  final Color salesColor;
  const SalesProfitChart({super.key, required this.trend, required this.salesColor});

  @override
  State<SalesProfitChart> createState() => _SalesProfitChartState();
}

class _SalesProfitChartState extends State<SalesProfitChart> with SingleTickerProviderStateMixin {
  static const _profitColor = AppColors.success;

  late final AnimationController _enter;
  int? _selected; // scrub index; null = show period summary

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))..forward();
  }

  @override
  void didUpdateWidget(covariant SalesProfitChart old) {
    super.didUpdateWidget(old);
    // Re-animate + clear scrub when the period (point count) changes.
    if (old.trend.points.length != widget.trend.points.length) {
      _selected = null;
      _enter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _scrub(double dx, double width, int n) {
    if (n == 0) return;
    final idx = (dx / width * n).floor().clamp(0, n - 1);
    if (idx != _selected) {
      HapticFeedback.selectionClick();
      setState(() => _selected = idx);
    }
  }

  String _fmtLabel(String label) =>
      (label.length == 10 && label[4] == '-') ? label.substring(5) : label;

  @override
  Widget build(BuildContext context) {
    final pts = widget.trend.points;
    final maxVal = pts.fold<double>(0, (a, p) => p.sales > a ? p.sales : a);
    final hasData = pts.isNotEmpty && maxVal > 0;

    // Readout target: the scrubbed bucket, else the latest one.
    final idx = hasData ? (_selected ?? pts.length - 1) : 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.tr('rd_sales_profit_chart'), style: AppTypography.titleSmall)),
              _legendDot(widget.salesColor, context.tr('rd_sort_revenue')),
              const SizedBox(width: AppSpacing.md),
              _legendDot(_profitColor, context.tr('rd_sort_profit')),
            ],
          ),
          if (hasData) ...[
            const SizedBox(height: AppSpacing.sm),
            _readout(context, pts[idx]),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (!hasData)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(context.tr('rd_no_data'),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              ),
            )
          else ...[
            Directionality(
              textDirection: TextDirection.ltr, // time always reads left → right
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final n = pts.length;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _scrub(d.localPosition.dx, w, n),
                    onHorizontalDragStart: (d) => _scrub(d.localPosition.dx, w, n),
                    onHorizontalDragUpdate: (d) => _scrub(d.localPosition.dx, w, n),
                    onHorizontalDragEnd: (_) => setState(() => _selected = null),
                    onTapUp: (_) => setState(() => _selected = null),
                    child: SizedBox(
                      height: 138,
                      child: AnimatedBuilder(
                        animation: _enter,
                        builder: (_, _) => CustomPaint(
                          size: Size.infinite,
                          painter: _ChartPainter(
                            pts: pts,
                            maxVal: maxVal,
                            salesColor: widget.salesColor,
                            profitColor: _profitColor,
                            progress: Curves.easeOutCubic.transform(_enter.value),
                            selected: _selected,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _axisLabels(pts),
          ],
        ],
      ),
    );
  }

  Widget _readout(BuildContext context, TrendBucket b) {
    final margin = b.sales > 0 ? (b.profit / b.sales * 100) : 0.0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.borderFull),
          child: Text(_fmtLabel(b.label),
              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        _readoutMetric(context.tr('rd_sort_revenue'), sarCompact(b.sales), widget.salesColor),
        const SizedBox(width: AppSpacing.base),
        _readoutMetric('${context.tr('rd_sort_profit')} · ${margin.toStringAsFixed(0)}٪', sarCompact(b.profit), _profitColor),
      ],
    );
  }

  Widget _readoutMetric(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
          Text(value, style: AppTypography.titleSmall.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
        ],
      );

  Widget _axisLabels(List<TrendBucket> pts) {
    final first = _fmtLabel(pts.first.label);
    final mid = _fmtLabel(pts[pts.length ~/ 2].label);
    final last = _fmtLabel(pts.last.label);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [first, mid, last]
            .map((s) => Text(s, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)))
            .toList(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<TrendBucket> pts;
  final double maxVal;
  final Color salesColor;
  final Color profitColor;
  final double progress;
  final int? selected;

  _ChartPainter({
    required this.pts,
    required this.maxVal,
    required this.salesColor,
    required this.profitColor,
    required this.progress,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = pts.length;
    if (n == 0 || maxVal <= 0) return;

    final h = size.height;
    final slot = size.width / n;
    final bw = (slot - 4).clamp(2.0, 22.0);

    // Baseline.
    final base = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h - 0.5), Offset(size.width, h - 0.5), base);

    // Sales bars.
    for (var i = 0; i < n; i++) {
      final bh = (pts[i].sales / maxVal) * h * progress;
      if (bh <= 0) continue;
      final left = i * slot + (slot - bw) / 2;
      final rect = Rect.fromLTWH(left, h - bh, bw, bh);
      final isSel = selected == i;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSel
              ? [salesColor, salesColor.withValues(alpha: 0.55)]
              : [salesColor.withValues(alpha: 0.55), salesColor.withValues(alpha: 0.16)],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
        paint,
      );
    }

    // Profit smooth curve points.
    final pp = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = i * slot + slot / 2;
      final y = h - (pts[i].profit / maxVal) * h * progress;
      pp.add(Offset(x, y));
    }
    final linePath = _smoothPath(pp);

    // Area fill under profit line.
    final areaPath = Path.from(linePath)
      ..lineTo(pp.last.dx, h)
      ..lineTo(pp.first.dx, h)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [profitColor.withValues(alpha: 0.22), profitColor.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );

    // Profit line.
    canvas.drawPath(
      linePath,
      Paint()
        ..color = profitColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Static profit dots when sparse.
    if (n <= 16 && selected == null) {
      for (final p in pp) {
        canvas.drawCircle(p, 2.4, Paint()..color = profitColor);
        canvas.drawCircle(p, 1.1, Paint()..color = Colors.white);
      }
    }

    // Scrub guide + markers.
    if (selected != null && selected! >= 0 && selected! < n) {
      final x = selected! * slot + slot / 2;
      final guide = Paint()
        ..color = AppColors.textTertiary.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      _dashedLine(canvas, Offset(x, 4), Offset(x, h), guide);
      // Profit marker.
      final mp = pp[selected!];
      canvas.drawCircle(mp, 6, Paint()..color = profitColor.withValues(alpha: 0.18));
      canvas.drawCircle(mp, 4, Paint()..color = profitColor);
      canvas.drawCircle(mp, 1.8, Paint()..color = Colors.white);
    }
  }

  Path _smoothPath(List<Offset> p) {
    final path = Path();
    if (p.isEmpty) return path;
    path.moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = i == 0 ? p[i] : p[i - 1];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = i + 2 < p.length ? p[i + 2] : p2;
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 3.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final s = a + dir * d;
      final e = a + dir * (d + dash).clamp(0, total);
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.progress != progress || old.selected != selected || old.pts != pts || old.maxVal != maxVal;
}
