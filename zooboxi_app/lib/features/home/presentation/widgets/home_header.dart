import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../location/presentation/location_sheet.dart';
import '../../../search/presentation/express_search_field.dart';
import '../../../search/presentation/search_transition.dart';
import 'shelf_tabs.dart';

/// The home header: who we're delivering to, and the two things a customer
/// reaches for first — search and their saved list.
///
/// [onCanvas] renders it for the hero canvas — the deep colored panel the
/// header fuses with — so every stroke turns light and the search field stays
/// a bright, obvious well on top of the color.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, this.onCanvas = false, this.scope});

  final bool onCanvas;

  /// The active shelf, as the server resolved it: it decides the arrival time
  /// on the address line and carries the express branch's opening hours for
  /// the tab. Null (the ghost twin, a payload still loading) falls back to
  /// the saved location — same height either way, so ghost and overlay agree.
  final CatalogScope? scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final fg = onCanvas ? _canvasFg(context) : null;
    final express = scope?.shelf == 'express';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The two storefronts, above everything — the first decision on the
          // page is which shop you are in, not which product you want.
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8, bottom: 10),
            child: ShelfTabs(
              onCanvas: onCanvas,
              hours: scope?.expressHours,
              expressAvailable: scope?.expressAvailable,
              standardCutoffMinutes: scope?.standardCutoffMinutes,
            ),
          ),
          Row(
            children: [
              // The address gets the whole row it needs. A logo sticker used
              // to open it — pretty, and the one purely playful thing in the
              // app — but it spent about fifty points on saying a name the
              // customer already knows, in the row that answers the two
              // questions they actually have: WHERE it goes and WHEN it
              // arrives. The district and the hour own that space now.
              Expanded(child: LocationChip(onCanvas: onCanvas, scope: scope)),
              // Search is a button, not a field: the strip under the address
              // is worth more as store than as an empty input, and the button
              // opens by *becoming* that input.
              //
              // The flight belongs to whoever is on screen: `branch` keeps
              // home's hero out of a search opened from another tab.
              //
              // إكسبريس is the exception — it gets the field, full width, on
              // its own row below (there is no shop window to protect, and
              // the customer arrives knowing what they want). One Hero per
              // tag per route, so the button steps aside for it.
              if (!express) SearchHeroButton(onCanvas: onCanvas, branch: 0),
              if (!express) Gap.w4,
              IconButton(
                onPressed: () {
                  Haptics.light();
                  context.push('/wishlist');
                },
                icon: ZbIcon(
                  ZbIconKind.heart,
                  size: 23,
                  ink: fg ?? context.cs.onSurfaceVariant,
                ),
                tooltip: l.wishlistTitle,
              ),
            ],
          ),
          if (express) ...[
            Gap.h8,
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 8, end: 8),
              child: SearchHeroField(branch: 0),
            ),
          ],
        ],
      ),
    );
  }
}

/// Foreground for header strokes sitting on the hero canvas — always light,
/// because every canvas color is deep by design.
Color _canvasFg(BuildContext context) =>
    context.isDark ? ZbTokens.inkDark : Colors.white;
