import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';

void main() {
  test('motionArtFor prefers the animated WebP of the best slot, else the static art', () {
    final c = Campaign.fromJson({
      'campaign_id': '4432',
      'zones': ['hero'],
      'creatives': {'hero': 'https://x/hero.png', 'card': 'https://x/card.png'},
      'motion': {'hero': 'https://x/hero.webp'},
    });
    expect(c.motion['hero'], 'https://x/hero.webp');
    expect(c.motionArtFor(const ['app_hero', 'card', 'hero']), 'https://x/hero.webp');
    expect(c.artFor(const ['app_hero', 'card', 'hero']), 'https://x/card.png');
    expect(c.finishedPlate, isNull);
  });

  test('finishedPlate is the app_hero slot, animated first', () {
    final a = Campaign.fromJson({'campaign_id': '2', 'creatives': {'app_hero': 'https://x/a.png'}, 'motion': {'app_hero': 'https://x/a.webp'}});
    expect(a.finishedPlate, 'https://x/a.webp');
    final b = Campaign.fromJson({'campaign_id': '3', 'creatives': {'app_hero': 'https://x/b.png'}});
    expect(b.finishedPlate, 'https://x/b.png');
  });

  test('campaigns without motion keep the static creative and never break', () {
    final c = Campaign.fromJson({'campaign_id': '1', 'creatives': {'wide': 'https://x/wide.png'}, 'motion': []});
    expect(c.motion, isEmpty);
    expect(c.motionArtFor(const ['wide', 'strip']), 'https://x/wide.png');
    expect(c.motionArtFor(const ['card']), isNull);
  });
}
