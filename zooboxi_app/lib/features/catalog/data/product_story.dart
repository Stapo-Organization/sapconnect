import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';

/// «قصة المنتج» — the product description as typed pieces, parsed once on
/// the store (`Zooboxi_Product_Story`) from the catalogue's HTML copy. The
/// product page draws highlights, key facts, tiles and sheets from this
/// instead of stripping the HTML to one wall of text.
@immutable
class ProductStory {
  const ProductStory({
    this.highlights = const [],
    this.facts = const [],
    this.sections = const [],
    this.composition,
    this.feeding,
    this.species,
  });

  final List<StoryHighlight> highlights;
  final List<StoryFact> facts;
  final List<StorySection> sections;
  final StoryComposition? composition;
  final FeedingGuide? feeding;

  /// Who the product is for — cat, dog, bird, fish, small, reptile — from its
  /// category; the page casts the matching character. Null when unknown.
  final String? species;

  /// A story that is only an overview adds no structure; the page keeps the
  /// plain description for it.
  bool get isUseful => sections.length >= 2;

  StorySection? section(String key) {
    for (final s in sections) {
      if (s.key == key) return s;
    }
    return null;
  }

  static ProductStory? maybe(Object? json) {
    final m = asMap(json);
    if (m.isEmpty) return null;
    final story = ProductStory(
      highlights: asMapList(m['highlights']).map(StoryHighlight.fromJson).toList(),
      facts: asMapList(m['facts']).map(StoryFact.fromJson).toList(),
      sections: asMapList(m['sections']).map(StorySection.fromJson).toList(),
      composition: StoryComposition.maybe(m['composition']),
      feeding: FeedingGuide.maybe(m['feeding']),
      species: asStringOrNull(m['species']),
    );
    return story.sections.isEmpty ? null : story;
  }
}

@immutable
class StoryHighlight {
  const StoryHighlight({required this.title, this.text = ''});

  final String title;
  final String text;

  factory StoryHighlight.fromJson(Map<String, dynamic> json) =>
      StoryHighlight(title: asString(json['title']), text: asString(json['text']));
}

/// One cell of the key-facts strip. [kind] picks the icon: weight, size,
/// dimensions, material, form, color, species, origin, protein.
@immutable
class StoryFact {
  const StoryFact({required this.kind, required this.label, required this.value});

  final String kind;
  final String label;
  final String value;

  factory StoryFact.fromJson(Map<String, dynamic> json) => StoryFact(
        kind: asString(json['kind']),
        label: asString(json['label']),
        value: asString(json['value']),
      );
}

/// A headed part of the copy. [key] is one of overview, features, feeding,
/// ingredients, analysis, specs, contents, breeds, usage, storage, safety,
/// other — [title] is the heading as written, used only for `other`.
@immutable
class StorySection {
  const StorySection({required this.key, this.title = '', this.blocks = const []});

  final String key;
  final String title;
  final List<StoryBlock> blocks;

  factory StorySection.fromJson(Map<String, dynamic> json) => StorySection(
        key: asString(json['key'], fallback: 'other'),
        title: asString(json['title']),
        blocks: asMapList(json['blocks']).map(StoryBlock.fromJson).whereType<StoryBlock>().toList(),
      );

  Iterable<StoryParagraph> get paragraphs => blocks.whereType<StoryParagraph>();
  Iterable<StoryTable> get tables => blocks.whereType<StoryTable>();

  List<StoryListItem> get items => [
        for (final b in blocks.whereType<StoryList>()) ...b.items,
      ];

  List<List<String>> get tableRows => [
        for (final t in tables) ...t.rows,
      ];

  /// The first thing the section says — for a tile or a collapsed row.
  String get teaser {
    for (final b in blocks) {
      switch (b) {
        case StoryParagraph(:final text):
          return text;
        case StoryList(:final items) when items.isNotEmpty:
          return items.take(4).map((i) => i.title.isNotEmpty ? i.title : i.text).join(' · ');
        case StoryTable(:final rows) when rows.isNotEmpty:
          return rows.take(3).map((r) => r.take(2).join(' ')).join(' · ');
        default:
      }
    }
    return '';
  }

  /// Rows of an analysis table that carry a percentage: (label, value).
  List<(String, double)> get percentRows {
    final out = <(String, double)>[];
    final pct = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');
    for (final r in tableRows) {
      if (r.length < 2) continue;
      final m = pct.firstMatch(r[1]);
      if (m == null) continue;
      final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (v != null) out.add((r[0], v));
    }
    return out;
  }
}

sealed class StoryBlock {
  const StoryBlock();

  static StoryBlock? fromJson(Map<String, dynamic> json) => switch (asString(json['type'])) {
        'p' => StoryParagraph(asString(json['text'])),
        'list' => StoryList(
            ordered: asBool(json['ordered']),
            lead: asString(json['lead']),
            items: asMapList(json['items']).map(StoryListItem.fromJson).toList(),
          ),
        'table' => StoryTable(
            headers: asStringList(json['headers']),
            rows: (json['rows'] is List ? json['rows'] as List : const [])
                .map((r) => r is List ? r.map((c) => '$c').toList() : <String>[])
                .where((r) => r.isNotEmpty)
                .toList(),
          ),
        _ => null,
      };
}

class StoryParagraph extends StoryBlock {
  const StoryParagraph(this.text);
  final String text;
}

class StoryList extends StoryBlock {
  const StoryList({this.ordered = false, this.lead = '', this.items = const []});
  final bool ordered;
  final String lead;
  final List<StoryListItem> items;
}

class StoryTable extends StoryBlock {
  const StoryTable({this.headers = const [], this.rows = const []});
  final List<String> headers;
  final List<List<String>> rows;
}

@immutable
class StoryListItem {
  const StoryListItem({this.title = '', this.text = ''});

  /// The bold lead («صحة المسالك البولية»), empty for a plain item.
  final String title;
  final String text;

  factory StoryListItem.fromJson(Map<String, dynamic> json) =>
      StoryListItem(title: asString(json['title']), text: asString(json['text']));
}

/// Ingredients, in label order, plus the donut slices when the copy states
/// shares (e.g. «بط 35%، دجاج 35%») and a centre line for it.
@immutable
class StoryComposition {
  const StoryComposition({this.items = const [], this.slices = const [], this.centerValue, this.centerLabel});

  final List<StoryIngredient> items;
  final List<StorySlice> slices;
  final String? centerValue;
  final String? centerLabel;

  bool get hasChart => slices.length >= 2;

  static StoryComposition? maybe(Object? json) {
    final m = asMap(json);
    if (m.isEmpty) return null;
    final center = asMap(m['center']);
    return StoryComposition(
      items: asMapList(m['items']).map(StoryIngredient.fromJson).toList(),
      slices: asMapList(m['slices']).map(StorySlice.fromJson).toList(),
      centerValue: asStringOrNull(center['value']),
      centerLabel: asStringOrNull(center['label']),
    );
  }
}

@immutable
class StoryIngredient {
  const StoryIngredient({required this.name, this.detail = '', this.pct});

  final String name;
  final String detail;
  final double? pct;

  factory StoryIngredient.fromJson(Map<String, dynamic> json) => StoryIngredient(
        name: asString(json['name']),
        detail: asString(json['detail']),
        pct: asDoubleOrNull(json['pct']),
      );
}

@immutable
class StorySlice {
  const StorySlice({required this.name, required this.pct, this.rest = false});

  final String name;
  final double pct;

  /// «باقي المكونات» — drawn in the neutral slot, never a category hue.
  final bool rest;

  factory StorySlice.fromJson(Map<String, dynamic> json) => StorySlice(
        name: asString(json['name']),
        pct: asDouble(json['pct']),
        rest: asBool(json['rest']),
      );
}

/// The manufacturer's feeding table, keyed by pet weight.
@immutable
class FeedingGuide {
  const FeedingGuide({this.headers = const [], this.rows = const [], this.packGrams});

  final List<String> headers;
  final List<FeedingRow> rows;

  /// Pack size from the product name, for "one pack lasts N days".
  final double? packGrams;

  /// The row a first-time reader sees: the second band (a typical adult)
  /// when there is one.
  int get defaultIndex => rows.length > 1 ? 1 : 0;

  /// Every band states its amount as numbers, in one unit — enough to draw
  /// the amounts against weight as a real chart.
  bool get hasChart =>
      rows.every((r) => r.hi != null && r.hi! > 0 && r.unit != null) &&
      rows.map((r) => r.unit).toSet().length == 1;

  double get chartMax => rows.fold<double>(0, (a, r) => (r.hi ?? 0) > a ? r.hi! : a);

  static FeedingGuide? maybe(Object? json) {
    final m = asMap(json);
    if (m.isEmpty) return null;
    final rows = asMapList(m['rows']).map(FeedingRow.fromJson).toList();
    if (rows.length < 2) return null;
    return FeedingGuide(
      headers: asStringList(m['headers']),
      rows: rows,
      packGrams: asDoubleOrNull(m['pack_grams']),
    );
  }

  /// Days a carton of [cartonUnits] pieces (or one pack, for gram rows)
  /// lasts at [row]'s daily amount — null when the numbers are not there.
  /// Returns (days, isCarton).
  (int, bool)? lasts(FeedingRow row, int cartonUnits) {
    final daily = row.daily;
    if (daily == null || daily <= 0) return null;
    double? days;
    var carton = false;
    if (row.unit == 'piece' && cartonUnits > 1) {
      days = cartonUnits / daily;
      carton = true;
    } else if (row.unit == 'g' && packGrams != null && packGrams! > daily * 2) {
      days = packGrams! / daily;
    }
    if (days == null || days < 2) return null;
    return (days.round(), carton);
  }
}

@immutable
class FeedingRow {
  const FeedingRow({required this.label, this.cells = const [], this.daily, this.lo, this.hi, this.unit});

  /// The weight band as written («3-4 كجم»).
  final String label;

  /// The amounts, one per column after the weight.
  final List<String> cells;

  /// Mid-point daily amount when it is a count of packs or grams.
  final double? daily;

  /// The amount's own range («2.5 - 3 أكياس» → 2.5 and 3); equal when the
  /// copy gives one number.
  final double? lo;
  final double? hi;

  /// 'piece' | 'g' | null.
  final String? unit;

  factory FeedingRow.fromJson(Map<String, dynamic> json) => FeedingRow(
        label: asString(json['label']),
        cells: asStringList(json['cells']),
        daily: asDoubleOrNull(json['daily']),
        lo: asDoubleOrNull(json['lo']),
        hi: asDoubleOrNull(json['hi']),
        unit: asStringOrNull(json['unit']),
      );
}
