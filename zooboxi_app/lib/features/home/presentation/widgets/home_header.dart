import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../location/presentation/location_sheet.dart';

/// The home header: who we're delivering to, and the two things a customer
/// reaches for first — search and their saved list.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(sessionProvider).user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: LocationChip()),
              IconButton(
                onPressed: () {
                  Haptics.light();
                  context.push('/wishlist');
                },
                icon: const Icon(Icons.favorite_border_rounded),
                tooltip: l.wishlistTitle,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8, top: 4, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    user == null ? l.homeGreeting : '${l.homeGreeting.split(' ').first} ${user.firstName}',
                    style: context.tt.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const PromiseLine(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
            child: _SearchBar(
              onTap: () => context.push('/search'),
              onScan: () => context.push('/scan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tap target that *looks* like a field but pushes the search screen — so
/// the keyboard and the suggestion list belong to one screen instead of
/// half-opening over the home feed.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap, required this.onScan});

  final VoidCallback onTap;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.light();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 2, bottom: 2),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              Gap.w12,
              Expanded(
                child: Text(
                  l.searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              IconButton(
                onPressed: () {
                  Haptics.light();
                  onScan();
                },
                icon: Icon(Icons.qr_code_scanner_rounded, size: 20, color: cs.primary),
                tooltip: l.searchScan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
