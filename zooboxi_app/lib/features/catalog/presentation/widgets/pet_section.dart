import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';
import '../../data/category_tree.dart';
import '../pet_palette.dart';

/// One pet's board: a coloured band that names the aisle, then its
/// departments as cards — the ones nearly everyone came for (food, treats)
/// full-width up top, the rest two across.
///
/// [revealed] is flipped by the screen the first time the board scrolls into
/// view; until then the cards wait at rest so the entrance plays when the
/// customer actually arrives at the board, not while it is still off-screen.
class PetSection extends StatelessWidget {
  const PetSection({
    super.key,
    required this.pet,
    required this.palette,
    required this.revealed,
    required this.onOpen,
  });

  final CategoryNode pet;
  final PetPalette palette;
  final bool revealed;

  /// Called with the slug and the title to show on the listing screen.
  final void Function(String slug, String title) onOpen;

  /// Card text is sized from this ceiling; the layout must not be asked to
  /// absorb a larger one.
  static const double maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final departments = orderedDepartments(pet.children);
    final wide = wideDepartmentCount(departments.length);
    final still = context.reduceMotion;

    var order = 0;
    Widget enter(Widget child) {
      if (still) return child;
      final delay = Motion.stagger * math.min(order++, 8);
      return child
          .animate(target: revealed ? 1 : 0)
          .fadeIn(delay: delay, duration: 260.ms, curve: Motion.decelerate)
          .slideY(
            begin: 0.08,
            end: 0,
            delay: delay,
            duration: 320.ms,
            curve: Motion.decelerate,
          );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PetBand(
            pet: pet,
            palette: palette,
            revealed: revealed,
            onTap: () => onOpen(pet.slug, pet.name),
          ),
          if (departments.isNotEmpty) ...[
            Gap.h12,
            for (final node in departments.take(wide)) ...[
              enter(
                _WideCard(
                  node: node,
                  palette: palette,
                  onTap: () => onOpen(node.slug, node.name),
                ),
              ),
              Gap.h8,
            ],
            if (departments.length > wide)
              _TwoUp(
                children: [
                  for (final node in departments.skip(wide))
                    enter(
                      _Card(
                        node: node,
                        palette: palette,
                        onTap: () => onOpen(node.slug, node.name),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// The aisle sign. The pet's photo — an animal in a Zooboxi box — sits on the
/// band as a slapped-on sticker with sparkles, the logo's own vocabulary.
class _PetBand extends StatelessWidget {
  const _PetBand({
    required this.pet,
    required this.palette,
    required this.revealed,
    required this.onTap,
  });

  final CategoryNode pet;
  final PetPalette palette;
  final bool revealed;
  final VoidCallback onTap;

  static const double _sticker = 108;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final still = context.reduceMotion;

    Widget sticker = _Sticker(pet: pet, size: _sticker);
    if (!still) {
      // The sticker lands: a little big and over-rotated, then settles onto
      // its final tilt. Plays once, when the board is first reached.
      sticker = sticker
          .animate(target: revealed ? 1 : 0)
          .scale(
            begin: const Offset(0.82, 0.82),
            end: const Offset(1, 1),
            duration: 480.ms,
            curve: Motion.spring,
          )
          .rotate(begin: -0.03, end: 0, duration: 480.ms, curve: Motion.spring);
    }

    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [palette.band, palette.bandEnd],
          ),
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
        ),
        padding: const EdgeInsetsDirectional.only(
          start: 18,
          end: 14,
          top: 16,
          bottom: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pet.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: palette.headline,
                      height: 1.15,
                    ),
                  ),
                  if (pet.count > 0) ...[
                    Gap.h4,
                    Text(
                      l.categoriesProductCount(pet.count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodyMedium?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                  Gap.h12,
                  _Cta(label: l.categoriesShopAll, palette: palette),
                ],
              ),
            ),
            Gap.w12,
            SizedBox(
              width: _sticker + 16,
              height: _sticker + 12,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: context.isRtl ? 0.07 : -0.07,
                    child: sticker,
                  ),
                  if (revealed && !still)
                    Positioned.fill(
                      child: SparkleField(
                        twinkle: true,
                        sparkles: [
                          const SparkleSpec(
                            dx: 0.06,
                            dy: 0.10,
                            size: 12,
                            color: ZbTokens.sparkAmber,
                          ),
                          SparkleSpec(
                            dx: 0.96,
                            dy: 0.22,
                            size: 8,
                            color: palette.accent,
                            delay: const Duration(milliseconds: 120),
                            rotation: 0.35,
                          ),
                          SparkleSpec(
                            dx: 0.10,
                            dy: 0.92,
                            size: 7,
                            color: palette.accent,
                            delay: const Duration(milliseconds: 220),
                            rotation: 0.6,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker({required this.pet, required this.size});

  final CategoryNode pet;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = pet.icon;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ZbImage(
        url: pet.image,
        fit: BoxFit.cover,
        backgroundColor: Colors.white,
        fallback: icon == null
            ? null
            : Center(
                child: Text(
                  icon,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: size * 0.46),
                ),
              ),
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.palette});

  final String label;
  final PetPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 14,
        end: 8,
        top: 7,
        bottom: 7,
      ),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.tt.labelLarge?.copyWith(
              color: palette.onAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            context.isRtl
                ? Icons.keyboard_arrow_left_rounded
                : Icons.keyboard_arrow_right_rounded,
            size: 18,
            color: palette.onAccent,
          ),
        ],
      ),
    );
  }
}

/// A full-width department card: illustration, name, count, and an arrow.
class _WideCard extends StatelessWidget {
  const _WideCard({
    required this.node,
    required this.palette,
    required this.onTap,
  });

  final CategoryNode node;
  final PetPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      onTap: onTap,
      child: Container(
        decoration: _cardDecoration(context),
        padding: const EdgeInsetsDirectional.only(
          start: 10,
          end: 12,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            _ArtWell(
              node: node,
              palette: palette,
              size: 84,
              radius: ZbTokens.rMd,
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (node.count > 0) ...[
                    Gap.h4,
                    Text(
                      l.categoriesProductCount(node.count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Gap.w8,
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.well(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                context.isRtl
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
                color: palette.headline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A half-width department card: illustration above, name and count below.
class _Card extends StatelessWidget {
  const _Card({required this.node, required this.palette, required this.onTap});

  final CategoryNode node;
  final PetPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      onTap: onTap,
      child: Container(
        decoration: _cardDecoration(context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: AspectRatio(
                aspectRatio: 1.45,
                child: _ArtWell(
                  node: node,
                  palette: palette,
                  radius: ZbTokens.rMd,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _twoLines(context, context.tt.titleSmall),
                    child: Text(
                      node.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Gap.h4,
                  Text(
                    node.count > 0 ? l.categoriesProductCount(node.count) : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Two lines of [style], honoured up to the section's text-scale ceiling,
  /// so a one-line name and a two-line name make cards of equal height.
  static double _twoLines(BuildContext context, TextStyle? style) {
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: PetSection.maxTextScale);
    return scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.3) * 2;
  }
}

/// The tinted well a department illustration sits in. The art is a warm line
/// drawing on white; the well lifts it off the card in the pet's colour.
class _ArtWell extends StatelessWidget {
  const _ArtWell({
    required this.node,
    required this.palette,
    required this.radius,
    this.size,
  });

  final CategoryNode node;
  final PetPalette palette;
  final double radius;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final icon = node.icon;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.well(context),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ZbImage(
        url: node.image,
        fit: BoxFit.contain,
        padding: const EdgeInsets.all(10),
        backgroundColor: Colors.transparent,
        fallback: icon == null
            ? null
            : Center(
                child: Text(
                  icon,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final cs = context.cs;
  return BoxDecoration(
    color: cs.surface,
    borderRadius: BorderRadius.circular(ZbTokens.rLg),
    border: Border.all(
      color: cs.outlineVariant.withValues(alpha: context.isDark ? 1 : 0.7),
    ),
    boxShadow: [
      if (!context.isDark)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
    ],
  );
}

/// Two cards per row, rows as tall as their taller card. A plain grid would
/// need a guessed aspect ratio; this lets a two-line name cost nothing.
class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.children});

  final List<Widget> children;

  static const double _gutter = 8;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final pair = children.sublist(i, math.min(i + 2, children.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: pair[0]),
              const SizedBox(width: _gutter),
              Expanded(
                child: pair.length > 1 ? pair[1] : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) rows.add(const SizedBox(height: _gutter));
    }
    return Column(children: rows);
  }
}
