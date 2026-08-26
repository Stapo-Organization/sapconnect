import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_composition.dart';
import 'campaign_countdown.dart';

/// The one pill shape every campaign chip uses, so a badge, a coupon and a
/// countdown line up on the same baseline at the same weight.
class CampaignChip extends StatelessWidget {
  const CampaignChip({
    super.key,
    required this.label,
    required this.foreground,
    this.background,
    this.icon,
    this.dashed = false,
  });

  final String label;
  final Color foreground;
  final Color? background;
  final IconData? icon;

  /// Coupon codes get a torn-ticket edge — it reads as "something to take"
  /// rather than as another status pill.
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsetsDirectional.only(start: 9, end: 9, top: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            Gap.w4,
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (dashed) {
      return CustomPaint(
        painter: _DashedPillPainter(color: foreground.withValues(alpha: 0.75)),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: content,
    );
  }
}

class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 4;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + 3;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter old) => old.color != color;
}

/// Badge · coupon · discount · countdown, in that reading order.
///
/// [maxChips] is a design limit, not a layout one: four pills on a compact
/// banner is a crowded sticker sheet, and the second row they wrap onto is
/// height the headline needed. When the row has to give something up it drops
/// the *least actionable* chip — a discount percentage is decoration next to a
/// coupon code you can actually use, or a deadline you can miss.
class CampaignChipRow extends StatelessWidget {
  const CampaignChipRow({
    super.key,
    required this.campaign,
    required this.panel,
    this.includeBadge = true,
    this.maxChips,
  });

  final Campaign campaign;
  final CampaignPanel panel;

  /// The hero puts the badge above the headline, where it reads as a kicker;
  /// a compact banner has no room for that and folds it into the row.
  final bool includeBadge;

  final int? maxChips;

  // Keep order, lowest first.
  static const int _rankCoupon = 0;
  static const int _rankCountdown = 1;
  static const int _rankDiscount = 2;
  static const int _rankBadge = 3;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final discount = campaign.discountPct;

    // Built in reading order; ranked for what survives a squeeze.
    final candidates = <({int rank, Widget chip})>[
      if (includeBadge && (campaign.badge ?? '').isNotEmpty)
        (rank: _rankBadge, chip: CampaignBadgeChip(campaign: campaign, panel: panel)),
      if (campaign.couponCode != null)
        (
          rank: _rankCoupon,
          chip: CampaignChip(
            label: l.homeCampaignCoupon(campaign.couponCode!),
            foreground: panel.fg,
            icon: Icons.confirmation_number_outlined,
            dashed: true,
          ),
        ),
      if (discount != null && discount > 0)
        (
          rank: _rankDiscount,
          chip: CampaignChip(
            label: l.homeCampaignDiscount(Fmt.percent(discount, locale: locale)),
            foreground: panel.fg,
            background: panel.chipFill,
            icon: Icons.sell_outlined,
          ),
        ),
      if (campaign.endsAt != null)
        (
          rank: _rankCountdown,
          chip: CampaignCountdownChip(endsAt: campaign.endsAt!, panel: panel),
        ),
    ];
    if (candidates.isEmpty) return const SizedBox.shrink();

    var kept = candidates;
    final limit = maxChips;
    if (limit != null && candidates.length > limit) {
      final allowed = ([...candidates]..sort((a, b) => a.rank.compareTo(b.rank)))
          .take(limit)
          .map((entry) => entry.rank)
          .toSet();
      kept = [
        for (final candidate in candidates)
          if (allowed.contains(candidate.rank)) candidate,
      ];
    }

    // Still a Wrap: at 1.3× text scale a long coupon plus a countdown can
    // outgrow the panel, and a second row beats a clipped one.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final candidate in kept) candidate.chip],
    );
  }
}

/// The call to action on a composed slide.
///
/// A solid surface pill rather than an outline: on a photograph the outline is
/// the first thing that disappears, and this is the element the whole slide
/// exists to get tapped.
class CampaignCta extends StatelessWidget {
  const CampaignCta({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (compact ? context.tt.labelSmall : context.tt.labelMedium)
            ?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The kicker above a campaign headline ("عرض محدود").
class CampaignBadgeChip extends StatelessWidget {
  const CampaignBadgeChip({super.key, required this.campaign, required this.panel});

  final Campaign campaign;
  final CampaignPanel panel;

  @override
  Widget build(BuildContext context) {
    final badge = campaign.badge;
    if (badge == null || badge.isEmpty) return const SizedBox.shrink();
    final clearance = campaign.campaignType == 'clearance';

    return CampaignChip(
      label: badge,
      // A clearance kicker keeps the sale accent even on the sale-toned panel;
      // everything else borrows the panel's own foreground so the badge reads
      // as a label, not as a second brand colour.
      foreground: clearance ? Colors.white : panel.fg,
      background: clearance ? context.zb.sale : panel.chipFill,
    );
  }
}

/// The urgency chip. Its own [StatefulWidget] so a ticking second never
/// rebuilds the carousel — or the home screen — around it.
class CampaignCountdownChip extends StatefulWidget {
  const CampaignCountdownChip({super.key, required this.endsAt, required this.panel});

  final DateTime endsAt;
  final CampaignPanel panel;

  @override
  State<CampaignCountdownChip> createState() => _CampaignCountdownChipState();
}

class _CampaignCountdownChipState extends State<CampaignCountdownChip> {
  Timer? _timer;
  late CampaignCountdown _countdown = CampaignCountdown.of(widget.endsAt);
  bool _seconds = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: no self-starting flicker. The clock still runs, it just
    // steps once a minute and drops the seconds it can no longer show.
    _seconds = !context.reduceMotion;
    _restart();
  }

  @override
  void didUpdateWidget(CampaignCountdownChip old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) {
      _countdown = CampaignCountdown.of(widget.endsAt);
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_countdown.mode != CountdownMode.live) return;
    _timer = Timer.periodic(
      _seconds ? const Duration(seconds: 1) : const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        final next = CampaignCountdown.of(widget.endsAt);
        setState(() => _countdown = next);
        if (next.mode != CountdownMode.live) _restart();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final label = switch (_countdown.mode) {
      CountdownMode.live => l.homeCampaignEndsIn(
          CampaignCountdown.format(_countdown.remaining, seconds: _seconds),
        ),
      CountdownMode.days => l.homeCampaignEndsInDays(_countdown.days),
      CountdownMode.none => null,
    };
    if (label == null) return const SizedBox.shrink();

    return CampaignChip(
      label: label,
      icon: Icons.schedule_rounded,
      foreground: widget.panel.fg,
      background: widget.panel.chipFill,
    );
  }
}
