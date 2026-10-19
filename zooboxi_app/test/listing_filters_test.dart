import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/pet_fit.dart';

/// «فهرس الفلاتر» on the app side: the query speaks the index's language,
/// a deep link keeps the picks, and a pet's birth date picks its age.
void main() {
  group('ListingQuery', () {
    test('asks for the facet index and sends picks as f_<facet>, values sorted', () {
      const q = ListingQuery(category: 'wet', filters: {
        'flavor': {'tuna', 'chicken'},
        'life': {'young'},
      }, minPrice: 5, orderBy: 'price');
      final p = q.toQueryParameters(2);
      expect(p['fv'], 2);
      expect(p['f_flavor'], 'chicken,tuna');
      expect(p['f_life'], 'young');
      expect(p['min_price'], 5);
      expect(p['orderby'], 'price');
      expect(p['page'], 2);
      expect(p.keys.where((k) => k.startsWith('pa_')), isEmpty);
    });

    test('a deep link restores picks, price and sort', () {
      final q = ListingQuery.fromJson({
        'category': 'wet',
        'f_flavor': 'chicken, tuna',
        'f_life': 'young',
        'min_price': '5',
        'max_price': '30',
        'orderby': 'value',
      });
      expect(q.filters, {'flavor': {'chicken', 'tuna'}, 'life': {'young'}});
      expect(q.minPrice, 5);
      expect(q.maxPrice, 30);
      expect(q.orderBy, 'value');
      expect(q.activeFilterCount, 4);
    });

    test('toggling adds, removes and drops an emptied facet', () {
      var q = const ListingQuery(category: 'wet');
      q = q.toggled('flavor', 'duck');
      expect(q.isSelected('flavor', 'duck'), isTrue);
      q = q.toggled('flavor', 'duck');
      expect(q.filters.containsKey('flavor'), isFalse);
      q = q.withGroup('life', {'adult'}).withGroup('life', const {});
      expect(q.hasFilters, isFalse);
    });

    test('value equality ignores the order values were picked in', () {
      const a = ListingQuery(filters: {'flavor': {'a', 'b'}});
      const b = ListingQuery(filters: {'flavor': {'b', 'a'}});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.toggled('flavor', 'c'), isFalse);
    });

    test('cleared keeps the scope and the sort', () {
      const q = ListingQuery(category: 'wet', q: 'تونة', filters: {'life': {'young'}}, maxPrice: 9, orderBy: 'popularity');
      final c = q.cleared();
      expect(c.category, 'wet');
      expect(c.q, 'تونة');
      expect(c.orderBy, 'popularity');
      expect(c.hasFilters, isFalse);
    });
  });

  group('ListingFacets', () {
    test('reads the index payload', () {
      final f = ListingFacets.fromJson({
        'v': 2,
        'species': 'cat',
        'base_total': 530,
        'groups': [
          {
            'key': 'flavor',
            'label': 'النكهة',
            'icon': 'chicken',
            'values': [
              {'key': 'chicken', 'label': 'دجاج', 'count': 15, 'icon': 'chicken'},
              {'key': 'duck', 'label': 'بط', 'count': 0, 'icon': 'duck', 'note': 'غير متوفر مع قطط صغيرة'},
            ],
          },
          {'key': 'empty', 'label': 'x', 'values': []},
        ],
        'price': {
          'min': 5,
          'max': 192,
          'histogram': [
            {'from': 5, 'to': 16, 'count': 16},
          ],
          'buckets': [
            {'min': null, 'max': 10, 'label': 'أقل من 10', 'count': 15},
            {'min': 125, 'max': null, 'label': '125+', 'count': 6},
          ],
        },
        'promoted': [
          {'group': 'life', 'value': 'young', 'label': 'قطط صغيرة', 'icon': 'kitten', 'count': 29},
        ],
        'relax': [
          {'group': 'flavor', 'value': 'duck', 'label': 'بط', 'count': 29},
        ],
      });
      expect(f.species, 'cat');
      expect(f.baseTotal, 530);
      expect(f.groups.map((g) => g.key), ['flavor'], reason: 'a group with no values is dropped');
      expect(f.group('flavor')!.values.last.isEmpty, isTrue);
      expect(f.group('flavor')!.values.last.note, 'غير متوفر مع قطط صغيرة');
      expect(f.group('flavor')!.labelOf('chicken'), 'دجاج');
      expect(f.price!.buckets.first.min, isNull);
      expect(f.price!.buckets.last.max, isNull);
      expect(f.promoted.single.value, 'young');
      expect(f.relax.single.count, 29);
    });

    test('still reads the old taxonomy shape', () {
      final f = ListingFacets.fromJson({
        'groups': [
          {
            'taxonomy': 'pa_flavor',
            'label': 'النكهة',
            'terms': [
              {'slug': 'chicken', 'name': 'دجاج', 'count': 340},
            ],
          },
        ],
        'price': {'min': 1, 'max': 3910},
      });
      expect(f.group('pa_flavor')!.values.single.label, 'دجاج');
      expect(f.price!.isUsable, isTrue);
    });
  });

  group('lifeStageFor', () {
    final now = DateTime(2026, 9, 24);
    test('under a year is young', () => expect(lifeStageFor(DateTime(2026, 5, 1), now: now), 'young'));
    test('the first birthday makes an adult', () => expect(lifeStageFor(DateTime(2025, 9, 24), now: now), 'adult'));
    test('one day short of a year is still young', () => expect(lifeStageFor(DateTime(2025, 9, 25), now: now), 'young'));
    test('seven years is senior', () => expect(lifeStageFor(DateTime(2019, 9, 1), now: now), 'senior'));
    test('no birth date, no guess', () => expect(lifeStageFor(null, now: now), isNull));
    test('a future date is ignored', () => expect(lifeStageFor(DateTime(2027, 1, 1), now: now), isNull));
  });
}
