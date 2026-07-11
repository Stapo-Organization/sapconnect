import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../channel_tokens.dart';

/// مبدّل القنوات — مصنوع خصيصاً بدل [AppSegmentedControl]:
/// إبهام منزلق تتلوّن حدوده وظلّه بهوية القناة، أيقونات تنبض عند الاختيار،
/// وأيقونة «الإجمالي» ليست رمزاً جامداً بل **دونات حيّة** ترسم حصّتَي
/// المعارض/الجملة الفعليتين (نيلي/ذهبي) — البيانات نفسها هي الأيقونة.
class ChannelSwitcher extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  /// الحصص الفعلية (معارض، جملة) لرسم دونات «الإجمالي» — null = دونات رمزية.
  final (double, double)? shares;

  const ChannelSwitcher({
    super.key,
    required this.selected,
    required this.onChanged,
    this.shares,
  });

  @override
  Widget build(BuildContext context) {
    final channels = SalesChannel.order;
    final index = math.max(0, channels.indexOf(selected));
    final active = SalesChannel.color(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth / channels.length;
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        return Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  channels.length == 1
                      ? 0
                      : (isRtl ? -1 : 1) * (index / (channels.length - 1) * 2 - 1),
                  0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: w - 8,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(color: active.withValues(alpha: 0.28), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: active.withValues(alpha: 0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final ch in channels)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (ch == selected) return;
                          HapticFeedback.selectionClick();
                          onChanged(ch);
                        },
                        child: _segment(context, ch, ch == selected),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _segment(BuildContext context, String channel, bool isSelected) {
    final color = isSelected ? SalesChannel.color(channel) : AppColors.textTertiary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: isSelected ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: channel == SalesChannel.total
              ? SplitDonut(
                  size: 16,
                  shares: shares,
                  dimmed: !isSelected,
                )
              : Icon(SalesChannel.icon(channel), size: 16, color: color),
        ),
        const SizedBox(width: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? SalesChannel.color(channel) : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
          child: Text(context.tr(SalesChannel.labelKey(channel))),
        ),
      ],
    );
  }
}

/// دونات مصغّرة حيّة: قوس نيلي (المعارض) + قوس ذهبي (الجملة) بحصصهما الفعليتين
/// فوق مسار خافت — تُستخدم كأيقونة «الإجمالي» وفي شريحة الهيرو.
class SplitDonut extends StatelessWidget {
  final double size;
  final (double, double)? shares;
  final bool dimmed;
  final double strokeWidth;

  /// تجاوزات لونية للأسطح غير القياسية (مثل الهيرو النيلي: أبيض/ذهبي).
  final Color? retailColor;
  final Color? wholesaleColor;
  final Color? trackColor;

  const SplitDonut({
    super.key,
    this.size = 16,
    this.shares,
    this.dimmed = false,
    this.strokeWidth = 3,
    this.retailColor,
    this.wholesaleColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final (r, w) = shares ?? (0.5, 0.5);
    final rc = retailColor ?? SalesChannel.fill(SalesChannel.retail);
    final wc = wholesaleColor ?? SalesChannel.fill(SalesChannel.wholesale);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _SplitDonutPainter(
          retailShare: r * t,
          wholesaleShare: w * t,
          retailColor: rc.withValues(alpha: dimmed ? 0.45 : 1.0),
          wholesaleColor: wc.withValues(alpha: dimmed ? 0.45 : 1.0),
          trackColor: trackColor ?? AppColors.borderLight,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SplitDonutPainter extends CustomPainter {
  final double retailShare;
  final double wholesaleShare;
  final Color retailColor;
  final Color wholesaleColor;
  final Color trackColor;
  final double strokeWidth;

  const _SplitDonutPainter({
    required this.retailShare,
    required this.wholesaleShare,
    required this.retailColor,
    required this.wholesaleColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(strokeWidth / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(inner, 0, math.pi * 2, false, base..color = trackColor);

    const gap = 0.30; // radians of breathing room between the two arcs
    var start = -math.pi / 2 + gap / 2;
    final retailSweep = math.max(0.0, retailShare * (math.pi * 2) - gap);
    if (retailSweep > 0.01) {
      canvas.drawArc(inner, start, retailSweep, false, base..color = retailColor);
    }
    start += retailSweep + gap;
    final wholesaleSweep = math.max(0.0, wholesaleShare * (math.pi * 2) - gap);
    if (wholesaleSweep > 0.01) {
      canvas.drawArc(inner, start, wholesaleSweep, false, base..color = wholesaleColor);
    }
  }

  @override
  bool shouldRepaint(_SplitDonutPainter old) =>
      old.retailShare != retailShare ||
      old.wholesaleShare != wholesaleShare ||
      old.retailColor != retailColor ||
      old.wholesaleColor != wholesaleColor;
}
