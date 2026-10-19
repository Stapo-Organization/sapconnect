import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/core/home_widget/pet_widget_sync.dart';
import 'package:zooboxi_app/core/utils/formatters.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/home_screen.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/pet_shelf_card.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';

/// The fixes from the 2026-09-24 UX review: one price, one threshold, one line.
void main() {
  group('one price: every figure the customer reads is VAT-inclusive', () {
    // The basket the review found: a 3.15 scoop and a 50.40 bag of litter,
    // express delivery 25 ex-VAT, total 82.30.
    final today = {
      'items': [
        {'key': 'a', 'product_id': 1, 'name': 'سكوب', 'qty': 1, 'unit_price': 3.15, 'line_total': 2.74},
        {'key': 'b', 'product_id': 2, 'name': 'رمل', 'qty': 1, 'unit_price': 50.40, 'line_total': 43.83},
      ],
      'totals': {'subtotal': 46.57, 'discount': 0, 'shipping': 25, 'tax': 10.73, 'total': 82.30},
    };

    test('a line reads its shelf price, not WooCommerce\'s ex-VAT figure', () {
      final cart = CartData.fromJson(today);
      expect(cart.items.map((i) => i.lineTotal), [3.15, 50.40]);
    });

    test('a store before the fix still adds up to the money charged', () {
      final totals = CartData.fromJson(today).totals;
      expect(totals.subtotal, 53.55);
      expect(totals.shipping, 28.75);
      expect(totals.total, 82.30);
      expect(totals.tax, 10.73); // named inside the total, not added to it
      expect(totals.subtotal - totals.discount + totals.shipping, closeTo(totals.total, 0.001));
    });

    test('the store\'s own display figures win when it sends them', () {
      final totals = CartTotals.fromJson({
        'subtotal': 46.57,
        'total': 82.30,
        'display': {'items': 53.55, 'discount': 0, 'shipping': 28.75, 'fees': 0, 'total': 82.30, 'tax': 10.73},
      });
      expect(totals.subtotal, 53.55);
      expect(totals.shipping, 28.75);
    });

    test('line_total_incl is preferred over unit price × quantity', () {
      expect(
        CartItem.lineTotalOf({'unit_price': 10, 'qty': 3, 'line_total_incl': 29.5}),
        29.5,
      );
      expect(CartItem.lineTotalOf({'unit_price': 3.15, 'qty': 3}), 9.45);
    });

    test('a stepper tap moves the total by the same VAT-inclusive step', () {
      final cart = CartData.fromJson(today).withItemQty('a', 2);
      expect(cart.items.first.lineTotal, 6.30);
      expect(cart.totals.subtotal, 56.70);
      expect(cart.totals.total, 85.45);
    });
  });

  group('one threshold: cart and checkout quote the same line', () {
    const lines = FreeShipping(
      min: 200,
      remaining: 146.45,
      express: FreeShipping(min: 150, remaining: 96.45),
    );

    test('an express basket is measured against the express line', () {
      final pick = freeDeliveryLine(lines, const CartBasket(shelf: 'express'));
      expect(pick.line.remaining, 96.45);
      expect(pick.express, isTrue);
    });

    test('the store\'s basket is measured against the national line', () {
      final pick = freeDeliveryLine(lines, const CartBasket(shelf: 'all'));
      expect(pick.line.remaining, 146.45);
      expect(pick.express, isFalse);
    });

    test('the shelf the store served wins over the one the basket named', () {
      final pick = freeDeliveryLine(lines, const CartBasket(shelf: 'all', effectiveShelf: 'express'));
      expect(pick.express, isTrue);
    });
  });

  group('numbers read the Saudi way', () {
    test('a price is 3.15, not 3٫15', () {
      expect(Fmt.number(3.15, locale: 'ar'), '3.15');
      expect(Fmt.number(1240, locale: 'ar', decimals: 0), '1,240');
      expect(Fmt.number(1234.5, locale: 'en'), '1,234.50');
    });
  });

  group('a product line shows once per shelf', () {
    test('every flavour of one treat is one line', () {
      expect(productLineOf('زولكس سويتيز مكافآت دجاج للكلاب 14غ'), 'زولكس سويتيز مكافآت');
      expect(productLineOf('زولكس سويتيز مكافآت بط للكلاب 14غ'), 'زولكس سويتيز مكافآت');
    });

    test('bundles of one line collapse, sizes and counts ignored', () {
      expect(
        productLineOf('12 + 3 مجاناً · ويلنس كور بيوري'),
        productLineOf('12 + 3 مجاناً · ويلنس كور بيوري باتيه أظرف'),
      );
    });

    test('a name too short to say has no line', () {
      expect(productLineOf('رمل 10'), isNull);
    });
  });

  group('«رفّ لولو»', () {
    const lulu = PetRef(id: 7, name: 'لولو', species: PetSpecies.cat);
    const max = PetRef(id: 8, name: 'ماكس', species: PetSpecies.dog);
    SupplyItem line(int id, String kind, PetRef pet, int days) => SupplyItem(
          product: ProductCard(id: id, name: 'منتج $id'),
          kind: kind,
          pet: pet,
          daysLeft: days,
          runsOutAt: DateTime(2026, 9, 24).add(Duration(days: days)),
        );

    test('the pet whose food runs out first leads, food then litter then treat', () {
      final summary = LoyaltySummary(
        supply: SupplyBlock(items: [
          line(1, 'treat', lulu, 9),
          line(2, 'dry', max, 12),
          line(3, 'litter', lulu, 6),
          line(4, 'dry', lulu, 4),
          line(5, 'wet', lulu, 8),
        ]),
      );
      final shelf = petShelfOf(summary)!;
      expect(shelf.pet.name, 'لولو');
      expect(shelf.lines.map((l) => l.product.id), [4, 3, 1]);
    });

    test('no pet on any line means no shelf', () {
      expect(petShelfOf(const LoyaltySummary()), isNull);
    });

    test('the widget counts down to an instant, not a day count', () {
      final food = line(4, 'dry', lulu, 4);
      final json = jsonDecode(petShelfJson(food, lang: 'ar')!) as Map<String, dynamic>;
      expect(json['pet'], 'لولو');
      expect(json['species'], 'cat');
      expect(json['runsOut'], food.runsOutAt!.millisecondsSinceEpoch ~/ 1000);
      expect(petShelfJson(null, lang: 'ar'), isNull);
    });

    test('the widget follows food, never litter or treats', () {
      final summary = LoyaltySummary(
        supply: SupplyBlock(items: [line(3, 'litter', lulu, 1), line(4, 'dry', lulu, 4)]),
      );
      expect(widgetFoodLine(summary)!.product.id, 4);
    });
  });

  group('«يكفي لولو كم يوم؟»', () {
    final lasts = PetLasts.fromJson({
      'pet': 'لولو',
      'kind': 'dry',
      'units': [
        {'variation_id': 11, 'days': 38, 'per_day': 1.9},
        {'variation_id': 12, 'days': 133, 'per_day': 1.4},
      ],
    });

    test('the answer follows the chosen size', () {
      expect(lasts.forVariation(12)!.days, 133);
      expect(lasts.forVariation(99), isNull);
    });

    test('a range of sizes with none chosen has no single answer', () {
      expect(lasts.forVariation(null), isNull);
      final single = PetLasts.fromJson({
        'pet': 'لولو',
        'units': [
          {'variation_id': 0, 'days': 20, 'per_day': 2.5},
        ],
      });
      expect(single.forVariation(null)!.days, 20);
    });
  });
}
