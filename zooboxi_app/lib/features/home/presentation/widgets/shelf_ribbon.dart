import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/shelf/shelf_controller.dart';
import '../../../../core/shelf/shelf_identity.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../../l10n/app_localizations.dart';

/// The promise ribbon at the header's foot — the active storefront speaking
/// in its own colour.
///
/// It closes the header the way a shop's fascia board closes its entrance:
/// إكسبريس ends in ember and names the branch racing your order, زوبكسي ends
/// in teal and owns the whole catalogue. Because it is part of the header,
/// crossing the tabs repaints it in the other store's voice in the same
/// breath as the thumb slides — the chrome agrees instantly, even while the
/// shelves below are still on their way.
class ShelfRibbon extends ConsumerWidget {
  const ShelfRibbon({super.key, this.scope});

  /// The server's sentence for this shelf ("… من فرع الملك فهد"), handed down
  /// by the screen that fetched it. The ribbon itself never starts a request:
  /// a header must be paintable anywhere — the hero's ghost twin included —
  /// without waking the network.
  final CatalogScope? scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final shelf = ref.watch(shelfProvider);
    final identity = ShelfIdentity.of(context, shelf);

    // While the switch's refetch is in flight the fallback line keeps the
    // ribbon honest — it never shows the other store's note.
    final serverNote = scope?.note;
    final note = (serverNote != null && serverNote.isNotEmpty)
        ? serverNote
        : (shelf == Shelf.express ? l.shelfExpressSub : l.shelfAllSub);

    return AnimatedContainer(
      duration: context.motion(Motion.enter),
      curve: Motion.decelerate,
      decoration: BoxDecoration(
        gradient: identity.ribbon,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      padding: const EdgeInsetsDirectional.only(start: 12, end: 14, top: 6, bottom: 6),
      child: Row(
        children: [
          Icon(identity.icon, size: 15, color: identity.onRibbon),
          Gap.w6,
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion(Motion.enter),
              child: Text(
                note,
                key: ValueKey(note),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelMedium?.copyWith(
                  color: identity.onRibbon,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
