import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';

/// Locks the variation contract to what the live server actually sends
/// (captured from product 11748): combination keys carry WooCommerce's
/// `attribute_` prefix and Arabic option slugs arrive percent-encoded on
/// BOTH sides. The picker selects by bare group slug — if normalisation
/// ever regresses, every option renders struck-through and dead.
void main() {
  const piece = '%d8%ad%d8%a8%d8%a9'; // حبة
  const carton = '%d9%83%d8%b1%d8%aa%d9%88%d9%86-17-%d8%ad%d8%a8%d8%a9';

  ProductVariation v(Map<String, dynamic> attrs, {bool inStock = true}) =>
      ProductVariation.fromJson({
        'variation_id': 1,
        'attributes': attrs,
        'price': 6.65,
        'in_stock': inStock,
      });

  test('attribute_ prefix is stripped so bare-slug selections match', () {
    final variation = v({'attribute_pa_choose-opt': piece});
    expect(variation.attributes.containsKey('pa_choose-opt'), isTrue);
    expect(variation.matches({'pa_choose-opt': piece}), isTrue);
    expect(variation.matches({'pa_choose-opt': carton}), isFalse);
  });

  test('an empty stored value means "Any" and accepts every choice', () {
    final any = v({'attribute_pa_choose-opt': ''});
    expect(any.matches({'pa_choose-opt': piece}), isTrue);
    expect(any.matches({'pa_choose-opt': carton}), isTrue);
  });

  test('multi-axis: every chosen axis must be satisfied', () {
    final variation = v({
      'attribute_pa_choose-opt': carton,
      'attribute_pa_weight-opt': '400g',
    });
    expect(
      variation.matches({'pa_choose-opt': carton, 'pa_weight-opt': '400g'}),
      isTrue,
    );
    expect(
      variation.matches({'pa_choose-opt': carton, 'pa_weight-opt': '2kg'}),
      isFalse,
    );
  });
}
