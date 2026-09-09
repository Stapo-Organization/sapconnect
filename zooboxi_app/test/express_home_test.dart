import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/core/delivery/delivery_eta.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/need_nav.dart';

/// The express home's new judgement calls, each pinned where it is decided:
/// which free-delivery line a basket measures itself against, whose needs row
/// is drawn and in what order, when the closing countdown may appear, and what
/// a suggestion knows about being bought before.

void main() {
  group('the free-delivery line', () {
    const national = FreeShipping(min: 200, remaining: 164, qualified: false);
    const express = FreeShipping(min: 79, remaining: 43, qualified: false);

    test('an express basket measures itself against its own line', () {
      const line = FreeShipping(min: 200, remaining: 164, qualified: false, express: express);
      expect(line.forShelf('express').min, 79);
      expect(line.forShelf('all').min, 200);
      expect(line.forShelf('').min, 200);
    });

    test('a store without an express line falls back to the national one', () {
      expect(national.forShelf('express').min, 200);
    });

    test('an express line switched off (0) is not a line', () {
      const line = FreeShipping(min: 200, remaining: 164, express: FreeShipping(min: 0));
      expect(line.forShelf('express').min, 200);
    });

    test('it parses the nested express block and keeps value equality', () {
      final a = FreeShipping.fromJson({
        'min': 200, 'remaining': 164, 'qualified': false,
        'express': {'min': 79, 'remaining': 43, 'qualified': false},
      });
      final b = FreeShipping.fromJson({
        'min': 200, 'remaining': 164, 'qualified': false,
        'express': {'min': 79, 'remaining': 43, 'qualified': false},
      });
      expect(a.express?.remaining, 43);
      expect(a, equals(b));
    });
  });

  group('the needs row', () {
    final bySpecies = NeedNavItem.mapFrom({
      'cat': [
        {'key': 'dry', 'id': 109, 'slug': 'dry', 'name': 'طعام جاف', 'icon': 'dry'},
        {'key': 'wet', 'id': 128, 'slug': 'wet', 'name': 'معلبات', 'icon': 'wet'},
        {'key': 'litter', 'id': 235, 'slug': 'litter', 'name': 'رمل', 'icon': 'litter'},
        {'key': 'treats', 'id': 132, 'slug': 'treats', 'name': 'مكافآت', 'icon': 'treats'},
      ],
      'dog': [
        {'key': 'dry', 'id': 116, 'slug': 'dog-dry', 'name': 'طعام جاف', 'icon': 'dry'},
      ],
    });

    test('a guest gets the cat row in its curated order', () {
      final tiles = NeedNav.resolve(bySpecies, NeedsHint.none);
      expect(tiles.map((t) => t.key), ['dry', 'wet', 'litter', 'treats']);
    });

    test('a dog owner gets the dog row', () {
      final tiles = NeedNav.resolve(bySpecies, const NeedsHint(species: 'dog'));
      expect(tiles.single.id, 116);
    });

    test('what they buy leads; the rest keep their place behind', () {
      final tiles = NeedNav.resolve(
        bySpecies,
        const NeedsHint(species: 'cat', order: ['litter', 'wet']),
      );
      expect(tiles.map((t) => t.key), ['litter', 'wet', 'dry', 'treats']);
    });

    test('a species the store has no row for falls back to the cat', () {
      final tiles = NeedNav.resolve(bySpecies, const NeedsHint(species: 'reptile'));
      expect(tiles.first.id, 109);
    });
  });

  group('the closing countdown', () {
    const hours = ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60);

    test('counts down to the shutter while the branch is open', () {
      final left = timeUntilExpressClose(DateTime(2026, 9, 9, 22, 15), hours);
      expect(left, const Duration(minutes: 45));
    });

    test('is nothing once the branch has shut, or before it opens', () {
      expect(timeUntilExpressClose(DateTime(2026, 9, 9, 23, 30), hours), isNull);
      expect(timeUntilExpressClose(DateTime(2026, 9, 9, 7, 0), hours), isNull);
    });

    test('an overnight shift closes tomorrow, not an hour ago', () {
      const night = ExpressHours(openMinutes: 18 * 60, closeMinutes: 2 * 60);
      final left = timeUntilExpressClose(DateTime(2026, 9, 9, 23, 0), night);
      expect(left, const Duration(hours: 3));
      // And in the small hours the shutter is today's.
      expect(timeUntilExpressClose(DateTime(2026, 9, 10, 1, 30), night), const Duration(minutes: 30));
    });

    test('no schedule means no shutter to count to', () {
      expect(timeUntilExpressClose(DateTime(2026, 9, 9, 22, 0), null), isNull);
    });
  });

  group('a suggestion that was bought before', () {
    test('carries the flag and the age of the last order', () {
      final s = SearchSuggestion.fromJson({
        'id': 42, 'name': 'رويال كانين', 'bought': true, 'last_ordered_days': 12,
      });
      expect(s.bought, isTrue);
      expect(s.lastOrderedDays, 12);
    });

    test('an older store that says nothing means not bought', () {
      final s = SearchSuggestion.fromJson({'id': 42, 'name': 'x'});
      expect(s.bought, isFalse);
      expect(s.lastOrderedDays, isNull);
    });
  });
}
