import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import 'widgets/category_group.dart';

/// The category browser.
///
/// The store's tree is four animals wide and one level deep, so it is shown as
/// four boards on one screen rather than as a drill-down: each animal's own
/// artwork heads a board, and its departments sit under it as tiles carrying
/// their own illustrations. An extra tap between "قطط" and "طعام" is an extra
/// tap on the way to nearly every purchase this store makes.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _open(BuildContext context, String slug, String title) {
    context.push(
      Uri(
        path: '/listing',
        queryParameters: {'category': slug, 'title': title},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final categories = ref.watch(categoriesProvider(null));

    return Scaffold(
      appBar: AppBar(title: Text(l.categoriesTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(categoriesProvider(null));
          await ref.read(categoriesProvider(null).future);
        },
        child: AsyncView<List<CategoryNode>>(
          value: categories,
          onRetry: () => ref.invalidate(categoriesProvider(null)),
          skeleton: const _CategoriesSkeleton(),
          builder: (nodes) {
            if (nodes.isEmpty) {
              return EmptyState(
                icon: Icons.grid_view_rounded,
                title: l.categoriesEmpty,
                message: l.listingEmptyHint,
              );
            }
            return ListView.separated(
              // The floating tab bar's height arrives as bottom padding, so
              // the last board clears it instead of hiding behind the glass.
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: nodes.length,
              separatorBuilder: (_, _) => Gap.h16,
              itemBuilder: (context, index) => CategoryGroup(
                node: nodes[index],
                onOpen: (slug, title) => _open(context, slug, title),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (_, _) => Gap.h16,
          itemBuilder: (context, _) => Container(
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: context.cs.outlineVariant),
            ),
            padding: const EdgeInsets.all(12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox.circle(size: 58),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonBox(width: 110, height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: 64, height: 10),
                      ],
                    ),
                  ],
                ),
                Gap.h16,
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 92, radius: ZbTokens.rMd)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 92, radius: ZbTokens.rMd)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 92, radius: ZbTokens.rMd)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
