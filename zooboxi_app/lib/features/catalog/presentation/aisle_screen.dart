import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/category_art.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../home/presentation/widgets/express_cards/card_form.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../data/product_models.dart';
import 'pet_palette.dart';

/// A category, walked.
///
/// Two pages share one payload ([Aisle]) and one screen. A species root is
/// «الممرّ» — a supermarket aisle: the animal's sticker as the sign, a strip
/// of its departments that stays put, then every department as one row of
/// three products already chosen, with its own «الكل». Nothing to learn,
/// nothing to open; the customer who buys the same litter every fortnight
/// is two taps from it. A department is «الطبقات» — the same rows, but each
/// sub-need stands on a shelf of its own with its cut-outs on the ledge, so
/// the department's whole shape is seen at once without a filter sheet.
///
/// The owner chose both from a canvas of three directions apiece
/// (2026-09-15); the other sketches are on that canvas, not in here.
class AisleScreen extends ConsumerStatefulWidget {
  const AisleScreen({super.key, required this.aisleKey, this.title = ''});

  /// The category's id (from the tree) or slug (from a link) — the server
  /// resolves either.
  final String aisleKey;

  /// The name the caller already knew, so the first frame is honest.
  final String title;

  @override
  ConsumerState<AisleScreen> createState() => _AisleScreenState();
}

class _AisleScreenState extends ConsumerState<AisleScreen> {
  final _scroll = ScrollController();

  /// One anchor per row, so the strip can glide to a department and tell
  /// which one is under the reader.
  final List<GlobalKey> _rowKeys = [];

  /// The strip's lit chip: 0 is «الكل», then the rows in order.
  int _lit = 0;

  /// While a tap-triggered glide is in flight the strip holds the tapped
  /// chip instead of flickering through the rows it passes.
  bool _gliding = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_track);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.track(ZbEvent(
        type: ZbEvents.view,
        zone: 'aisle',
        payload: {'category': widget.aisleKey},
      ));
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_track)
      ..dispose();
    super.dispose();
  }

  void _track() {
    if (_gliding || _rowKeys.isEmpty) return;
    // The row whose top has passed the strip is the one being read.
    var lit = 0;
    for (var i = 0; i < _rowKeys.length; i++) {
      final box = _rowKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= _ChipStrip.height + MediaQuery.paddingOf(context).top + 8) {
        lit = i + 1;
      }
    }
    if (lit != _lit) setState(() => _lit = lit);
  }

  Future<void> _glide(int index) async {
    Haptics.selection();
    setState(() {
      _lit = index;
      _gliding = true;
    });
    if (index == 0) {
      await _scroll.animateTo(0, duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
    } else {
      final target = _rowKeys[index - 1].currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0,
        );
      }
    }
    if (mounted) setState(() => _gliding = false);
  }

  void _openRow(AisleRow row) {
    context.push(
      row.hasChildren
          ? Uri(path: '/aisle/${row.node.id}', queryParameters: {'title': row.node.name}).toString()
          : Uri(
              path: '/listing',
              queryParameters: {'category': row.node.slug, 'title': row.node.name},
            ).toString(),
    );
  }

  Future<bool> _add(ProductCard product) =>
      addToCart(context, ref, product: product, zone: 'aisle', quiet: true);

  @override
  Widget build(BuildContext context) {
    final aisle = ref.watch(aisleProvider(widget.aisleKey));

    if (aisle.hasValue) return _loaded(aisle.requireValue);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: aisle.hasError
          ? ErrorState(
              error: aisle.error,
              onRetry: () => ref.invalidate(aisleProvider(widget.aisleKey)),
            )
          : const _Skeleton(),
    );
  }

  Widget _loaded(Aisle aisle) {
    final l = L.of(context);
    final palette = PetPalette.resolve(context, icon: aisle.species.icon, index: 0);
    while (_rowKeys.length < aisle.rows.length) {
      _rowKeys.add(GlobalKey());
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 28;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: aisle.isSpecies
            ? _Sign(aisle: aisle, palette: palette)
            : _DeptHeader(aisle: aisle, palette: palette),
      ),
      if (aisle.isSpecies && aisle.rows.isNotEmpty)
        SliverPersistentHeader(
          pinned: true,
          delegate: _ChipStrip(
            labels: [l.aisleSeeAll, for (final r in aisle.rows) r.node.name],
            lit: _lit,
            palette: palette,
            onTap: _glide,
          ),
        ),
      if (aisle.bestsellers.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: _SectionTitle(
              title: aisle.isSpecies ? l.aisleBestsellers : l.aisleBestsellersIn(aisle.node.name),
              mark: Icons.star_rounded,
              tone: ZbTokens.amber,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _CoinRail(products: aisle.bestsellers, onAdd: _add),
        ),
      ],
      if (aisle.rows.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 40, color: context.cs.onSurfaceVariant),
                  Gap.h12,
                  Text(l.aisleEmpty, style: context.tt.titleMedium),
                  Gap.h4,
                  Text(
                    l.aisleEmptyHint,
                    textAlign: TextAlign.center,
                    style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.only(top: aisle.isSpecies ? 10 : 4, bottom: bottom),
          sliver: SliverList.separated(
            itemCount: aisle.rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 22),
            itemBuilder: (context, i) {
              final row = aisle.rows[i];
              return KeyedSubtree(
                key: _rowKeys[i],
                child: aisle.isSpecies
                    ? _AisleRow(
                        row: row,
                        palette: palette,
                        onAll: () => _openRow(row),
                        onAdd: _add,
                      )
                    : _Shelf(
                        row: row,
                        wash: _Shelf.washes[i % _Shelf.washes.length],
                        onAll: () => _openRow(row),
                        onAdd: _add,
                      ),
              );
            },
          ),
        ),
    ];

    return Scaffold(
      body: CustomScrollView(controller: _scroll, slivers: slivers),
    );
  }
}

// ── The sign ─────────────────────────────────────────────────────────

/// «ممرّ القطط»: the animal's sticker slapped on at a tilt, the kicker, the
/// name, the size of the aisle — and the way back and the way to search.
class _Sign extends StatelessWidget {
  const _Sign({required this.aisle, required this.palette});

  final Aisle aisle;
  final PetPalette palette;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final node = aisle.node;
    final top = MediaQuery.paddingOf(context).top;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, top + 8, 16, 14),
        child: Row(
          children: [
            _RoundButton(
              icon: context.isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () => context.pop(),
            ),
            Gap.w10,
            _Sticker(node: node, size: 72),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.aisleKicker,
                    style: context.tt.labelSmall?.copyWith(
                      color: palette.headline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l.brandProductCount(node.count)} · ${l.aisleSections(aisle.rows.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Gap.w8,
            _RoundButton(
              icon: Icons.search_rounded,
              tooltip: l.aisleSearchHint(node.name),
              onTap: () => context.push('/search'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The species' own art on a cream tile, landed at the angle a thumb leaves
/// it — the logo's sticker vocabulary, the same one the categories board uses.
class _Sticker extends StatelessWidget {
  const _Sticker({required this.node, required this.size});

  final CategoryNode node;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -5 * math.pi / 180,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: context.isDark ? ZbTokens.graphiteHighest : ZbTokens.cream,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: CategoryArt(
          image: node.image,
          icon: node.icon,
          size: size - 10,
          circular: false,
          borderRadius: size * 0.2,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: cs.surface,
        shape: CircleBorder(side: BorderSide(color: cs.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.light();
            onTap();
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}

// ── The strip ────────────────────────────────────────────────────────

/// The departments as a row of chips that stays under the finger while the
/// rows scroll away — the aisle's table of contents.
class _ChipStrip extends SliverPersistentHeaderDelegate {
  const _ChipStrip({
    required this.labels,
    required this.lit,
    required this.palette,
    required this.onTap,
  });

  static const double height = 56;

  final List<String> labels;
  final int lit;
  final PetPalette palette;
  final ValueChanged<int> onTap;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  bool shouldRebuild(_ChipStrip old) =>
      old.lit != lit || old.labels != labels || old.palette != palette;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = context.cs;
    return Container(
      height: height,
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: AlignmentDirectional.centerStart,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: labels.length,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, i) {
          final on = i == lit;
          return PressScale(
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? palette.accent : cs.surface,
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
                border: Border.all(color: on ? palette.accent : cs.outlineVariant),
              ),
              child: Text(
                labels[i],
                style: context.tt.labelLarge?.copyWith(
                  fontSize: 13,
                  color: on ? palette.onAccent : cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Shared bits ──────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.mark,
    required this.tone,
  });

  final String title;
  final IconData mark;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: context.isDark ? 0.22 : 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(mark, size: 17, color: tone),
        ),
        Gap.w10,
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _AllLink extends StatelessWidget {
  const _AllLink({required this.label, required this.tone, this.onTap});

  final String label;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rPill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.tt.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w700),
            ),
            Icon(
              context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 18,
              color: tone,
            ),
          ],
        ),
      ),
    );
  }
}

/// The top sellers as coins on a rail: rank, a thumb, the name and the price
/// on one pill each — the podium's answer for a page that has eight rows
/// under it and no room for a stage.
class _CoinRail extends ConsumerWidget {
  const _CoinRail({required this.products, required this.onAdd});

  final List<ProductCard> products;
  final Future<bool> Function(ProductCard) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, i) {
          final p = products[i];
          return PressScale(
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
            onTap: () => openProduct(context, ref, p, zone: 'aisle_best'),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 12, 4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RankCoin(rank: i + 1, size: 24, filled: true),
                  Gap.w6,
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: (p.cutout ?? '').isNotEmpty
                        ? FloatingProduct(url: p.cutout!, width: 36, height: 36, shadow: 0.2, drop: 3)
                        : PhotoPlate(product: p, radius: 8, inset: 3, status: false),
                  ),
                  Gap.w8,
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        InlinePrice(
                          product: p,
                          style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── «الممرّ»: one row per department ─────────────────────────────────

class _AisleRow extends ConsumerWidget {
  const _AisleRow({
    required this.row,
    required this.palette,
    required this.onAll,
    required this.onAdd,
  });

  final AisleRow row;
  final PetPalette palette;
  final VoidCallback onAll;
  final Future<bool> Function(ProductCard) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final node = row.node;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: onAll,
            borderRadius: BorderRadius.circular(ZbTokens.rMd),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: palette.well(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CategoryArt(
                    image: node.image,
                    icon: node.icon,
                    size: 30,
                    circular: false,
                    fit: BoxFit.contain,
                  ),
                ),
                Gap.w10,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        l.brandProductCount(node.count),
                        style: context.tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                _AllLink(label: l.aisleSeeAll, tone: palette.accent, onTap: onAll),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) Gap.w8,
                Expanded(
                  child: i < row.products.length
                      ? _MiniCard(product: row.products[i], onAdd: onAdd)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A third of a row: the plate with the add control riding its corner, two
/// lines of name, the price.
class _MiniCard extends ConsumerWidget {
  const _MiniCard({required this.product, required this.onAdd});

  final ProductCard product;
  final Future<bool> Function(ProductCard) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      onTap: () => openProduct(context, ref, product, zone: 'aisle'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: PhotoPlate(
                product: product,
                onAdd: onAdd,
                radius: 10,
                inset: 6,
                addInset: 4,
                color: context.isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
              ),
            ),
            Gap.h4,
            InlinePrice(
              product: product,
              style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ── «الطبقات»: one shelf per sub-need ────────────────────────────────

/// The department's own sign: its illustration in a tinted well, the name,
/// the size — on a wash of the species' colour.
class _DeptHeader extends StatelessWidget {
  const _DeptHeader({required this.aisle, required this.palette});

  final Aisle aisle;
  final PetPalette palette;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final node = aisle.node;
    final top = MediaQuery.paddingOf(context).top;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [palette.band, palette.bandEnd],
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, top + 8, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoundButton(
                  icon: context.isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => context.pop(),
                ),
                Gap.w10,
                Expanded(
                  child: Text(
                    aisle.species.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelLarge?.copyWith(
                      color: palette.headline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _RoundButton(
                  icon: Icons.search_rounded,
                  tooltip: l.aisleSearchHint(node.name),
                  onTap: () => context.push('/search'),
                ),
              ],
            ),
            Gap.h16,
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: context.isDark ? 0.10 : 0.6),
                    borderRadius: BorderRadius.circular(ZbTokens.rXl),
                  ),
                  child: CategoryArt(
                    image: node.image,
                    icon: node.icon,
                    size: 56,
                    circular: false,
                    fit: BoxFit.contain,
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        node.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          color: palette.headline,
                        ),
                      ),
                      Gap.h4,
                      Text(
                        '${l.brandProductCount(node.count)} · ${l.aisleSections(aisle.rows.length)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          color: palette.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One sub-need as a shelf: its name and size above, three cut-outs standing
/// on a wash with their own shadows and a lit ledge under them, the name and
/// price beneath each. A product the store could not cut sits on a plate.
class _Shelf extends ConsumerWidget {
  const _Shelf({
    required this.row,
    required this.wash,
    required this.onAll,
    required this.onAdd,
  });

  final AisleRow row;
  final (Color, Color) wash;
  final VoidCallback onAll;
  final Future<bool> Function(ProductCard) onAdd;

  /// The studio sweeps the polaroids stand on — light and dark of each.
  static const List<(Color, Color)> washes = [
    (Color(0xFFF3EADB), Color(0xFF3A3225)),
    (Color(0xFFE3EFE7), Color(0xFF24332A)),
    (Color(0xFFF9E6E1), Color(0xFF3B2A27)),
    (Color(0xFFE4EDF6), Color(0xFF25313C)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final ground = context.isDark ? wash.$2 : wash.$1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  row.node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Gap.w8,
              Text(
                l.brandProductCount(row.node.count),
                style: context.tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              _AllLink(label: l.aisleSeeAll, tone: cs.primary, onTap: onAll),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ground,
                gradient: RadialGradient(
                  center: const Alignment(0, -1),
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: context.isDark ? 0.08 : 0.7),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.8],
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) Gap.w6,
                          Expanded(
                            child: i < row.products.length
                                ? _ShelfItem(product: row.products[i], onAdd: onAdd)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // The ledge the cut-outs stand on.
                  Container(
                    height: 10,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: ZbTokens.ink.withValues(alpha: context.isDark ? 0.35 : 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: ZbTokens.ink.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfItem extends ConsumerWidget {
  const _ShelfItem({required this.product, required this.onAdd});

  final ProductCard product;
  final Future<bool> Function(ProductCard) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final cut = product.cutout ?? '';

    return PressScale(
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      onTap: () => openProduct(context, ref, product, zone: 'aisle_shelf'),
      child: Column(
        children: [
          SizedBox(
            height: 92,
            child: Center(
              child: cut.isNotEmpty
                  ? FloatingProduct(url: cut, width: 88, height: 88, drop: 5, shadow: context.isDark ? 0.55 : 0.3)
                  : SizedBox(
                      width: 84,
                      height: 84,
                      child: PhotoPlate(product: product, radius: 12, inset: 6, status: false),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: Text(
              product.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
            ),
          ),
          Gap.h4,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: InlinePrice(
                  product: product,
                  style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Gap.w6,
              Material(
                color: cs.primary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Haptics.light();
                    onAdd(product);
                  },
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(Icons.add_rounded, size: 17, color: cs.onPrimary),
                  ),
                ),
              ),
            ],
          ),
          Gap.h8,
        ],
      ),
    );
  }
}

// ── First paint ──────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final tone = context.cs.surfaceContainerHigh;
    Widget block(double w, double h, [double r = 12]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(r)),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [block(72, 72, 20), Gap.w12, Expanded(child: block(double.infinity, 48))]),
        Gap.h16,
        Row(children: [for (var i = 0; i < 4; i++) ...[block(72, 36, 999), Gap.w8]]),
        Gap.h20,
        for (var i = 0; i < 3; i++) ...[
          block(160, 20),
          const SizedBox(height: 10),
          Row(children: [for (var j = 0; j < 3; j++) ...[Expanded(child: block(double.infinity, 168)), if (j < 2) Gap.w8]]),
          Gap.h20,
        ],
      ],
    );
  }
}
