import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/characters/characters.dart';
import '../../../../../core/motion/motion.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_story.dart';
import 'story_sheets.dart';
import 'story_style.dart';

/// «حوالي 5.0 سم × 3.2 سم (حجم كبير)» → «5.0 سم × 3.2 سم» — a tile has room
/// for the value, not for the hedging around it.
String storyShort(String v) => v
    .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
    .replaceFirst(RegExp(r'^(~|≈|حوالي|تقريبًا|تقريباً|approx\.?|approximately|about)\s*', caseSensitive: false), '')
    .trim();

/// Beside the price: the reasons to buy (each with a glyph that means
/// something) and a strip of four key facts.
class StoryHighlights extends StatelessWidget {
  const StoryHighlights({super.key, required this.story});

  final ProductStory story;

  @override
  Widget build(BuildContext context) {
    final chips = story.highlights.take(6).toList();
    final facts = story.facts;
    if (chips.isEmpty && facts.length < 2) return const SizedBox.shrink();
    final colors = storyChipColors(context);
    final features = story.section('features');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chips.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chips.length,
              separatorBuilder: (_, _) => Gap.w8,
              itemBuilder: (context, i) => _Benefit(
                title: chips[i].title,
                color: colors[i % colors.length],
                onTap: features == null
                    ? null
                    : () => showStorySheet(context, story: story, section: features),
              )
                  .animate(delay: context.motion(Motion.stagger * i))
                  .fadeIn(duration: context.motion(Motion.enter))
                  .slideX(begin: context.isRtl ? -0.12 : 0.12, curve: Motion.decelerate),
            ),
          ),
        if (facts.length >= 2) ...[
          if (chips.isNotEmpty) Gap.h12,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FactsStrip(facts: facts),
          ),
        ],
      ],
    );
  }
}

/// A soft pill in its own hue: a solid disc with the benefit's glyph, then
/// the words in the deep shade of the same colour.
class _Benefit extends StatelessWidget {
  const _Benefit({required this.title, required this.color, this.onTap});

  final String title;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final bg = dark ? color.withValues(alpha: 0.28) : Color.alphaBlend(color.withValues(alpha: 0.11), Colors.white);
    final ink = dark ? Colors.white : Color.alphaBlend(Colors.black.withValues(alpha: 0.18), color);
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 14, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: StoryIcon(storyBenefitIcon(title), color: Colors.white, size: 17, stroke: 2.1),
              ),
              Gap.w8,
              Text(
                title,
                style: context.tt.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactsStrip extends StatelessWidget {
  const _FactsStrip({required this.facts});

  final List<StoryFact> facts;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final hues = storyChipColors(context);
    final line = dark ? ZbTokens.lineDark : ZbTokens.line;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? ZbTokens.graphiteRaised : ZbTokens.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: line),
              Expanded(
                child: Semantics(
                  label: '${facts[i].label}: ${facts[i].value}',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
                    child: Column(
                      children: [
                        StoryIcon(storyIconFor(facts[i].kind), color: hues[i % 4], size: 20, stroke: 1.9),
                        const SizedBox(height: 6),
                        Text(
                          storyShort(facts[i].value),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          facts[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «دليل زوبكسي»: the product's own animal peeking over the first card, an
/// editorial «عن المنتج», then a bento of light tiles in the logo's colours —
/// the feeding one charts the real amounts and works in place, the analysis
/// one splits every 100 g — closed by the Zooboxi seal.
class ProductStoryTiles extends StatelessWidget {
  const ProductStoryTiles({super.key, required this.story, this.cartonUnits = 0});

  final ProductStory story;
  final int cartonUnits;

  /// Tiles lead with what decides a purchase.
  static const _rank = ['feeding', 'ingredients', 'analysis', 'breeds', 'usage', 'specs', 'contents', 'safety', 'storage'];

  static const double _peekHeight = 64;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final sections = story.sections.where((s) => _rank.contains(s.key)).toList()
      ..sort((a, b) => _rank.indexOf(a.key).compareTo(_rank.indexOf(b.key)));

    final tiles = <_TileSpec>[];
    for (final s in sections) {
      final t = _tileFor(context, l, s);
      if (t != null) tiles.add(t);
    }
    final overview = story.section('overview');

    // Two columns: wide tiles take a row; small ones pair up, and an odd one
    // out stretches across its row rather than leaving a hole.
    final rows = <Widget>[];
    final pending = <Widget>[];
    for (final t in tiles) {
      if (t.wide) {
        rows.add(t.widget);
        continue;
      }
      pending.add(t.widget);
      if (pending.length == 2) {
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: pending[0]), Gap.w10, Expanded(child: pending[1])],
          ),
        ));
        pending.clear();
      }
    }
    if (pending.isNotEmpty) rows.add(pending.single);
    if (rows.isEmpty && overview == null) return const SizedBox.shrink();

    final blocks = <Widget>[
      if (overview != null) _OverviewCard(section: overview),
      ...rows,
    ];

    final cast = storyCast(story.species);
    final peekKey = switch (cast) {
      ZbCast.cat || ZbCast.dog || null => castStickerKey(cast ?? ZbCast.cat, ZbPose.peek),
      final c => castStickerKey(c, ZbPose.sitUp),
    };
    final peekSize = ZbSticker.sizeOf(peekKey, height: _peekHeight);
    final species = switch (story.species) {
      'cat' || 'dog' || 'bird' || 'fish' => story.species!,
      _ => 'other',
    };
    final dark = context.isDark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      decoration: BoxDecoration(
        color: dark ? ZbTokens.graphite : ZbTokens.cream,
        borderRadius: BorderRadius.circular(ZbTokens.rXl + 4),
        border: dark ? Border.all(color: ZbTokens.lineDark) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The masthead leaves room at the end for the animal peeking over
          // the first card below it.
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StorySparkle(color: dark ? ZbTokens.amberOnDark : ZbTokens.sparkAmber, size: 13),
                            Gap.w6,
                            Text(
                              l.storyGuideEyebrow,
                              style: context.tt.labelLarge?.copyWith(
                                color: dark ? ZbTokens.tealOnDark : ZbTokens.storyTeal,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.storyGuideTitle(species),
                          style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: peekSize.width + 14, height: _peekHeight - 6),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            if (i == 0)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _enter(context, blocks[0], 0),
                  PositionedDirectional(
                    end: 18,
                    top: -_peekHeight + 1,
                    child: ExcludeSemantics(
                      child: ZbSticker(peekKey, height: _peekHeight, idle: ZbIdle.peek, delay: 300.ms),
                    ),
                  ),
                  PositionedDirectional(
                    end: 18 + peekSize.width + 2,
                    top: -_peekHeight + 6,
                    child: StorySparkle(color: dark ? ZbTokens.coralOnDark : ZbTokens.coral, size: 12, delay: 500.ms),
                  ),
                  PositionedDirectional(
                    end: 8,
                    top: -_peekHeight - 4,
                    child: StorySparkle(color: dark ? ZbTokens.tealOnDark : ZbTokens.logoTeal, size: 15, delay: 700.ms),
                  ),
                ],
              )
            else
              _enter(context, blocks[i], i),
          ],
          const SizedBox(height: 18),
          const _Seal(),
        ],
      ),
    );
  }

  Widget _enter(BuildContext context, Widget child, int i) => child
      .animate(delay: context.motion(Motion.stagger * 2 * i))
      .fadeIn(duration: context.motion(Motion.page))
      .slideY(begin: 0.06, curve: Motion.decelerate);

  _TileSpec? _tileFor(BuildContext context, L l, StorySection s) {
    final hue = StoryHue.of(context, s.key);
    final sub = context.cs.onSurfaceVariant;
    final big = context.tt.headlineSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w900, height: 1.15);
    final small = context.tt.bodySmall?.copyWith(color: sub, height: 1.5);
    void open() => showStorySheet(context, story: story, section: s, cartonUnits: cartonUnits);

    switch (s.key) {
      case 'feeding':
        final f = story.feeding;
        if (f != null) {
          return _TileSpec(wide: true, widget: _FeedingHero(guide: f, cartonUnits: cartonUnits, onTable: open));
        }
        return _TileSpec(
          wide: false,
          widget: _Tile(hue: hue, icon: 'bowl', title: l.storyFeeding, onTap: open,
              child: Text(s.teaser, maxLines: 4, overflow: TextOverflow.ellipsis, style: small)),
        );

      case 'ingredients':
        final c = story.composition;
        if (c != null && c.hasChart) {
          return _TileSpec(
            wide: true,
            widget: _Tile(
              hue: hue,
              plain: true,
              icon: 'leaf',
              title: l.storyIngredients,
              onTap: open,
              child: Row(
                children: [
                  StoryDonut(composition: c, size: 128),
                  Gap.w16,
                  Expanded(child: StoryLegend(composition: c)),
                ],
              ),
            ),
          );
        }
        final names = (c?.items ?? const <StoryIngredient>[]).take(4).map((i) => i.name).toList();
        return _TileSpec(
          wide: false,
          widget: _Tile(
            hue: hue,
            plain: true,
            icon: 'leaf',
            title: l.storyIngredients,
            onTap: open,
            child: names.isEmpty
                ? Text(s.teaser, maxLines: 4, overflow: TextOverflow.ellipsis, style: small)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < names.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: hue.tint, shape: BoxShape.circle),
                                child: Text('${i + 1}',
                                    style: context.tt.labelSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w900)),
                              ),
                              Gap.w8,
                              Expanded(
                                child: Text(names[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.tt.bodySmall?.copyWith(
                                        fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        );

      case 'analysis':
        final rows = s.percentRows;
        if (rows.isEmpty) return null;
        final n = StoryNutrition.from(rows);
        return _TileSpec(wide: n != null, widget: _AnalysisTile(rows: rows, nutrition: n, onTap: open));

      case 'breeds':
        final names = s.items.map((i) => i.title).where((t) => t.isNotEmpty).toList();
        if (names.isEmpty) return null;
        final shown = names.take(3).toList();
        return _TileSpec(
          wide: false,
          widget: _Tile(
            hue: hue,
            icon: 'paw',
            title: l.storyBreedsShort,
            onTap: open,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in shown) _Pill(text: n, hue: hue),
                if (names.length > shown.length)
                  _Pill(text: l.storyMoreBreeds(names.length - shown.length), hue: hue, faint: true),
              ],
            ),
          ),
        );

      case 'usage':
        final steps = s.items;
        if (steps.isEmpty) return null;
        return _TileSpec(
          wide: true,
          widget: _Tile(
            hue: hue,
            icon: 'steps',
            title: l.storyUsage,
            onTap: open,
            trailing: l.storyAllSteps,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepDots(count: steps.length, hue: hue),
                const SizedBox(height: 10),
                Text(steps.first.text.isNotEmpty ? steps.first.text : steps.first.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: context.tt.bodyMedium?.copyWith(color: hue.ink, height: 1.5)),
              ],
            ),
          ),
        );

      case 'safety' || 'storage':
        final count = s.items.isEmpty ? 1 : s.items.length;
        final first = s.items.isNotEmpty ? s.items.first.text : s.teaser;
        return _TileSpec(
          wide: false,
          widget: _Tile(
            hue: hue,
            icon: s.key == 'safety' ? 'shield' : 'snow',
            title: s.key == 'safety' ? l.storySafetyShort : l.storyStorage,
            onTap: open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.key == 'safety' ? l.storyWarningsCount(count) : l.storyTipsCount(count), style: big),
                Gap.h4,
                Text(first, maxLines: 3, overflow: TextOverflow.ellipsis, style: small),
              ],
            ),
          ),
        );

      case 'specs' || 'contents':
        final rows = s.tableRows.where((r) => r.length >= 2).take(3).toList();
        if (rows.isEmpty && s.items.isEmpty) return null;
        return _TileSpec(
          wide: false,
          widget: _Tile(
            hue: hue,
            icon: s.key == 'specs' ? 'ruler' : 'box',
            title: s.key == 'specs' ? l.storySpecs : l.storyContents,
            onTap: open,
            child: rows.isEmpty
                ? Text(s.teaser, maxLines: 4, overflow: TextOverflow.ellipsis, style: small)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r[0], maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.labelSmall?.copyWith(color: sub)),
                              Text(storyShort(r[1]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        );
    }
    return null;
  }
}

class _TileSpec {
  const _TileSpec({required this.widget, required this.wide});
  final Widget widget;
  final bool wide;
}

/// One light tile: a wash of its logo colour, a hairline in the same hue, a
/// solid badge, the content, an optional trailing link, and a gentle press.
/// [plain] keeps a white ground under a chart so its colours read true.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.hue,
    required this.icon,
    required this.title,
    required this.child,
    required this.onTap,
    this.trailing,
    this.badge,
    this.plain = false,
  });

  final StoryHue hue;
  final String icon;
  final String title;
  final Widget child;
  final VoidCallback onTap;
  final String? trailing;
  final String? badge;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final fill = plain ? (dark ? ZbTokens.graphiteRaised : ZbTokens.paper) : hue.fill;
    final line = plain ? (dark ? ZbTokens.lineDark : ZbTokens.line) : hue.line;
    return _Pressable(
      onTap: onTap,
      label: title,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: line)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TileHeader(hue: hue, icon: icon, title: title, trailing: trailing, badge: badge),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _TileHeader extends StatelessWidget {
  const _TileHeader({required this.hue, required this.icon, required this.title, this.trailing, this.badge});

  final StoryHue hue;
  final String icon;
  final String title;
  final String? trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StoryDisc(icon: icon, bg: hue.accent, fg: Colors.white, size: 30),
        Gap.w8,
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.titleSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w900),
          ),
        ),
        if (badge != null) ...[
          Gap.w8,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: context.isDark ? hue.tint : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hue.line),
            ),
            child: Text(badge!,
                style: context.tt.labelSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w800)),
          ),
        ],
        if (trailing != null) ...[
          Gap.w8,
          Text(trailing!, style: context.tt.labelMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w800)),
          Gap.w4,
          StoryIcon('chevron', color: hue.deep, size: 14, stroke: 2.4),
        ],
      ],
    );
  }
}

/// Scales down a touch while pressed, with a selection tick on release.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap, required this.label});

  final Widget child;
  final VoidCallback onTap;
  final String label;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? Motion.pressScale : 1,
          duration: context.motion(Motion.pressIn),
          curve: Motion.decelerate,
          child: widget.child,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.hue, this.faint = false});

  final String text;
  final StoryHue hue;
  final bool faint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: faint ? Colors.transparent : (context.isDark ? hue.tint : Colors.white),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: hue.line),
        ),
        child: Text(text,
            style: context.tt.labelMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w800)),
      );
}

/// ①—②—③—④: how many steps, drawn instead of written.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.hue});

  final int count;
  final StoryHue hue;

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(1, 6);
    return Row(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) Expanded(child: Container(height: 2, color: hue.accent.withValues(alpha: 0.3))),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == 0 ? hue.accent : (context.isDark ? hue.tint : Colors.white),
              shape: BoxShape.circle,
              border: i == 0 ? null : Border.all(color: hue.accent.withValues(alpha: 0.45), width: 1.5),
            ),
            child: Text(
              '${i + 1}',
              style: context.tt.labelLarge?.copyWith(
                color: i == 0 ? Colors.white : hue.deep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// «القيم الغذائية» on kraft — the colour of the box it ships in. When the
/// numbers add up it becomes a real chart: one bar of every 100 g, then the
/// same food with the water taken out, the way vets compare a wet food with
/// a dry one. Otherwise the plain label rows.
class _AnalysisTile extends StatelessWidget {
  const _AnalysisTile({required this.rows, required this.nutrition, required this.onTap});

  final List<(String, double)> rows;
  final StoryNutrition? nutrition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hue = StoryHue.of(context, 'analysis');
    final n = nutrition;
    final dark = context.isDark;

    return _Tile(
      hue: hue,
      icon: 'chart',
      title: l.storyNutritionLabel,
      badge: n != null ? l.storyPer100g : null,
      onTap: onTap,
      child: n == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.take(5).length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(top: BorderSide(color: hue.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            StoryNutrition.clean(rows[i].$1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.bodySmall?.copyWith(fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500),
                          ),
                        ),
                        Text('${storyNum(rows[i].$2)}%',
                            style: context.tt.labelLarge?.copyWith(color: hue.deep, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StoryNutritionBar(data: n),
                if (n.water >= 1) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: dark ? hue.tint : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: hue.line),
                    ),
                    child: Row(
                      children: [
                        StoryDisc(icon: 'drop', bg: hue.tint, fg: hue.deep, size: 34),
                        Gap.w10,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.storyDryMatter,
                                  style: context.tt.labelMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                '${n.proteinLabel} ${storyPct(n.dry(n.protein).roundToDouble())}  ·  '
                                '${n.fatLabel} ${storyPct(n.dry(n.fat).roundToDouble())}',
                                style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(l.storyDryMatterHint,
                                  style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// «كم أقدّم؟» that answers in place: the amount for the chosen weight in
/// large type, the real amounts charted against every weight band (the
/// weights are the controls), and the carton counted out in paws.
class _FeedingHero extends StatefulWidget {
  const _FeedingHero({required this.guide, required this.cartonUnits, required this.onTable});

  final FeedingGuide guide;
  final int cartonUnits;
  final VoidCallback onTable;

  @override
  State<_FeedingHero> createState() => _FeedingHeroState();
}

class _FeedingHeroState extends State<_FeedingHero> {
  late int _i = widget.guide.defaultIndex;

  void _pick(int i) {
    if (i == _i) return;
    HapticFeedback.selectionClick();
    setState(() => _i = i);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final g = widget.guide;
    final row = g.rows[_i];
    final lasts = g.lasts(row, widget.cartonUnits);
    final hue = StoryHue.of(context, 'feeding');
    final dark = context.isDark;
    final amount = row.cells.isNotEmpty ? row.cells.first : '';
    final mixed = row.cells.length > 1 ? row.cells[1] : null;
    final mixedLabel = g.headers.length > 2 ? g.headers[2] : null;

    return Material(
      color: hue.fill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: hue.line)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StoryDisc(icon: 'bowl', bg: hue.accent, fg: Colors.white),
                Gap.w8,
                Expanded(
                  child: Text(l.storyFeeding,
                      style: context.tt.titleSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w900)),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTable();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.storyFullTable,
                            style: context.tt.labelMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w800)),
                        Gap.w4,
                        StoryIcon('chevron', color: hue.deep, size: 14, stroke: 2.4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedSwitcher(
                duration: context.motion(Motion.enter),
                switchInCurve: Motion.decelerate,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: AlignmentDirectional.topStart,
                  children: [...previous, ?current],
                ),
                child: Column(
                  key: ValueKey(_i),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(amount,
                              style: context.tt.headlineMedium?.copyWith(
                                  color: hue.deep, fontWeight: FontWeight.w900, height: 1.15)),
                        ),
                        Gap.w8,
                        Text(l.storyPerDay,
                            style: context.tt.titleSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                      ],
                    ),
                    if (mixed != null) ...[
                      Gap.h4,
                      Text(
                        mixedLabel != null ? '$mixedLabel: $mixed' : mixed,
                        style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (g.hasChart) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(8, 12, 10, 8),
                decoration: BoxDecoration(
                  color: dark ? ZbTokens.graphiteRaised : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hue.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
                      child: Text(
                        g.headers.length > 1 ? g.headers[1] : l.storyDailyAmount,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                    ),
                    StoryFeedingChart(guide: g, selected: _i, onSelect: _pick, hue: hue),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StoryIcon('hand', color: context.cs.onSurfaceVariant, size: 13, stroke: 1.8),
                        Gap.w4,
                        Text(l.storyChartHint,
                            style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ] else
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: g.rows.length,
                  separatorBuilder: (_, _) => Gap.w6,
                  itemBuilder: (context, i) {
                    final on = i == _i;
                    return Semantics(
                      selected: on,
                      button: true,
                      child: GestureDetector(
                        onTap: () => _pick(i),
                        child: AnimatedContainer(
                          duration: context.motion(Motion.select),
                          curve: Motion.decelerate,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? hue.accent : (dark ? hue.tint : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: on ? hue.accent : hue.line),
                          ),
                          child: Text(
                            g.rows[i].label,
                            style: context.tt.labelLarge?.copyWith(
                              color: on ? Colors.white : hue.deep,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: dark ? hue.tint : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  StoryIcon(lasts == null ? 'info' : 'calendar', color: hue.accent, size: 20),
                  Gap.w10,
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: context.motion(Motion.enter),
                      child: Column(
                        key: ValueKey('${_i}_${lasts?.$1}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lasts == null
                                ? l.storyFeedingNote
                                : (lasts.$2
                                    ? l.storyCartonLasts(widget.cartonUnits, lasts.$1)
                                    : l.storyPackLasts(lasts.$1)),
                            style: context.tt.bodySmall?.copyWith(
                              color: lasts == null ? context.cs.onSurfaceVariant : hue.deep,
                              fontWeight: lasts == null ? FontWeight.w500 : FontWeight.w800,
                              height: 1.4,
                            ),
                          ),
                          if (lasts != null) ...[
                            const SizedBox(height: 6),
                            StoryPawDays(days: lasts.$1, color: hue.accent),
                          ],
                        ],
                      ),
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

/// «عن المنتج» as an editorial card: a coral quote mark, the opening lines,
/// and a quiet «اقرأ المزيد» that unfolds the rest in place.
class _OverviewCard extends StatefulWidget {
  const _OverviewCard({required this.section});

  final StorySection section;

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    final paras = widget.section.paragraphs.map((p) => p.text).where((t) => t.isNotEmpty).toList();
    if (paras.isEmpty) return const SizedBox.shrink();
    final text = paras.join('\n\n');
    final hue = StoryHue.of(context, 'overview');
    final style = context.tt.bodyLarge?.copyWith(height: 1.8, color: context.cs.onSurface);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: dark ? ZbTokens.graphiteRaised : ZbTokens.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dark ? ZbTokens.lineDark : ZbTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StoryDisc(icon: 'quote', bg: hue.tint, fg: hue.accent),
              Gap.w8,
              Text(l.storyOverview, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: context.motion(Motion.page),
            curve: Motion.emphasized,
            alignment: AlignmentDirectional.topStart,
            child: Text(
              text,
              maxLines: _open ? null : 4,
              overflow: _open ? TextOverflow.visible : TextOverflow.fade,
              style: style,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _open = !_open);
              },
              style: TextButton.styleFrom(
                foregroundColor: hue.deep,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                minimumSize: const Size(0, 44),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_open ? l.storyReadLess : l.storyReadMore,
                      style: context.tt.labelLarge?.copyWith(color: hue.deep, fontWeight: FontWeight.w800)),
                  Gap.w4,
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: context.motion(Motion.select),
                    child: StoryIcon('down', color: hue.deep, size: 18, stroke: 2.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Zooboxi seal that closes the guide: the whole logo — never a piece of
/// it — between two stitched lines, and one warm line under it.
class _Seal extends StatelessWidget {
  const _Seal();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    final stitch = dark ? ZbTokens.lineDark : ZbTokens.storyKraftLine;
    Widget line() => Expanded(
          child: CustomPaint(size: const Size.fromHeight(2), painter: _Stitch(stitch)),
        );
    return Semantics(
      label: '${l.storySignoff} — ${l.storySignoffSub}',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              line(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Image.asset('assets/brand/logo_full.png', height: 74, filterQuality: FilterQuality.medium),
              ),
              line(),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.storySignoff,
              textAlign: TextAlign.center,
              style: context.tt.titleSmall?.copyWith(
                  color: dark ? ZbTokens.inkDark : ZbTokens.inkWarm, fontWeight: FontWeight.w900)),
          Text(l.storySignoffSub,
              textAlign: TextAlign.center,
              style: context.tt.bodySmall?.copyWith(color: dark ? ZbTokens.coralOnDark : ZbTokens.coral,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Stitch extends CustomPainter {
  const _Stitch(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(_Stitch old) => old.color != color;
}
