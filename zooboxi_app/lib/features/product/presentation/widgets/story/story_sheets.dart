import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/zb_colors.dart';
import '../../../../../app/theme/zooboxi_tokens.dart';
import '../../../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../catalog/data/product_story.dart';
import 'story_style.dart';

/// Opens one story section in a sheet — the tile's promise, in full.
Future<void> showStorySheet(
  BuildContext context, {
  required ProductStory story,
  required StorySection section,
  int cartonUnits = 0,
}) {
  final l = L.of(context);
  final hue = StoryHue.of(context, section.key);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.isDark ? ZbTokens.graphiteRaised : ZbTokens.paper,
    builder: (sheetContext) => BottomSheetScaffold(
      title: storyTitle(l, section),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: StoryDisc(icon: storyIconFor(section.key), bg: hue.accent, fg: Colors.white, size: 40),
      ),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: StorySectionBody(story: story, section: section, cartonUnits: cartonUnits),
    ),
  );
}

/// The full content of a section, drawn for what it is: a calculator, a
/// donut and ranked list, bars, cards, numbered steps or a spec sheet.
class StorySectionBody extends StatelessWidget {
  const StorySectionBody({super.key, required this.story, required this.section, this.cartonUnits = 0});

  final ProductStory story;
  final StorySection section;
  final int cartonUnits;

  @override
  Widget build(BuildContext context) {
    final children = switch (section.key) {
      'feeding' => _feeding(context),
      'ingredients' => _ingredients(context),
      'analysis' => _analysis(context),
      'overview' => _overview(context),
      'features' => [_Features(items: section.items), ..._blocks(context, skipLists: true)],
      'breeds' => _cards(context, section.items, StoryHue.of(context, 'breeds')),
      'usage' => [_Steps(items: section.items), ..._blocks(context, skipLists: true)],
      'safety' || 'storage' => [_Notes(section: section), ..._blocks(context, skipLists: true)],
      'specs' || 'contents' => [
          if (section.tableRows.isNotEmpty) _SpecSheet(rows: section.tableRows),
          ..._blocks(context, skipTables: true),
        ],
      _ => _blocks(context),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Gap.h16,
          children[i],
        ],
      ],
    );
  }

  List<Widget> _feeding(BuildContext context) {
    final f = story.feeding;
    if (f == null) return _blocks(context);
    return [
      FeedingCalculator(guide: f, cartonUnits: cartonUnits),
      _Table(headers: f.headers, rows: [for (final r in f.rows) [r.label, ...r.cells]]),
      ..._blocks(context, skipTables: true),
      // The copy often carries its own «ملاحظة»; ours only fills the gap.
      if (section.paragraphs.isEmpty)
        Text(L.of(context).storyFeedingNote,
            style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
    ];
  }

  List<Widget> _ingredients(BuildContext context) {
    final l = L.of(context);
    final c = story.composition;
    final analysis = story.section('analysis');
    return [
      if (c != null && c.hasChart)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.isDark ? ZbTokens.lineDark : ZbTokens.line),
          ),
          child: Row(
            children: [
              StoryDonut(composition: c, size: 150),
              Gap.w16,
              Expanded(child: StoryLegend(composition: c)),
            ],
          ),
        ),
      if (c != null && c.items.isNotEmpty) ...[
        Text(l.storyIngredientsInOrder, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        _Ingredients(items: c.items),
      ] else
        ..._blocks(context),
      // Chewy and Zooplus read ingredients and analysis together: one sheet.
      if (analysis != null && analysis.percentRows.isNotEmpty) _AnalysisCard(section: analysis),
    ];
  }

  List<Widget> _analysis(BuildContext context) => [
        if (section.percentRows.isNotEmpty) _AnalysisCard(section: section, titled: false),
        ..._blocks(context, skipTables: section.percentRows.isNotEmpty),
      ];

  List<Widget> _overview(BuildContext context) {
    final features = story.section('features');
    return [
      ..._blocks(context),
      if (features != null && features.items.isNotEmpty) ...[
        Text(L.of(context).storyFeatures, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        _Features(items: features.items),
      ],
    ];
  }

  List<Widget> _cards(BuildContext context, List<StoryListItem> items, StoryHue hue) => [
        for (final b in section.blocks.whereType<StoryList>())
          if (b.lead.isNotEmpty) _Para(b.lead),
        for (final it in items)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: hue.tint, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (it.title.isNotEmpty)
                  Text(it.title, style: context.tt.titleSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w900)),
                if (it.text.isNotEmpty) ...[
                  if (it.title.isNotEmpty) Gap.h4,
                  Text(it.text, style: context.tt.bodyMedium?.copyWith(height: 1.65)),
                ],
              ],
            ),
          ),
        ..._blocks(context, skipLists: true),
      ];

  /// Whatever else the section holds, in order.
  List<Widget> _blocks(BuildContext context, {bool skipLists = false, bool skipTables = false}) {
    final out = <Widget>[];
    for (final b in section.blocks) {
      switch (b) {
        case StoryParagraph(:final text):
          out.add(_Para(text));
        case StoryList(:final items, :final ordered, :final lead) when !skipLists:
          if (lead.isNotEmpty) out.add(_Para(lead));
          out.add(ordered ? _Steps(items: items) : _Bullets(items: items));
        case StoryTable(:final headers, :final rows) when !skipTables:
          out.add(_Table(headers: headers, rows: rows));
        default:
      }
    }
    return out;
  }
}

/// «كم أقدّم؟» — pick a weight, read the day's amount and how long a carton
/// (or a pack) lasts at it.
class FeedingCalculator extends StatefulWidget {
  const FeedingCalculator({super.key, required this.guide, this.cartonUnits = 0});

  final FeedingGuide guide;
  final int cartonUnits;

  @override
  State<FeedingCalculator> createState() => _FeedingCalculatorState();
}

class _FeedingCalculatorState extends State<FeedingCalculator> {
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
    final headers = g.headers;
    final hue = StoryHue.of(context, 'feeding');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(headers.isNotEmpty ? headers.first : l.storyPetWeight,
            style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
        Gap.h8,
        if (g.hasChart)
          StoryFeedingChart(guide: g, selected: _i, onSelect: _pick, hue: hue, plotHeight: 130)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < g.rows.length; i++)
                ChoiceChip(
                  label: Text(g.rows[i].label),
                  selected: i == _i,
                  showCheckmark: false,
                  labelStyle: context.tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: i == _i ? Colors.white : hue.deep,
                  ),
                  selectedColor: hue.accent,
                  shape: StadiumBorder(side: BorderSide(color: hue.line)),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => _pick(i),
                ),
            ],
          ),
        Gap.h12,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: ValueKey(_i),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hue.fill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hue.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headers.length > 1 ? headers[1] : l.storyDailyAmount,
                    style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant)),
                Gap.h4,
                Text(row.cells.isNotEmpty ? row.cells.first : '',
                    style: context.tt.headlineSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w900)),
                for (var c = 1; c < row.cells.length; c++) ...[
                  Gap.h4,
                  Text(
                    headers.length > c + 1 ? '${headers[c + 1]}: ${row.cells[c]}' : row.cells[c],
                    style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
                  ),
                ],
                if (lasts != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: hue.line),
                  ),
                  Text(
                    lasts.$2 ? l.storyCartonLasts(widget.cartonUnits, lasts.$1) : l.storyPackLasts(lasts.$1),
                    style: context.tt.bodyMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  StoryPawDays(days: lasts.$1, color: hue.accent),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.section, this.titled = true});

  final StorySection section;
  final bool titled;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hue = StoryHue.of(context, 'analysis');
    final n = StoryNutrition.from(section.percentRows);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hue.fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hue.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titled || n != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(titled ? l.storyAnalysis : l.storyPer100g,
                      style: context.tt.titleSmall?.copyWith(color: hue.deep, fontWeight: FontWeight.w900)),
                ),
                if (titled && n != null)
                  Text(l.storyPer100g, style: context.tt.labelMedium?.copyWith(color: hue.deep)),
              ],
            ),
            Gap.h12,
          ],
          if (n != null) ...[
            StoryNutritionBar(data: n),
            Gap.h16,
            _DryMatterTable(rows: section.percentRows, nutrition: n, hue: hue),
          ] else
            StoryBars(
              rows: section.percentRows,
              ink: context.cs.onSurface,
              track: hue.line,
              fill: hue.accent,
            ),
        ],
      ),
    );
  }
}

/// Every nutrient as written on the pack, beside the same share with the
/// water taken out — the column vets use to compare foods.
class _DryMatterTable extends StatelessWidget {
  const _DryMatterTable({required this.rows, required this.nutrition, required this.hue});

  final List<(String, double)> rows;
  final StoryNutrition nutrition;
  final StoryHue hue;

  static final _water = RegExp(r'رطوبة|moisture', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final head = context.tt.labelMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w800);
    final shown = rows.where((r) => !_water.hasMatch(r.$1)).toList();
    Widget cell(String t, TextStyle? st, {TextAlign align = TextAlign.center}) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text(t, style: st, textAlign: align));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
          border: TableBorder(horizontalInside: BorderSide(color: hue.line)),
          children: [
            TableRow(children: [
              cell('', head, align: TextAlign.start),
              cell(l.storyPer100g, head),
              cell(l.storyDryMatter, head),
            ]),
            for (final r in shown)
              TableRow(children: [
                cell(StoryNutrition.clean(r.$1), context.tt.bodyMedium, align: TextAlign.start),
                cell('${storyNum(r.$2)}%', context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                cell('${storyNum((nutrition.dry(r.$2) * 10).roundToDouble() / 10)}%',
                    context.tt.bodyMedium?.copyWith(color: hue.deep, fontWeight: FontWeight.w900)),
              ]),
          ],
        ),
        Gap.h8,
        Text(l.storyDryMatterHint, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
      ],
    );
  }
}

class _Ingredients extends StatelessWidget {
  const _Ingredients({required this.items});

  final List<StoryIngredient> items;

  @override
  Widget build(BuildContext context) {
    final line = context.isDark ? ZbTokens.lineDark : ZbTokens.line;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: i == 0 ? null : Border(top: BorderSide(color: line)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.center,
                    style: context.tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: i < 2 ? ZbTokens.coral : context.cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Gap.w10,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].name,
                          style: context.tt.bodyLarge?.copyWith(fontWeight: i < 2 ? FontWeight.w800 : FontWeight.w500)),
                      if (items[i].detail.isNotEmpty)
                        Text(items[i].detail,
                            style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (items[i].pct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: i < 2
                          ? (context.isDark ? ZbTokens.coralContainerDark : const Color(0xFFFBE3DF))
                          : (context.isDark ? ZbTokens.graphiteHigh : const Color(0xFFF1F4F3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${storyNum(items[i].pct!)}%',
                      style: context.tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: i < 2
                            ? (context.isDark ? ZbTokens.coralOnDark : const Color(0xFF8E2A1F))
                            : context.cs.onSurfaceVariant,
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

class _Features extends StatelessWidget {
  const _Features({required this.items});

  final List<StoryListItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = storyChipColors(context);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            margin: EdgeInsets.only(top: i == 0 ? 0 : 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.isDark ? ZbTokens.graphiteHigh : const Color(0xFFF6F9F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const StoryIcon('check', color: Colors.white, size: 14, stroke: 2.6),
                ),
                Gap.w10,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items[i].title.isNotEmpty)
                        Text(items[i].title, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      if (items[i].text.isNotEmpty)
                        Text(items[i].text, style: context.tt.bodyMedium?.copyWith(height: 1.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.items});

  final List<StoryListItem> items;

  @override
  Widget build(BuildContext context) {
    final hue = StoryHue.of(context, 'usage');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: hue.accent, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: context.tt.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
                Gap.w12,
                Expanded(child: _ItemText(item: items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.section});

  final StorySection section;

  @override
  Widget build(BuildContext context) {
    final hue = StoryHue.of(context, section.key);
    final icon = section.key == 'safety' ? 'shield' : 'snow';
    return Column(
      children: [
        for (var i = 0; i < section.items.length; i++)
          Container(
            margin: EdgeInsets.only(top: i == 0 ? 0 : 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: hue.tint, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: StoryIcon(icon, color: hue.deep, size: 18),
                ),
                Gap.w10,
                Expanded(child: _ItemText(item: section.items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});

  final List<StoryListItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: context.cs.primary, shape: BoxShape.circle),
                  ),
                ),
                Gap.w10,
                Expanded(child: _ItemText(item: it)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemText extends StatelessWidget {
  const _ItemText({required this.item});

  final StoryListItem item;

  @override
  Widget build(BuildContext context) {
    final base = context.tt.bodyMedium?.copyWith(height: 1.65);
    if (item.title.isEmpty) return Text(item.text, style: base);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${item.title}: ', style: base?.copyWith(fontWeight: FontWeight.w800)),
          TextSpan(text: item.text),
        ],
      ),
      style: base,
    );
  }
}

class _Para extends StatelessWidget {
  const _Para(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.tt.bodyLarge?.copyWith(height: 1.8, color: context.cs.onSurface));
}

class _SpecSheet extends StatelessWidget {
  const _SpecSheet({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final line = dark ? ZbTokens.lineDark : ZbTokens.line;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: i.isOdd ? (dark ? ZbTokens.graphiteHigh : const Color(0xFFFAFCFB)) : null,
                border: i == 0 ? null : Border(top: BorderSide(color: line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(rows[i].first,
                        style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
                  ),
                  Gap.w12,
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].skip(1).join(' · '),
                      textAlign: TextAlign.end,
                      style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A plain table, horizontally scrollable when it has many columns.
class _Table extends StatelessWidget {
  const _Table({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final dark = context.isDark;
    final line = dark ? ZbTokens.lineDark : ZbTokens.line;
    final cols = [headers.length, ...rows.map((r) => r.length)].reduce((a, b) => a > b ? a : b);

    Widget cell(String t, {bool head = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            t,
            style: (head ? context.tt.labelLarge : context.tt.bodyMedium)
                ?.copyWith(fontWeight: head ? FontWeight.w800 : null, height: 1.45),
          ),
        );

    final table = Table(
      defaultColumnWidth: cols > 3 ? const IntrinsicColumnWidth() : const FlexColumnWidth(),
      border: TableBorder(horizontalInside: BorderSide(color: line)),
      children: [
        if (headers.isNotEmpty)
          TableRow(
            decoration: BoxDecoration(color: dark ? ZbTokens.graphiteHigh : const Color(0xFFF1F6F5)),
            children: [for (var c = 0; c < cols; c++) cell(c < headers.length ? headers[c] : '', head: true)],
          ),
        for (final r in rows)
          TableRow(children: [for (var c = 0; c < cols; c++) cell(c < r.length ? r[c] : '')]),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
      child: cols > 3 ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table) : table,
    );
  }
}
