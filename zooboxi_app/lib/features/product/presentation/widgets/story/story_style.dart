import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/characters/characters.dart';
import '../../../../../core/motion/motion.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_story.dart';

/// Colour, icon and title of one story section — the same identity on the
/// tile, its sheet and the web page. Round 3: every section is a light wash
/// of a Zooboxi logo colour, never a saturated block.
@immutable
class StoryHue {
  const StoryHue({
    required this.fill,
    required this.ink,
    required this.tint,
    required this.deep,
    required this.accent,
    required this.line,
  });

  /// Tile background — a light wash.
  final Color fill;

  /// Body text on the tile.
  final Color ink;

  /// A second, softer wash for cards inside the sheet.
  final Color tint;

  /// The deep shade: titles, numbers and links in the section's colour.
  final Color deep;

  /// The solid colour: the badge disc, a selected bar, a chart mark.
  final Color accent;

  /// Hairline border.
  final Color line;

  /// Kept for the sheets: no section is a dark block any more.
  bool get isDark => false;

  static StoryHue of(BuildContext context, String key) {
    final dark = context.isDark;
    StoryHue wash(Color fill, Color line, Color accent, Color deep, {Color? accentDark}) => dark
        ? StoryHue(
            fill: Color.alphaBlend((accentDark ?? accent).withValues(alpha: 0.10), ZbTokens.graphiteRaised),
            ink: ZbTokens.inkDark,
            tint: Color.alphaBlend((accentDark ?? accent).withValues(alpha: 0.18), ZbTokens.graphiteRaised),
            deep: accentDark ?? accent,
            accent: accentDark ?? accent,
            line: Color.alphaBlend((accentDark ?? accent).withValues(alpha: 0.22), ZbTokens.graphiteRaised),
          )
        : StoryHue(fill: fill, ink: ZbTokens.ink, tint: Color.alphaBlend(accent.withValues(alpha: 0.12), Colors.white), deep: deep, accent: accent, line: line);

    return switch (key) {
      'feeding' || 'storage' => wash(ZbTokens.storyTealWash, ZbTokens.storyTealLine, ZbTokens.storyTeal, ZbTokens.tealDeep,
          accentDark: ZbTokens.tealOnDark),
      'analysis' || 'contents' => wash(ZbTokens.storyKraftWash, ZbTokens.storyKraftLine, ZbTokens.orange, ZbTokens.storyKraftDeep,
          accentDark: const Color(0xFFE7A56B)),
      'breeds' => wash(ZbTokens.storyMintWash, ZbTokens.storyMintLine, ZbTokens.storyMint, ZbTokens.storyMintDeep,
          accentDark: ZbTokens.successOnDark),
      'usage' => wash(ZbTokens.storyAmberWash, ZbTokens.storyAmberLine, ZbTokens.sliceGold, ZbTokens.amberDeep,
          accentDark: ZbTokens.amberOnDark),
      'safety' || 'overview' || 'ingredients' => wash(ZbTokens.storyCoralWash, ZbTokens.storyCoralLine, ZbTokens.coral,
          ZbTokens.coralDark, accentDark: ZbTokens.coralOnDark),
      _ => wash(ZbTokens.storyTealWash, ZbTokens.storyTealLine, ZbTokens.storyTeal, ZbTokens.tealDeep,
          accentDark: ZbTokens.tealOnDark),
    };
  }
}

/// The logo's colours, in the order the benefit pills and fact icons take
/// them: teal, coral, orange, mint.
List<Color> storyChipColors(BuildContext context) => context.isDark
    ? const [ZbTokens.tealOnDark, ZbTokens.coralOnDark, Color(0xFFE7A56B), ZbTokens.successOnDark]
    : const [ZbTokens.storyTeal, ZbTokens.coral, ZbTokens.orange, ZbTokens.storyMint];

/// The drawn character for a product's species: cat and dog carry every
/// pose; the other animals were drawn once.
ZbCast? storyCast(String? species) => switch (species) {
      'cat' => ZbCast.cat,
      'dog' => ZbCast.dog,
      'bird' => ZbCast.budgie,
      'fish' => ZbCast.fish,
      'small' => ZbCast.hamster,
      'reptile' => ZbCast.turtle,
      _ => null,
    };

String storyTitle(L l, StorySection s) => switch (s.key) {
      'overview' => l.storyOverview,
      'features' => l.storyFeatures,
      'feeding' => l.storyFeeding,
      'ingredients' => l.storyIngredients,
      'analysis' => l.storyAnalysis,
      'specs' => l.storySpecs,
      'contents' => l.storyContents,
      'breeds' => l.storyBreeds,
      'usage' => l.storyUsage,
      'storage' => l.storyStorage,
      'safety' => l.storySafety,
      _ => s.title.isNotEmpty ? s.title : l.storyOther,
    };

String storyIconFor(String key) => switch (key) {
      'overview' => 'info',
      'features' => 'sparkle',
      'feeding' => 'bowl',
      'ingredients' => 'leaf',
      'analysis' => 'chart',
      'specs' || 'dimensions' => 'ruler',
      'contents' || 'material' || 'form' => 'box',
      'breeds' || 'species' => 'paw',
      'usage' => 'steps',
      'storage' => 'snow',
      'safety' => 'shield',
      'weight' || 'size' => 'scale',
      'color' => 'drop',
      'origin' => 'pin',
      'protein' => 'chart',
      _ => 'info',
    };

/// Stroke icons shared with the web page (24×24, round caps).
const _paths = <String, String>{
  'info': '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5h.01"/>',
  'sparkle': '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
  'bowl': '<path d="M3 11h18a9 9 0 0 1-18 0zM8 7c0-1 1-1 1-2M12 7c0-1 1-1 1-2M16 7c0-1 1-1 1-2"/>',
  'leaf': '<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14zM5 19l7-7"/>',
  'chart': '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  'ruler': '<path d="M3 17L17 3l4 4L7 21z"/><path d="M7 13l2 2M10 10l2 2M13 7l2 2"/>',
  'box': '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M12 12l8-4.5M12 12v9M12 12L4 7.5"/>',
  'paw': '<circle cx="7" cy="9" r="1.8"/><circle cx="12" cy="6.5" r="1.8"/><circle cx="17" cy="9" r="1.8"/><path d="M7.5 17c0-3 2-5.5 4.5-5.5s4.5 2.5 4.5 5.5c0 1.6-1.4 2.5-2.8 2.1-1.2-.4-2.2-.4-3.4 0C8.9 19.5 7.5 18.6 7.5 17z"/>',
  'steps': '<path d="M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01"/>',
  'snow': '<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"/>',
  'shield': '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M12 8v5M12 16h.01"/>',
  'scale': '<path d="M5 7h14l-2 12H7zM9 7a3 3 0 0 1 6 0"/>',
  'drop': '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>',
  'pin': '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  'check': '<path d="M5 12l4 4 10-10"/>',
  'chevron': '<path d="M9 5l7 7-7 7"/>',
  'down': '<path d="M6 9l6 6 6-6"/>',
  'drumstick': '<path d="M15.5 4.5a4.5 4.5 0 0 1 4 6.6c-1.2 2.2-4 3.4-6.4 2.6L9 17.8a2 2 0 1 1-2.8-2.8l4.1-4.1c-.8-2.4.4-5.2 2.6-6.4a4.5 4.5 0 0 1 2.6-.5z"/>',
  'tooth': '<path d="M7 3c-2.5 0-4 2-4 4.5 0 3 1.5 4.5 2 7.5.4 2.5.8 6 2.5 6s1.8-4 2.5-6c.3-.8 1.7-.8 2 0 .7 2 .8 6 2.5 6s2.1-3.5 2.5-6c.5-3 2-4.5 2-7.5C21 5 19.5 3 17 3c-2 0-3 1-5 1S9 3 7 3z"/>',
  'bone': '<path d="M8.6 15.4l6.8-6.8"/><circle cx="6.2" cy="15.6" r="2.1"/><circle cx="8.4" cy="17.8" r="2.1"/><circle cx="15.6" cy="6.2" r="2.1"/><circle cx="17.8" cy="8.4" r="2.1"/>',
  'bolt': '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
  'heart': '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
  'grain': '<path d="M12 21V9M12 9c-3-1-4-4-4-6 3 0 4 3 4 6zM12 9c3-1 4-4 4-6-3 0-4 3-4 6zM12 14c-3-1-4-3-4-5 3 0 4 2 4 5zM12 14c3-1 4-3 4-5-3 0-4 2-4 5z"/><path d="M4 4l16 16"/>',
  'kidney': '<path d="M9 4c-3 0-5 3-5 7s2 9 6 9c2 0 3-2 2-4s-2-3 0-5 2-4 1-6-2-1-4-1z"/><path d="M15 7c2 0 5 2 5 6s-2 7-5 7"/>',
  'fur': '<path d="M4 18c2-6 5-10 8-12M9 20c1-5 4-9 7-11M14 20c1-3 3-6 6-8"/>',
  'hand': '<path d="M12 21c-4 0-6-3-6-6V9a1.5 1.5 0 0 1 3 0v3M9 11V5a1.5 1.5 0 0 1 3 0v6M12 10V4.5a1.5 1.5 0 0 1 3 0V11M15 10V6.5a1.5 1.5 0 0 1 3 0V15c0 3-2 6-6 6"/>',
  'pen': '<path d="M4 20l4-1 11-11-3-3L5 16zM14 6l3 3"/>',
  'calendar': '<rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/>',
  'quote': '<path d="M10 7c-3 1-5 3.5-5 7v3h5v-5H7.5c0-2 1-3.2 2.5-3.8zM19 7c-3 1-5 3.5-5 7v3h5v-5h-2.5c0-2 1-3.2 2.5-3.8z"/>',
  'arrow': '<path d="M5 12h14M13 6l6 6-6 6"/>',
  'stomach': '<path d="M9 3v4c0 2-3 2.5-3 6a6 6 0 0 0 6 6c3.5 0 7-2 7-6 0-3-2-4.5-4-4.5-1.5 0-2 1-3 1s-1-1-1-2.5V3"/>',
};

/// A meaningful glyph for a highlight, read from its words — protein gets a
/// drumstick, omega a drop, teeth a tooth — instead of the same tick on every
/// chip. Falls back to a sparkle.
String storyBenefitIcon(String title) {
  final t = title.toLowerCase();
  const map = <(String, String)>[
    ('حبوب|grain|gluten|غلوتين', 'grain'),
    ('بروتين|protein|لحم|meat', 'drumstick'),
    ('أوميغا|اوميغا|omega|ترطيب|hydrat|رطوبة|ماء|water', 'drop'),
    ('مسالك|بول|كلى|urinary|kidney', 'kidney'),
    ('شعر|فراء|فرو|جلد|coat|fur|hair|skin', 'fur'),
    ('هضم|معدة|أمعاء|digest|gut|probiotic', 'stomach'),
    ('أسنان|اسنان|فم|لثة|teeth|dental|tooth|breath', 'tooth'),
    ('مفاصل|عظام|joint|bone', 'bone'),
    ('مناعة|فيتامين|أكسدة|اكسدة|immun|vitamin|antioxid|صحة|health', 'shield'),
    ('طاقة|نشاط|حيوية|energy|active|vital', 'bolt'),
    ('طبيعي|طبيعية|natural|organic|عضوي', 'leaf'),
    ('وزن|weight|سعرات|calorie', 'scale'),
    ('مذاق|طعم|لذيذ|نكهة|taste|flavor|palat|تحب', 'heart'),
    ('يدوي|يدويًا|حرفية|hand|craft', 'hand'),
    ('نقش|engrav|تخصيص|personal', 'pen'),
    ('متين|متانة|قوي|آمن|امن|سلامة|durab|strong|safe', 'shield'),
    ('خصوبة|أجنة|اجنة|تكاثر|fertil|breed', 'heart'),
  ];
  for (final (words, icon) in map) {
    if (RegExp(words).hasMatch(t)) return icon;
  }
  return 'sparkle';
}

class StoryIcon extends StatelessWidget {
  const StoryIcon(this.name, {super.key, required this.color, this.size = 20, this.stroke = 2});

  final String name;
  final Color color;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final body = _paths[name] ?? _paths['info']!;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
      'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$body</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      // The chevron points "forward": flip it in RTL so it always leads on.
      matchTextDirection: name == 'chevron',
      excludeFromSemantics: true,
    );
  }
}

/// A round disc with an icon — the section's badge on tiles and sheets.
class StoryDisc extends StatelessWidget {
  const StoryDisc({super.key, required this.icon, required this.bg, required this.fg, this.size = 30});

  final String icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: StoryIcon(icon, color: fg, size: size * 0.55),
      );
}

/// «35.0» → «35», «0.20» → «0.2».
String storyNum(double v) {
  final s = v.toStringAsFixed(2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// «80%» isolated left-to-right, so inside an Arabic sentence the sign stays
/// after the number instead of jumping in front of it («%80»).
String storyPct(double v) => '\u2066${storyNum(v)}%\u2069';

Color _sliceColor(StorySlice s, int i, {bool dark = false}) {
  if (s.rest) return dark ? ZbTokens.sliceRestDark : ZbTokens.sliceRest;
  return const [ZbTokens.sliceRed, ZbTokens.sliceGold, ZbTokens.sliceTeal][math.min(i, 2)];
}

/// The ingredient donut: named shares plus the rest, with a centre line
/// («70% مصادر حيوانية»). Identity is never colour alone — the legend beside
/// it names every slice and its share.
class StoryDonut extends StatelessWidget {
  const StoryDonut({super.key, required this.composition, this.size = 118});

  final StoryComposition composition;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = composition.slices.map((s) => '${s.name} ${storyNum(s.pct)}%').join('، ');
    return Semantics(
      label: label,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The ring draws itself in, once, the first time it is built.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                size: Size.square(size),
                painter: _DonutPainter(
                  slices: composition.slices,
                  progress: t,
                  gapColor: context.isDark ? ZbTokens.graphiteRaised : ZbTokens.paper,
                  track: context.isDark ? ZbTokens.graphiteHigh : const Color(0xFFF1F3F2),
                  dark: context.isDark,
                ),
              ),
            ),
            if (composition.centerValue != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      composition.centerValue!,
                      style: context.tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: size * 0.19,
                        height: 1.1,
                      ),
                    ),
                    if ((composition.centerLabel ?? '').isNotEmpty)
                      Text(
                        composition.centerLabel!,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                          fontSize: math.max(9, size * 0.08),
                          height: 1.15,
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

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.gapColor, required this.track, this.progress = 1, this.dark = false});

  final List<StorySlice> slices;
  final bool dark;
  final double progress;
  final Color gapColor;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.15;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);

    final total = slices.fold<double>(0, (a, s) => a + s.pct);
    if (total <= 0) return;
    const gap = 0.045; // radians of surface between segments
    var start = -math.pi / 2;
    final limit = -math.pi / 2 + math.pi * 2 * progress;
    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].pct / total * math.pi * 2;
      if (start >= limit) break;
      final draw = math.min(math.max(0.02, sweep - gap), limit - start - gap / 2);
      if (draw <= 0) break;
      canvas.drawArc(
        arcRect,
        start + gap / 2,
        draw,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = _sliceColor(slices[i], i, dark: dark),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.gapColor != gapColor || old.progress != progress;
}

/// The donut's legend: swatch, name, share.
class StoryLegend extends StatelessWidget {
  const StoryLegend({super.key, required this.composition});

  final StoryComposition composition;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < composition.slices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _sliceColor(composition.slices[i], i, dark: context.isDark),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Gap.w8,
                Expanded(
                  child: Text(
                    composition.slices[i].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Gap.w6,
                Text(
                  '${storyNum(composition.slices[i].pct)}%',
                  style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontal nutrient bars; moisture (most of a wet food) becomes a line
/// under them so it does not flatten every other bar.
class StoryBars extends StatelessWidget {
  const StoryBars({
    super.key,
    required this.rows,
    required this.track,
    required this.fill,
    required this.ink,
    this.limit,
    this.compact = false,
  });

  final List<(String, double)> rows;
  final Color track;
  final Color fill;
  final Color ink;
  final int? limit;
  final bool compact;

  static final _moisture = RegExp(r'رطوبة|moisture', caseSensitive: false);
  static final _crude = RegExp(r'\s*(الخام|الخامة|crude)\s*', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final bars = rows.where((r) => !_moisture.hasMatch(r.$1)).toList();
    final moisture = rows.where((r) => _moisture.hasMatch(r.$1)).firstOrNull;
    final shown = limit == null ? bars : bars.take(limit!).toList();
    final max = bars.fold<double>(1, (a, r) => math.max(a, r.$2));
    final style = (compact ? context.tt.labelMedium : context.tt.bodyMedium)?.copyWith(color: ink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, v) in shown)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 7 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label.replaceAll(_crude, ' ').trim(),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                    ),
                    Text('${storyNum(v)}%', style: style?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
                SizedBox(height: compact ? 3 : 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: compact ? 6 : 8,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: track)),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: context.reduceMotion ? math.max(0.04, v / max) : 0.02, end: math.max(0.04, v / max)),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, w, _) => FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: w,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (moisture != null)
          Text('${moisture.$1} ${storyPct(moisture.$2)}',
              style: style?.copyWith(color: ink.withValues(alpha: 0.85))),
      ],
    );
  }
}


/// A big, faint section glyph bleeding off a tile's corner — the tile's
/// identity at a glance, and depth without a gradient.
class StoryWatermark extends StatelessWidget {
  const StoryWatermark({super.key, required this.icon, required this.color, this.size = 96});

  final String icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
        bottom: -size * 0.22,
        end: -size * 0.18,
        child: ExcludeSemantics(
          child: Transform.rotate(
            angle: -0.18,
            child: StoryIcon(icon, color: color, size: size, stroke: 1.6),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  Round 3 — the logo's confetti, and charts drawn from the real numbers
// ════════════════════════════════════════════════════════════════════

/// The logo's four-point sparkle, twinkling a few times after it arrives
/// and then resting — confetti that belongs to the brand, not decoration.
class StorySparkle extends StatelessWidget {
  const StorySparkle({super.key, required this.color, this.size = 14, this.delay = Duration.zero});

  final Color color;
  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final star = ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _SparklePainter(color)),
    );
    if (context.reduceMotion) return star;
    return star
        .animate(delay: delay, onPlay: (c) => c.repeat(reverse: true, count: 6))
        .scaleXY(begin: 0.55, end: 1, duration: 900.ms, curve: Curves.easeInOutSine)
        .rotate(begin: -0.04, end: 0.04, duration: 900.ms);
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2;
    final k = w * 0.12; // how deep the sides curve in
    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + k, cy - k, w, cy)
      ..quadraticBezierTo(cx + k, cy + k, cx, h)
      ..quadraticBezierTo(cx - k, cy + k, 0, cy)
      ..quadraticBezierTo(cx - k, cy - k, cx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// Round axis steps: 0.5, 1, 2, 5, 10, 20, 25, 50…
double _niceStep(double max, {int ticks = 3}) {
  if (max <= 0) return 1;
  final raw = max / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (raw <= m * mag) return m * mag;
  }
  return 10 * mag;
}

/// «2.5–3», isolated left-to-right so Arabic never flips it to «3–2.5».
String _range(FeedingRow r) => r.lo == null || r.lo == r.hi
    ? storyNum(r.hi!)
    : '\u2066${storyNum(r.lo!)}–${storyNum(r.hi!)}\u2069';

/// «كم أقدّم؟» as a real chart: one column per weight band, drawn to the
/// amount the copy gives — the solid part is the lower figure, the pale cap
/// the upper one — on a labelled axis. The weights under the columns are the
/// controls: tap one to read its amount.
class StoryFeedingChart extends StatelessWidget {
  const StoryFeedingChart({
    super.key,
    required this.guide,
    required this.selected,
    required this.onSelect,
    required this.hue,
    this.plotHeight = 112,
  });

  final FeedingGuide guide;
  final int selected;
  final ValueChanged<int> onSelect;
  final StoryHue hue;
  final double plotHeight;

  static const double _gutter = 30;

  @override
  Widget build(BuildContext context) {
    final rows = guide.rows;
    final step = _niceStep(guide.chartMax);
    final top = (guide.chartMax / step).ceil() * step;
    final ticks = [for (var v = 0.0; v <= top + 0.0001; v += step) v];
    final muted = context.isDark ? ZbTokens.inkSoftDark : ZbTokens.inkSoft;
    final grid = hue.line;
    final labelStyle = context.tt.labelSmall?.copyWith(color: muted, fontSize: 10.5, height: 1.1);
    const valueRoom = 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: plotHeight + valueRoom,
          child: Stack(
            children: [
              // Grid lines and their values, on the reading-start side.
              for (final v in ticks)
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: v / top * plotHeight - 6,
                  height: 12,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _gutter - 6,
                        child: Text(storyNum(v), style: labelStyle, textAlign: TextAlign.end),
                      ),
                      Gap.w6,
                      Expanded(
                        child: Container(height: v == 0 ? 1.4 : 1, color: v == 0 ? muted.withValues(alpha: 0.5) : grid),
                      ),
                    ],
                  ),
                ),
              Positioned.fill(
                child: Padding(
                padding: const EdgeInsetsDirectional.only(start: _gutter + 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      Expanded(
                        child: _Column(
                          row: rows[i],
                          top: top,
                          plotHeight: plotHeight,
                          on: i == selected,
                          hue: hue,
                          index: i,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: _gutter + 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rows.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: '${rows[i].label}: ${rows[i].cells.isNotEmpty ? rows[i].cells.first : _range(rows[i])}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedContainer(
                          duration: context.motion(Motion.select),
                          curve: Motion.decelerate,
                          constraints: const BoxConstraints(minHeight: 34),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == selected ? hue.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            rows[i].label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: context.tt.labelSmall?.copyWith(
                              color: i == selected ? Colors.white : hue.deep,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.row,
    required this.top,
    required this.plotHeight,
    required this.on,
    required this.hue,
    required this.index,
    required this.onTap,
  });

  final FeedingRow row;
  final double top;
  final double plotHeight;
  final bool on;
  final StoryHue hue;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hi = row.hi! / top * plotHeight;
    final lo = (row.lo ?? row.hi!) / top * plotHeight;
    final solid = on ? hue.accent : hue.accent.withValues(alpha: 0.28);
    final cap = on ? hue.accent.withValues(alpha: 0.45) : hue.accent.withValues(alpha: 0.13);

    final bar = SizedBox(
      width: 26,
      height: math.max(hi, 4),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7), bottom: Radius.circular(3)),
        child: Column(
          children: [
            if (hi - lo > 0.5) AnimatedContainer(duration: context.motion(Motion.select), height: hi - lo, color: cap),
            Expanded(child: AnimatedContainer(duration: context.motion(Motion.select), color: solid)),
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: context.motion(Motion.select),
            child: Text(
              _range(row),
              maxLines: 1,
              style: context.tt.labelMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          context.reduceMotion
              ? bar
              : bar
                  .animate(delay: context.motion(Motion.stagger * 2 * index))
                  .scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, duration: 650.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}

/// «في كل 100 جم»: the guaranteed analysis as one 100% bar — protein, fat,
/// fibre-minerals-and-the-rest, water — so a wet food's small-looking
/// protein reads for what it is. Only drawn when the numbers add up.
class StoryNutrition {
  const StoryNutrition({
    required this.protein,
    required this.fat,
    required this.water,
    required this.proteinLabel,
    required this.fatLabel,
    required this.waterLabel,
  });

  final double protein;
  final double fat;
  final double water;
  final String proteinLabel;
  final String fatLabel;
  final String waterLabel;

  double get rest => math.max(0, 100 - protein - fat - water);

  /// Share on a dry-matter basis — how vets compare a wet food with a dry one.
  double dry(double v) => water >= 100 ? 0 : v / (100 - water) * 100;

  static final _protein = RegExp(r'بروتين|protein', caseSensitive: false);
  static final _fat = RegExp(r'دهون|دهن|fat', caseSensitive: false);
  static final _water = RegExp(r'رطوبة|moisture', caseSensitive: false);
  static final _fibre = RegExp(r'ألياف|الياف|fib', caseSensitive: false);
  static final _ash = RegExp(r'رماد|ash', caseSensitive: false);
  static final _crude = RegExp(r'\s*(الخام|الخامة|crude)\s*', caseSensitive: false);

  static String clean(String label) => label.replaceAll(_crude, ' ').trim();

  static StoryNutrition? from(List<(String, double)> rows) {
    (String, double)? pick(RegExp r) => rows.where((x) => r.hasMatch(x.$1)).firstOrNull;
    final p = pick(_protein), f = pick(_fat), w = pick(_water);
    if (p == null || f == null || w == null) return null;
    final fibre = pick(_fibre)?.$2 ?? 0, ash = pick(_ash)?.$2 ?? 0;
    final sum = p.$2 + f.$2 + w.$2 + fibre + ash;
    if (sum > 100.5 || p.$2 <= 0) return null;
    return StoryNutrition(
      protein: p.$2,
      fat: f.$2,
      water: w.$2,
      proteinLabel: clean(p.$1),
      fatLabel: clean(f.$1),
      waterLabel: clean(w.$1),
    );
  }
}

class StoryNutritionBar extends StatelessWidget {
  const StoryNutritionBar({super.key, required this.data, this.height = 22, this.dense = false});

  final StoryNutrition data;
  final double height;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    final parts = <(String, double, Color)>[
      (data.proteinLabel, data.protein, ZbTokens.sliceRed),
      (data.fatLabel, data.fat, ZbTokens.sliceGold),
      (l.storyNutritionRest, data.rest, dark ? ZbTokens.sliceRestDark : ZbTokens.sliceRest),
      (data.waterLabel, data.water, ZbTokens.sliceTeal),
    ].where((p) => p.$2 > 0).toList();
    final gap = dark ? ZbTokens.graphiteRaised : Colors.white;

    final bar = Row(
      children: [
        for (var i = 0; i < parts.length; i++)
          Expanded(
            flex: math.max(1, (parts[i].$2 * 10).round()),
            child: Container(
              height: height,
              margin: EdgeInsetsDirectional.only(end: i == parts.length - 1 ? 0 : 2),
              decoration: BoxDecoration(
                color: parts[i].$3,
                borderRadius: BorderRadiusDirectional.horizontal(
                  start: Radius.circular(i == 0 ? 8 : 2),
                  end: Radius.circular(i == parts.length - 1 ? 8 : 2),
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      label: parts.map((p) => '${p.$1} ${storyNum(p.$2)}%').join('، '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: gap, borderRadius: BorderRadius.circular(9)),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => ClipRect(
                  child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: t, child: child),
                ),
                child: bar,
              ),
            ),
          ),
          SizedBox(height: dense ? 10 : 12),
          // Every segment named with its value: identity is never colour alone.
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final p in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3)),
                    ),
                    Gap.w6,
                    Text(p.$1, style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant)),
                    Gap.w4,
                    Text('${storyNum(p.$2)}%',
                        style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How long the carton lasts, counted out as days: one paw per day, popping
/// in one after another each time the weight changes.
class StoryPawDays extends StatelessWidget {
  const StoryPawDays({super.key, required this.days, required this.color});

  final int days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (days < 2 || days > 14) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Wrap(
        key: ValueKey(days),
        spacing: 3,
        runSpacing: 3,
        children: [
          for (var i = 0; i < days; i++)
            context.reduceMotion
                ? StoryIcon('paw', color: color, size: 15, stroke: 2)
                : StoryIcon('paw', color: color, size: 15, stroke: 2)
                    .animate(delay: (40 * i).ms)
                    .scaleXY(begin: 0, end: 1, duration: 260.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}
