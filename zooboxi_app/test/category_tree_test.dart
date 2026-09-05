import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/category_tree.dart';

CategoryNode _n(
  int id,
  String name, {
  String? slug,
  List<CategoryNode> children = const [],
}) =>
    CategoryNode(id: id, slug: slug ?? 'c$id', name: name, children: children);

void main() {
  group('orderedDepartments', () {
    test(
      'food leads, then treats and supplies; litter aisles stay together',
      () {
        final server = [
          _n(141, 'التنظيف والتدريب'),
          _n(132, 'المكافآت والفيتامينات'),
          _n(130, 'بكجات متعددة وموفّرة'),
          _n(235, 'رمل القطط'),
          _n(148, 'صحة القطط'),
          _n(108, 'طعام'),
          _n(152, 'مستلزمات الرمل'),
          _n(146, 'مستلزمات القطط'),
        ];
        expect(orderedDepartments(server).map((n) => n.id).toList(), [
          108,
          132,
          146,
          148,
          235,
          152,
          141,
          130,
        ]);
      },
    );

    test('unknown departments keep server order after the known groups', () {
      final ordered = orderedDepartments([
        _n(1, 'غريب'),
        _n(2, 'طعام'),
        _n(3, 'آخر'),
      ]);
      expect(ordered.map((n) => n.id).toList(), [2, 1, 3]);
    });
  });

  group('wideDepartmentCount', () {
    test('never leaves the two-up grid with a half row', () {
      for (var total = 0; total <= 12; total++) {
        final wide = wideDepartmentCount(total);
        expect(wide, lessThanOrEqualTo(total));
        expect(
          (total - wide).isEven,
          isTrue,
          reason: 'total=$total wide=$wide',
        );
        if (total > 2) expect(wide, inInclusiveRange(1, 2));
      }
      expect(wideDepartmentCount(2), 2);
      expect(wideDepartmentCount(5), 1);
      expect(wideDepartmentCount(8), 2);
    });
  });

  group('locateCategory', () {
    final roots = [
      _n(
        107,
        'قطط',
        slug: '%d9%82%d8%b7%d8%b7',
        children: [_n(108, 'طعام', slug: '%d8%b7%d8%b9%d8%a7%d9%85')],
      ),
      _n(
        114,
        'كلاب',
        slug: 'dogs',
        children: [_n(115, 'الطعام', slug: 'dog-food')],
      ),
    ];

    test('finds a pet by its own slug with no current department', () {
      final place = locateCategory(roots, 'dogs');
      expect(place?.root.id, 114);
      expect(place?.current, isNull);
    });

    test('finds a department and its pet, encoded or decoded', () {
      expect(
        locateCategory(roots, '%d8%b7%d8%b9%d8%a7%d9%85')?.current?.id,
        108,
      );
      expect(locateCategory(roots, 'طعام')?.root.id, 107);
    });

    test('is null for searches and unknown slugs', () {
      expect(locateCategory(roots, null), isNull);
      expect(locateCategory(roots, 'nope'), isNull);
    });
  });
}
