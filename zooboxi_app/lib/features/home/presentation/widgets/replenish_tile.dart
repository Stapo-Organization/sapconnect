import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/paw_wallpaper.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/data/loyalty_repository.dart';
import '../../../loyalty/presentation/supply_actions.dart';
import '../../../pets/data/household.dart';

/// «يخلص طعام أوريو خلال ٤ أيام» — the one tile no grocery app can draw.
///
/// The store knows the animal, its weight and its feeding plan, so it knows
/// the bowl is running low before the owner does. Until now that lived inside
/// the family card, one of six things it might say. On a two-hour shelf it is
/// the most useful sentence on the page, so it gets a tile of its own — and
/// the tile is quiet when there is nothing to say, which is most days.
///
/// The ring is the same gauge the family hub draws; the button is the whole
/// point: the same product, the same pack, the same quantity, one tap, and it
/// is at the door in two hours. That turns a reminder into a solution.
class ReplenishTile extends ConsumerStatefulWidget {
  const ReplenishTile({super.key, this.express = true});

  /// Whether the two-hour promise may be made here.
  final bool express;

  @override
  ConsumerState<ReplenishTile> createState() => _ReplenishTileState();
}

class _ReplenishTileState extends ConsumerState<ReplenishTile> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(loyaltySummaryProvider).value;
    final item = summary?.supplyDue;
    if (item == null) return const SizedBox.shrink();

    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final out = item.daysLeft <= 0;
    final tone = out ? cs.error : zb.warning;
    final pet = item.pet?.name;

    final title = out
        ? (pet == null ? l.replenishOutNoPet : l.replenishOut(pet))
        : '${pet == null ? l.replenishTitleNoPet : l.replenishTitle(pet)} ${l.replenishDays(item.daysLeft)}';

    if (widget.express) {
      return _ExpressForm(
        item: item,
        title: title,
        adding: _adding,
        onOrder: () async {
          setState(() => _adding = true);
          await orderSupplyItem(context, ref, item, zone: 'home_replenish');
          if (mounted) setState(() => _adding = false);
        },
      );
    }

    // «الاستراحة»: the animal whose food this is sits at the card's end,
    // its head above the edge — the reminder is theirs, not the store's.
    final cast = item.pet == null ? null : castForSpecies(item.pet!.species);
    const sitter = 108.0;
    final card = Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            context.push('/family/supply');
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: tone.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [tone.withValues(alpha: 0.10), tone.withValues(alpha: 0.02)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _GaugeAvatar(item: item, tone: tone),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      Gap.h8,
                      FilledButton.tonal(
                        onPressed: _adding
                            ? null
                            : () async {
                                setState(() => _adding = true);
                                await orderSupplyItem(context, ref, item, zone: 'home_replenish');
                                if (mounted) setState(() => _adding = false);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: tone.withValues(alpha: context.isDark ? 0.28 : 0.16),
                          foregroundColor: context.isDark ? cs.onSurface : tone,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_adding)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(widget.express ? Icons.bolt_rounded : Icons.replay_rounded, size: 16),
                            Gap.w6,
                            Text(widget.express ? l.replenishCta : l.replenishCtaPlain),
                            if (widget.express) ...[
                              Gap.w6,
                              Text(
                                '· ${l.replenishArrives}',
                                style: context.tt.labelSmall?.copyWith(
                                  color: (context.isDark ? cs.onSurface : tone).withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (cast != null) const SizedBox(width: sitter * 0.62),
              ],
            ),
          ),
        ),
      ),
    );
    if (cast == null) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 30), child: card),
        PositionedDirectional(
          end: 26,
          bottom: 6,
          child: Companion(ZbPose.sitUp, cast: cast, height: sitter, flip: !context.isRtl),
        ),
      ],
    );
  }
}

/// The product's photo wearing how much of the last pack is left.
class _GaugeAvatar extends StatelessWidget {
  const _GaugeAvatar({required this.item, required this.tone});

  final SupplyItem item;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: item.remaining.clamp(0.0, 1.0),
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              backgroundColor: tone.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: ZbImage(url: item.product.image, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}

/// The express form: the bowl itself, drawn at the level the plan says it is
/// at, on the deep green the mockup wears. The tile is the one sentence on
/// the page no grocery app can write, so it looks like nothing else on it.
class _ExpressForm extends StatelessWidget {
  const _ExpressForm({
    required this.item,
    required this.title,
    required this.adding,
    required this.onOrder,
  });

  final SupplyItem item;
  final String title;
  final bool adding;
  final Future<void> Function() onOrder;

  static const Color _deep = Color(0xFF0F3326);
  static const Color _mid = Color(0xFF1E5C3F);
  static const Color _gold = Color(0xFFFBD268);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = context.tt;
    final pet = item.pet?.name;
    final level = item.remaining.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Haptics.selection();
            context.push('/family/supply');
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [_deep, _mid, ZbTokens.success],
                stops: [0, 0.55, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: _mid.withValues(alpha: 0.55),
                  blurRadius: 30,
                  spreadRadius: -14,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  const Positioned.fill(child: PawWallpaper()),
                  PositionedDirectional(
                    start: -30,
                    top: -40,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [_gold.withValues(alpha: 0.35), _gold.withValues(alpha: 0)]),
                      ),
                    ),
                  ),
                  Positioned(top: 0, left: 0, right: 0, height: 1, child: ColoredBox(color: Colors.white.withValues(alpha: 0.25))),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
                    child: Row(
                      children: [
                        _Bowl(level: level),
                        Gap.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.pets_rounded, size: 11, color: _mid),
                                  ),
                                  Gap.w6,
                                  Flexible(
                                    child: Text(
                                      pet == null ? l.replenishBowlNoPet : l.replenishBowl(pet),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.labelSmall?.copyWith(color: _gold, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.2),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
                              ),
                            ],
                          ),
                        ),
                        Gap.w10,
                        Semantics(
                          button: true,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ZbTokens.rPill),
                            elevation: 6,
                            shadowColor: Colors.black.withValues(alpha: 0.5),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(ZbTokens.rPill),
                              onTap: adding ? null : onOrder,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: adding
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(
                                        l.replenishCtaShort,
                                        style: tt.labelLarge?.copyWith(color: _deep, fontWeight: FontWeight.w900),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bowl, filled to the level the feeding plan computes, with the
/// percentage on a white pill at its shoulder.
class _Bowl extends StatelessWidget {
  const _Bowl({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _BowlPainter(level: level))),
          PositionedDirectional(
            top: -6,
            end: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Text(
                '${(level * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  height: 1.2,
                  color: _ExpressForm._deep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BowlPainter extends CustomPainter {
  const _BowlPainter({required this.level});

  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 66;
    final sy = size.height / 62;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    // The shadow on the floor.
    canvas.drawOval(
      Rect.fromCenter(center: p(33, 58), width: 48 * sx, height: 7 * sy),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    final bowl = Path()
      ..moveTo(5 * sx, 22 * sy)
      ..lineTo(61 * sx, 22 * sy)
      ..lineTo(54 * sx, 49 * sy)
      ..arcToPoint(p(46, 56), radius: Radius.circular(8 * sx))
      ..lineTo(20 * sx, 56 * sy)
      ..arcToPoint(p(12, 49), radius: Radius.circular(8 * sx))
      ..close();
    canvas.drawPath(bowl, Paint()..color = Colors.white.withValues(alpha: 0.16));

    // The food, up to the level, clipped to the bowl.
    canvas.save();
    canvas.clipPath(bowl);
    final top = 56 - math.max(0.0, level) * 34;
    canvas.drawRect(Rect.fromLTRB(0, top * sy, size.width, size.height), Paint()..color = const Color(0xFFFBD268));
    final kibble = Paint()..color = const Color(0xFFC98A25);
    for (final k in const [(20.0, 44.0), (30.0, 47.0), (41.0, 44.0), (35.0, 52.0), (25.0, 53.0), (46.0, 50.0)]) {
      if (k.$2 > top) canvas.drawCircle(p(k.$1, k.$2), 2 * sx, kibble);
    }
    canvas.restore();

    canvas.drawPath(
      bowl,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    // The rim.
    final rim = Rect.fromCenter(center: p(33, 22), width: 56 * sx, height: 11 * sy);
    canvas.drawOval(rim, Paint()..color = Colors.white.withValues(alpha: 0.28));
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_BowlPainter old) => old.level != level;
}
