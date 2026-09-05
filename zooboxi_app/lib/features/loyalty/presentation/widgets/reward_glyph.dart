import 'package:flutter/material.dart';

import 'loyalty_art.dart';

export 'loyalty_art.dart' show rewardKindLabel;

/// The drawn mark for a reward kind — a thin door onto [RewardSticker], kept
/// so the cart's gift chip and the scratch card's prize face draw the same
/// sticker the catalogue does.
class RewardGlyph extends StatelessWidget {
  const RewardGlyph({super.key, required this.kind, this.size = 26, this.tint});

  final String kind;
  final double size;

  /// Accepted for source compatibility; a sticker keeps its own colours.
  final Color? tint;

  @override
  Widget build(BuildContext context) => RewardSticker(kind: kind, size: size);
}

/// The hue a reward kind carries — its chip text, its ring, its wash.
Color rewardKindTint(BuildContext context, String kind) => rewardKindHue(context, kind);
