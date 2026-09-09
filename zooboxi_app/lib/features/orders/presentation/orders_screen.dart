import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/data/cart_controller.dart';
import '../../checkout/data/checkout_models.dart';
import '../data/live_tracking.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';
import 'widgets/order_card.dart';

/// The four tabs above the history, and the group each one asks the store for.
///
/// The filtering is the SERVER'S job: a page holds ten orders, so narrowing in
/// the app would show «طلبان مكتملان» to a customer who has thirty and simply
/// has not scrolled far enough to load them.
enum OrdersFilter {
  all(null),
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  const OrdersFilter(this.param);

  /// What goes on the wire. Null means "everything", and sends nothing.
  final String? param;
}

/// «طلباتي» — the order history.
///
/// Three things make it a screen rather than a receipt drawer: the order that
/// is actually moving wears its courier's live sentence, every row carries the
/// one action its state is asking for, and the history is grouped by month so
/// a long list has landmarks instead of being a wall of identical cards.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scroll = ScrollController();
  final List<OrderSummary> _orders = [];

  OrdersFilter _filter = OrdersFilter.all;

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _firstLoading = true;
  bool _loadingMore = false;

  /// A page-1 load in flight — the first one, a filter tap, or a pull. While it
  /// is true no further page may be appended: it was requested against a list
  /// that is about to be thrown away, and appending it would leave page 1
  /// followed by page 4 with twenty orders silently missing in between.
  bool _reloading = false;
  Object? _error;
  Object? _moreError;

  /// Which order is being refilled into the cart right now.
  int? _reordering;

  /// Guards a page that lands after the filter has changed under it.
  int _generation = 0;

  bool get _hasMore => _page < _lastPage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 500) _loadMore();
  }

  Future<void> _loadFirst() async {
    final generation = ++_generation;
    setState(() {
      _firstLoading = _orders.isEmpty;
      _reloading = true;
      // Whatever page was in flight belongs to the list we are replacing. Its
      // result will be dropped by the generation guard, so the flag it set
      // must be cleared HERE — nobody else ever will, and a stuck flag means
      // infinite scroll never fires again for the life of the screen.
      _loadingMore = false;
      _error = null;
      _moreError = null;
    });

    // A guest has no history, and asking for one would 401. Say the empty
    // thing rather than the error thing.
    if (!ref.read(isAuthenticatedProvider)) {
      setState(() {
        _orders.clear();
        _page = 1;
        _lastPage = 1;
        _total = 0;
        // Signing out of a filtered view would otherwise land on «لا طلبات في
        // هذا القسم» — the wrong news, and with no filter bar to escape it.
        _filter = OrdersFilter.all;
        _firstLoading = false;
        _reloading = false;
      });
      return;
    }

    try {
      final page = await ref
          .read(ordersRepositoryProvider)
          .orders(page: 1, status: _filter.param);
      if (!mounted || generation != _generation) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page.orders);
        _page = page.page;
        _lastPage = page.pages;
        _total = page.total;
        _firstLoading = false;
        _reloading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // A refresh that fails on a list already on screen must not replace it
      // with an error page — and must not leave `_error` set either, which
      // would block the next page behind a spinner that never resolves. Say
      // so, and leave the customer reading what they had.
      final loaded = _orders.isNotEmpty;
      setState(() {
        _firstLoading = false;
        _reloading = false;
        _error = loaded ? null : e;
      });
      if (loaded && mounted) {
        AppToast.error(context, errorMessage(context, e));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||
        _firstLoading ||
        _reloading ||
        !_hasMore ||
        _error != null ||
        _moreError != null) {
      return;
    }
    final generation = _generation;
    setState(() => _loadingMore = true);

    try {
      final page = await ref
          .read(ordersRepositoryProvider)
          .orders(page: _page + 1, status: _filter.param);
      if (!mounted || generation != _generation) return;
      setState(() {
        _orders.addAll(page.orders);
        _page = page.page;
        _lastPage = page.pages;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _moreError = e;
      });
    }
  }

  void _select(OrdersFilter filter) {
    if (filter == _filter) return;
    Haptics.selection();
    setState(() => _filter = filter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _orders.clear();
    _loadFirst();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final signedIn = ref.watch(isAuthenticatedProvider);

    // Signing in on another tab must fill this one, and signing out must empty
    // it — the history is fetched once in initState, so nothing else would.
    ref.listen(isAuthenticatedProvider, (_, _) => _loadFirst());

    // And the same for an order that changed while the customer was away:
    // checkout landing, payment settling, payment abandoned.
    ref.listen(ordersRevisionProvider, (_, _) => _loadFirst());

    // The order the customer is waiting on, from the same poll the bar above
    // the tab bar already runs — the list adds no traffic of its own.
    final active = ref.watch(activeOrderProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.ordersTitle),
        bottom: signedIn
            ? _FilterBar(
                selected: _filter,
                onSelect: _select,
                total: _filter == OrdersFilter.all ? _total : null,
              )
            : null,
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _loadFirst,
        child: _body(context, l, active),
      ),
    );
  }

  Widget _body(BuildContext context, L l, ActiveOrder? active) {
    if (_firstLoading) return const _OrdersSkeleton();

    if (_error != null && _orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          ErrorState(error: _error, onRetry: _loadFirst),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // A filtered emptiness is not the same news as having never ordered:
          // one is "try another tab", the other is "go shopping".
          if (_filter == OrdersFilter.all)
            EmptyState(
              icon: Icons.receipt_long_rounded,
              title: l.ordersEmpty,
              message: l.ordersEmptyHint,
              actionLabel: l.cartStartShopping,
              onAction: () => context.go('/home'),
              mascot: true,
            )
          else
            EmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: l.ordersEmptyFiltered,
              message: l.ordersEmptyFilteredHint,
              actionLabel: l.ordersFilterAll,
              onAction: () => _select(OrdersFilter.all),
            ),
        ],
      );
    }

    final rows = _rows(context);

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.paddingOf(context).bottom),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == rows.length) return _footer(l);
        final row = rows[index];

        return switch (row) {
          _MonthRow(:final label) => Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 20, bottom: 10),
              child: Row(
                children: [
                  Text(
                    label,
                    style: context.tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  Gap.w12,
                  Expanded(child: Divider(height: 1, color: context.cs.outlineVariant)),
                ],
              ),
            ),
          _OrderRow(:final order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OrderCard(
                order: order,
                live: active?.order.id == order.id ? active?.tracking : null,
                busy: _reordering == order.id,
                onTap: () => context.push('/orders/${order.id}'),
                onAction: (action) => _act(action, order),
              ),
            ),
        };
      },
    );
  }

  Widget _footer(L l) {
    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() => _moreError = null);
              _loadMore();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l.actionRetry),
          ),
        ),
      );
    }
    if (_loadingMore || _hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  /// Month landmarks, computed once per build over a list that is already in
  /// date order — the server sorts it, so this never has to.
  List<_Row> _rows(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();

    final rows = <_Row>[];
    String? current;

    for (final order in _orders) {
      final date = order.date?.toLocal();
      final label = date == null
          ? null
          : (date.year == now.year && date.month == now.month
              ? l.ordersThisMonth
              : l.ordersMonthYear(Fmt.month(date, locale), '${date.year}'));

      if (label != null && label != current) {
        current = label;
        rows.add(_MonthRow(label));
      }
      rows.add(_OrderRow(order));
    }

    return rows;
  }

  void _act(OrderAction action, OrderSummary order) {
    switch (action) {
      // Neither of these refreshes the list on the way back: a payment that
      // settles bumps [ordersRevisionProvider], and rebuilding page one on
      // every return would drop pages 2..n and dump a customer who was reading
      // order 25 at the bottom of page 1.
      case OrderAction.pay:
        Haptics.light();
        context.push(
          '/checkout/pay',
          extra: PlacedOrder(
            orderId: order.id,
            orderNumber: order.number,
            orderKey: order.orderKey,
            status: order.status,
            total: order.total,
            paymentMethod: order.paymentMethod ?? 'myfatoorah',
            paymentRequired: true,
          ),
        );
      case OrderAction.track:
        Haptics.light();
        context.push('/orders/${order.id}');
      case OrderAction.reorder:
        _reorder(order);
      case OrderAction.none:
        break;
    }
  }

  /// Refills the cart from a past order, said honestly — "3 added, 1
  /// unavailable" — because silently dropping a line is how someone discovers
  /// at the door that half the order is missing.
  Future<void> _reorder(OrderSummary order) async {
    if (_reordering != null) return;
    final l = L.of(context);
    setState(() => _reordering = order.id);

    try {
      final result = await ref.read(ordersRepositoryProvider).reorder(order.id);
      ref.read(cartControllerProvider.notifier).applyServerCart(result.cart);
      if (!mounted) return;
      await Haptics.success();
      if (!mounted) return;

      setState(() => _reordering = null);
      if (result.missing.isEmpty) {
        AppToast.success(context, l.orderReorderAdded(result.added));
      } else {
        AppToast.info(
          context,
          '${l.orderReorderAdded(result.added)} · ${l.orderReorderMissing(result.missing.length)}',
        );
      }
      context.go('/cart');
    } catch (e) {
      if (!mounted) return;
      setState(() => _reordering = null);
      Haptics.warning();
      AppToast.error(context, errorMessage(context, e));
    }
  }
}

/* ── Rows ───────────────────────────────────────────────────────── */

sealed class _Row {
  const _Row();
}

class _MonthRow extends _Row {
  const _MonthRow(this.label);
  final String label;
}

class _OrderRow extends _Row {
  const _OrderRow(this.order);
  final OrderSummary order;
}

/* ── The tabs ───────────────────────────────────────────────────── */

/// Four pills under the title.
///
/// A [PreferredSizeWidget] rather than a sliver: it belongs to the app bar, so
/// it stays put while the history scrolls under it — which is the whole reason
/// to have it.
class _FilterBar extends StatelessWidget implements PreferredSizeWidget {
  const _FilterBar({required this.selected, required this.onSelect, this.total});

  final OrdersFilter selected;
  final void Function(OrdersFilter filter) onSelect;

  /// Shown beside «الكل» once the store has said how many there are.
  final int? total;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    String label(OrdersFilter f) => switch (f) {
          OrdersFilter.all => total == null || total == 0
              ? l.ordersFilterAll
              : '${l.ordersFilterAll} ($total)',
          OrdersFilter.active => l.ordersFilterActive,
          OrdersFilter.completed => l.ordersFilterCompleted,
          OrdersFilter.cancelled => l.ordersFilterCancelled,
        };

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          for (final f in OrdersFilter.values) ...[
            _Pill(
              label: label(f),
              selected: f == selected,
              onTap: () => onSelect(f),
            ),
            Gap.w8,
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Material(
      color: selected ? cs.primary : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              label,
              style: context.tt.labelMedium?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ── Loading ────────────────────────────────────────────────────── */

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.paddingOf(context).bottom),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (_, _) => Gap.h12,
          itemBuilder: (_, _) => const SkeletonBox(
            width: double.infinity,
            height: 150,
            radius: ZbTokens.rLg,
          ),
        ),
      );
}
