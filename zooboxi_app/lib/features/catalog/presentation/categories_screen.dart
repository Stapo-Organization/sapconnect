import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/motion/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import 'pet_palette.dart';
import 'widgets/pet_section.dart';
import 'widgets/pet_strip.dart';

/// The category browser.
///
/// The store is shopped by pet: someone has a cat, or a dog, and everything
/// else is a filter on top of that. So the screen is four aisles on one page
/// — a coloured board per pet with its departments laid out underneath — and
/// a pinned strip of the four pets that doubles as a table of contents:
/// it tracks the board under it and glides to a board when tapped. An extra
/// tap between "قطط" and "طعام" is an extra tap on the way to nearly every
/// purchase this store makes, so there is no drill-down.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  List<GlobalKey> _sectionKeys = const [];

  int _active = 0;

  /// Boards that have entered the viewport at least once — their entrance
  /// has played and must not replay on the way back up.
  Set<int> _revealed = {0};

  /// While a tap-triggered glide is in flight the strip holds the tapped pet
  /// rather than flickering through the boards it passes.
  int? _gliding;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_measure)
      ..dispose();
    super.dispose();
  }

  void _open(String slug, String title) {
    context.push(
      Uri(
        path: '/listing',
        queryParameters: {'category': slug, 'title': title},
      ).toString(),
    );
  }

  /// Each board's top edge, measured against the viewport — the one number
  /// both the strip highlight and the reveal logic are read from.
  List<double>? _sectionTops() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final tops = <double>[];
    for (final key in _sectionKeys) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return null;
      tops.add(box.localToGlobal(Offset.zero, ancestor: viewport).dy);
    }
    return tops;
  }

  void _measure() {
    if (!mounted || _sectionKeys.isEmpty) return;
    final tops = _sectionTops();
    if (tops == null) return;

    final viewportHeight = _viewportKey.currentContext?.size?.height ?? 0;
    var active = 0;
    final revealed = Set<int>.of(_revealed);
    for (var i = 0; i < tops.length; i++) {
      if (tops[i] <= PetStrip.height + 12) active = i;
      if (tops[i] < viewportHeight * 0.92) revealed.add(i);
    }
    // The last board is often too short to ever reach the strip; at the end
    // of the page it is the one being read.
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 2) {
      active = tops.length - 1;
    }
    final shown = _gliding ?? active;

    if (shown != _active || revealed.length != _revealed.length) {
      setState(() {
        _active = shown;
        _revealed = revealed;
      });
    }
  }

  Future<void> _glideTo(int index) async {
    final tops = _sectionTops();
    if (tops == null || index >= tops.length || !_scroll.hasClients) return;
    final target = (_scroll.offset + tops[index] - PetStrip.height - 4).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    setState(() {
      _gliding = index;
      _active = index;
      _revealed = {..._revealed, index};
    });
    await _scroll.animateTo(
      target,
      duration: context.motion(const Duration(milliseconds: 420)),
      curve: Motion.emphasized,
    );
    if (!mounted) return;
    // The tapped pet stays lit until the customer scrolls. Re-measuring here
    // would hand a short board near the end of the page to its neighbour
    // when the glide had to stop early at the scroll limit.
    _gliding = null;
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      _measure();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final categories = ref.watch(categoriesProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.categoriesTitle),
        actions: [
          IconButton(
            onPressed: () {
              Haptics.light();
              context.push('/search');
            },
            icon: ZbIcon(
              ZbIconKind.search,
              size: 22,
              ink: context.cs.onSurface,
            ),
            tooltip: l.searchHint,
          ),
          Gap.w4,
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(categoriesProvider(null));
          await ref.read(categoriesProvider(null).future);
        },
        child: AsyncView<List<CategoryNode>>(
          value: categories,
          onRetry: () => ref.invalidate(categoriesProvider(null)),
          skeleton: const _CategoriesSkeleton(),
          builder: (pets) {
            if (pets.isEmpty) {
              return EmptyState(
                icon: Icons.grid_view_rounded,
                title: l.categoriesEmpty,
                message: l.listingEmptyHint,
              );
            }
            if (_sectionKeys.length != pets.length) {
              _sectionKeys = List.generate(pets.length, (_) => GlobalKey());
            }
            _scheduleMeasure();

            return CustomScrollView(
              key: _viewportKey,
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PetStripHeader(
                    pets: pets,
                    active: _active,
                    onSelect: _glideTo,
                  ),
                ),
                SliverPadding(
                  // The floating tab bar's height arrives as bottom padding,
                  // so the last board clears it instead of hiding behind
                  // the glass.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverToBoxAdapter(
                    // One box for all four boards: they are always laid out,
                    // so the strip can measure and glide to any of them.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, pet) in pets.indexed) ...[
                          if (index > 0) Gap.h24,
                          KeyedSubtree(
                            key: _sectionKeys[index],
                            child: PetSection(
                              pet: pet,
                              palette: PetPalette.resolve(
                                context,
                                icon: pet.icon,
                                index: index,
                              ),
                              revealed: _revealed.contains(index),
                              onOpen: _open,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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
  Widget build(BuildContext context) {
    final cs = context.cs;
    Widget card({double height = 104}) => Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(10),
      child: const Row(
        children: [
          SkeletonBox(width: 84, height: 84, radius: ZbTokens.rMd),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonBox(width: 120, height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: 70, height: 10),
            ],
          ),
        ],
      ),
    );

    return ShimmerGroup(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: PetStrip.height,
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonBox.circle(size: 38),
                        SizedBox(height: 7),
                        SkeletonBox(width: 40, height: 10),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: Column(
              children: [
                const SkeletonBox(height: 150, radius: ZbTokens.rXl),
                Gap.h12,
                card(),
                Gap.h8,
                card(),
                Gap.h8,
                const Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(height: 190, radius: ZbTokens.rLg),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: SkeletonBox(height: 190, radius: ZbTokens.rLg),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
