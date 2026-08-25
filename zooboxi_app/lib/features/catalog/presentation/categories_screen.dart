import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/zb_image.dart';
import '../../../l10n/app_localizations.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

/// The category browser.
///
/// Top-level categories are cards with their sub-categories inlined as chips —
/// one screen instead of a drill-down, because a pet store's tree is shallow
/// and an extra tap between "Cats" and "Dry food" is an extra tap on the way
/// to every purchase.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: nodes.length,
              separatorBuilder: (_, _) => Gap.h12,
              itemBuilder: (context, index) => _CategoryCard(node: nodes[index]),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.node});

  final CategoryNode node;

  void _open(BuildContext context, {String? slug, String? title}) {
    context.push(
      Uri(
        path: '/listing',
        queryParameters: {
          'category': slug ?? node.slug,
          'title': title ?? node.name,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressScale(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(ZbTokens.rSm),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ZbImage(
                      url: node.image,
                      fit: BoxFit.cover,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node.name, style: context.tt.titleMedium),
                        if (node.count > 0)
                          Text(
                            L.of(context).listingResults(node.count),
                            style: context.tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    context.isRtl
                        ? Icons.keyboard_arrow_left_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (node.hasChildren)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final child in node.children)
                    ActionChip(
                      label: Text(child.name),
                      onPressed: () => _open(context, slug: child.slug, title: child.name),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          separatorBuilder: (_, _) => Gap.h12,
          itemBuilder: (context, _) => Container(
            height: 80,
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: context.cs.outlineVariant),
            ),
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                SkeletonBox(width: 56, height: 56, radius: ZbTokens.rSm),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 120, height: 13),
                    SizedBox(height: 8),
                    SkeletonBox(width: 70, height: 10),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
