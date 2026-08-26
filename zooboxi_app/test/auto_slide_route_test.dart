import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/hero_carousel.dart';

/// A server-composed hero slide is merchandising built out of *our own*
/// catalogue, so tapping it has to land on one of our own screens. It used to
/// follow the store URL the slide carried, which meant a browser tab mid-shop
/// — and the clearance slide carried no URL at all, so the biggest promotion on
/// the page did nothing when tapped.
///
/// These lock the resolution table, and lock it against the two ways it breaks
/// quietly: a theme silently falling through to null, and an Arabic headline
/// coming back out of the URL mangled.

HeroSlide _auto(String theme, {String? title, String? link}) =>
    HeroSlide(kind: 'auto', theme: theme, title: title, linkUrl: link);

void main() {
  group('autoSlideRoute', () {
    test('clearance opens the clearance ranking, not a dead link', () {
      final uri = Uri.parse(autoSlideRoute(_auto('clearance', title: 'تخفيضات'))!);

      expect(uri.path, '/listing');
      expect(uri.queryParameters['rail'], 'clearance');
      expect(uri.queryParameters['title'], 'تخفيضات');
    });

    test('bestsellers keeps the ranking the slide was built from', () {
      final uri = Uri.parse(autoSlideRoute(_auto('bestsellers', title: 'الأكثر مبيعًا'))!);

      expect(uri.path, '/listing');
      expect(uri.queryParameters['rail'], 'bestsellers');
    });

    test('express carries no rail — the listing already floats nearby stock', () {
      final uri = Uri.parse(autoSlideRoute(_auto('express', title: 'خلال ساعتين'))!);

      expect(uri.path, '/listing');
      expect(uri.queryParameters.containsKey('rail'), isFalse);
      expect(uri.queryParameters['title'], 'خلال ساعتين');
    });

    test('a titleless slide produces a clean path, not a dangling "?"', () {
      expect(autoSlideRoute(_auto('express')), '/listing');
    });

    test('a brand slide resolves its store URL to the brand page', () {
      final route = autoSlideRoute(_auto(
        'brand',
        title: 'Applaws',
        link: 'https://store.zooboxi.com/brand/applaws/',
      ))!;
      final uri = Uri.parse(route);

      expect(uri.path, '/brand/applaws');
      expect(uri.queryParameters['title'], 'Applaws');
    });

    test('a brand slide with an unusable link still lands in the store', () {
      final uri = Uri.parse(autoSlideRoute(_auto(
        'brand',
        title: 'ماركات مختارة',
        link: 'https://example.com/promo',
      ))!);

      expect(uri.path, '/listing');
      expect(uri.queryParameters['title'], 'ماركات مختارة');
    });

    test('a brand slide with no link at all is still in-app', () {
      expect(autoSlideRoute(_auto('brand')), '/listing');
    });

    // Same contract as the home layout: a slot this build has never heard of
    // draws nothing rather than guessing at a destination.
    test('an unknown theme resolves to nothing rather than to a browser', () {
      expect(autoSlideRoute(_auto('wormhole', title: 'x')), isNull);
      expect(autoSlideRoute(const HeroSlide(kind: 'auto')), isNull);
    });

    test('Arabic headlines survive the round trip through the query string', () {
      const headline = 'خصم حتى 45% على أطعمة القطط والكلاب';

      for (final theme in const ['clearance', 'bestsellers', 'express']) {
        final route = autoSlideRoute(_auto(theme, title: headline))!;
        expect(
          Uri.parse(route).queryParameters['title'],
          headline,
          reason: '$theme must hand the listing the headline it was tapped from',
        );
      }

      final branded = autoSlideRoute(_auto(
        'brand',
        title: headline,
        link: 'https://store.zooboxi.com/brand/applaws/',
      ))!;
      expect(Uri.parse(branded).queryParameters['title'], headline);
    });
  });
}
