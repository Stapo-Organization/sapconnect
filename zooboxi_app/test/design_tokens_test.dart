import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to write a colour as hex.
///
/// The theme and its palettes, and the illustrations — podium metals, loyalty
/// art, scratch foil, species avatars, story sheets, brand identities, the
/// express cards' art — whose colours are part of a drawing rather than of
/// the interface. Everything else takes its colours from `ZbTokens` or the
/// theme; a new hex anywhere else fails here, which is what keeps the rule at
/// the top of zooboxi_tokens.dart true as the app grows.
const Set<String> _allowed = {
  'app/theme/app_theme.dart',
  'app/theme/zb_colors.dart',
  'app/theme/zooboxi_tokens.dart',
  'core/characters/characters.dart',
  'core/characters/props.dart',
  'core/shelf/shelf_identity.dart',
  'features/brand/presentation/brand_screen.dart',
  'features/brand/presentation/widgets/brand_about_sheet.dart',
  'features/brand/presentation/widgets/brand_activation_widgets.dart',
  'features/brand/presentation/widgets/brand_palette.dart',
  'features/brand/presentation/widgets/brand_sections.dart',
  'features/catalog/data/catalog_models.dart',
  'features/catalog/presentation/pet_palette.dart',
  'features/home/presentation/widgets/express_cards/arrivals_wall.dart',
  'features/home/presentation/widgets/express_cards/clearance_ticket.dart',
  'features/home/presentation/widgets/express_cards/need_pockets.dart',
  'features/home/presentation/widgets/express_cards/podium.dart',
  'features/home/presentation/widgets/express_offers.dart',
  'features/home/presentation/widgets/hero_auto_slide.dart',
  'features/home/presentation/widgets/hero_carousel.dart',
  'features/home/presentation/widgets/hero_slide_layouts.dart',
  'features/home/presentation/widgets/promise_header.dart',
  'features/home/presentation/widgets/replenish_tile.dart',
  'features/loyalty/presentation/ledger_screen.dart',
  'features/loyalty/presentation/widgets/grant_card.dart',
  'features/loyalty/presentation/widgets/loyalty_art.dart',
  'features/loyalty/presentation/widgets/mission_card.dart',
  'features/loyalty/presentation/widgets/moment_cards.dart',
  'features/loyalty/presentation/widgets/paws_pill.dart',
  'features/loyalty/presentation/widgets/reward_card.dart',
  'features/loyalty/presentation/widgets/scratch_canvas.dart',
  'features/loyalty/presentation/widgets/scratch_card_view.dart',
  'features/loyalty/presentation/widgets/tier_card.dart',
  'features/onboarding/presentation/household_step.dart',
  'features/orders/presentation/widgets/live_tracking_card.dart',
  'features/pets/presentation/weight_sheet.dart',
  'features/pets/presentation/widgets/species_avatar.dart',
  'features/product/presentation/widgets/story/story_sheets.dart',
  'features/product/presentation/widgets/story/story_style.dart',
};

void main() {
  test('no interface file writes a colour as hex', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceFirst(RegExp(r'^lib[/\\]'), '').replaceAll(r'\', '/');
      if (path.endsWith('.g.dart') || path.startsWith('l10n/') || _allowed.contains(path)) continue;
      if (entity.readAsStringSync().contains('Color(0x')) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'take the colour from ZbTokens or the theme');
  });
}
