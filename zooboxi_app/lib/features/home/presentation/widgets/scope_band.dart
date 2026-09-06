import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../catalog/data/catalog_models.dart';

/// Names the shelf the customer is browsing.
///
/// The app shows one warehouse's stock — whatever can reach this address
/// fastest. Without a line saying so, a shorter catalogue reads as "you are out
/// of stock"; with it, the same catalogue reads as a promise: everything here
/// arrives within two hours. So the band leads with the promise and only then
/// explains where it comes from.
class ScopeBand extends StatelessWidget {
  const ScopeBand({super.key, required this.scope});

  final CatalogScope scope;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final pair = _pair(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: pair.bg,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          border: Border.all(color: pair.fg.withValues(alpha: 0.18)),
        ),
        padding: const EdgeInsetsDirectional.only(
          start: 12,
          end: 12,
          top: 9,
          bottom: 9,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              scope.icon ?? '⚡',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 15),
            ),
            Gap.w8,
            Expanded(
              child: Text(
                scope.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall?.copyWith(
                  color: context.isDark ? cs.onSurface : pair.fg,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The delivery tier's own colours — the same family the chips on the cards
  /// below already use, so the band reads as their heading rather than as a
  /// warning.
  ZbPair _pair(BuildContext context) {
    final zb = context.zb;
    return switch (scope.tier) {
      'express' => zb.tierExpress,
      'same_day' => zb.tierSameDay,
      _ => zb.tierShipping,
    };
  }
}
