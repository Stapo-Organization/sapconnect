import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/gradient_header.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/theme_toggle_button.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/pressable.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/retail_dashboard/data/models/retail_models.dart';
import 'package:exhibition_manager_app/features/retail_dashboard/presentation/channel_tokens.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../owner_theme.dart';
import '../../data/models/owner_command_models.dart';

/// هيرو «مركز القيادة» — **المخطّط المُدمَج**: تحية بالاسم + شارة المالك + مبدّل
/// الوضع، ثم **إجمالي مبيعات اليوم** (معارض + جملة) برقم تصاعدي وشارة دلتا،
/// يطفو فوق مخطّط مبيعات مصغّر، ثم **شريط تقسيم القنوات** (أبيض = معارض،
/// ذهبي = جملة) وخليتا قناة قابلتان للضغط تفتحان صفحة الأداء على تلك القناة،
/// وتحتها الخلايا الحيوية (الربح/الهامش/الفواتير).
class OwnerHero extends StatelessWidget {
  final String userName;
  final OwnerCommandSnapshot? snapshot;
  final bool loading;

  /// يُستدعى عند ضغط خلية قناة — يفتح تبويب الأداء على تلك القناة.
  final void Function(String channel)? onOpenPerformance;

  const OwnerHero({
    super.key,
    required this.userName,
    required this.snapshot,
    this.loading = false,
    this.onOpenPerformance,
  });

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 12) return 'owner_greeting_morning';
    if (h >= 12 && h < 17) return 'owner_greeting_noon';
    return 'owner_greeting_evening';
  }

  @override
  Widget build(BuildContext context) {
    final comma = AppLocalizations.isArabic ? '،' : ',';
    final greeting = '${context.tr(_greetingKey())}$comma $userName';
    return GradientHeader(
      gradient: OwnerTheme.heroGradient,
      title: greeting,
      subtitle: context.tr('owner_command_subtitle'),
      actions: [
        const ThemeToggleButton(size: 40),
        const SizedBox(width: AppSpacing.sm),
        _ownerBadge(context),
      ],
      child: _netBlock(context),
    );
  }

  Widget _ownerBadge(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              context.tr('owner_role_badge'),
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _netBlock(BuildContext context) {
    final s = snapshot;
    final net = s?.netSalesToday ?? 0;
    final retailOk = s?.retailOk ?? false;
    final points = <double>[
      if (retailOk) for (final p in s!.trend.points) p.sales,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.tr((s?.hasChannels ?? false) ? 'owner_total_sales_today' : 'owner_net_sales_today'),
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const Spacer(),
            if (retailOk && s?.netSalesDelta != null) _deltaPill(s!),
          ],
        ),
        const SizedBox(height: 2),
        if (loading && s == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Container(
              width: 180,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: AppRadius.borderSm,
              ),
            ),
          )
        else if (!retailOk)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              context.tr('owner_net_unavailable'),
              style: AppTypography.titleMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          )
        else ...[
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: net),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              sarAmount(v),
              style: AppTypography.displayMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          // مخطّط مبيعات مصغّر مُدمَج تحت الرقم مباشرةً.
          if (points.length >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: CustomPaint(painter: _SparklinePainter(points, Colors.white)),
            ),
          ],
          // تقسيم القنوات: شريط نِسَب + خليتا معارض/جملة قابلتان للضغط.
          if (s!.hasChannels) ...[
            const SizedBox(height: AppSpacing.md),
            _channelSplitStrip(s.channelsToday!),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _channelCell(
                    context,
                    channel: SalesChannel.retail,
                    swatch: Colors.white.withValues(alpha: 0.92),
                    iconColor: const Color(0xFF243041),
                    net: s.channelsToday!.retail.net,
                    share: s.channelsToday!.retailShare,
                    deltaPct: s.retailDeltaPct,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _channelCell(
                    context,
                    channel: SalesChannel.wholesale,
                    swatch: AppColors.accent,
                    iconColor: Colors.white,
                    net: s.channelsToday!.wholesale.net,
                    share: s.channelsToday!.wholesaleShare,
                    deltaPct: s.wholesaleDeltaPct,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          _vitals(context, s),
        ],
      ],
    );
  }

  /// شريط نِسَب القنوات: أبيض = معارض، ذهبي = جملة — يتمدّد بحركة ناعمة.
  Widget _channelSplitStrip(ChannelSplit ch) {
    final retail = ch.retailShare;
    final wholesale = ch.wholesaleShare;
    if (retail <= 0 && wholesale <= 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: AppRadius.borderFull,
      child: SizedBox(
        height: 8,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Row(
            children: [
              Expanded(
                flex: ((retail * v) * 1000).round().clamp(1, 1000),
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.92)),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: ((wholesale * v) * 1000).round().clamp(1, 1000),
                child: ColoredBox(color: AppColors.accent),
              ),
              if (v < 1)
                Expanded(
                  flex: (((1 - (retail + wholesale) * v)) * 1000).round().clamp(0, 1000),
                  child: ColoredBox(color: Colors.white.withValues(alpha: 0.10)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// خلية قناة: أيقونة القناة في مربّع بلونها + الاسم + حصّتها + الصافي بعدّاد
  /// تصاعدي + دلتا مصغّرة. الضغط يفتح الأداء على تلك القناة.
  Widget _channelCell(
    BuildContext context, {
    required String channel,
    required Color swatch,
    required Color iconColor,
    required double net,
    required double share,
    double? deltaPct,
  }) {
    final up = (deltaPct ?? 0) >= 0;
    final cell = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(5)),
                child: Icon(SalesChannel.icon(channel), size: 11, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr(SalesChannel.labelKey(channel)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (share > 0)
                Text(
                  pctLabel(share * 100),
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              Icon(
                AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Flexible(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: net),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    sarCompact(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (deltaPct != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${up ? '▲' : '▼'} ${pctLabel(deltaPct.abs())}',
                  style: AppTypography.labelSmall.copyWith(
                    color: up ? OwnerTheme.positive : OwnerTheme.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (onOpenPerformance == null) return cell;
    return Pressable(onTap: () => onOpenPerformance!(channel), child: cell);
  }

  // ─── خلايا حيوية (بدل الشرائح المسطّحة) ───
  Widget _vitals(BuildContext context, OwnerCommandSnapshot s) {
    return Row(
      children: [
        Expanded(
          child: _vitalCell(
            context,
            label: context.tr('owner_kpi_profit'),
            value: sarCompact(s.totalProfit),
            positive: s.totalProfit > 0,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _vitalCell(
            context,
            label: context.tr('owner_kpi_margin'),
            value: s.marginPct != null ? pctLabel(s.marginPct!) : '—',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _vitalCell(
            context,
            label: context.tr('rd_total_invoices'),
            value: intGrouped(s.totalInvoices),
          ),
        ),
      ],
    );
  }

  Widget _vitalCell(
    BuildContext context, {
    required String label,
    required String value,
    bool positive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              if (positive)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 3),
                  child: Icon(Icons.arrow_drop_up_rounded, size: 16, color: Colors.white),
                ),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deltaPill(OwnerCommandSnapshot s) {
    final delta = s.netSalesDelta ?? 0;
    final up = delta >= 0;
    final pct = s.netSalesDeltaPct;
    final label = pct != null
        ? '${up ? '▲' : '▼'} ${pctLabel(pct.abs())}'
        : '${up ? '+' : '−'} ${sarCompact(delta.abs())}';
    final color = up ? OwnerTheme.positive : OwnerTheme.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// مخطّط مساحي صغير أملس (بيزييه رباعي عبر نقاط المنتصف) + تعبئة متدرّجة + نقطة
/// نهاية بارزة. أبيض شفّاف ليعمل فوق تدرّج الهيرو في الوضعين الفاتح والداكن.
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    const pad = 2.0;
    final w = size.width, h = size.height;

    Offset at(int i) {
      final x = pad + i * ((w - 2 * pad) / (values.length - 1));
      final norm = (values[i] - minV) / range;
      final y = h - pad - norm * (h - 2 * pad);
      return Offset(x, y);
    }

    final pts = [for (var i = 0; i < values.length; i++) at(i)];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1], cur = pts[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      line.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    line.lineTo(pts.last.dx, pts.last.dy);

    final area = Path.from(line)
      ..lineTo(pts.last.dx, h)
      ..lineTo(pts.first.dx, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(pts.last, 5.5, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(pts.last, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
