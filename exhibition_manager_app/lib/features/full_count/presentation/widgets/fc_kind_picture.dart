import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'fc_widgets.dart';

/// Kind of place → the letter its shelf codes start with (StoreLocation::KINDS).
const fcKindLetters = {'gondola': 'G', 'wall': 'W', 'endcap': 'E', 'cashier': 'C', 'backroom': 'B', 'other': 'X'};

/// A tiny showroom seen from above with one kind of place lit up — so a
/// counter learns «where is a G?» by looking, not by reading a term.
class FcKindPicture extends StatelessWidget {
  final String kind;
  final double width;
  const FcKindPicture({super.key, required this.kind, this.width = 96});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 0.8,
    child: CustomPaint(
      painter: _ShowroomPainter(
        kind: kind,
        hot: Fc.kindColor(kind),
        cold: AppColors.border,
        floor: AppColors.surfaceVariant,
        wall: AppColors.textTertiary,
      ),
    ),
  );
}

class _ShowroomPainter extends CustomPainter {
  final String kind;
  final Color hot, cold, floor, wall;
  _ShowroomPainter({
    required this.kind,
    required this.hot,
    required this.cold,
    required this.floor,
    required this.wall,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 100 × 80 grid.
    final k = size.width / 100;
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * k, t * k, rr * k, b * k);
    Paint fill(bool on) => Paint()..color = on ? hot : cold;
    final line = Paint()
      ..color = wall
      ..strokeWidth = 1.4 * k
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void rrect(Rect x, bool on) {
      // The lit part gets a soft halo so it reads at a glance.
      if (on) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(x.inflate(2.2 * k), Radius.circular(2.4 * k)),
          Paint()..color = hot.withValues(alpha: 0.25),
        );
      }
      canvas.drawRRect(RRect.fromRectAndRadius(x, Radius.circular(1.2 * k)), fill(on));
    }

    // Floor.
    canvas.drawRRect(RRect.fromRectAndRadius(r(2, 2, 98, 78), Radius.circular(3 * k)), Paint()..color = floor);

    // Storeroom in the back corner, behind a door.
    final back = kind == 'backroom';
    if (back) {
      canvas.drawRect(r(70, 2, 98, 30), Paint()..color = hot.withValues(alpha: 0.22));
      for (final x in [74.0, 82.0, 90.0]) {
        rrect(r(x, 8, x + 6, 14), true);
        rrect(r(x, 17, x + 6, 23), true);
      }
    }
    canvas.drawLine(Offset(70 * k, 2 * k), Offset(70 * k, 30 * k), line);
    canvas.drawLine(Offset(70 * k, 30 * k), Offset(79 * k, 30 * k), line);
    canvas.drawLine(Offset(89 * k, 30 * k), Offset(98 * k, 30 * k), line);

    // Shelves fixed to the walls.
    final w = kind == 'wall';
    rrect(r(6, 4, 66, 8), w);
    rrect(r(4, 11, 8, 74), w);
    rrect(r(92, 36, 96, 74), w);

    // Free-standing shelves in the middle, with their two short ends.
    final g = kind == 'gondola', e = kind == 'endcap';
    for (final x in [22.0, 40.0]) {
      rrect(r(x, 22, x + 9, 54), g);
      rrect(r(x, 14.5, x + 9, 19.5), e);
      rrect(r(x, 56.5, x + 9, 61.5), e);
    }

    // Cashier by the door.
    final c = kind == 'cashier';
    rrect(r(60, 62, 82, 68), c);
    rrect(r(76, 52, 82, 62), c);

    // Anything else: a display table.
    if (kind == 'other')
      canvas.drawCircle(Offset(66 * k, 40 * k), 7.5 * k, Paint()..color = hot.withValues(alpha: 0.25));
    canvas.drawCircle(Offset(66 * k, 40 * k), 5 * k, fill(kind == 'other'));

    // Walls, with the entrance in the front.
    final path = Path()
      ..moveTo(40 * k, 78 * k)
      ..lineTo(5 * k, 78 * k)
      ..arcToPoint(Offset(2 * k, 75 * k), radius: Radius.circular(3 * k))
      ..lineTo(2 * k, 5 * k)
      ..arcToPoint(Offset(5 * k, 2 * k), radius: Radius.circular(3 * k))
      ..lineTo(95 * k, 2 * k)
      ..arcToPoint(Offset(98 * k, 5 * k), radius: Radius.circular(3 * k))
      ..lineTo(98 * k, 75 * k)
      ..arcToPoint(Offset(95 * k, 78 * k), radius: Radius.circular(3 * k))
      ..lineTo(56 * k, 78 * k);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_ShowroomPainter o) => o.kind != kind || o.hot != hot || o.cold != cold;
}

/// One shelf unit seen from the front: R1 at the top, counting down.
class FcShelfNumbersPicture extends StatelessWidget {
  final int shelves;
  const FcShelfNumbersPicture({super.key, this.shelves = 4});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 1; i <= shelves; i++) {
      rows.add(
        Row(
          children: [
            Container(
              width: 34,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: i == 1 ? Fc.accentDark : AppColors.surface,
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: i == 1 ? Fc.accentDark : AppColors.border),
              ),
              child: Text(
                'R$i',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: i == 1 ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.textTertiary, width: 2)),
                ),
                child: Row(
                  children: [
                    for (var j = 0; j < 4 + (i % 2); j++)
                      Container(
                        width: 9,
                        height: 12 + ((i + j) % 3) * 3.0,
                        margin: const EdgeInsetsDirectional.only(start: 4),
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                      ),
                  ].map((b) => Align(alignment: Alignment.bottomCenter, child: b)).toList(),
                ),
              ),
            ),
          ],
        ),
      );
      if (i < shelves) rows.add(const SizedBox(height: 4));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: rows)),
        const SizedBox(width: AppSpacing.sm),
        Column(
          children: [
            Icon(Icons.arrow_downward_rounded, color: Fc.accentDark, size: 20),
            Text(
              context.tr('fc_code_top_down'),
              style: AppTypography.labelSmall.copyWith(color: Fc.accentDark, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

/// «What does a shelf code mean?»: a worked example, each letter with a picture
/// of where it is in the showroom, then the shelf numbers.
class FcCodeGuide extends StatelessWidget {
  const FcCodeGuide({super.key});

  /// How to read a shelf code: a worked example, then each letter with a
  /// picture of where it is in the showroom, then the shelf numbers.
  @override
  Widget build(BuildContext context) {
    return FcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('fc_code_system'), style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            context.tr('fc_code_intro'),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          _example(context),
          const SizedBox(height: AppSpacing.lg),
          Text(context.tr('fc_code_letter_t'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          for (final k in fcKindLetters.keys) _kindRow(context, k),
          const SizedBox(height: AppSpacing.md),
          Text(context.tr('fc_code_shelf_t'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(context.tr('fc_code_shelf'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          const FcShelfNumbersPicture(),
        ],
      ),
    );
  }

  Widget _example(BuildContext context) {
    Widget part(String code, String meaning, Color c) => Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: c.withValues(alpha: 0.5)),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: AppTypography.mono.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: c),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meaning,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.borderLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('fc_code_example'), style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          // The code reads left to right in every language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                part('G', context.tr('fc_kind_gondola'), Fc.kindColor('gondola')),
                const SizedBox(width: 6),
                part('03', context.tr('fc_code_part_no'), AppColors.textPrimary),
                const SizedBox(width: 6),
                part('R2', context.tr('fc_code_part_shelf'), Fc.accentDark),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('fc_code_example_says'),
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _kindRow(BuildContext context, String k) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        FcKindPicture(kind: k, width: 100),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Fc.kindColor(k), borderRadius: AppRadius.borderSm),
                    child: Text(
                      fcKindLetters[k]!,
                      style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      Fc.kindLabel(context, k),
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('fc_kind_${k}_desc'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
